"""Local music source provider scanning backend/music/ with mutagen."""
import hashlib
import logging
import os
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import httpx
import mutagen
from mutagen.easyid3 import EasyID3

from app.schemas import SongRead, StreamInfo
from app.services.sources.base import MusicSource

logger = logging.getLogger(__name__)

SUPPORTED_EXTENSIONS = {".mp3", ".flac", ".m4a", ".ogg", ".opus", ".wav", ".aac"}


def normalize_string(val: str) -> str:
    """Normalize string for fuzzy title/artist matching (lowercase, alphanumeric only)."""
    if not val:
        return ""
    # Remove text in parentheses/brackets e.g. (feat. ...), [Official Video]
    cleaned = re.sub(r"[\(\[\{].*?[\)\]\}]", "", val)
    # Strip non-alphanumeric characters
    cleaned = re.sub(r"[^a-zA-Z0-9\s]", "", cleaned)
    return " ".join(cleaned.lower().split())


class LocalSource(MusicSource):
    """Scans and serves full local music files from backend/music/."""

    def __init__(self, music_dir: Optional[str] = None):
        if music_dir:
            self.music_dir = Path(music_dir)
        else:
            # Default to backend/music
            self.music_dir = Path(__file__).resolve().parent.parent.parent.parent / "music"

        self.covers_dir = Path(__file__).resolve().parent.parent.parent.parent / "cache" / "covers"
        self.covers_dir.mkdir(parents=True, exist_ok=True)
        self.music_dir.mkdir(parents=True, exist_ok=True)

        self._tracks_by_id: Dict[str, Tuple[SongRead, Path]] = {}
        # Key: (normalized_artist, normalized_title) -> local_id
        self._match_index: Dict[Tuple[str, str], str] = {}
        self.scan_files()

    @property
    def name(self) -> str:
        return "local"

    @property
    def is_configured(self) -> bool:
        return True

    def rescan(self) -> int:
        """Public rescan trigger for POST /library/rescan."""
        return self.scan_files()

    def scan_files(self) -> int:
        """Scan music directory, parse audio tags with mutagen, and build in-memory indexes."""
        self._tracks_by_id.clear()
        self._match_index.clear()

        if not self.music_dir.exists():
            return 0

        scanned = 0
        for root, _, files in os.walk(self.music_dir):
            for f in files:
                ext = Path(f).suffix.lower()
                if ext in SUPPORTED_EXTENSIONS:
                    file_path = Path(root) / f
                    try:
                        song = self._read_metadata(file_path)
                        if song:
                            self._tracks_by_id[song.source_id] = (song, file_path)
                            norm_artist = normalize_string(song.artist)
                            norm_title = normalize_string(song.title)
                            self._match_index[(norm_artist, norm_title)] = song.source_id
                            scanned += 1
                    except Exception as e:
                        logger.warning("Failed to parse local audio file %s: %s", file_path, e)

        logger.info("LocalSource: scanned %d local audio track(s) from %s", scanned, self.music_dir)
        return scanned

    def _extract_embedded_cover(self, file_path: Path) -> Optional[bytes]:
        """Extract embedded cover image bytes using mutagen."""
        try:
            raw = mutagen.File(file_path)
            if raw is None:
                return None

            # 1. ID3 (mp3)
            if hasattr(raw, "tags") and raw.tags:
                for tag in raw.tags.values():
                    if tag.__class__.__name__ == "APIC":
                        return getattr(tag, "data", None)

            # 2. FLAC
            if hasattr(raw, "pictures") and raw.pictures:
                return raw.pictures[0].data

            # 3. MP4 / M4A
            if hasattr(raw, "tags") and raw.tags and "covr" in raw.tags:
                covers = raw.tags["covr"]
                if covers:
                    return bytes(covers[0])

            # 4. OGG / Opus
            if hasattr(raw, "tags") and raw.tags and "metadata_block_picture" in raw.tags:
                import base64
                from mutagen.flac import Picture
                pic_data = base64.b64decode(raw.tags["metadata_block_picture"][0])
                pic = Picture(pic_data)
                return pic.data
        except Exception as e:
            logger.debug("Embedded cover extraction failed for %s: %s", file_path, e)
        return None

    def _enrich_cover_from_deezer(self, title: str, artist: str, source_id: str) -> Optional[str]:
        """Fetch album poster from Deezer if local file has no embedded artwork."""
        cover_path = self.covers_dir / f"{source_id}.jpg"
        if cover_path.exists():
            return f"/songs/local:{source_id}/cover"

        try:
            query = f"{title} {artist}".strip()
            with httpx.Client(timeout=4.0) as client:
                res = client.get("https://api.deezer.com/search", params={"q": query, "limit": 1})
                if res.status_code == 200:
                    data = res.json()
                    tracks = data.get("data", [])
                    if tracks:
                        track = tracks[0]
                        album = track.get("album", {})
                        cover_url = album.get("cover_xl") or album.get("cover_big") or album.get("cover")
                        if cover_url:
                            img_res = client.get(cover_url)
                            if img_res.status_code == 200:
                                cover_path.write_bytes(img_res.content)
                                return f"/songs/local:{source_id}/cover"
                            return cover_url
        except Exception as e:
            logger.debug("Deezer cover lookup skipped for %s - %s: %s", artist, title, e)
        return None

    def _read_metadata(self, file_path: Path) -> Optional[SongRead]:
        """Extract tags, duration, and cover using mutagen."""
        # Stable unique ID from relative path
        rel_path = file_path.relative_to(self.music_dir).as_posix()
        source_id = hashlib.sha1(rel_path.encode("utf-8")).hexdigest()[:12]

        title = file_path.stem
        artist = "Local Artist"
        album = None
        genre = None
        duration_sec = 0

        try:
            audio = mutagen.File(file_path, easy=True)
            if audio is not None:
                if audio.info:
                    duration_sec = int(getattr(audio.info, "length", 0))

                title = audio.get("title", [title])[0]
                artist = audio.get("artist", [artist])[0]
                album = audio.get("album", [None])[0]
                genre = audio.get("genre", [None])[0]
        except Exception:
            pass

        # If artist is still default and filename has "Artist - Title" format, extract them
        if (artist == "Local Artist" or not artist) and " - " in file_path.stem:
            parts = file_path.stem.split(" - ", 1)
            artist = parts[0].strip()
            title = parts[1].strip()

        # Cover resolution: embedded cover first, Deezer fallback second
        artwork_url = None
        cover_path = self.covers_dir / f"{source_id}.jpg"
        if cover_path.exists():
            artwork_url = f"/songs/local:{source_id}/cover"
        else:
            embedded_data = self._extract_embedded_cover(file_path)
            if embedded_data:
                try:
                    cover_path.write_bytes(embedded_data)
                    artwork_url = f"/songs/local:{source_id}/cover"
                except Exception as e:
                    logger.warning("Could not cache embedded cover: %s", e)
            else:
                artwork_url = self._enrich_cover_from_deezer(title, artist, source_id)

        return SongRead(
            id=f"local:{source_id}",
            source="local",
            source_id=source_id,
            title=title,
            artist=artist,
            album=album,
            duration_seconds=duration_sec,
            artwork_url=artwork_url,
            stream_url=f"/songs/local:{source_id}/stream",
            genre=genre,
            is_preview=False,
            is_full=True,
        )

    def find_match(self, artist: str, title: str) -> Optional[SongRead]:
        """Check if an external song has a matching full local file."""
        norm_artist = normalize_string(artist)
        norm_title = normalize_string(title)

        # 1. Exact match on normalized (artist, title)
        source_id = self._match_index.get((norm_artist, norm_title))
        if source_id and source_id in self._tracks_by_id:
            return self._tracks_by_id[source_id][0]

        # 2. Relaxed matching: check if titles match and artists intersect
        for (idx_artist, idx_title), s_id in self._match_index.items():
            if idx_title == norm_title and (idx_artist in norm_artist or norm_artist in idx_artist):
                return self._tracks_by_id[s_id][0]

        return None

    def get_file_path(self, source_id: str) -> Optional[Path]:
        """Get absolute path for local track."""
        if source_id in self._tracks_by_id:
            return self._tracks_by_id[source_id][1]
        return None

    def get_cover_path(self, source_id: str) -> Optional[Path]:
        """Get path for cached cover image."""
        cover_path = self.covers_dir / f"{source_id}.jpg"
        if cover_path.exists():
            return cover_path
        return None

    async def search(self, query: str, limit: int = 20) -> List[SongRead]:
        """Search local tracks by title or artist."""
        q = query.lower()
        results: List[SongRead] = []
        for song, _ in self._tracks_by_id.values():
            if q in song.title.lower() or q in song.artist.lower():
                results.append(song)
                if len(results) >= limit:
                    break
        return results

    async def trending(self, limit: int = 20) -> List[SongRead]:
        """Return available local tracks."""
        return [song for song, _ in list(self._tracks_by_id.values())[:limit]]

    async def get_stream_url(self, source_id: str) -> StreamInfo:
        """Return internal streaming URL for local file."""
        if source_id not in self._tracks_by_id:
            raise ValueError(f"Local file with ID {source_id} not found.")

        song, file_path = self._tracks_by_id[source_id]
        ext = file_path.suffix.lstrip(".").lower()
        return StreamInfo(
            song_id=f"local:{source_id}",
            stream_url=f"/songs/local:{source_id}/stream",
            format=ext,
            bitrate_kbps=320,
            is_direct_url=True,
        )

    async def get_track(self, source_id: str) -> Optional[SongRead]:
        """Get local track by ID."""
        if source_id in self._tracks_by_id:
            return self._tracks_by_id[source_id][0]
        return None
