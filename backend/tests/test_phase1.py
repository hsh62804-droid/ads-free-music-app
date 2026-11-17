"""Unit and integration tests for Phase 1 upgrades."""
import os
from pathlib import Path
import pytest
from fastapi.testclient import TestClient

from app.db import Base, engine, get_db
from app.main import app
from app.services.sources.deezer import DeezerSource
from app.services.sources.itunes import ItunesSource
from app.services.sources.local import LocalSource, normalize_string
from app.services.sources.manager import source_manager


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.create_all(bind=engine)
    yield


@pytest.fixture
def client():
    return TestClient(app)


def test_normalize_string():
    assert normalize_string("Eminem (feat. Rihanna)") == "eminem"
    assert normalize_string("Lose Yourself [Official Video]") == "lose yourself"
    assert normalize_string("Don't Stop Believin'!") == "dont stop believin"


def test_local_source_and_matching(tmp_path):
    # Create a dummy audio file in temporary music dir
    music_dir = tmp_path / "music"
    music_dir.mkdir()
    fake_mp3 = music_dir / "Coldplay - Yellow.mp3"
    fake_mp3.write_bytes(b"ID3" + b"\x00" * 2000)

    local_source = LocalSource(music_dir=str(music_dir))
    count = local_source.scan_files()
    assert count == 1

    # Check match logic
    match = local_source.find_match(artist="Coldplay", title="Yellow")
    assert match is not None
    assert match.source == "local"
    assert match.is_preview is False


@pytest.mark.asyncio
async def test_itunes_source_search():
    itunes = ItunesSource()
    results = await itunes.search("Taylor Swift", limit=3)
    assert len(results) > 0
    first = results[0]
    assert first.source == "itunes"
    assert first.stream_url is not None
    assert first.is_preview is True


@pytest.mark.asyncio
async def test_itunes_country_top():
    itunes = ItunesSource()
    in_results = await itunes.get_country_top(country="IN", limit=3)
    assert len(in_results) > 0


def test_charts_endpoint(client):
    r = client.get("/charts?country=IN&limit=5")
    assert r.status_code == 200
    data = r.json()
    assert "trending_now" in data
    assert "top_by_country" in data
    assert "top_artists" in data
    assert "made_for_you" in data
    assert "independent_picks" in data
    assert data["country"] == "IN"


def test_local_range_streaming(client, tmp_path):
    # Setup temporary local music track
    fake_file = tmp_path / "stream_test.mp3"
    content = b"ABCDEFGHIJ" * 100  # 1000 bytes
    fake_file.write_bytes(content)

    source_manager.local._tracks_by_id["test123"] = (
        None,
        fake_file,
    )

    # 1. Full content request (no Range header)
    r = client.get("/songs/local:test123/stream")
    assert r.status_code == 200
    assert r.headers["Accept-Ranges"] == "bytes"
    assert len(r.content) == 1000

    # 2. Range request: bytes 10-29
    r_range = client.get("/songs/local:test123/stream", headers={"Range": "bytes=10-29"})
    assert r_range.status_code == 206
    assert r_range.headers["Content-Range"] == "bytes 10-29/1000"
    assert len(r_range.content) == 20
    assert r_range.content == content[10:30]
