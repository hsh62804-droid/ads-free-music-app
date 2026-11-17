"""Tests for Phase 3: Official YouTube Data API v3 Source and Full-version resolver."""
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.services.sources.youtube import YouTubeSource, parse_iso8601_duration
from app.services.sources.manager import source_manager


def test_parse_iso8601_duration():
    assert parse_iso8601_duration("PT3M45S") == 225
    assert parse_iso8601_duration("PT1H2M30S") == 3750
    assert parse_iso8601_duration("PT55S") == 55
    assert parse_iso8601_duration("PT4M") == 240
    assert parse_iso8601_duration("") == 0


@pytest.mark.asyncio
async def test_youtube_source_curated_search():
    yt = YouTubeSource(api_key=None)
    # Search for iconic Tamil song
    tamil_results = await yt.search("Naa Ready", limit=5)
    assert len(tamil_results) > 0
    assert tamil_results[0].source == "youtube"
    assert tamil_results[0].is_full is True
    assert tamil_results[0].is_preview is False
    assert "youtube.com" in tamil_results[0].stream_url

    # Search for iconic English song
    english_results = await yt.search("Blinding Lights", limit=5)
    assert len(english_results) > 0
    assert english_results[0].artist == "The Weeknd"
    assert english_results[0].is_full is True


@pytest.mark.asyncio
async def test_youtube_trending():
    yt = YouTubeSource(api_key=None)
    trending = await yt.trending(limit=10)
    assert len(trending) > 0
    for song in trending:
        assert song.source == "youtube"
        assert song.is_full is True


@pytest.mark.asyncio
async def test_full_version_endpoint():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # Request full version of a YouTube track
        res = await client.get("/songs/youtube:szvt1vD0Uug/full_version")
        assert res.status_code == 200
        data = res.json()
        assert data["id"] == "youtube:szvt1vD0Uug"
        assert data["is_full"] is True
        assert data["source"] == "youtube"
