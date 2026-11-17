import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/playlist_model.dart';
import '../../../data/models/song_model.dart';
import '../../player/player_controller.dart';

final userPlaylistsProvider = FutureProvider<List<PlaylistModel>>((ref) async {
  final repo = ref.watch(musicRepositoryProvider);
  final rawList = await repo.getPlaylists();
  return rawList.map((item) => PlaylistModel.fromJson(item as Map<String, dynamic>)).toList();
});

class AddToPlaylistSheet extends ConsumerStatefulWidget {
  final SongModel song;

  const AddToPlaylistSheet({super.key, required this.song});

  @override
  ConsumerState<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends ConsumerState<AddToPlaylistSheet> {
  final Set<int> _addedPlaylistIds = {};

  Future<void> _createAndAddPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Give your playlist a name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'My Playlist #1',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final repo = ref.read(musicRepositoryProvider);
      final newPlaylist = await repo.createPlaylist(name);
      if (newPlaylist != null) {
        final id = newPlaylist['id'] as int;
        await repo.addSongToPlaylist(id, widget.song.id);
        ref.invalidate(userPlaylistsProvider);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added to "$name"'),
              backgroundColor: AppTheme.surfaceElevated,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleAddSong(PlaylistModel playlist) async {
    final repo = ref.read(musicRepositoryProvider);
    final success = await repo.addSongToPlaylist(playlist.id, widget.song.id);
    if (success && mounted) {
      setState(() => _addedPlaylistIds.add(playlist.id));
      ref.invalidate(userPlaylistsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added to "${playlist.name}"'),
          backgroundColor: AppTheme.surfaceElevated,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(userPlaylistsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Song Summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 44,
                      height: 44,
                      color: AppTheme.surfaceElevated,
                      child: widget.song.artworkUrl != null
                          ? CachedNetworkImage(
                              imageUrl: widget.song.artworkUrl!,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.music_note, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          widget.song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppTheme.dividerColor, height: 28),

            // New Playlist Button
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
              title: const Text('New playlist', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: _createAndAddPlaylist,
            ),

            const SizedBox(height: 8),

            // User Playlists List
            Flexible(
              child: playlistsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: AppTheme.primaryRed),
                  ),
                ),
                error: (_, __) => const Center(
                  child: Text('Failed to load playlists', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                data: (playlists) {
                  if (playlists.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, idx) {
                      final p = playlists[idx];
                      final isAdded = _addedPlaylistIds.contains(p.id);

                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 48,
                            height: 48,
                            color: AppTheme.surfaceElevated,
                            child: p.coverUrl != null
                                ? CachedNetworkImage(imageUrl: p.coverUrl!, fit: BoxFit.cover)
                                : const Icon(Icons.music_note, color: AppTheme.textSecondary),
                          ),
                        ),
                        title: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${p.songCount} songs',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: Icon(
                          isAdded ? Icons.check_circle : Icons.circle_outlined,
                          color: isAdded ? AppTheme.primaryRed : AppTheme.textSecondary,
                        ),
                        onTap: () => _toggleAddSong(p),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
