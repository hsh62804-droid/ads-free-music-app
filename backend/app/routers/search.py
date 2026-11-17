"""Routers for music discovery: search and trending."""
from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Like
from app.schemas import SearchResult, TrendingResult
from app.services.sources.manager import source_manager

router = APIRouter(tags=["discovery"])


def enrich_with_likes(db: Session, songs: list) -> list:
    """Helper to attach is_liked=True if a song is in user's likes table."""
    if not songs:
        return songs
    song_ids = [s.id for s in songs]
    liked_ids = set(
        row[0] for row in db.query(Like.song_id).filter(Like.song_id.in_(song_ids)).all()
    )
    for s in songs:
        s.is_liked = s.id in liked_ids
    return songs


@router.get("/search", response_model=SearchResult)
async def search_tracks(
    q: str = Query(..., min_length=1, description="Search term for tracks or artists"),
    source: str = Query("all", description="Source filter: 'audius', 'jamendo', or 'all'"),
    limit: int = Query(20, ge=1, le=50, description="Maximum results to return"),
    db: Session = Depends(get_db),
):
    """Search for songs across Audius and Jamendo."""
    songs = await source_manager.search(query=q, source=source, limit=limit, db=db)
    enriched = enrich_with_likes(db, songs)
    return SearchResult(query=q, total=len(enriched), results=enriched)


@router.get("/trending", response_model=TrendingResult)
async def get_trending(
    source: str = Query("all", description="Source filter: 'audius', 'jamendo', or 'all'"),
    limit: int = Query(20, ge=1, le=50, description="Maximum results to return"),
    db: Session = Depends(get_db),
):
    """Retrieve hot and trending tracks across sources."""
    songs = await source_manager.trending(source=source, limit=limit, db=db)
    enriched = enrich_with_likes(db, songs)
    return TrendingResult(source=source, total=len(enriched), results=enriched)
