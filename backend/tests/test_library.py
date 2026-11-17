"""Integration tests for Library endpoints (Likes & Play History)."""
import pytest
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock, patch

from app.db import init_db, SessionLocal
from app.main import app
from app.models import Song, Like, PlayHistory
from app.schemas import SongRead

init_db()
client = TestClient(app)


@pytest.fixture(autouse=True)
def clean_db():
    """Clean library tables between tests."""
    db = SessionLocal()
    db.query(Like).delete()
    db.query(PlayHistory).delete()
    db.query(Song).delete()
    db.commit()
    db.close()


def create_sample_song(song_id="audius:sample1", title="Sample Track", artist="Sample Artist"):
    """Helper to seed a song into local DB."""
    db = SessionLocal()
    song = Song(
        id=song_id,
        source="audius",
        source_id="sample1",
        title=title,
        artist=artist,
        duration_seconds=180,
    )
    db.add(song)
    db.commit()
    db.close()


def test_like_and_unlike_song():
    """Verify liking and unliking a song."""
    create_sample_song("audius:sample1")

    # 1. Like the song
    res_like = client.post("/library/likes/audius:sample1")
    assert res_like.status_code == 200
    assert res_like.json() == {"song_id": "audius:sample1", "is_liked": True}

    # 2. Check like status
    res_status = client.get("/library/likes/audius:sample1/status")
    assert res_status.status_code == 200
    assert res_status.json()["is_liked"] is True

    # 3. Check liked songs list
    res_list = client.get("/library/likes")
    assert res_list.status_code == 200
    data = res_list.json()
    assert data["total"] == 1
    assert data["results"][0]["id"] == "audius:sample1"
    assert data["results"][0]["is_liked"] is True

    # 4. Unlike the song
    res_unlike = client.delete("/library/likes/audius:sample1")
    assert res_unlike.status_code == 200
    assert res_unlike.json() == {"song_id": "audius:sample1", "is_liked": False}

    # 5. Verify list is now empty
    res_list2 = client.get("/library/likes")
    assert res_list2.json()["total"] == 0


@pytest.mark.asyncio
async def test_like_song_auto_resolves_uncached():
    """Verify liking a song not yet cached fetches it via source manager."""
    mock_song = SongRead(
        id="audius:uncached99",
        source="audius",
        source_id="uncached99",
        title="Discovered Song",
        artist="DJ Stream",
        duration_seconds=200,
    )

    with patch("app.routers.library.source_manager.get_song", new_callable=AsyncMock) as mock_get:
        mock_get.return_value = mock_song

        res = client.post("/library/likes/audius:uncached99")
        assert res.status_code == 200
        assert res.json()["is_liked"] is True


def test_play_history_lifecycle():
    """Verify recording, listing, and clearing play history."""
    create_sample_song("audius:sample1", "Groove 1")
    create_sample_song("audius:sample2", "Groove 2")

    # 1. Record play for sample 1
    res1 = client.post("/library/history", json={
        "song_id": "audius:sample1",
        "played_duration_seconds": 120,
        "completed": True,
    })
    assert res1.status_code == 200
    data1 = res1.json()
    assert data1["song_id"] == "audius:sample1"
    assert data1["completed"] is True
    assert data1["song"]["title"] == "Groove 1"

    # 2. Record play for sample 2
    res2 = client.post("/library/history", json={
        "song_id": "audius:sample2",
        "played_duration_seconds": 30,
        "completed": False,
    })
    assert res2.status_code == 200

    # 3. Retrieve history list
    res_hist = client.get("/library/history?limit=10")
    assert res_hist.status_code == 200
    hist_data = res_hist.json()
    assert hist_data["total"] == 2
    # Most recent first
    assert hist_data["results"][0]["song_id"] == "audius:sample2"

    # 4. Clear history
    res_clear = client.delete("/library/history")
    assert res_clear.status_code == 200

    # 5. Verify history is empty
    res_empty = client.get("/library/history")
    assert res_empty.json()["total"] == 0
