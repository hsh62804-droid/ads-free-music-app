"""Abstract base class for all music source providers."""
from abc import ABC, abstractmethod
import asyncio
import logging
from typing import List, Optional
import httpx

from app.schemas import SongRead, StreamInfo

logger = logging.getLogger(__name__)

# Standard timeout: 6 seconds total, 3 seconds to establish connection
DEFAULT_TIMEOUT = httpx.Timeout(6.0, connect=3.0)


async def fetch_with_retry(
    client: httpx.AsyncClient,
    method: str,
    url: str,
    max_retries: int = 2,
    retry_delay: float = 0.3,
    **kwargs
) -> Optional[httpx.Response]:
    """Execute an HTTP request with up to max_retries on timeout or transport failure."""
    for attempt in range(max_retries + 1):
        try:
            resp = await client.request(method, url, **kwargs)
            return resp
        except (httpx.TimeoutException, httpx.TransportError) as e:
            if attempt < max_retries:
                logger.warning(
                    "HTTP %s to %s failed (%s), retrying attempt %d of %d...",
                    method, url, e, attempt + 1, max_retries
                )
                await asyncio.sleep(retry_delay)
            else:
                logger.warning(
                    "HTTP %s to %s failed after %d retries: %s",
                    method, url, max_retries, e
                )
                return None
        except Exception as e:
            logger.error("Unexpected error during HTTP %s to %s: %s", method, url, e)
            return None
    return None


class MusicSource(ABC):
    """Common interface that all music sources (Audius, Jamendo, Local) must implement."""

    @property
    @abstractmethod
    def name(self) -> str:
        """Name of the source provider (e.g., 'audius', 'jamendo', 'local')."""
        pass

    @property
    @abstractmethod
    def is_configured(self) -> bool:
        """Return True if this source is ready to be used (e.g. required keys present)."""
        pass

    @abstractmethod
    async def search(self, query: str, limit: int = 20) -> List[SongRead]:
        """Search for tracks matching the query."""
        pass

    @abstractmethod
    async def trending(self, limit: int = 20) -> List[SongRead]:
        """Fetch trending / top tracks."""
        pass

    @abstractmethod
    async def get_stream_url(self, source_id: str) -> StreamInfo:
        """Resolve a playable stream URL for a song given its source-native ID."""
        pass

    @abstractmethod
    async def get_track(self, source_id: str) -> Optional[SongRead]:
        """Fetch full metadata for a single track by its source-native ID."""
        pass
