"""Routers for song metadata and streaming with HTTP Range support for local files."""
import mimetypes
import os
from typing import Generator
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from fastapi.responses import RedirectResponse, StreamingResponse
import httpx
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Like
from app.schemas import SongRead, StreamInfo
from app.services.sources.manager import source_manager

router = APIRouter(prefix="/songs", tags=["songs"])


async def proxy_remote_stream(stream_url: str, request: Request) -> StreamingResponse:
    """Stream remote audio through backend with Range support and CORS headers for web browsers."""
    headers = {}
    range_header = request.headers.get("range")
    if range_header:
        headers["Range"] = range_header

    client = httpx.AsyncClient(timeout=30.0, follow_redirects=True)
    try:
        req = client.build_request("GET", stream_url, headers=headers)
        resp = await client.send(req, stream=True)
    except Exception as e:
        await client.aclose()
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Unable to proxy remote stream: {e}",
        )

    resp_headers = {
        "Accept-Ranges": "bytes",
        "Content-Type": resp.headers.get("content-type", "audio/mpeg"),
    }
    if "content-range" in resp.headers:
        resp_headers["Content-Range"] = resp.headers["content-range"]
    if "content-length" in resp.headers:
        resp_headers["Content-Length"] = resp.headers["content-length"]

    async def stream_generator():
        try:
            async for chunk in resp.aiter_bytes(chunk_size=65536):
                yield chunk
        finally:
            await resp.aclose()
            await client.aclose()

    return StreamingResponse(
        stream_generator(),
        status_code=resp.status_code,
        headers=resp_headers,
    )


def range_streamer(file_path: str, start: int, chunk_size: int, block_size: int = 65536) -> Generator[bytes, None, None]:
    """Stream a byte range from a file chunk by chunk."""
    with open(file_path, "rb") as f:
        f.seek(start)
        remaining = chunk_size
        while remaining > 0:
            read_size = min(block_size, remaining)
            data = f.read(read_size)
            if not data:
                break
            remaining -= len(data)
            yield data


@router.get("/{id:path}/stream")
async def get_song_stream(
    id: str,
    request: Request,
    redirect: bool = Query(
        True,
        description="If True, returns HTTP 302 redirect for external sources or streams local file. If False, returns StreamInfo JSON.",
    ),
    proxy: bool = Query(
        False,
        description="If True, proxies audio through backend with proper CORS and Range headers for web browser compatibility.",
    ),
):
    """Resolve and stream audio with HTTP Range support for local files."""
    if not redirect:
        try:
            stream_info = await source_manager.get_stream_url(id)
            return stream_info
        except ValueError as e:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
        except Exception as e:
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=f"Unable to resolve stream info: {e}")

    # Handle local file streaming with HTTP Range support
    if id.startswith("local:"):
        source_id = id.split("local:", 1)[1]
        file_path = source_manager.local.get_file_path(source_id)
        if not file_path or not os.path.exists(file_path):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Local track '{source_id}' not found.")

        file_size = os.path.getsize(file_path)
        content_type, _ = mimetypes.guess_type(str(file_path))
        if not content_type:
            content_type = "audio/mpeg"

        range_header = request.headers.get("range")
        if range_header:
            # Parse Range: bytes=start-end
            try:
                range_str = range_header.replace("bytes=", "").strip()
                parts = range_str.split("-")
                start = int(parts[0]) if parts[0] else 0
                end = int(parts[1]) if len(parts) > 1 and parts[1] else file_size - 1
                end = min(end, file_size - 1)
                chunk_size = (end - start) + 1

                headers = {
                    "Content-Range": f"bytes {start}-{end}/{file_size}",
                    "Accept-Ranges": "bytes",
                    "Content-Length": str(chunk_size),
                    "Content-Type": content_type,
                }
                return StreamingResponse(
                    range_streamer(str(file_path), start, chunk_size),
                    status_code=status.HTTP_206_PARTIAL_CONTENT,
                    headers=headers,
                )
            except Exception as e:
                raise HTTPException(status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE, detail=str(e))

        # No range requested: return full audio stream
        headers = {
            "Accept-Ranges": "bytes",
            "Content-Length": str(file_size),
            "Content-Type": content_type,
        }
        return StreamingResponse(
            range_streamer(str(file_path), 0, file_size),
            status_code=status.HTTP_200_OK,
            headers=headers,
        )

    # For external sources (Deezer, iTunes, Audius, Jamendo)
    try:
        stream_info = await source_manager.get_stream_url(id)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Unable to resolve audio stream: {e}",
        )

    if proxy:
        if not stream_info.is_direct_url and stream_info.format == "youtube":
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Unable to extract direct audio stream for this YouTube track.",
            )
        return await proxy_remote_stream(stream_info.stream_url, request)

    return RedirectResponse(
        url=stream_info.stream_url,
        status_code=status.HTTP_302_FOUND,
    )


@router.get("/{id:path}/cover")
async def get_song_cover(id: str):
    """Serve cached or embedded local cover artwork."""
    from fastapi.responses import FileResponse
    clean_id = id.removeprefix("local:")
    cover_path = source_manager.local.get_cover_path(clean_id)
    if cover_path and cover_path.exists():
        return FileResponse(str(cover_path), media_type="image/jpeg")
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cover artwork not found.")


@router.get("/{id:path}/full_version", response_model=SongRead)
async def get_song_full_version(
    id: str,
    db: Session = Depends(get_db),
):
    """Resolve a full-length version (e.g. from local or official YouTube Data API v3) for preview tracks."""
    try:
        song = await source_manager.get_song(id, db=db)
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=f"Error looking up track: {e}")

    if not song:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Song '{id}' not found.")

    if song.is_full:
        return song

    full = await source_manager.find_full_version(song)
    if full:
        return full

    return song


@router.get("/{id:path}", response_model=SongRead)
async def get_song_details(
    id: str,
    db: Session = Depends(get_db),
):
    """Retrieve full metadata for a song by unified ID."""
    try:
        song = await source_manager.get_song(id, db=db)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Error fetching song details: {e}",
        )

    if not song:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Song with ID '{id}' not found.",
        )

    # Attach is_liked status
    like_entry = db.query(Like).filter(Like.song_id == id).first()
    return song.model_copy(update={"is_liked": like_entry is not None})
