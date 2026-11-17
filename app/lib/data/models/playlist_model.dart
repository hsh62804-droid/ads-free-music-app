import 'song_model.dart';

class PlaylistModel {
  final int id;
  final String name;
  final String? description;
  final String? coverUrl;
  final int songCount;
  final List<SongModel> songs;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PlaylistModel({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    this.songCount = 0,
    this.songs = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory PlaylistModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? rawSongs = json['songs'] as List<dynamic>?;
    final List<SongModel> parsedSongs = rawSongs != null
        ? rawSongs.map((s) => SongModel.fromJson(s as Map<String, dynamic>)).toList()
        : [];

    return PlaylistModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Untitled Playlist',
      description: json['description'] as String?,
      coverUrl: json['cover_url'] as String?,
      songCount: json['song_count'] as int? ?? parsedSongs.length,
      songs: parsedSongs,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'cover_url': coverUrl,
      'song_count': songCount,
      'songs': songs.map((s) => s.toJson()).toList(),
    };
  }

  PlaylistModel copyWith({
    int? id,
    String? name,
    String? description,
    String? coverUrl,
    int? songCount,
    List<SongModel>? songs,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      songCount: songCount ?? this.songCount,
      songs: songs ?? this.songs,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
