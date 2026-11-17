"""Pydantic schemas for data validation and API serialization."""
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict, Field


class SongBase(BaseModel):
    """Base song fields."""
    id: str = Field(..., description="Unique ID in format <source>:<source_id>")
    source: str = Field(..., description="Source name (audius, jamendo, local)")
    source_id: str = Field(..., description="Native ID on the upstream service")
    title: str
    artist: str
    album: Optional[str] = None
    duration_seconds: int = 0
    artwork_url: Optional[str] = None
    genre: Optional[str] = None
    is_preview: bool = False
    is_full: bool = True


class SongRead(SongBase):
    """Song returned from API endpoints."""
    stream_url: Optional[str] = None
    is_liked: Optional[bool] = False
    created_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class StreamInfo(BaseModel):
    """Streaming URL information."""
    song_id: str
    stream_url: str
    format: str = "mp3"
    bitrate_kbps: Optional[int] = 320
    is_direct_url: bool = True


class SearchResult(BaseModel):
    """Unified search response."""
    query: str
    total: int
    results: List[SongRead]


class TrendingResult(BaseModel):
    """Trending songs response."""
    source: str
    total: int
    results: List[SongRead]


# Schemas for Phase 2 readiness
class PlaylistBase(BaseModel):
    name: str
    description: Optional[str] = None


class PlaylistCreate(PlaylistBase):
    pass


class PlaylistUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None


class PlaylistRead(PlaylistBase):
    id: int
    cover_url: Optional[str] = None
    song_count: int = 0
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class PlaylistDetailRead(PlaylistRead):
    songs: List[SongRead] = []


class PlaylistAddSong(BaseModel):
    """Payload to add a song to a playlist."""
    song_id: str = Field(..., description="Unified song ID (e.g. audius:D72mb)")


class PlaylistReorder(BaseModel):
    """Payload to reorder songs in a playlist."""
    song_ids: List[str] = Field(..., description="Ordered list of song IDs")


class LikeStatus(BaseModel):
    """Status of whether a song is liked."""
    song_id: str
    is_liked: bool


class LikedSongsResult(BaseModel):
    """List of liked songs with total count."""
    total: int
    results: List[SongRead]


class PlayHistoryCreate(BaseModel):
    """Payload when recording a playback event."""
    song_id: str
    played_duration_seconds: int = 0
    completed: bool = False


class PlayHistoryRead(BaseModel):
    """Playback history entry with song metadata."""
    id: int
    song_id: str
    played_duration_seconds: int
    completed: bool
    played_at: datetime
    song: Optional[SongRead] = None

    model_config = ConfigDict(from_attributes=True)


class PlayHistoryResult(BaseModel):
    """List of history entries with total count."""
    total: int
    results: List[PlayHistoryRead]


class ArtistRead(BaseModel):
    """Artist details for chart display."""
    id: str
    name: str
    picture_url: Optional[str] = None
    track_count: Optional[int] = None


class HomeSectionsResult(BaseModel):
    """Aggregated home screen sections for Tamil, English, and personal music."""
    language: str = "both"
    tamil_trending: List[SongRead] = []
    english_trending: List[SongRead] = []
    tamil_indie: List[SongRead] = []
    english_indie: List[SongRead] = []
    my_music: List[SongRead] = []
    made_for_you: List[SongRead] = []
    # Backward compatibility fields
    trending_now: List[SongRead] = []
    top_by_country: List[SongRead] = []
    country: str = "IN"
    top_artists: List[ArtistRead] = []
    independent_picks: List[SongRead] = []
