"""High performance in-memory TTL cache with 30-minute default expiration."""
import time
from typing import Any, Optional, Dict, Tuple


class MemoryCache:
    """Simple in-memory key-value store with expiration times."""

    def __init__(self, default_ttl_seconds: int = 1800):
        self._default_ttl = default_ttl_seconds
        self._store: Dict[str, Tuple[Any, float]] = {}

    def get(self, key: str) -> Optional[Any]:
        """Retrieve a value if present and not expired."""
        if key not in self._store:
            return None

        val, expires_at = self._store[key]
        if time.time() > expires_at:
            del self._store[key]
            return None

        return val

    def set(self, key: str, value: Any, ttl_seconds: Optional[int] = None) -> None:
        """Store a value with an expiration timestamp."""
        ttl = ttl_seconds if ttl_seconds is not None else self._default_ttl
        expires_at = time.time() + ttl
        self._store[key] = (value, expires_at)

    def clear(self) -> None:
        """Clear all entries in the cache."""
        self._store.clear()


# Global cache instance for charts and searches (30-minute TTL)
charts_cache = MemoryCache(default_ttl_seconds=1800)

# Global cache instance for song metadata and stream info (24-hour TTL)
song_info_cache = MemoryCache(default_ttl_seconds=86400)

