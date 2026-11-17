"""Deezer music source provider implementation."""
import logging
from typing import List, Optional
import httpx

from app.schemas import SongRead, StreamInfo, ArtistRead
from app.services.sources.base import MusicSource, DEFAULT_TIMEOUT, fetch_with_retry

logger = logging.getLogger(__name__)


class DeezerSource(MusicSource):
    """Provides tracks, search, charts, and 30-second previews via public Deezer API."""

    BASE_URL = "https://api.deezer.com"

    def __init__(self, timeout: httpx.Timeout = DEFAULT_TIMEOUT):
        self._timeout = timeout
        self._headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json",
        }

    @property
    def name(self) -> str:
        return "deezer"

    @property
    def is_configured(self) -> bool:
        # Deezer public endpoints require no API key
        return True

    def _parse_track(self, item: dict) -> SongRead:
        """Map raw Deezer JSON track object to SongRead schema."""
        artist_obj = item.get("artist") or {}
        artist_name = artist_obj.get("name") if isinstance(artist_obj, dict) else str(artist_obj or "Unknown Artist")
        
        album_obj = item.get("album") or {}
        album_title = album_obj.get("title") if isinstance(album_obj, dict) else None
        
        # Prefer cover_xl (1000x1000) for gorgeous album posters
        artwork = None
        if isinstance(album_obj, dict):
            artwork = album_obj.get("cover_xl") or album_obj.get("cover_big") or album_obj.get("cover_medium")
        if not artwork and isinstance(artist_obj, dict):
            artwork = artist_obj.get("picture_xl") or artist_obj.get("picture_big")

        source_id = str(item.get("id", ""))
        preview_url = item.get("preview") or None

        return SongRead(
            id=f"deezer:{source_id}",
            source="deezer",
            source_id=source_id,
            title=item.get("title_short") or item.get("title") or "Untitled Track",
            artist=artist_name,
            album=album_title,
            duration_seconds=int(item.get("duration") or 30),
            artwork_url=artwork,
            stream_url=preview_url,
            genre=None,
            is_preview=True,
        )

    async def trending(self, limit: int = 30) -> List[SongRead]:
        """Fetch trending chart tracks from Deezer."""
        try:
            async with httpx.AsyncClient(timeout=self._timeout, headers=self._headers) as client:
                # 1. First attempt /chart/0/tracks
                r = await fetch_with_retry(client, "GET", f"{self.BASE_URL}/chart/0/tracks?limit={limit}")
                if r and r.status_code == 200:
                    data = r.json().get("data", [])
                    if data:
                        return [self._parse_track(t) for t in data[:limit]]

                # 2. Fallback to Deezer Global Top 50 playlist
                r_pl = await fetch_with_retry(client, "GET", f"{self.BASE_URL}/playlist/3155776842")
                if r_pl and r_pl.status_code == 200:
                    tracks = r_pl.json().get("tracks", {}).get("data", [])
                    if tracks:
                        return [self._parse_track(t) for t in tracks[:limit]]

                # 3. Fallback to /chart general endpoint
                r_chart = await fetch_with_retry(client, "GET", f"{self.BASE_URL}/chart")
                if r_chart and r_chart.status_code == 200:
                    tracks = r_chart.json().get("tracks", {}).get("data", [])
                    return [self._parse_track(t) for t in tracks[:limit]]
        except Exception as e:
            logger.warning("Deezer trending request failed: %s", e)

        return []

    async def search(self, query: str, limit: int = 20) -> List[SongRead]:
        """Search tracks via Deezer search API."""
        try:
            async with httpx.AsyncClient(timeout=self._timeout, headers=self._headers) as client:
                r = await fetch_with_retry(client, "GET", f"{self.BASE_URL}/search", params={"q": query, "limit": limit})
                if r and r.status_code == 200:
                    data = r.json().get("data", [])
                    return [self._parse_track(t) for t in data[:limit]]
        except Exception as e:
            logger.warning("Deezer search failed for query '%s': %s", query, e)

        return []

    async def get_stream_url(self, source_id: str) -> StreamInfo:
        """Resolve preview MP3 stream URL for Deezer track."""
        track = await self.get_track(source_id)
        stream_url = track.stream_url if track else None

        if not stream_url:
            # Fallback to direct track lookup
            try:
                async with httpx.AsyncClient(timeout=self._timeout, headers=self._headers) as client:
                    r = await fetch_with_retry(client, "GET", f"{self.BASE_URL}/track/{source_id}")
                    if r and r.status_code == 200:
                        stream_url = r.json().get("preview")
            except Exception as e:
                logger.warning("Failed to fetch stream url for deezer:%s: %s", source_id, e)

        if not stream_url:
            raise ValueError(f"No preview audio available for deezer track {source_id}")

        return StreamInfo(
            song_id=f"deezer:{source_id}",
            stream_url=stream_url,
            format="mp3",
            bitrate_kbps=128,
            is_direct_url=True,
        )

    async def get_track(self, source_id: str) -> Optional[SongRead]:
        """Fetch full metadata for a single Deezer track."""
        try:
            async with httpx.AsyncClient(timeout=self._timeout, headers=self._headers) as client:
                r = await fetch_with_retry(client, "GET", f"{self.BASE_URL}/track/{source_id}")
                if r and r.status_code == 200:
                    data = r.json()
                    if "id" in data:
                        return self._parse_track(data)
        except Exception as e:
            logger.warning("Deezer track lookup failed for %s: %s", source_id, e)

        return None

    async def get_top_artists(self, limit: int = 15) -> List[ArtistRead]:
        """Fetch current top trending artists from Deezer chart."""
        try:
            async with httpx.AsyncClient(timeout=self._timeout, headers=self._headers) as client:
                r = await fetch_with_retry(client, "GET", f"{self.BASE_URL}/chart")
                if r and r.status_code == 200:
                    artists = r.json().get("artists", {}).get("data", [])
                    return [
                        ArtistRead(
                            id=str(a.get("id", "")),
                            name=a.get("name", "Unknown Artist"),
                            picture_url=a.get("picture_xl") or a.get("picture_big") or a.get("picture_medium"),
                            track_count=a.get("nb_fan"),
                        )
                        for a in artists[:limit]
                    ]
        except Exception as e:
            logger.warning("Deezer top artists lookup failed: %s", e)

        return []
