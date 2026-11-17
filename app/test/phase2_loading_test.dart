import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/network/api_client.dart';
import 'package:music_app/data/models/home_sections_model.dart';
import 'package:music_app/data/models/song_model.dart';
import 'package:music_app/data/repositories/music_repository.dart';

void main() {
  group('Phase 2 Loading Problem Tests', () {
    test('ApiClient has tightened timeouts and retry interceptor', () {
      final client = ApiClient();
      expect(client.client.options.connectTimeout, const Duration(seconds: 4));
      expect(client.client.options.receiveTimeout, const Duration(seconds: 6));
      expect(client.client.options.sendTimeout, const Duration(seconds: 4));
      // Interceptors count: should have RetryInterceptor and error logger wrapper
      expect(client.client.interceptors.length, greaterThanOrEqualTo(2));
    });

    test('MusicRepository caches HomeSectionsModel for instant UI display', () {
      final repo = MusicRepository();

      // Verify getCachedHomeSections returns null initially
      final initial = repo.getCachedHomeSections(country: 'IN', language: 'both');
      expect(initial, isNull);

      // Simulate cached section
      final sample = HomeSectionsModel(
        myMusic: [
          SongModel(
            id: 'local_1',
            source: 'local',
            sourceId: 'kadhaippoma.mp3',
            title: 'Kadhaippoma',
            artist: 'Leon James',
            durationSeconds: 240,
            streamUrl: '/stream/local/kadhaippoma.mp3',
            isFull: true,
          ),
        ],
      );

      // Save into cache and retrieve
      MusicRepository.setCachedHomeSectionsForTest('IN-both', sample);
      final cached = repo.getCachedHomeSections(country: 'IN', language: 'both');
      expect(cached, isNotNull);
      expect(cached!.myMusic.length, 1);
      expect(cached.myMusic.first.title, 'Kadhaippoma');
    });
  });
}
