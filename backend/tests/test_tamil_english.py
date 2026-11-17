"""Tests for Tamil & English curation, is_full flags, and library rescan."""
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.sources.manager import load_artists_config

client = TestClient(app)


def test_artists_config_loaded():
    cfg = load_artists_config()
    assert "tamil" in cfg
    assert "english" in cfg
    assert any("Anirudh" in a for a in cfg["tamil"])
    assert any("Weeknd" in a for a in cfg["english"])


def test_library_rescan_endpoint():
    res = client.post("/library/rescan")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "success"
    assert "total_tracks" in data
    assert isinstance(data["total_tracks"], int)


def test_charts_language_filters():
    # Test Tamil language
    res_tamil = client.get("/charts?language=tamil&limit=5")
    assert res_tamil.status_code == 200
    data_tamil = res_tamil.json()
    assert data_tamil["language"] == "tamil"
    assert "tamil_trending" in data_tamil
    assert "my_music" in data_tamil

    # Test English language
    res_english = client.get("/charts?language=english&limit=5")
    assert res_english.status_code == 200
    data_english = res_english.json()
    assert data_english["language"] == "english"
    assert "english_trending" in data_english

    # Test Both languages
    res_both = client.get("/charts?language=both&limit=5")
    assert res_both.status_code == 200
    data_both = res_both.json()
    assert data_both["language"] == "both"


def test_song_is_full_flag():
    res = client.get("/charts?language=both&limit=5")
    assert res.status_code == 200
    data = res.json()
    songs = data.get("trending_now", []) or data.get("tamil_trending", []) or data.get("english_trending", [])
    if songs:
        song = songs[0]
        assert "is_full" in song
        assert isinstance(song["is_full"], bool)
        assert song["is_full"] == (not song["is_preview"])
