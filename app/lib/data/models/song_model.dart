class SongModel {
  final String id;
  final String source;
  final String sourceId;
  final String title;
  final String artist;
  final String? album;
  final int durationSeconds;
  final String? artworkUrl;
  final String? streamUrl;
  final String? genre;
  final bool isLiked;
  final bool isPreview;
  final bool isFull;

  SongModel({
    required this.id,
    required this.source,
    required this.sourceId,
    required this.title,
    required this.artist,
    this.album,
    this.durationSeconds = 0,
    this.artworkUrl,
    this.streamUrl,
    this.genre,
    this.isLiked = false,
    this.isPreview = false,
    bool? isFull,
  }) : isFull = isFull ?? !isPreview;

  factory SongModel.fromJson(Map<String, dynamic> json) {
    final preview = json['is_preview'] as bool? ?? false;
    final full = json['is_full'] as bool? ?? !preview;

    final source = json['source'] as String? ?? 'unknown';
    final sourceId = json['source_id'] as String? ?? '';
    var artwork = json['artwork_url'] as String?;
    if ((artwork == null || artwork.isEmpty) && source == 'youtube' && sourceId.isNotEmpty) {
      artwork = 'https://i.ytimg.com/vi/$sourceId/hqdefault.jpg';
    }

    return SongModel(
      id: json['id'] as String? ?? '',
      source: source,
      sourceId: sourceId,
      title: json['title'] as String? ?? 'Untitled',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String?,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      artworkUrl: artwork,
      streamUrl: json['stream_url'] as String?,
      genre: json['genre'] as String?,
      isLiked: json['is_liked'] as bool? ?? false,
      isPreview: preview,
      isFull: full,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source,
      'source_id': sourceId,
      'title': title,
      'artist': artist,
      'album': album,
      'duration_seconds': durationSeconds,
      'artwork_url': artworkUrl,
      'stream_url': streamUrl,
      'genre': genre,
      'is_liked': isLiked,
      'is_preview': isPreview,
      'is_full': isFull,
    };
  }

  SongModel copyWith({
    String? id,
    String? source,
    String? sourceId,
    String? title,
    String? artist,
    String? album,
    int? durationSeconds,
    String? artworkUrl,
    String? streamUrl,
    String? genre,
    bool? isLiked,
    bool? isPreview,
    bool? isFull,
  }) {
    return SongModel(
      id: id ?? this.id,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      genre: genre ?? this.genre,
      isLiked: isLiked ?? this.isLiked,
      isPreview: isPreview ?? this.isPreview,
      isFull: isFull ?? this.isFull,
    );
  }

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
