import 'song_model.dart';

class PlayHistoryModel {
  final int id;
  final String songId;
  final int playedDurationSeconds;
  final bool completed;
  final DateTime playedAt;
  final SongModel? song;

  PlayHistoryModel({
    required this.id,
    required this.songId,
    required this.playedDurationSeconds,
    required this.completed,
    required this.playedAt,
    this.song,
  });

  factory PlayHistoryModel.fromJson(Map<String, dynamic> json) {
    return PlayHistoryModel(
      id: json['id'] as int? ?? 0,
      songId: json['song_id'] as String? ?? '',
      playedDurationSeconds: json['played_duration_seconds'] as int? ?? 0,
      completed: json['completed'] as bool? ?? false,
      playedAt: json['played_at'] != null
          ? DateTime.tryParse(json['played_at']) ?? DateTime.now()
          : DateTime.now(),
      song: json['song'] != null ? SongModel.fromJson(json['song']) : null,
    );
  }
}
