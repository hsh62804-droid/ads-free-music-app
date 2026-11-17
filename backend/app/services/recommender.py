"""Music Recommendation Service with pluggable scoring engine."""
from abc import ABC, abstractmethod
from collections import defaultdict
import logging
from typing import Dict, List, Set
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.models import Like, PlayHistory, Song
from app.schemas import SongRead
from app.services.sources.manager import source_manager

logger = logging.getLogger(__name__)


class BaseRecommender(ABC):
    """Abstract recommender interface allowing rule-based or ML models."""

    @abstractmethod
    async def get_recommendations(self, db: Session, limit: int = 20) -> List[SongRead]:
        """Compute recommended tracks for the single user."""
        pass


class RuleBasedRecommender(BaseRecommender):
    """Rule-based scoring recommender matching artists and genres from likes and play history,

    with penalization for tracks skipped quickly (< 15 seconds).
    """

    # Scoring weights
    WEIGHT_LIKE_ARTIST = 3.0
    WEIGHT_LIKE_GENRE = 2.0
    WEIGHT_PLAY_COMPLETE_ARTIST = 2.0
    WEIGHT_PLAY_COMPLETE_GENRE = 1.0
    PENALTY_SKIP_ARTIST = -2.5
    PENALTY_SKIP_GENRE = -1.5

    async def get_recommendations(self, db: Session, limit: int = 20) -> List[SongRead]:
        """Generate, score, and rank songs tailored to user preferences."""
        # 1. Build user profile: calculate affinity scores for artists and genres
        artist_scores: Dict[str, float] = defaultdict(float)
        genre_scores: Dict[str, float] = defaultdict(float)
        played_or_liked_ids: Set[str] = set()

        # Process Likes (Strong positive signal)
        liked_songs = (
            db.query(Song)
            .join(Like, Song.id == Like.song_id)
            .all()
        )
        for s in liked_songs:
            played_or_liked_ids.add(s.id)
            if s.artist:
                artist_scores[s.artist.lower()] += self.WEIGHT_LIKE_ARTIST
            if s.genre:
                genre_scores[s.genre.lower()] += self.WEIGHT_LIKE_GENRE

        # Process Play History (Completed plays boost; quick skips penalize)
        history_records = (
            db.query(PlayHistory)
            .order_by(desc(PlayHistory.played_at))
            .limit(100)
            .all()
        )

        for record in history_records:
            song = record.song
            if not song:
                continue
            played_or_liked_ids.add(song.id)
            artist_key = song.artist.lower() if song.artist else None
            genre_key = song.genre.lower() if song.genre else None

            # Quick skip penalty: played under 15s and marked incomplete
            is_quick_skip = not record.completed and record.played_duration_seconds < 15

            if is_quick_skip:
                if artist_key:
                    artist_scores[artist_key] += self.PENALTY_SKIP_ARTIST
                if genre_key:
                    genre_scores[genre_key] += self.PENALTY_SKIP_GENRE
            elif record.completed:
                if artist_key:
                    artist_scores[artist_key] += self.WEIGHT_PLAY_COMPLETE_ARTIST
                if genre_key:
                    genre_scores[genre_key] += self.WEIGHT_PLAY_COMPLETE_GENRE

        # 2. Candidate Generation: fetch candidates from trending and top sources
        candidates: List[SongRead] = []
        try:
            trending_candidates = await source_manager.trending(source="all", limit=40, db=db)
            candidates.extend(trending_candidates)
        except Exception as e:
            logger.error("Error gathering candidate tracks for recommendation: %s", e)

        # Also pull cached tracks from DB that user hasn't liked yet
        db_cached = (
            db.query(Song)
            .filter(~Song.id.in_(played_or_liked_ids) if played_or_liked_ids else True)
            .order_by(desc(Song.created_at))
            .limit(30)
            .all()
        )
        for s in db_cached:
            candidates.append(SongRead.model_validate(s))

        # 3. Deduplicate candidate tracks
        unique_candidates: Dict[str, SongRead] = {}
        for c in candidates:
            if c.id not in unique_candidates:
                unique_candidates[c.id] = c

        # 4. Score each candidate track
        scored_tracks: List[tuple[float, SongRead]] = []
        for song in unique_candidates.values():
            score = 1.0  # Base discovery baseline score

            # Artist affinity match
            if song.artist:
                score += artist_scores.get(song.artist.lower(), 0.0)

            # Genre affinity match
            if song.genre:
                score += genre_scores.get(song.genre.lower(), 0.0)

            # Slight penalty if user already liked it (encourage discovery)
            if song.id in played_or_liked_ids:
                score -= 1.0

            scored_tracks.append((score, song))

        # 5. Sort by highest score first
        scored_tracks.sort(key=lambda x: x[0], reverse=True)

        # Return top N recommendations
        return [track for _, track in scored_tracks[:limit]]


# Default recommender instance (can be swapped for an ML model)
recommender_service: BaseRecommender = RuleBasedRecommender()
