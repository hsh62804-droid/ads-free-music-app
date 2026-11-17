import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/data/models/song_model.dart';
import 'package:music_app/data/models/playlist_model.dart';
import 'package:music_app/data/models/play_history_model.dart';
import 'package:music_app/data/models/artist_model.dart';
import 'package:music_app/data/models/home_sections_model.dart';

void main() {
  group('SongModel Tests', () {
    test('fromJson and toJson roundtrip', () {
      final json = {
        'id': 'deezer:123',
        'source': 'deezer',
        'source_id': '123',
        'title': 'Test Track',
        'artist': 'Test Artist',
        'album': 'Test Album',
        'duration_seconds': 30,
        'artwork_url': 'https://example.com/art.jpg',
        'stream_url': 'https://example.com/stream.mp3',
        'genre': 'Pop',
        'is_liked': true,
        'is_preview': true,
        'is_full': false,
      };

      final song = SongModel.fromJson(json);
      expect(song.id, 'deezer:123');
      expect(song.title, 'Test Track');
      expect(song.artist, 'Test Artist');
      expect(song.durationSeconds, 30);
      expect(song.isLiked, isTrue);
      expect(song.isPreview, isTrue);
      expect(song.isFull, isFalse);

      final outJson = song.toJson();
      expect(outJson['id'], 'deezer:123');
      expect(outJson['is_preview'], isTrue);
      expect(outJson['is_full'], isFalse);
    });

    test('copyWith updates specific fields', () {
      final song = SongModel(
        id: '1',
        source: 'audius',
        sourceId: '1',
        title: 'Original Title',
        artist: 'Artist',
        isPreview: true,
        isFull: false,
      );

      final updated = song.copyWith(title: 'Updated Title', isPreview: false, isFull: true);
      expect(updated.title, 'Updated Title');
      expect(updated.artist, 'Artist');
      expect(updated.isPreview, isFalse);
      expect(updated.isFull, isTrue);
    });
  });

  group('ArtistModel Tests', () {
    test('fromJson and toJson', () {
      final json = {
        'id': '13',
        'name': 'Eminem',
        'picture_url': 'https://example.com/eminem.jpg',
        'track_count': 50000000,
      };

      final artist = ArtistModel.fromJson(json);
      expect(artist.id, '13');
      expect(artist.name, 'Eminem');
      expect(artist.trackCount, 50000000);
    });
  });

  group('HomeSectionsModel Tests', () {
    test('fromJson parses sections', () {
      final json = {
        'trending_now': [
          {
            'id': 'deezer:1',
            'source': 'deezer',
            'source_id': '1',
            'title': 'Viral Hit',
            'artist': 'Star',
            'is_preview': true,
            'is_full': false,
          }
        ],
        'top_by_country': [],
        'country': 'IN',
        'language': 'both',
        'tamil_trending': [
          {
            'id': 'deezer:2',
            'source': 'deezer',
            'source_id': '2',
            'title': 'Hukum',
            'artist': 'Anirudh Ravichander',
            'is_preview': true,
            'is_full': false,
          }
        ],
        'english_trending': [],
        'tamil_indie': [],
        'english_indie': [],
        'my_music': [],
        'top_artists': [
          {'id': '1', 'name': 'Arijit Singh'}
        ],
        'made_for_you': [],
        'independent_picks': [],
      };

      final sections = HomeSectionsModel.fromJson(json);
      expect(sections.trendingNow.length, 1);
      expect(sections.trendingNow.first.isPreview, isTrue);
      expect(sections.trendingNow.first.isFull, isFalse);
      expect(sections.country, 'IN');
      expect(sections.language, 'both');
      expect(sections.tamilTrending.length, 1);
      expect(sections.tamilTrending.first.title, 'Hukum');
      expect(sections.topArtists.first.name, 'Arijit Singh');
    });
  });

  group('PlaylistModel Tests', () {
    test('fromJson parses playlist and songs list', () {
      final json = {
        'id': 1,
        'name': 'Chill Vibes',
        'description': 'Relaxing tunes',
        'created_at': '2026-10-25T00:00:00',
        'song_count': 1,
        'songs': [
          {
            'id': 'jamendo:99',
            'source': 'jamendo',
            'source_id': '99',
            'title': 'Chill Beat',
            'artist': 'Producer X',
            'duration_seconds': 120,
          }
        ],
      };

      final playlist = PlaylistModel.fromJson(json);
      expect(playlist.id, 1);
      expect(playlist.name, 'Chill Vibes');
      expect(playlist.songCount, 1);
      expect(playlist.songs.length, 1);
      expect(playlist.songs.first.title, 'Chill Beat');
    });
  });

  group('PlayHistoryModel Tests', () {
    test('fromJson parses history entry', () {
      final json = {
        'id': 42,
        'song_id': 'audius:123',
        'played_at': '2026-10-25T11:00:00',
        'played_duration_seconds': 95,
        'completed': true,
        'song': {
          'id': 'audius:123',
          'source': 'audius',
          'source_id': '123',
          'title': 'History Song',
          'artist': 'History Artist',
          'duration_seconds': 100,
        },
      };

      final history = PlayHistoryModel.fromJson(json);
      expect(history.id, 42);
      expect(history.songId, 'audius:123');
      expect(history.playedDurationSeconds, 95);
      expect(history.completed, isTrue);
      expect(history.song?.title, 'History Song');
    });
  });
}
