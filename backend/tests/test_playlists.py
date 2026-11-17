"""Integration tests for Playlist endpoints."""
import pytest
from fastapi.testclient import TestClient

from app.db import init_db, SessionLocal
from app.main import app
from app.models import Song, Playlist, PlaylistSong

init_db()
client = TestClient(app)


@pytest.fixture(autouse=True)
def clean_db():
    """Clean playlist and song tables between tests."""
    db = SessionLocal()
    db.query(PlaylistSong).delete()
    db.query(Playlist).delete()
    db.query(Song).delete()
    db.commit()
    db.close()


def seed_songs():
    """Seed test songs into SQLite."""
    db = SessionLocal()
    s1 = Song(id="audius:p1", source="audius", source_id="p1", title="Track One", artist="Artist 1")
    s2 = Song(id="audius:p2", source="audius", source_id="p2", title="Track Two", artist="Artist 2")
    s3 = Song(id="audius:p3", source="audius", source_id="p3", title="Track Three", artist="Artist 3")
    db.add_all([s1, s2, s3])
    db.commit()
    db.close()


def test_playlist_crud_lifecycle():
    """Verify creating, reading, updating, and deleting playlists."""
    # 1. Create playlist
    create_res = client.post("/playlists", json={
        "name": "My Workout Mix",
        "description": "High energy beats",
    })
    assert create_res.status_code == 201
    p_data = create_res.json()
    playlist_id = p_data["id"]
    assert p_data["name"] == "My Workout Mix"
    assert p_data["song_count"] == 0

    # 2. List playlists
    list_res = client.get("/playlists")
    assert list_res.status_code == 200
    assert len(list_res.json()) == 1

    # 3. Update playlist
    patch_res = client.patch(f"/playlists/{playlist_id}", json={
        "name": "Heavy Cardio Beats",
        "description": "Updated description",
    })
    assert patch_res.status_code == 200
    assert patch_res.json()["name"] == "Heavy Cardio Beats"
    assert patch_res.json()["description"] == "Updated description"

    # 4. Delete playlist
    del_res = client.delete(f"/playlists/{playlist_id}")
    assert del_res.status_code == 204

    # 5. Verify deleted
    get_res = client.get(f"/playlists/{playlist_id}")
    assert get_res.status_code == 404


def test_playlist_songs_management():
    """Verify adding, removing, and reordering songs in playlist."""
    seed_songs()

    # 1. Create playlist
    create_res = client.post("/playlists", json={"name": "Favorites"})
    playlist_id = create_res.json()["id"]

    # 2. Add songs p1 and p2
    add1 = client.post(f"/playlists/{playlist_id}/songs", json={"song_id": "audius:p1"})
    assert add1.status_code == 200
    assert add1.json()["song_count"] == 1

    add2 = client.post(f"/playlists/{playlist_id}/songs", json={"song_id": "audius:p2"})
    assert add2.status_code == 200
    assert add2.json()["song_count"] == 2
    assert add2.json()["songs"][0]["id"] == "audius:p1"
    assert add2.json()["songs"][1]["id"] == "audius:p2"

    # 3. Duplicate add should not duplicate song
    add_dup = client.post(f"/playlists/{playlist_id}/songs", json={"song_id": "audius:p1"})
    assert add_dup.status_code == 200
    assert add_dup.json()["song_count"] == 2

    # 4. Reorder songs (swap p2 and p1)
    reorder_res = client.put(f"/playlists/{playlist_id}/reorder", json={
        "song_ids": ["audius:p2", "audius:p1"]
    })
    assert reorder_res.status_code == 200
    songs = reorder_res.json()["songs"]
    assert songs[0]["id"] == "audius:p2"
    assert songs[1]["id"] == "audius:p1"

    # 5. Remove song p1
    rem_res = client.delete(f"/playlists/{playlist_id}/songs/audius:p1")
    assert rem_res.status_code == 200
    assert rem_res.json()["song_count"] == 1
    assert rem_res.json()["songs"][0]["id"] == "audius:p2"
