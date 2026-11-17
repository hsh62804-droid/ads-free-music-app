class ArtistModel {
  final String id;
  final String name;
  final String? pictureUrl;
  final int? trackCount;

  ArtistModel({
    required this.id,
    required this.name,
    this.pictureUrl,
    this.trackCount,
  });

  factory ArtistModel.fromJson(Map<String, dynamic> json) {
    return ArtistModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Unknown Artist',
      pictureUrl: json['picture_url'] as String?,
      trackCount: json['track_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'picture_url': pictureUrl,
      'track_count': trackCount,
    };
  }
}
