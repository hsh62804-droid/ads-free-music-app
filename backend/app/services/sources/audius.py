"""Audius Music Source client."""
import logging
from typing import List, Optional
import httpx

from app.schemas import SongRead, StreamInfo
from app.services.sources.base import MusicSource, DEFAULT_TIMEOUT, fetch_with_retry

logger = logging.getLogger(__name__)

# Fallback discovery nodes in case api.audius.co is slow or down
DEFAULT_FALLBACK_HOSTS = [
    "https://api.audius.co",
    "https://discoveryprovider.audius.co",
    "https://audius-discovery-1.cultur3stake.com",
    "https://discoveryprovider2.audius.co",
]


class AudiusSource(MusicSource):
    """Audius decentralized streaming source."""

    def __init__(self, app_name: str = "PersonalSpotifyClone"):
        self.app_name = app_name
        self._cached_host: Optional[str] = None

    @property
    def name(self) -> str:
        return "audius"

    @property
    def is_configured(self) -> bool:
        # Audius requires no API keys and is always active
        return True

    async def _get_host(self, client: httpx.AsyncClient) -> str:
        """Resolve a healthy Audius discovery node."""
        if self._cached_host:
            return self._cached_host

        try:
            resp = await fetch_with_retry(client, "GET", "https://api.audius.co", max_retries=1)
            if resp and resp.status_code == 200:
                data = resp.json().get("data", [])
                if data and isinstance(data, list):
                    self._cached_host = data[0].rstrip("/")
                    return self._cached_host
        except Exception as e:
            logger.warning("Failed to auto-select Audius host: %s, using fallback", e)

        # Fallback to the first healthy default host
        for host in DEFAULT_FALLBACK_HOSTS:
            try:
                resp = await client.get(f"{host}/v1/health_check", timeout=DEFAULT_TIMEOUT)
                if resp.status_code == 200:
                    self._cached_host = host
                    return self._cached_host
            except Exception:
                continue

        # If all health checks fail, default to primary
        self._cached_host = DEFAULT_FALLBACK_HOSTS[0]
        return self._cached_host

    def _parse_track(self, host: str, track: dict) -> SongRead:
        """Convert an Audius raw track dict into standard SongRead schema."""
        raw_id = str(track.get("id"))
        artwork = track.get("artwork") or {}
        artwork_url = (
            artwork.get("1000x1000")
            or artwork.get("480x480")
            or artwork.get("150x150")
        )

        user = track.get("user") or {}
        artist_name = user.get("name") or user.get("handle") or "Unknown Artist"

        stream_url = f"{host}/v1/tracks/{raw_id}/stream?app_name={self.app_name}"

        return SongRead(
            id=f"audius:{raw_id}",
            source="audius",
            source_id=raw_id,
            title=track.get("title") or "Untitled Track",
            artist=artist_name,
            album=None,
            duration_seconds=int(track.get("duration") or 0),
            artwork_url=artwork_url,
            genre=track.get("genre"),
            stream_url=stream_url,
        )

    async def search(self, query: str, limit: int = 20) -> List[SongRead]:
        """Search tracks on Audius."""
        if not query.strip():
            return []

        async with httpx.AsyncClient(timeout=DEFAULT_TIMEOUT, follow_redirects=True) as client:
            host = await self._get_host(client)
            try:
                response = await fetch_with_retry(
                    client,
                    "GET",
                    f"{host}/v1/tracks/search",
                    params={"query": query, "app_name": self.app_name, "limit": limit},
                )
                if response and response.status_code == 200:
                    data = response.json().get("data", [])
                    return [self._parse_track(host, t) for t in data if isinstance(t, dict)]
            except Exception as e:
                logger.error("Audius search failed for query '%s': %s", query, e)
            return []

    async def trending(self, limit: int = 20) -> List[SongRead]:
        """Get trending tracks on Audius."""
        async with httpx.AsyncClient(timeout=DEFAULT_TIMEOUT, follow_redirects=True) as client:
            host = await self._get_host(client)
            try:
                response = await fetch_with_retry(
                    client,
                    "GET",
                    f"{host}/v1/tracks/trending",
                    params={"app_name": self.app_name, "limit": limit},
                )
                if response and response.status_code == 200:
                    data = response.json().get("data", [])
                    return [self._parse_track(host, t) for t in data if isinstance(t, dict)]
            except Exception as e:
                logger.error("Audius trending fetch failed: %s", e)
            return []

    async def get_stream_url(self, source_id: str) -> StreamInfo:
        """Return stream URL for Audius track."""
        async with httpx.AsyncClient(timeout=DEFAULT_TIMEOUT) as client:
            host = await self._get_host(client)

        stream_url = f"{host}/v1/tracks/{source_id}/stream?app_name={self.app_name}"
        return StreamInfo(
            song_id=f"audius:{source_id}",
            stream_url=stream_url,
            format="mp3",
            bitrate_kbps=320,
            is_direct_url=True,
        )

    async def get_track(self, source_id: str) -> Optional[SongRead]:
        """Get full track metadata from Audius."""
        async with httpx.AsyncClient(timeout=DEFAULT_TIMEOUT, follow_redirects=True) as client:
            host = await self._get_host(client)
            try:
                response = await fetch_with_retry(
                    client,
                    "GET",
                    f"{host}/v1/tracks/{source_id}",
                    params={"app_name": self.app_name},
                )
                if response and response.status_code == 200:
                    track_data = response.json().get("data")
                    if track_data:
                        return self._parse_track(host, track_data)
            except Exception as e:
                logger.error("Failed to get Audius track %s: %s", source_id, e)
        return None
