"""iTunes / Apple Music source provider implementation."""
import logging
from typing import List, Optional
import httpx

from app.schemas import SongRead, StreamInfo
from app.services.sources.base import MusicSource, DEFAULT_TIMEOUT, fetch_with_retry

logger = logging.getLogger(__name__)


class ItunesSource(MusicSource):
    """Provides high-reliability search, country charts, and previews via iTunes Search API."""

    SEARCH_URL = "https://itunes.apple.com/search"
    LOOKUP_URL = "https://itunes.apple.com/lookup"

    def __init__(self, timeout: httpx.Timeout = DEFAULT_TIMEOUT):
        self._timeout = timeout
        self._headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json",
        }

    @property
    def name(self) -> str:
        return "itunes"

    @property
    def is_configured(self) -> bool:
        return True

    def _parse_track(self, item: dict) -> SongRead:
        """Parse raw iTunes track into SongRead schema."""
        source_id = str(item.get("trackId") or item.get("collectionId", ""))
        
        # Upgrade standard 100x100 thumbnail to 600x600 or 1000x1000 high-res cover art
        art_url = item.get("artworkUrl100") or item.get("artworkUrl60")
        if art_url:
            art_url = art_url.replace("100x100bb.jpg", "600x600bb.jpg").replace("60x60bb.jpg", "600x600bb.jpg")

        millis = int(item.get("trackTimeMillis") or 30000)
        duration_sec = max(1, millis // 1000)

        return SongRead(
            id=f"itunes:{source_id}",
            source="itunes",
            source_id=source_id,
            title=item.get("trackName") or item.get("collectionName") or "Untitled Track",
            artist=item.get("artistName") or "Unknown Artist",
            album=item.get("collectionName"),
            duration_seconds=duration_sec,
            artwork_url=art_url,
            stream_url=item.get("previewUrl"),
            genre=item.get("primaryGenreName"),
            is_preview=True,
        )

    async def search(self, query: str, limit: int = 20, country: str = "US") -> List[SongRead]:
        """Search songs on iTunes."""
        try:
            async with httpx.AsyncClient(timeout=self._timeout, headers=self._headers) as client:
                params = {
                    "term": query,
                    "entity": "song",
                    "limit": limit,
                    "country": country,
                }
                r = await fetch_with_retry(client, "GET", self.SEARCH_URL, params=params)
                if r and r.status_code == 200:
                    results = r.json().get("results", [])
                    return [self._parse_track(t) for t in results if t.get("previewUrl")]
        except Exception as e:
            logger.warning("iTunes search failed for '%s': %s", query, e)

        return []

    async def trending(self, limit: int = 30) -> List[SongRead]:
        """Fetch global trending top songs from iTunes."""
        return await self.get_country_top(country="US", limit=limit)

    async def get_country_top(self, country: str = "IN", limit: int = 30) -> List[SongRead]:
        """Fetch country top songs (e.g. IN for India, US for USA, GB for Global)."""
        # Search for top/hit songs in specified country
        country_code = country.upper()
        if country_code in ("GLOBAL", "ALL"):
            country_code = "US"

        queries = {
            "IN": "bollywood top hits",
            "US": "top hits 2024",
            "GB": "official charts uk",
        }
        term = queries.get(country_code, "top hits")

        return await self.search(query=term, limit=limit, country=country_code)

    async def get_stream_url(self, source_id: str) -> StreamInfo:
        """Resolve preview audio URL for iTunes track."""
        track = await self.get_track(source_id)
        if not track or not track.stream_url:
            raise ValueError(f"No preview stream available for iTunes track {source_id}")

        return StreamInfo(
            song_id=f"itunes:{source_id}",
            stream_url=track.stream_url,
            format="m4a",
            bitrate_kbps=256,
            is_direct_url=True,
        )

    async def get_track(self, source_id: str) -> Optional[SongRead]:
        """Look up single track on iTunes."""
        try:
            async with httpx.AsyncClient(timeout=self._timeout, headers=self._headers) as client:
                r = await fetch_with_retry(client, "GET", self.LOOKUP_URL, params={"id": source_id, "entity": "song"})
                if r and r.status_code == 200:
                    results = r.json().get("results", [])
                    if results:
                        return self._parse_track(results[0])
        except Exception as e:
            logger.warning("iTunes lookup failed for %s: %s", source_id, e)

        return None
