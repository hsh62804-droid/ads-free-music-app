import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/data/models/song_model.dart';

void main() {
  test('SongModel with YouTube source', () {
    final song = SongModel(
      id: 'youtube:szvt1vD0Uug',
      source: 'youtube',
      sourceId: 'szvt1vD0Uug',
      title: 'Naa Ready',
      artist: 'Anirudh Ravichander',
      isFull: true,
      isPreview: false,
      streamUrl: 'https://www.youtube.com/watch?v=szvt1vD0Uug',
      artworkUrl: 'https://i.ytimg.com/vi/szvt1vD0Uug/hqdefault.jpg',
    );
    expect(song.source, 'youtube');
    expect(song.isFull, true);
    expect(song.isPreview, false);
    expect(song.streamUrl, contains('youtube.com'));
    expect(song.artworkUrl, contains('ytimg.com'));
  });
}
