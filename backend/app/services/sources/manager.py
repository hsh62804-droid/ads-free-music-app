"""Source Manager for coordinating music providers, local file matching, and chart caching."""
import asyncio
import json
import logging
from pathlib import Path
from typing import Dict, List, Optional
from sqlalchemy.orm import Session

from app.config import get_settings
from app.models import Song, Like, PlayHistory
from app.schemas import SongRead, StreamInfo, ArtistRead, HomeSectionsResult
from app.services.cache import charts_cache, song_info_cache
from app.services.sources.audius import AudiusSource
from app.services.sources.base import MusicSource
from app.services.sources.deezer import DeezerSource
from app.services.sources.itunes import ItunesSource
from app.services.sources.jamendo import JamendoSource
from app.services.sources.local import LocalSource, normalize_string
from app.services.sources.youtube import YouTubeSource

logger = logging.getLogger(__name__)


def load_artists_config() -> dict:
    """Load Tamil and English artists configuration from config/artists.json."""
    config_path = Path(__file__).resolve().parent.parent.parent / "config" / "artists.json"
    if config_path.exists():
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            logger.warning("Could not read artists.json: %s", e)
    return {
        "tamil": [
            "Anirudh Ravichander",
            "A.R. Rahman",
            "Yuvan Shankar Raja",
            "Harris Jayaraj",
            "Sid Sriram",
            "Santhosh Narayanan"
        ],
        "english": [
            "The Weeknd",
            "Dua Lipa",
            "Ed Sheeran",
            "Taylor Swift",
            "Post Malone",
            "Billie Eilish"
        ]
    }


