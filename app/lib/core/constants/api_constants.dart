// API configuration constants.
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  /// Resolves appropriate backend host:
  /// - Android Emulator: 10.0.2.2:8000
  static const String _envUrl = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    try {
      if (Platform.isAndroid) {
        // If built with --dart-define=API_URL=... that is used.
        // Otherwise, default to your computer's local Wi-Fi IP for physical phones:
        return 'http://192.168.1.9:8000';
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000';
  }

  // Endpoints
  static const String searchEndpoint = '/search';
  static const String trendingEndpoint = '/trending';
  static const String chartsEndpoint = '/charts';
  static const String songsEndpoint = '/songs';
  static const String libraryLikesEndpoint = '/library/likes';
  static const String libraryHistoryEndpoint = '/library/history';
  static const String playlistsEndpoint = '/playlists';
}
