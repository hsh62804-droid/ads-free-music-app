"""SQLAlchemy database models for music streaming."""
from datetime import datetime, timezone
from typing import Optional, List
from sqlalchemy import (
    Column,
    String,
    Integer,
    Boolean,
    DateTime,
    ForeignKey,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from app.db import Base


def utc_now() -> datetime:
    """Return current UTC time."""
    return datetime.now(timezone.utc)


class Song(Base):
    """Cached song metadata from external sources (Audius, Jamendo, etc.)."""
    __tablename__ = "songs"

    # ID format: "<source>:<source_id>", e.g., "audius:D72mb"
    id = Column(String, primary_key=True, index=True)
    source = Column(String, nullable=False, index=True)
    source_id = Column(String, nullable=False)
    title = Column(String, nullable=False, index=True)
    artist = Column(String, nullable=False, index=True)
    album = Column(String, nullable=True)
    duration_seconds = Column(Integer, default=0, nullable=False)
    artwork_url = Column(String, nullable=True)
    stream_url = Column(String, nullable=True)
    genre = Column(String, nullable=True, index=True)
    is_preview = Column(Boolean, default=False, nullable=False)
    is_full = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=utc_now, nullable=False)

    # Relationships
    likes = relationship("Like", back_populates="song", cascade="all, delete-orphan")
    history_entries = relationship("PlayHistory", back_populates="song", cascade="all, delete-orphan")
    playlist_entries = relationship("PlaylistSong", back_populates="song", cascade="all, delete-orphan")


class Playlist(Base):
    """User-created playlist."""
    __tablename__ = "playlists"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    cover_url = Column(String, nullable=True)
    created_at = Column(DateTime, default=utc_now, nullable=False)
    updated_at = Column(DateTime, default=utc_now, onupdate=utc_now, nullable=False)

    # Relationships
    songs = relationship(
        "PlaylistSong",
        back_populates="playlist",
        cascade="all, delete-orphan",
        order_by="PlaylistSong.position"
    )


class PlaylistSong(Base):
    """Association table linking playlists and songs with order/position."""
    __tablename__ = "playlist_songs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    playlist_id = Column(Integer, ForeignKey("playlists.id", ondelete="CASCADE"), nullable=False, index=True)
    song_id = Column(String, ForeignKey("songs.id", ondelete="CASCADE"), nullable=False, index=True)
    position = Column(Integer, nullable=False, default=0)
    added_at = Column(DateTime, default=utc_now, nullable=False)

    playlist = relationship("Playlist", back_populates="songs")
    song = relationship("Song", back_populates="playlist_entries")

    __table_args__ = (
        UniqueConstraint("playlist_id", "song_id", name="uq_playlist_song"),
    )


class Like(Base):
    """User-liked (favorited) songs."""
    __tablename__ = "likes"

    id = Column(Integer, primary_key=True, autoincrement=True)
    song_id = Column(String, ForeignKey("songs.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)
    created_at = Column(DateTime, default=utc_now, nullable=False)

    song = relationship("Song", back_populates="likes")


class PlayHistory(Base):
    """Playback history log for analytics and recommendation scoring."""
    __tablename__ = "play_history"

    id = Column(Integer, primary_key=True, autoincrement=True)
    song_id = Column(String, ForeignKey("songs.id", ondelete="CASCADE"), nullable=False, index=True)
    played_duration_seconds = Column(Integer, default=0, nullable=False)
    completed = Column(Boolean, default=False, nullable=False)
    played_at = Column(DateTime, default=utc_now, nullable=False)

    song = relationship("Song", back_populates="history_entries")
