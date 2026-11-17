"""Integration tests for FastAPI endpoints."""
import pytest
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock, patch

from app.db import init_db
from app.main import app
from app.schemas import SongRead, StreamInfo

# Ensure tables exist for tests
init_db()

client = TestClient(app)


def test_health_and_root():
    """Verify health and root endpoints return 200 OK."""
    res_root = client.get("/")
    assert res_root.status_code == 200
    assert res_root.json()["status"] == "online"

    res_health = client.get("/health")
    assert res_health.status_code == 200
    assert res_health.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_search_endpoint():
    """Verify GET /search calls manager and returns results schema."""
    fake_songs = [
        SongRead(
            id="audius:mock1",
            source="audius",
            source_id="mock1",
            title="Lofi Beats",
            artist="Chill Guy",
            duration_seconds=120,
            genre="Lofi",
        )
    ]

    with patch("app.routers.search.source_manager.search", new_callable=AsyncMock) as mock_search:
        mock_search.return_value = fake_songs
        response = client.get("/search?q=lofi")
        assert response.status_code == 200
        data = response.json()
        assert data["query"] == "lofi"
        assert data["total"] == 1
        assert data["results"][0]["title"] == "Lofi Beats"
        assert data["results"][0]["id"] == "audius:mock1"


@pytest.mark.asyncio
async def test_trending_endpoint():
    """Verify GET /trending returns results schema."""
    fake_songs = [
        SongRead(
            id="audius:trend1",
            source="audius",
            source_id="trend1",
            title="Top Chart Song",
            artist="Star Artist",
            duration_seconds=180,
        )
    ]

    with patch("app.routers.search.source_manager.trending", new_callable=AsyncMock) as mock_trend:
        mock_trend.return_value = fake_songs
        response = client.get("/trending")
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 1
        assert data["results"][0]["id"] == "audius:trend1"


@pytest.mark.asyncio
async def test_songs_stream_redirect():
    """Verify GET /songs/{id}/stream redirects with 302 by default."""
    fake_stream = StreamInfo(
        song_id="audius:123",
        stream_url="https://audio-cdn.audius.co/stream/123.mp3",
        format="mp3",
        bitrate_kbps=320,
        is_direct_url=True,
    )

    with patch("app.routers.songs.source_manager.get_stream_url", new_callable=AsyncMock) as mock_stream:
        mock_stream.return_value = fake_stream
        response = client.get("/songs/audius:123/stream", follow_redirects=False)
        assert response.status_code == 302
        assert response.headers["location"] == "https://audio-cdn.audius.co/stream/123.mp3"


@pytest.mark.asyncio
async def test_songs_stream_json():
    """Verify GET /songs/{id}/stream?redirect=false returns JSON StreamInfo."""
    fake_stream = StreamInfo(
        song_id="audius:123",
        stream_url="https://audio-cdn.audius.co/stream/123.mp3",
        format="mp3",
        bitrate_kbps=320,
        is_direct_url=True,
    )

    with patch("app.routers.songs.source_manager.get_stream_url", new_callable=AsyncMock) as mock_stream:
        mock_stream.return_value = fake_stream
        response = client.get("/songs/audius:123/stream?redirect=false")
        assert response.status_code == 200
        data = response.json()
        assert data["song_id"] == "audius:123"
        assert data["stream_url"] == "https://audio-cdn.audius.co/stream/123.mp3"
        assert data["bitrate_kbps"] == 320
