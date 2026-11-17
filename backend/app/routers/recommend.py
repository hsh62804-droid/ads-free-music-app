"""Router for personalized song suggestions and recommendations."""
from typing import List
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Like
from app.schemas import SongRead, TrendingResult
from app.services.recommender import recommender_service

router = APIRouter(tags=["recommendations"])


@router.get("/recommend", response_model=TrendingResult)
async def get_recommendations(
    limit: int = Query(20, ge=1, le=50, description="Number of suggestions to return"),
    db: Session = Depends(get_db),
):
    """Retrieve personalized song suggestions scored from your likes and listening habits.

    Songs with artists or genres you skip quickly are penalized.
    """
    recommended_songs = await recommender_service.get_recommendations(db=db, limit=limit)

    # Attach is_liked status
    song_ids = [s.id for s in recommended_songs]
    liked_ids = set(
        row[0] for row in db.query(Like.song_id).filter(Like.song_id.in_(song_ids)).all()
    )
    for s in recommended_songs:
        s.is_liked = s.id in liked_ids

    return TrendingResult(
        source="recommendation_engine",
        total=len(recommended_songs),
        results=recommended_songs,
    )
