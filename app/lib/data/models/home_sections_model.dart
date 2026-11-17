import 'artist_model.dart';
import 'song_model.dart';

class HomeSectionsModel {
  final String language;
  final List<SongModel> tamilTrending;
  final List<SongModel> englishTrending;
  final List<SongModel> tamilIndie;
  final List<SongModel> englishIndie;
  final List<SongModel> myMusic;
  final List<SongModel> madeForYou;

  // Backward-compatible fields
  final List<SongModel> trendingNow;
  final List<SongModel> topByCountry;
  final String country;
  final List<ArtistModel> topArtists;
  final List<SongModel> independentPicks;

  HomeSectionsModel({
    this.language = 'both',
    this.tamilTrending = const [],
    this.englishTrending = const [],
    this.tamilIndie = const [],
    this.englishIndie = const [],
    this.myMusic = const [],
    this.madeForYou = const [],
    this.trendingNow = const [],
    this.topByCountry = const [],
    this.country = 'IN',
    this.topArtists = const [],
    this.independentPicks = const [],
  });

  factory HomeSectionsModel.fromJson(Map<String, dynamic> json) {
    List<SongModel> parseSongs(dynamic list) {
      if (list is List) {
        return list.map((item) => SongModel.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    }

    List<ArtistModel> parseArtists(dynamic list) {
      if (list is List) {
        return list.map((item) => ArtistModel.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    }

    return HomeSectionsModel(
      language: json['language'] as String? ?? 'both',
      tamilTrending: parseSongs(json['tamil_trending']),
      englishTrending: parseSongs(json['english_trending']),
      tamilIndie: parseSongs(json['tamil_indie']),
      englishIndie: parseSongs(json['english_indie']),
      myMusic: parseSongs(json['my_music']),
      madeForYou: parseSongs(json['made_for_you']),
      trendingNow: parseSongs(json['trending_now']),
      topByCountry: parseSongs(json['top_by_country']),
      country: json['country'] as String? ?? 'IN',
      topArtists: parseArtists(json['top_artists']),
      independentPicks: parseSongs(json['independent_picks']),
    );
  }
}
