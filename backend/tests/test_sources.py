"""Unit tests for music source providers and source manager."""
import pytest
import respx
import httpx

from app.services.sources.audius import AudiusSource
from app.services.sources.jamendo import JamendoSource
from app.services.sources.manager import SourceManager


@pytest.mark.asyncio
async def test_audius_parse_and_stream():
    """Verify Audius source returns valid stream URL format."""
    source = AudiusSource(app_name="TestApp")
    source._cached_host = "https://discoveryprovider.audius.co"

    stream_info = await source.get_stream_url("track123")
    assert stream_info.song_id == "audius:track123"
    assert "track123/stream" in stream_info.stream_url
    assert stream_info.bitrate_kbps == 320


@pytest.mark.asyncio
@respx.mock
async def test_audius_search_mocked():
    """Verify Audius search with mocked discovery node."""
    host = "https://discoveryprovider.audius.co"
    source = AudiusSource(app_name="TestApp")
    source._cached_host = host

    mock_track = {
        "id": "abc12345",
        "title": "Neon Lights",
        "duration": 210,
        "genre": "Electronic",
        "artwork": {"1000x1000": "https://img.audius.co/neon.jpg"},
        "user": {"name": "RetroWave", "handle": "retrowave"},
    }

    respx.get(f"{host}/v1/tracks/search").mock(
        return_value=httpx.Response(200, json={"data": [mock_track]})
    )

    results = await source.search("neon")
    assert len(results) == 1
    song = results[0]
    assert song.id == "audius:abc12345"
    assert song.title == "Neon Lights"
    assert song.artist == "RetroWave"
    assert song.duration_seconds == 210
    assert song.genre == "Electronic"


@pytest.mark.asyncio
async def test_jamendo_unconfigured():
    """Verify unconfigured Jamendo gracefully returns empty results."""
    source = JamendoSource(client_id=None)
    assert source.is_configured is False
    assert await source.search("rock") == []
    assert await source.trending() == []


@pytest.mark.asyncio
@respx.mock
async def test_jamendo_search_configured():
    """Verify configured Jamendo search parsing."""
    source = JamendoSource(client_id="test_client_id")
    assert source.is_configured is True

    mock_jamendo_track = {
        "id": "999888",
        "name": "Summer Breeze",
        "artist_name": "Acoustic Band",
        "album_name": "Sunsets",
        "duration": 185,
        "image": "https://img.jamendo.com/track.jpg",
        "audio": "https://prod-1.storage.jamendo.com/audio.mp3",
        "musicinfo": {"tags": {"genres": ["Acoustic", "Folk"]}},
    }

    respx.get("https://api.jamendo.com/v3.0/tracks/").mock(
        return_value=httpx.Response(200, json={"results": [mock_jamendo_track]})
    )

    results = await source.search("summer")
    assert len(results) == 1
    song = results[0]
    assert song.id == "jamendo:999888"
    assert song.title == "Summer Breeze"
    assert song.artist == "Acoustic Band"
    assert song.stream_url == "https://prod-1.storage.jamendo.com/audio.mp3"


def test_source_manager_parse_id():
    """Test parse_id helper on SourceManager."""
    src, track_id = SourceManager.parse_id("audius:xyz789")
    assert src == "audius"
    assert track_id == "xyz789"

    src2, track_id2 = SourceManager.parse_id("jamendo:12345")
    assert src2 == "jamendo"
    assert track_id2 == "12345"

    with pytest.raises(ValueError):
        SourceManager.parse_id("invalid_no_colon")
