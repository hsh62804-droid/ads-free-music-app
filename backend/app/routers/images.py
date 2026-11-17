"""Image proxy router with disk caching and CORS headers for Flutter Web compatibility."""
import hashlib
import mimetypes
import os
from pathlib import Path
import time
from urllib.parse import urlparse
from fastapi import APIRouter, HTTPException, Query, Response, status
import httpx

router = APIRouter(tags=["images"])

# Disk cache directory for proxied images (7 days TTL)
CACHE_DIR = Path(__file__).resolve().parent.parent.parent / "cache" / "images"
CACHE_DIR.mkdir(parents=True, exist_ok=True)
CACHE_TTL_SECONDS = 7 * 24 * 3600  # 7 days

# Allowed hostnames for security (reject arbitrary SSRF)
ALLOWED_DOMAINS = [
    "i.ytimg.com",
    "ytimg.com",
    "img.youtube.com",
    "e-cdns-images.dzcdn.net",
    "cdns-images.dzcdn.net",
    "cdn-images.dzcdn.net",
    "mzstatic.com",
    "is1-ssl.mzstatic.com",
    "is2-ssl.mzstatic.com",
    "is3-ssl.mzstatic.com",
    "is4-ssl.mzstatic.com",
    "is5-ssl.mzstatic.com",
    "audius.co",
    "jamendo.com",
    "usercontent.jamendo.com",
]


def is_host_allowed(host: str) -> bool:
    """Validate that the host is in our allowed domains whitelist."""
    host = host.lower()
    for allowed in ALLOWED_DOMAINS:
        if host == allowed or host.endswith("." + allowed):
            return True
    return False


@router.get("/image")
@router.head("/image")
@router.get("/images")
@router.head("/images")
async def proxy_image(url: str = Query(..., description="Remote image URL to proxy and cache")):
    """Download, disk-cache for 7 days, and serve images with open CORS headers."""
    parsed = urlparse(url)
    if not parsed.scheme or not parsed.netloc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid image URL format.",
        )

    if not is_host_allowed(parsed.netloc):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Host '{parsed.netloc}' is not allowed for image proxy.",
        )

    # Determine cache file path using SHA256 of the URL
    url_hash = hashlib.sha256(url.encode("utf-8")).hexdigest()
    ext = os.path.splitext(parsed.path)[1].lower() or ".jpg"
    if ext not in [".jpg", ".jpeg", ".png", ".webp", ".gif"]:
        ext = ".jpg"
    cache_file = CACHE_DIR / f"{url_hash}{ext}"

    # Check if cached file exists and is younger than 7 days
    if cache_file.exists():
        age = time.time() - cache_file.stat().st_mtime
        if age < CACHE_TTL_SECONDS:
            content = cache_file.read_bytes()
            content_type = mimetypes.guess_type(str(cache_file))[0] or "image/jpeg"
            return Response(
                content=content,
                media_type=content_type,
                headers={
                    "Cache-Control": f"public, max-age={CACHE_TTL_SECONDS}, immutable",
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "GET, OPTIONS",
                    "X-Image-Cache": "HIT",
                },
            )

    # Fetch from remote source with strict timeout
    try:
        async with httpx.AsyncClient(timeout=8.0, follow_redirects=True) as client:
            resp = await client.get(url)
            if resp.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"Upstream image server responded with status {resp.status_code}",
                )

            image_bytes = resp.content
            content_type = resp.headers.get("content-type") or mimetypes.guess_type(url)[0] or "image/jpeg"

            # Save to disk cache
            try:
                cache_file.write_bytes(image_bytes)
            except Exception:
                pass

            return Response(
                content=image_bytes,
                media_type=content_type,
                headers={
                    "Cache-Control": f"public, max-age={CACHE_TTL_SECONDS}, immutable",
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "GET, OPTIONS",
                    "X-Image-Cache": "MISS",
                },
            )
    except httpx.RequestError as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to fetch remote image: {e}",
        )