class SourceManager:
    """Coordinates search, trending, streaming, local matching, and charts across all providers."""

    def __init__(self):
        settings = get_settings()
        self.deezer = DeezerSource()
        self.itunes = ItunesSource()
        self.local = LocalSource()
        self.audius = AudiusSource(app_name=settings.AUDIUS_APP_NAME)
        self.jamendo = JamendoSource(client_id=settings.JAMENDO_CLIENT_ID)
        self.youtube = YouTubeSource(api_key=settings.YOUTUBE_API_KEY)

        self.sources: Dict[str, MusicSource] = {
            "deezer": self.deezer,
            "itunes": self.itunes,
            "local": self.local,
            "audius": self.audius,
            "jamendo": self.jamendo,
            "youtube": self.youtube,
        }

    def register_source(self, source: MusicSource) -> None:
        """Register a new source provider."""
        self.sources[source.name] = source

    def get_source(self, name: str) -> Optional[MusicSource]:
        """Retrieve a specific source provider by name."""
        return self.sources.get(name)

    @staticmethod
    def parse_id(unified_id: str) -> tuple[str, str]:
        """Split a unified ID like 'deezer:123' into ('deezer', '123')."""
        if ":" not in unified_id:
            raise ValueError(
                f"Invalid song ID format '{unified_id}'. Expected '<source>:<id>'."
            )
        source_name, source_id = unified_id.split(":", 1)
        return source_name.lower(), source_id

    def enrich_with_local(self, song: SongRead) -> SongRead:
        """Enforce:
        1. If external song matches local full file in backend/music/, upgrade to local full file.
        2. Set is_full and is_preview accurately.
        """
        if song.source in ("local", "youtube"):
            return song.model_copy(update={"is_preview": False, "is_full": True})

        local_match = self.local.find_match(artist=song.artist, title=song.title)
        if local_match:
            # Upgraded to full local track
            return song.model_copy(
                update={
                    "stream_url": local_match.stream_url,
                    "duration_seconds": local_match.duration_seconds or song.duration_seconds,
                    "is_preview": False,
                    "is_full": True,
                }
            )

        # External sources: Audius, Jamendo, YouTube, and local are full tracks; Deezer and iTunes are 30s previews
        is_full = song.source in ("audius", "jamendo", "local", "youtube")
        return song.model_copy(update={"is_full": is_full, "is_preview": not is_full})

    def enrich_many(self, songs: List[SongRead]) -> List[SongRead]:
        """Enrich a list of songs with local matching and full-track flags."""
        return [self.enrich_with_local(s) for s in songs]

    async def find_full_version(self, song: SongRead) -> Optional[SongRead]:
        """Attempt to find a full-length version (local first, then official YouTube Data API audio)."""
        if song.is_full:
            return song

        # 1. Local files
        local_match = self.local.find_match(artist=song.artist, title=song.title)
        if local_match:
            return local_match

        # 2. Official YouTube Data API
        try:
            yt_match = await self.youtube.search_official_audio(title=song.title, artist=song.artist)
            if yt_match:
                return yt_match
        except Exception as e:
            logger.warning("Error resolving full version on YouTube: %s", e)

        return None

    async def search(
        self,
        query: str,
        source: str = "all",
        limit: int = 20,
        db: Optional[Session] = None
    ) -> List[SongRead]:
        """Search across one or all sources concurrently."""
        cache_key = f"search:{source.lower()}:{query.lower()}:{limit}"
        cached = charts_cache.get(cache_key)
        if cached:
            return cached

        target_sources = (
            [self.sources[s] for s in self.sources if s == source.lower()]
            if source.lower() != "all"
            else [self.local, self.youtube, self.deezer, self.itunes, self.audius, self.jamendo]
        )

        tasks = [s.search(query=query, limit=limit) for s in target_sources if s.is_configured]
        results_nested = await asyncio.gather(*tasks, return_exceptions=True)

        all_songs: List[SongRead] = []
        for result in results_nested:
            if isinstance(result, list):
                all_songs.extend(result)
            elif isinstance(result, Exception):
                logger.error("Search subtask failed: %s", result)

        enriched = self.enrich_many(all_songs)

        if db:
            self.cache_songs(db, enriched)

        charts_cache.set(cache_key, enriched, ttl_seconds=600)  # 10 min for search
        return enriched

    async def trending(
        self,
        source: str = "all",
        limit: int = 30,
        db: Optional[Session] = None
    ) -> List[SongRead]:
        """Fetch trending songs running sources concurrently and picking the first good result."""
        cache_key = f"trending:{source.lower()}:{limit}"
        cached = charts_cache.get(cache_key)
        if cached:
            return cached

        songs: List[SongRead] = []
        if source.lower() == "all":
            # Run Deezer, iTunes, Audius in parallel
            tasks = [
                self.deezer.trending(limit=limit),
                self.itunes.trending(limit=limit),
                self.audius.trending(limit=limit),
            ]
            results = await asyncio.gather(*tasks, return_exceptions=True)
            for res in results:
                if isinstance(res, list) and res:
                    songs = res
                    break
        elif source.lower() == "deezer":
            songs = await self.deezer.trending(limit=limit)
        elif source.lower() == "itunes":
            songs = await self.itunes.trending(limit=limit)
        elif source.lower() == "audius":
            songs = await self.audius.trending(limit=limit)

        enriched = self.enrich_many(songs)
        if db:
            self.cache_songs(db, enriched)

        charts_cache.set(cache_key, enriched, ttl_seconds=1800)
        return enriched

    async def get_home_sections(
        self,
        country: str = "IN",
        language: str = "both",
        limit: int = 15,
        db: Optional[Session] = None
    ) -> HomeSectionsResult:
        """Fetch home screen sections tailored to Tamil & English music, cached for 30 minutes."""
        country_code = country.upper()
        lang_filter = language.lower()
        cache_key = f"home_sections:{country_code}:{lang_filter}"
        cached = charts_cache.get(cache_key)
        if cached:
            return cached

        artists_cfg = load_artists_config()
        tamil_artists = artists_cfg.get("tamil", ["Anirudh Ravichander", "A.R. Rahman", "Yuvan Shankar Raja", "Sid Sriram"])
        english_artists = artists_cfg.get("english", ["The Weeknd", "Dua Lipa", "Ed Sheeran", "Taylor Swift"])

        # Construct asynchronous queries for Tamil & English trending
        async def fetch_tamil_trending() -> List[SongRead]:
            # Fetch full official YouTube Tamil tracks and Deezer Tamil tracks
            tasks = [
                self.youtube.search(query="Tamil songs hits", limit=10),
                self.deezer.search(query=f"{tamil_artists[0]} Tamil", limit=5),
                self.deezer.search(query=f"{tamil_artists[1]} Tamil", limit=5),
            ]
            searches = await asyncio.gather(*tasks, return_exceptions=True)
            results: List[SongRead] = []
            for res in searches:
                if isinstance(res, list):
                    results.extend(res)
            if not results:
                results = await self.youtube.search(query="Tamil Hits", limit=limit)
            return self.enrich_many(results[:limit])

        async def fetch_english_trending() -> List[SongRead]:
            # Fetch full official YouTube English hits and Deezer chart
            tasks = [
                self.youtube.search(query="English top hits", limit=10),
                self.deezer.trending(limit=limit),
            ]
            searches = await asyncio.gather(*tasks, return_exceptions=True)
            results: List[SongRead] = []
            for res in searches:
                if isinstance(res, list):
                    results.extend(res)
            return self.enrich_many(results[:limit])

        async def fetch_tamil_indie() -> List[SongRead]:
            # Audius + Jamendo search for tamil / kollywood indie tracks (full songs)
            tasks = [
                self.audius.search(query="tamil", limit=8),
                self.audius.search(query="kollywood", limit=6),
            ]
            nested = await asyncio.gather(*tasks, return_exceptions=True)
            indie: List[SongRead] = []
            for res in nested:
                if isinstance(res, list):
                    indie.extend(res)
            return self.enrich_many(indie[:limit])

        async def fetch_english_indie() -> List[SongRead]:
            # Audius + Jamendo search for pop / lofi / indie tracks (full songs)
            tasks = [
                self.audius.search(query="lofi", limit=8),
                self.jamendo.search(query="pop", limit=8),
            ]
            nested = await asyncio.gather(*tasks, return_exceptions=True)
            indie: List[SongRead] = []
            for res in nested:
                if isinstance(res, list):
                    indie.extend(res)
            return self.enrich_many(indie[:limit])

        async def fetch_my_music() -> List[SongRead]:
            return await self.local.trending(limit=limit)

        (
            tamil_trend,
            english_trend,
            tamil_ind,
            english_ind,
            my_mus,
            top_artists,
            country_res,
        ) = await asyncio.gather(
            fetch_tamil_trending(),
            fetch_english_trending(),
            fetch_tamil_indie(),
            fetch_english_indie(),
            fetch_my_music(),
            self.deezer.get_top_artists(limit=limit),
            self.itunes.get_country_top(country=country_code, limit=limit),
            return_exceptions=True
        )

        tamil_trending_songs = tamil_trend if isinstance(tamil_trend, list) else []
        english_trending_songs = english_trend if isinstance(english_trend, list) else []
        tamil_indie_songs = tamil_ind if isinstance(tamil_ind, list) else []
        english_indie_songs = english_ind if isinstance(english_ind, list) else []
        my_music_songs = my_mus if isinstance(my_mus, list) else []
        artists_list = top_artists if isinstance(top_artists, list) else []
        country_songs = self.enrich_many(country_res) if isinstance(country_res, list) else []

        # Personalized "Made for you" section
        made_for_you: List[SongRead] = []
        if db:
            try:
                liked_songs = (
                    db.query(Song)
                    .join(Like, Like.song_id == Song.id)
                    .order_by(Like.created_at.desc())
                    .limit(limit)
                    .all()
                )
                if liked_songs:
                    made_for_you = self.enrich_many([SongRead.model_validate(s) for s in liked_songs])
            except Exception as e:
                logger.warning("Could not fetch user likes: %s", e)

        if not made_for_you:
            # Fallback to local music + trending mix based on selected language
            if lang_filter == "tamil":
                made_for_you = (my_music_songs + tamil_trending_songs)[:limit]
            elif lang_filter == "english":
                made_for_you = (my_music_songs + english_trending_songs)[:limit]
            else:
                made_for_you = (my_music_songs + tamil_trending_songs[:4] + english_trending_songs[:4])[:limit]

        # Independent picks
        independent_picks = (tamil_indie_songs[:6] + english_indie_songs[:6])[:limit]

        result = HomeSectionsResult(
            language=lang_filter,
            tamil_trending=tamil_trending_songs,
            english_trending=english_trending_songs,
            tamil_indie=tamil_indie_songs,
            english_indie=english_indie_songs,
            my_music=my_music_songs,
            made_for_you=made_for_you,
            trending_now=english_trending_songs or tamil_trending_songs,
            top_by_country=country_songs,
            country=country_code,
            top_artists=artists_list,
            independent_picks=independent_picks,
        )

        charts_cache.set(cache_key, result, ttl_seconds=1800)  # 30 minutes cache
        return result

    async def get_tamil_trending(self, limit: int = 15) -> List[SongRead]:
        """Fetch Tamil trending tracks directly."""
        cache_key = f"tamil_trending:{limit}"
        cached = charts_cache.get(cache_key)
        if cached:
            return cached
        artists_cfg = load_artists_config()
        tamil_artists = artists_cfg.get("tamil", ["Anirudh Ravichander", "A.R. Rahman", "Yuvan Shankar Raja", "Sid Sriram"])
        tasks = [
            self.youtube.search(query="Tamil songs hits", limit=10),
            self.deezer.search(query=f"{tamil_artists[0]} Tamil", limit=5),
            self.deezer.search(query=f"{tamil_artists[1]} Tamil", limit=5),
        ]
        searches = await asyncio.gather(*tasks, return_exceptions=True)
        results: List[SongRead] = []
        for res in searches:
            if isinstance(res, list):
                results.extend(res)
        if not results:
            results = await self.youtube.search(query="Tamil Hits", limit=limit)
        enriched = self.enrich_many(results[:limit])
        charts_cache.set(cache_key, enriched, ttl_seconds=1800)
        return enriched

    async def get_english_trending(self, limit: int = 15) -> List[SongRead]:
        """Fetch English trending tracks directly."""
        cache_key = f"english_trending:{limit}"
        cached = charts_cache.get(cache_key)
        if cached:
            return cached
        tasks = [
            self.youtube.search(query="English top hits", limit=10),
            self.deezer.trending(limit=limit),
        ]
        searches = await asyncio.gather(*tasks, return_exceptions=True)
        results: List[SongRead] = []
        for res in searches:
            if isinstance(res, list):
                results.extend(res)
        enriched = self.enrich_many(results[:limit])
        charts_cache.set(cache_key, enriched, ttl_seconds=1800)
        return enriched

    async def get_independent_picks(self, limit: int = 15) -> List[SongRead]:
        """Fetch independent picks from Audius and Jamendo."""
        cache_key = f"independent_picks:{limit}"
        cached = charts_cache.get(cache_key)
        if cached:
            return cached
        tasks = [
            self.audius.search(query="tamil", limit=6),
            self.audius.search(query="lofi", limit=6),
            self.jamendo.search(query="pop", limit=6),
        ]
        nested = await asyncio.gather(*tasks, return_exceptions=True)
        indie: List[SongRead] = []
        for res in nested:
            if isinstance(res, list):
                indie.extend(res)
        enriched = self.enrich_many(indie[:limit])
        charts_cache.set(cache_key, enriched, ttl_seconds=1800)
        return enriched

    async def get_made_for_you(self, limit: int = 15, db: Optional[Session] = None) -> List[SongRead]:
        """Fetch personalized made for you picks based on liked tracks."""
        if db:
            try:
                liked_songs = (
                    db.query(Song)
                    .join(Like, Like.song_id == Song.id)
                    .order_by(Like.created_at.desc())
                    .limit(limit)
                    .all()
                )
                if liked_songs:
                    return [
                        SongRead(
                            id=s.id,
                            source=s.source,
                            source_id=s.source_id,
                            title=s.title,
                            artist=s.artist,
                            album=s.album,
                            duration_seconds=s.duration_seconds,
                            artwork_url=s.artwork_url,
                            genre=s.genre,
                            is_preview=s.is_preview,
                            is_full=s.is_full,
                            stream_url=s.stream_url,
                            is_liked=True,
                        )
                        for s in liked_songs
                    ]
            except Exception as e:
                logger.warning("Error loading made_for_you: %s", e)
        local_songs = await self.local.trending(limit=limit)
        if local_songs:
            return local_songs
        return await self.get_tamil_trending(limit=limit)

    async def get_stream_url(self, unified_id: str) -> StreamInfo:
        """Resolve playable stream URL according to priority:
        1. LocalSource: full file in backend/music/
        2. Audius: full track
        3. Jamendo: full track
        4. Deezer / iTunes 30-second preview (only if 1-3 fail)
        Results are cached in memory for 24 hours.
        """
        cached_stream = song_info_cache.get(f"stream:{unified_id}")
        if cached_stream:
            return cached_stream

        source_name, source_id = self.parse_id(unified_id)
        provider = self.get_source(source_name)
        if not provider:
            raise ValueError(f"Unknown source '{source_name}'.")

        res_stream: Optional[StreamInfo] = None

        # 1. Local files: direct full file stream
        if source_name == "local":
            res_stream = await provider.get_stream_url(source_id)

        # 2. Audius and Jamendo: full tracks natively
        elif source_name in ("audius", "jamendo"):
            res_stream = await provider.get_stream_url(source_id)

        # 3. For Deezer or iTunes songs: check full sources first!
        else:
            track_meta = await provider.get_track(source_id)
            if track_meta:
                # 3a. Check LocalSource match
                local_match = self.local.find_match(artist=track_meta.artist, title=track_meta.title)
                if local_match:
                    logger.info("Upgraded %s to local full file %s", unified_id, local_match.id)
                    res_stream = await self.local.get_stream_url(local_match.source_id)

                # 3b. Check Audius for full track match
                if not res_stream:
                    try:
                        norm_target_title = normalize_string(track_meta.title)
                        audius_tracks = await self.audius.search(f"{track_meta.artist} {track_meta.title}", limit=4)
                        for at in audius_tracks:
                            if normalize_string(at.title) == norm_target_title:
                                logger.info("Upgraded %s to Audius full track %s", unified_id, at.id)
                                res_stream = await self.audius.get_stream_url(at.source_id)
                                break
                    except Exception as e:
                        logger.debug("Audius full track lookup failed: %s", e)

                # 3c. Check Jamendo for full track match
                if not res_stream and self.jamendo.is_configured:
                    try:
                        jamendo_tracks = await self.jamendo.search(f"{track_meta.artist} {track_meta.title}", limit=4)
                        for jt in jamendo_tracks:
                            if normalize_string(jt.title) == norm_target_title:
                                logger.info("Upgraded %s to Jamendo full track %s", unified_id, jt.id)
                                res_stream = await self.jamendo.get_stream_url(jt.source_id)
                                break
                    except Exception as e:
                        logger.debug("Jamendo full track lookup failed: %s", e)

            # 4. Fall back to 30-second preview URL from Deezer / iTunes
            if not res_stream:
                res_stream = await provider.get_stream_url(source_id)

        if res_stream:
            song_info_cache.set(f"stream:{unified_id}", res_stream, ttl_seconds=86400)
            return res_stream

        raise ValueError(f"Unable to resolve stream URL for '{unified_id}'.")

    async def get_song(
        self,
        unified_id: str,
        db: Optional[Session] = None
    ) -> Optional[SongRead]:
        """Get song details from in-memory cache (24 hours), database cache, or upstream source."""
        # 1. Check in-memory 24-hour cache
        cached_song = song_info_cache.get(f"song:{unified_id}")
        if cached_song:
            return cached_song

        if db:
            db_song = db.query(Song).filter(Song.id == unified_id).first()
            if db_song:
                song_read = SongRead.model_validate(db_song)
                enriched = self.enrich_with_local(song_read)
                song_info_cache.set(f"song:{unified_id}", enriched, ttl_seconds=86400)
                return enriched

        source_name, source_id = self.parse_id(unified_id)
        provider = self.get_source(source_name)
        if not provider:
            return None

        song = await provider.get_track(source_id)
        if song:
            song = self.enrich_with_local(song)
            song_info_cache.set(f"song:{unified_id}", song, ttl_seconds=86400)
            if db:
                self.cache_songs(db, [song])
        return song

    def cache_songs(self, db: Session, songs: List[SongRead]) -> None:
        """Insert or update songs in the local database cache."""
        try:
            for s in songs:
                existing = db.query(Song).filter(Song.id == s.id).first()
                if not existing:
                    new_song = Song(
                        id=s.id,
                        source=s.source,
                        source_id=s.source_id,
                        title=s.title,
                        artist=s.artist,
                        album=s.album,
                        duration_seconds=s.duration_seconds,
                        artwork_url=s.artwork_url,
                        stream_url=s.stream_url,
                        genre=s.genre,
                        is_preview=s.is_preview,
                        is_full=s.is_full,
                    )
                    db.add(new_song)
                else:
                    existing.is_preview = s.is_preview
                    existing.is_full = s.is_full
                    if s.stream_url:
                        existing.stream_url = s.stream_url
            db.commit()
        except Exception as e:
            db.rollback()
            logger.warning("Failed to cache songs in database: %s", e)


# Global singleton instance
source_manager = SourceManager()
