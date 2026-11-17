"""Routers for user library: Likes and Play History."""
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.db import get_db
from app.models import Like, PlayHistory, Song
from app.schemas import (
    LikedSongsResult,
    LikeStatus,
    PlayHistoryCreate,
    PlayHistoryRead,
    PlayHistoryResult,
    SongRead,
)
from app.services.sources.manager import source_manager

router = APIRouter(prefix="/library", tags=["library"])


async def ensure_song_cached(db: Session, song_id: str) -> Song:
    """Ensure the song exists in the local database before attaching likes/history."""
    db_song = db.query(Song).filter(Song.id == song_id).first()
    if not db_song:
        # Fetch from remote source and cache it
        song = await source_manager.get_song(song_id, db=db)
        if not song:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Song '{song_id}' could not be found or resolved.",
            )
        db_song = db.query(Song).filter(Song.id == song_id).first()
    return db_song


# ---------------------------------------------------------------------------
# Likes
# ---------------------------------------------------------------------------

@router.post("/likes/{song_id:path}", response_model=LikeStatus)
async def like_song(
    song_id: str,
    db: Session = Depends(get_db),
):
    """Add a song to Liked Songs."""
    await ensure_song_cached(db, song_id)

    existing = db.query(Like).filter(Like.song_id == song_id).first()
    if not existing:
        new_like = Like(song_id=song_id)
        db.add(new_like)
        db.commit()

    return LikeStatus(song_id=song_id, is_liked=True)


@router.delete("/likes/{song_id:path}", response_model=LikeStatus)
async def unlike_song(
    song_id: str,
    db: Session = Depends(get_db),
):
    """Remove a song from Liked Songs."""
    existing = db.query(Like).filter(Like.song_id == song_id).first()
    if existing:
        db.delete(existing)
        db.commit()

    return LikeStatus(song_id=song_id, is_liked=False)


@router.get("/likes/{song_id:path}/status", response_model=LikeStatus)
async def check_like_status(
    song_id: str,
    db: Session = Depends(get_db),
):
    """Check if a specific song is liked."""
    is_liked = db.query(Like).filter(Like.song_id == song_id).first() is not None
    return LikeStatus(song_id=song_id, is_liked=is_liked)


@router.get("/likes", response_model=LikedSongsResult)
async def get_liked_songs(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    """List all liked songs ordered by most recently liked."""
    query = (
        db.query(Song)
        .join(Like, Song.id == Like.song_id)
        .order_by(desc(Like.created_at))
    )
    total = query.count()
    songs = query.offset(offset).limit(limit).all()

    results = []
    for s in songs:
        sr = SongRead.model_validate(s)
        sr.is_liked = True
        results.append(sr)

    return LikedSongsResult(total=total, results=results)


# ---------------------------------------------------------------------------
# Play History
# ---------------------------------------------------------------------------

@router.post("/history", response_model=PlayHistoryRead)
async def record_play_history(
    payload: PlayHistoryCreate,
    db: Session = Depends(get_db),
):
    """Record a song playback event (used for resume and recommendation scoring)."""
    db_song = await ensure_song_cached(db, payload.song_id)

    entry = PlayHistory(
        song_id=payload.song_id,
        played_duration_seconds=payload.played_duration_seconds,
        completed=payload.completed,
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)

    # Return with song details
    song_read = SongRead.model_validate(db_song)
    is_liked = db.query(Like).filter(Like.song_id == payload.song_id).first() is not None
    song_read.is_liked = is_liked

    res = PlayHistoryRead(
        id=entry.id,
        song_id=entry.song_id,
        played_duration_seconds=entry.played_duration_seconds,
        completed=entry.completed,
        played_at=entry.played_at,
        song=song_read,
    )
    return res


@router.get("/history", response_model=PlayHistoryResult)
async def get_play_history(
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    """Retrieve playback history ordered by most recent plays."""
    query = db.query(PlayHistory).order_by(desc(PlayHistory.played_at))
    total = query.count()
    entries = query.offset(offset).limit(limit).all()

    # Pre-fetch liked IDs for efficient mapping
    song_ids = [e.song_id for e in entries if e.song]
    liked_ids = set(
        row[0] for row in db.query(Like.song_id).filter(Like.song_id.in_(song_ids)).all()
    )

    results = []
    for e in entries:
        song_read = None
        if e.song:
            song_read = SongRead.model_validate(e.song)
            song_read.is_liked = e.song_id in liked_ids

        results.append(
            PlayHistoryRead(
                id=e.id,
                song_id=e.song_id,
                played_duration_seconds=e.played_duration_seconds,
                completed=e.completed,
                played_at=e.played_at,
                song=song_read,
            )
        )

    return PlayHistoryResult(total=total, results=results)


@router.delete("/history")
async def clear_play_history(db: Session = Depends(get_db)):
    """Clear all playback history."""
    db.query(PlayHistory).delete()
    db.commit()
    return {"message": "Play history cleared successfully."}


@router.get("/local", response_model=LikedSongsResult)
@router.get("/songs", response_model=LikedSongsResult)
async def get_local_songs(
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    """List all songs indexed from backend/music/."""
    all_tracks = list(source_manager.local._tracks_by_id.values())
    total = len(all_tracks)
    slice_tracks = all_tracks[offset : offset + limit]

    liked_ids = set(row[0] for row in db.query(Like.song_id).all())

    results = []
    for song, _ in slice_tracks:
        sr = SongRead.model_validate(song)
        sr.is_liked = sr.id in liked_ids
        results.append(sr)

    return LikedSongsResult(total=total, results=results)


@router.post("/rescan")
async def rescan_local_music():
    """Rescan backend/music/ folder, update indexes, and extract embedded/Deezer artwork."""
    count = source_manager.local.rescan()
    return {
        "status": "success",
        "message": f"Rescanned local music library. Found {count} track(s).",
        "total_tracks": count,
    }

