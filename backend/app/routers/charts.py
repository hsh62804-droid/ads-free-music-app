"""Routers for famous trending charts, country tops, and home sections."""
from typing import List
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.db import get_db
from app.routers.search import enrich_with_likes
from app.schemas import ArtistRead, HomeSectionsResult, SongRead
from app.services.sources.manager import source_manager

router = APIRouter(prefix="/charts", tags=["charts"])


@router.get("", response_model=HomeSectionsResult)
async def get_charts(
    country: str = Query("IN", description="Country code for top charts ('IN', 'US', 'GB')"),
    language: str = Query("both", description="Preferred language filter ('tamil', 'english', 'both')"),
    limit: int = Query(15, ge=5, le=50, description="Items per section"),
    db: Session = Depends(get_db),
):
    """Fetch home screen sections tailored to Tamil & English music cached for 30 minutes."""
    sections = await source_manager.get_home_sections(country=country, language=language, limit=limit, db=db)
    
    # Attach like status to all song lists
    enrich_with_likes(db, sections.tamil_trending)
    enrich_with_likes(db, sections.english_trending)
    enrich_with_likes(db, sections.tamil_indie)
    enrich_with_likes(db, sections.english_indie)
    enrich_with_likes(db, sections.my_music)
    enrich_with_likes(db, sections.made_for_you)
    enrich_with_likes(db, sections.trending_now)
    enrich_with_likes(db, sections.top_by_country)
    enrich_with_likes(db, sections.independent_picks)

    return sections


@router.get("/tamil-trending", response_model=List[SongRead])
async def get_tamil_trending_section(
    limit: int = Query(15, ge=1, le=50),
    db: Session = Depends(get_db),
):
    """Fetch Tamil trending tracks independently."""
    songs = await source_manager.get_tamil_trending(limit=limit)
    enrich_with_likes(db, songs)
    return songs


@router.get("/english-trending", response_model=List[SongRead])
async def get_english_trending_section(
    limit: int = Query(15, ge=1, le=50),
    db: Session = Depends(get_db),
):
    """Fetch English trending tracks independently."""
    songs = await source_manager.get_english_trending(limit=limit)
    enrich_with_likes(db, songs)
    return songs


@router.get("/made-for-you", response_model=List[SongRead])
async def get_made_for_you_section(
    limit: int = Query(15, ge=1, le=50),
    db: Session = Depends(get_db),
):
    """Fetch personalized Made for You tracks independently."""
    songs = await source_manager.get_made_for_you(limit=limit, db=db)
    enrich_with_likes(db, songs)
    return songs


@router.get("/independent-picks", response_model=List[SongRead])
async def get_independent_picks_section(
    limit: int = Query(15, ge=1, le=50),
    db: Session = Depends(get_db),
):
    """Fetch independent picks from Audius & Jamendo independently."""
    songs = await source_manager.get_independent_picks(limit=limit)
    enrich_with_likes(db, songs)
    return songs


@router.get("/artists", response_model=List[ArtistRead])
async def get_top_artists(
    limit: int = Query(15, ge=1, le=50),
):
    """Retrieve top trending artists from Deezer chart."""
    return await source_manager.deezer.get_top_artists(limit=limit)
