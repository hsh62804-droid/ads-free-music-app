import 'dart:developer' as dev;
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/artist_model.dart';
import '../models/home_sections_model.dart';
import '../models/song_model.dart';

class MusicRepository {
  final ApiClient _apiClient;

  MusicRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Fetch trending tracks across sources
  Future<List<SongModel>> getTrending({String source = 'all', int limit = 20}) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.trendingEndpoint,
        queryParameters: {'source': source, 'limit': limit},
      );
      if (response.statusCode == 200 && response.data != null) {
        final List results = response.data['results'] ?? [];
        return results.map((item) => SongModel.fromJson(item)).toList();
      }
    } catch (e) {
      dev.log('Error fetching trending tracks: $e', name: 'MusicRepository');
    }
    return [];
  }

  /// Search tracks across sources
  Future<List<SongModel>> search({
    required String query,
    String source = 'all',
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await _apiClient.get(
        ApiConstants.searchEndpoint,
        queryParameters: {'q': query, 'source': source, 'limit': limit},
      );
      if (response.statusCode == 200 && response.data != null) {
        final List results = response.data['results'] ?? [];
        return results.map((item) => SongModel.fromJson(item)).toList();
      }
    } catch (e) {
      dev.log('Error searching tracks: $e', name: 'MusicRepository');
    }
    return [];
  }

  /// Toggle like status for a track
  Future<bool> toggleLike(String songId, bool currentIsLiked) async {
    try {
      if (currentIsLiked) {
        final res = await _apiClient.delete('${ApiConstants.libraryLikesEndpoint}/$songId');
        return res.data?['is_liked'] ?? false;
      } else {
        final res = await _apiClient.post('${ApiConstants.libraryLikesEndpoint}/$songId');
        return res.data?['is_liked'] ?? true;
      }
    } catch (e) {
      dev.log('Error toggling like: $e', name: 'MusicRepository');
      return currentIsLiked;
    }
  }

  /// Record playback event for history & recommendation scoring
  Future<void> recordHistory({
    required String songId,
    required int playedDurationSeconds,
    required bool completed,
  }) async {
    try {
      await _apiClient.post(
        ApiConstants.libraryHistoryEndpoint,
        data: {
          'song_id': songId,
          'played_duration_seconds': playedDurationSeconds,
          'completed': completed,
        },
      );
    } catch (e) {
      dev.log('Error logging play history: $e', name: 'MusicRepository');
    }
  }

  /// Fetch user's liked songs
  Future<List<SongModel>> getLikedSongs({int limit = 50, int offset = 0}) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.libraryLikesEndpoint,
        queryParameters: {'limit': limit, 'offset': offset},
      );
      if (response.statusCode == 200 && response.data != null) {
        final List results = response.data['results'] ?? [];
        return results.map((item) => SongModel.fromJson(item)).toList();
      }
    } catch (e) {
      dev.log('Error fetching liked songs: $e', name: 'MusicRepository');
    }
    return [];
  }

  /// List all playlists
  Future<List<dynamic>> getPlaylists() async {
    try {
      final response = await _apiClient.get(ApiConstants.playlistsEndpoint);
      if (response.statusCode == 200 && response.data != null) {
        return response.data as List<dynamic>;
      }
    } catch (e) {
      dev.log('Error fetching playlists: $e', name: 'MusicRepository');
    }
    return [];
  }

  /// Get detailed playlist with songs
  Future<Map<String, dynamic>?> getPlaylistDetails(int playlistId) async {
    try {
      final response = await _apiClient.get('${ApiConstants.playlistsEndpoint}/$playlistId');
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      dev.log('Error fetching playlist details: $e', name: 'MusicRepository');
    }
    return null;
  }

  /// Create a new playlist
  Future<Map<String, dynamic>?> createPlaylist(String name, {String? description}) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.playlistsEndpoint,
        data: {'name': name, 'description': description},
      );
      if (response.statusCode == 201 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      dev.log('Error creating playlist: $e', name: 'MusicRepository');
    }
    return null;
  }

  /// Update playlist name / description
  Future<bool> updatePlaylist(int playlistId, {String? name, String? description}) async {
    try {
      final response = await _apiClient.patch(
        '${ApiConstants.playlistsEndpoint}/$playlistId',
        data: {'name': name, 'description': description},
      );
      return response.statusCode == 200;
    } catch (e) {
      dev.log('Error updating playlist: $e', name: 'MusicRepository');
      return false;
    }
  }

  /// Delete a playlist
  Future<bool> deletePlaylist(int playlistId) async {
    try {
      final response = await _apiClient.delete('${ApiConstants.playlistsEndpoint}/$playlistId');
      return response.statusCode == 204;
    } catch (e) {
      dev.log('Error deleting playlist: $e', name: 'MusicRepository');
      return false;
    }
  }

  /// Add a song to a playlist
  Future<bool> addSongToPlaylist(int playlistId, String songId) async {
    try {
      final response = await _apiClient.post(
        '${ApiConstants.playlistsEndpoint}/$playlistId/songs',
        data: {'song_id': songId},
      );
      return response.statusCode == 200;
    } catch (e) {
      dev.log('Error adding song to playlist: $e', name: 'MusicRepository');
      return false;
    }
  }

  /// Remove a song from a playlist
  Future<bool> removeSongFromPlaylist(int playlistId, String songId) async {
    try {
      final response = await _apiClient.delete(
        '${ApiConstants.playlistsEndpoint}/$playlistId/songs/$songId',
      );
      return response.statusCode == 200;
    } catch (e) {
      dev.log('Error removing song from playlist: $e', name: 'MusicRepository');
      return false;
    }
  }

  /// Reorder songs in playlist
  Future<bool> reorderPlaylist(int playlistId, List<String> songIds) async {
    try {
      final response = await _apiClient.client.put(
        '${ApiConstants.playlistsEndpoint}/$playlistId/reorder',
        data: {'song_ids': songIds},
      );
      return response.statusCode == 200;
    } catch (e) {
      dev.log('Error reordering playlist: $e', name: 'MusicRepository');
      return false;
    }
  }

  /// Get playback history
  Future<List<dynamic>> getPlayHistory({int limit = 50}) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.libraryHistoryEndpoint,
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data['results'] ?? [];
      }
    } catch (e) {
      dev.log('Error fetching play history: $e', name: 'MusicRepository');
    }
    return [];
  }

  static final Map<String, HomeSectionsModel> _homeCache = {};

  /// Retrieve cached home sections instantly without network roundtrip
  HomeSectionsModel? getCachedHomeSections({String country = 'IN', String language = 'both'}) {
    return _homeCache['$country-$language'];
  }

  /// Visible for testing cache operations
  static void setCachedHomeSectionsForTest(String key, HomeSectionsModel model) {
    _homeCache[key] = model;
  }

  /// Fetch all home screen sections (Tamil, English, My music, Indie, Made for You)
  Future<HomeSectionsModel> getHomeSections({
    String country = 'IN',
    String language = 'both',
    int limit = 15,
  }) async {
    final cacheKey = '$country-$language';
    try {
      final response = await _apiClient.get(
        ApiConstants.chartsEndpoint,
        queryParameters: {'country': country, 'language': language, 'limit': limit},
      );
      if (response.statusCode == 200 && response.data != null) {
        final sections = HomeSectionsModel.fromJson(response.data);
        _homeCache[cacheKey] = sections;
        return sections;
      }
    } catch (e) {
      dev.log('Error fetching home sections: $e', name: 'MusicRepository');
    }
    return _homeCache[cacheKey] ?? HomeSectionsModel();
  }

  /// Rescan backend/music/ folder for full local tracks
  Future<Map<String, dynamic>> rescanLibrary() async {
    try {
      final response = await _apiClient.post('/library/rescan');
      if (response.statusCode == 200 && response.data != null) {
        return Map<String, dynamic>.from(response.data);
      }
    } catch (e) {
      dev.log('Error rescanning library: $e', name: 'MusicRepository');
    }
    return {'status': 'error', 'message': 'Failed to reach backend to rescan.'};
  }

  /// Fetch all scanned local tracks from backend/music/
  Future<List<SongModel>> getLocalSongs({int limit = 100}) async {
    try {
      final response = await _apiClient.get(
        '/library/local',
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200 && response.data != null) {
        final List results = response.data['results'] ?? [];
        return results.map((item) => SongModel.fromJson(item)).toList();
      }
    } catch (e) {
      dev.log('Error fetching local songs: $e', name: 'MusicRepository');
    }
    return [];
  }

  /// Fetch top trending artists
  Future<List<ArtistModel>> getTopArtists({int limit = 15}) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.chartsEndpoint}/artists',
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => ArtistModel.fromJson(i)).toList();
      }
    } catch (e) {
      dev.log('Error fetching top artists: $e', name: 'MusicRepository');
    }
    return [];
  }

  /// Resolve a preview song (e.g. Deezer/iTunes) to full version (e.g. YouTube or local)
  Future<SongModel?> getFullVersion(String songId) async {
    try {
      final response = await _apiClient.get('/songs/$songId/full_version');
      if (response.statusCode == 200 && response.data != null) {
        return SongModel.fromJson(response.data);
      }
    } catch (e) {
      dev.log('Error fetching full version: $e', name: 'MusicRepository');
    }
    return null;
  }

  /// Fetch Tamil trending tracks independently
  Future<List<SongModel>> getTamilTrending({int limit = 15}) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.chartsEndpoint}/tamil-trending',
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => SongModel.fromJson(i)).toList();
      }
    } catch (e) {
      dev.log('Error fetching Tamil trending: $e', name: 'MusicRepository');
    }
    return [];
  }

  /// Fetch English trending tracks independently
  Future<List<SongModel>> getEnglishTrending({int limit = 15}) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.chartsEndpoint}/english-trending',
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => SongModel.fromJson(i)).toList();
      }
    } catch (e) {
      dev.log('Error fetching English trending: $e', name: 'MusicRepository');
    }
    return [];
  }

  /// Fetch Made for You tracks independently
  Future<List<SongModel>> getMadeForYou({int limit = 15}) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.chartsEndpoint}/made-for-you',
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => SongModel.fromJson(i)).toList();
      }
    } catch (e) {
      dev.log('Error fetching Made for you: $e', name: 'MusicRepository');
    }
    return [];
  }

  /// Fetch Independent Picks tracks independently
  Future<List<SongModel>> getIndependentPicks({int limit = 15}) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.chartsEndpoint}/independent-picks',
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => SongModel.fromJson(i)).toList();
      }
    } catch (e) {
      dev.log('Error fetching Independent picks: $e', name: 'MusicRepository');
    }
    return [];
  }
}


