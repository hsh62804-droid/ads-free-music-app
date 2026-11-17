"""Jamendo Music Source client."""
import logging
from typing import List, Optional
import httpx

from app.schemas import SongRead, StreamInfo
from app.services.sources.base import MusicSource, DEFAULT_TIMEOUT, fetch_with_retry

logger = logging.getLogger(__name__)

JAMENDO_API_BASE = "https://api.jamendo.com/v3.0"


class JamendoSource(MusicSource):
    """Jamendo music source using Jamendo v3.0 REST API."""

    def __init__(self, client_id: Optional[str] = None):
        self.client_id = client_id.strip() if client_id else None

    @property
    def name(self) -> str:
        return "jamendo"

    @property
    def is_configured(self) -> bool:
        """True if Jamendo client_id has been provided."""
        return bool(self.client_id)

    def _parse_track(self, track: dict) -> SongRead:
        """Convert a Jamendo track item into SongRead schema."""
        raw_id = str(track.get("id"))
        genre = None
        musicinfo = track.get("musicinfo")
        if isinstance(musicinfo, dict):
            tags = musicinfo.get("tags", {})
            if isinstance(tags, dict) and tags.get("genres"):
                genres = tags.get("genres")
                genre = genres[0] if isinstance(genres, list) and genres else str(genres)

        return SongRead(
            id=f"jamendo:{raw_id}",
            source="jamendo",
            source_id=raw_id,
            title=track.get("name") or "Untitled Track",
            artist=track.get("artist_name") or "Unknown Artist",
            album=track.get("album_name"),
            duration_seconds=int(track.get("duration") or 0),
            artwork_url=track.get("image") or track.get("album_image"),
            genre=genre,
            stream_url=track.get("audio"),
        )

    async def search(self, query: str, limit: int = 20) -> List[SongRead]:
        """Search Jamendo catalog."""
        if not self.is_configured:
            logger.info("Jamendo client ID not configured; skipping Jamendo search.")
            return []

        if not query.strip():
            return []

        async with httpx.AsyncClient(timeout=DEFAULT_TIMEOUT) as client:
            try:
                params = {
                    "client_id": self.client_id,
                    "format": "json",
                    "limit": limit,
                    "search": query,
                    "audioformat": "mp32",
                    "include": "musicinfo",
                }
                response = await fetch_with_retry(client, "GET", f"{JAMENDO_API_BASE}/tracks/", params=params)
                if response and response.status_code == 200:
                    data = response.json().get("results", [])
                    return [self._parse_track(t) for t in data if isinstance(t, dict)]
            except Exception as e:
                logger.error("Jamendo search failed: %s", e)
            return []

    async def trending(self, limit: int = 20) -> List[SongRead]:
        """Fetch popular / trending tracks on Jamendo."""
        if not self.is_configured:
            logger.info("Jamendo client ID not configured; skipping Jamendo trending.")
            return []

        async with httpx.AsyncClient(timeout=DEFAULT_TIMEOUT) as client:
            try:
                params = {
                    "client_id": self.client_id,
                    "format": "json",
                    "limit": limit,
                    "order": "popularity_total",
                    "audioformat": "mp32",
                    "include": "musicinfo",
                }
                response = await fetch_with_retry(client, "GET", f"{JAMENDO_API_BASE}/tracks/", params=params)
                if response and response.status_code == 200:
                    data = response.json().get("results", [])
                    return [self._parse_track(t) for t in data if isinstance(t, dict)]
            except Exception as e:
                logger.error("Jamendo trending failed: %s", e)
            return []

    async def get_stream_url(self, source_id: str) -> StreamInfo:
        """Fetch direct streaming URL for Jamendo track."""
        if not self.is_configured:
            raise ValueError("Jamendo client ID is not configured.")

        async with httpx.AsyncClient(timeout=DEFAULT_TIMEOUT) as client:
            params = {
                "client_id": self.client_id,
                "format": "json",
                "id": source_id,
                "audioformat": "mp32",
            }
            response = await fetch_with_retry(client, "GET", f"{JAMENDO_API_BASE}/tracks/", params=params)
            if not response or response.status_code != 200:
                raise ValueError(f"Jamendo track '{source_id}' could not be retrieved.")

            results = response.json().get("results", [])
            if not results:
                raise ValueError(f"Jamendo track '{source_id}' not found.")

            track = results[0]
            audio_url = track.get("audio")
            if not audio_url:
                raise ValueError("No audio URL found for this Jamendo track.")

            return StreamInfo(
                song_id=f"jamendo:{source_id}",
                stream_url=audio_url,
                format="mp3",
                bitrate_kbps=192,
                is_direct_url=True,
            )

    async def get_track(self, source_id: str) -> Optional[SongRead]:
        """Fetch track metadata."""
        if not self.is_configured:
            return None

        async with httpx.AsyncClient(timeout=DEFAULT_TIMEOUT) as client:
            try:
                params = {
                    "client_id": self.client_id,
                    "format": "json",
                    "id": source_id,
                    "audioformat": "mp32",
                    "include": "musicinfo",
                }
                response = await fetch_with_retry(client, "GET", f"{JAMENDO_API_BASE}/tracks/", params=params)
                if response and response.status_code == 200:
                    results = response.json().get("results", [])
                    if results:
                        return self._parse_track(results[0])
            except Exception as e:
                logger.error("Failed to fetch Jamendo track %s: %s", source_id, e)
        return None
