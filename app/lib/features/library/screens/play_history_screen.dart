import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/play_history_model.dart';
import '../../player/player_controller.dart';

final playHistoryProvider = FutureProvider<List<PlayHistoryModel>>((ref) async {
  final repo = ref.watch(musicRepositoryProvider);
  final raw = await repo.getPlayHistory(limit: 50);
  return raw.map((item) => PlayHistoryModel.fromJson(item as Map<String, dynamic>)).toList();
});

class PlayHistoryScreen extends ConsumerWidget {
  const PlayHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(playHistoryProvider);
    final controller = ref.read(playerControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently Played'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(playHistoryProvider),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryRed),
        ),
        error: (err, _) => Center(
          child: Text('Error loading history: $err', style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 48, color: AppTheme.surfaceElevated),
                  SizedBox(height: 12),
                  Text('No playback history yet.', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          final songs = entries.where((e) => e.song != null).map((e) => e.song!).toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length,
            itemBuilder: (context, idx) {
              final entry = entries[idx];
              final song = entry.song;
              if (song == null) return const SizedBox.shrink();

              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: AppTheme.surfaceDark,
                    child: song.artworkUrl != null
                        ? CachedNetworkImage(imageUrl: song.artworkUrl!, fit: BoxFit.cover)
                        : const Icon(Icons.music_note, color: AppTheme.textSecondary),
                  ),
                ),
                title: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Row(
                  children: [
                    if (song.isPreview) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'PREVIEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        '${song.artist} • ${song.formattedDuration}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                trailing: entry.completed
                    ? const Icon(Icons.check_circle_outline, color: AppTheme.primaryRed, size: 18)
                    : null,
                onTap: () => controller.playSong(song, queue: songs),
              );
            },
          );
        },
      ),
    );
  }
}
