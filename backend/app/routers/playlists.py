"""Routers for Playlist management."""
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.db import get_db
from app.models import Like, Playlist, PlaylistSong, Song
from app.schemas import (
    PlaylistAddSong,
    PlaylistCreate,
    PlaylistDetailRead,
    PlaylistRead,
    PlaylistReorder,
    PlaylistUpdate,
    SongRead,
)
from app.services.sources.manager import source_manager

router = APIRouter(prefix="/playlists", tags=["playlists"])


def build_playlist_read(p: Playlist) -> PlaylistRead:
    """Format Playlist model to PlaylistRead with computed fields."""
    cover = p.cover_url
    if not cover and p.songs:
        for ps in p.songs:
            if ps.song and ps.song.artwork_url:
                cover = ps.song.artwork_url
                break

    return PlaylistRead(
        id=p.id,
        name=p.name,
        description=p.description,
        cover_url=cover,
        song_count=len(p.songs),
        created_at=p.created_at,
        updated_at=p.updated_at,
    )


@router.get("", response_model=List[PlaylistRead])
async def list_playlists(db: Session = Depends(get_db)):
    """List all user playlists."""
    playlists = db.query(Playlist).order_by(desc(Playlist.updated_at)).all()
    return [build_playlist_read(p) for p in playlists]


@router.post("", response_model=PlaylistRead, status_code=status.HTTP_201_CREATED)
async def create_playlist(
    payload: PlaylistCreate,
    db: Session = Depends(get_db),
):
    """Create a new playlist."""
    playlist = Playlist(
        name=payload.name.strip(),
        description=payload.description.strip() if payload.description else None,
    )
    db.add(playlist)
    db.commit()
    db.refresh(playlist)
    return build_playlist_read(playlist)


@router.get("/{playlist_id}", response_model=PlaylistDetailRead)
async def get_playlist(
    playlist_id: int,
    db: Session = Depends(get_db),
):
    """Retrieve full details of a playlist including ordered songs."""
    playlist = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not playlist:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Playlist with id {playlist_id} not found.",
        )

    # Pre-fetch liked songs
    song_ids = [ps.song_id for ps in playlist.songs if ps.song]
    liked_ids = set(
        row[0] for row in db.query(Like.song_id).filter(Like.song_id.in_(song_ids)).all()
    )

    ordered_songs: List[SongRead] = []
    for ps in playlist.songs:
        if ps.song:
            sr = SongRead.model_validate(ps.song)
            sr.is_liked = ps.song_id in liked_ids
            ordered_songs.append(sr)

    base = build_playlist_read(playlist)
    return PlaylistDetailRead(
        id=base.id,
        name=base.name,
        description=base.description,
        cover_url=base.cover_url,
        song_count=len(ordered_songs),
        created_at=base.created_at,
        updated_at=base.updated_at,
        songs=ordered_songs,
    )


@router.patch("/{playlist_id}", response_model=PlaylistRead)
async def update_playlist(
    playlist_id: int,
    payload: PlaylistUpdate,
    db: Session = Depends(get_db),
):
    """Update playlist name or description."""
    playlist = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not playlist:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Playlist with id {playlist_id} not found.",
        )

    if payload.name is not None and payload.name.strip():
        playlist.name = payload.name.strip()
    if payload.description is not None:
        playlist.description = payload.description.strip() or None

    db.commit()
    db.refresh(playlist)
    return build_playlist_read(playlist)


@router.delete("/{playlist_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_playlist(
    playlist_id: int,
    db: Session = Depends(get_db),
):
    """Delete a playlist."""
    playlist = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not playlist:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Playlist with id {playlist_id} not found.",
        )

    db.delete(playlist)
    db.commit()
    return None


@router.post("/{playlist_id}/songs", response_model=PlaylistDetailRead)
async def add_song_to_playlist(
    playlist_id: int,
    payload: PlaylistAddSong,
    db: Session = Depends(get_db),
):
    """Add a song to a playlist."""
    playlist = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not playlist:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Playlist with id {playlist_id} not found.",
        )

    # Ensure song exists in DB cache
    db_song = db.query(Song).filter(Song.id == payload.song_id).first()
    if not db_song:
        song = await source_manager.get_song(payload.song_id, db=db)
        if not song:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Song '{payload.song_id}' could not be resolved.",
            )

    # Check if song is already in the playlist
    existing = (
        db.query(PlaylistSong)
        .filter(
            PlaylistSong.playlist_id == playlist_id,
            PlaylistSong.song_id == payload.song_id,
        )
        .first()
    )
    if existing:
        # Song already in playlist, return current detail without duplicating
        return await get_playlist(playlist_id, db=db)

    # Determine next position
    max_pos = (
        db.query(PlaylistSong.position)
        .filter(PlaylistSong.playlist_id == playlist_id)
        .order_by(desc(PlaylistSong.position))
        .first()
    )
    next_pos = (max_pos[0] + 1) if max_pos else 0

    entry = PlaylistSong(
        playlist_id=playlist_id,
        song_id=payload.song_id,
        position=next_pos,
    )
    db.add(entry)
    db.commit()
    db.refresh(playlist)

    return await get_playlist(playlist_id, db=db)


@router.delete("/{playlist_id}/songs/{song_id:path}", response_model=PlaylistDetailRead)
async def remove_song_from_playlist(
    playlist_id: int,
    song_id: str,
    db: Session = Depends(get_db),
):
    """Remove a song from a playlist."""
    entry = (
        db.query(PlaylistSong)
        .filter(
            PlaylistSong.playlist_id == playlist_id,
            PlaylistSong.song_id == song_id,
        )
        .first()
    )
    if not entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Song '{song_id}' not found in playlist {playlist_id}.",
        )

    db.delete(entry)
    db.commit()

    return await get_playlist(playlist_id, db=db)


@router.put("/{playlist_id}/reorder", response_model=PlaylistDetailRead)
async def reorder_playlist_songs(
    playlist_id: int,
    payload: PlaylistReorder,
    db: Session = Depends(get_db),
):
    """Update order of songs in a playlist."""
    playlist = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not playlist:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Playlist with id {playlist_id} not found.",
        )

    # Re-assign positions based on the order in the payload
    for new_index, song_id in enumerate(payload.song_ids):
        entry = (
            db.query(PlaylistSong)
            .filter(
                PlaylistSong.playlist_id == playlist_id,
                PlaylistSong.song_id == song_id,
            )
            .first()
        )
        if entry:
            entry.position = new_index

    db.commit()
    return await get_playlist(playlist_id, db=db)
