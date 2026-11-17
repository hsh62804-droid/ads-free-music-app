import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/playlist_model.dart';
import '../../../data/models/song_model.dart';
import '../../player/player_controller.dart';
import '../widgets/add_to_playlist_sheet.dart';

final playlistDetailProvider =
    FutureProvider.family<PlaylistModel?, int>((ref, playlistId) async {
  final repo = ref.watch(musicRepositoryProvider);
  final data = await repo.getPlaylistDetails(playlistId);
  if (data != null) {
    return PlaylistModel.fromJson(data);
  }
  return null;
});

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final int playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  Future<void> _editPlaylist(PlaylistModel playlist) async {
    final nameCtrl = TextEditingController(text: playlist.name);
    final descCtrl = TextEditingController(text: playlist.description ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Edit Playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: descCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, foregroundColor: Colors.white), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
        ],
      ),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final repo = ref.read(musicRepositoryProvider);
      await repo.updatePlaylist(playlist.id, name: nameCtrl.text.trim(), description: descCtrl.text.trim());
      ref.invalidate(playlistDetailProvider(widget.playlistId));
      ref.invalidate(userPlaylistsProvider);
    }
  }

  Future<void> _deletePlaylist() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Delete Playlist?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok == true) {
      final repo = ref.read(musicRepositoryProvider);
      await repo.deletePlaylist(widget.playlistId);
      ref.invalidate(userPlaylistsProvider);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _removeSong(SongModel song) async {
    final repo = ref.read(musicRepositoryProvider);
    await repo.removeSongFromPlaylist(widget.playlistId, song.id);
    ref.invalidate(playlistDetailProvider(widget.playlistId));
  }

  Future<void> _onReorder(List<SongModel> songs, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = songs.removeAt(oldIndex);
    songs.insert(newIndex, item);

    final repo = ref.read(musicRepositoryProvider);
    await repo.reorderPlaylist(widget.playlistId, songs.map((s) => s.id).toList());
    ref.invalidate(playlistDetailProvider(widget.playlistId));
  }

  @override
  Widget build(BuildContext context) {
    final playlistAsync = ref.watch(playlistDetailProvider(widget.playlistId));
    final controller = ref.read(playerControllerProvider.notifier);

    return Scaffold(
      body: playlistAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryRed),
        ),
        error: (err, _) => Center(
          child: Text('Error loading playlist: $err', style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        data: (playlist) {
          if (playlist == null) {
            return const Center(child: Text('Playlist not found.'));
          }

          final songs = List<SongModel>.from(playlist.songs);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: AppTheme.darkBackground,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF5A0004), AppTheme.darkBackground],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 140,
                            height: 140,
                            color: AppTheme.surfaceElevated,
                            child: playlist.coverUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: playlist.coverUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.music_note, size: 64, color: AppTheme.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          playlist.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (playlist.description != null)
                          Text(
                            playlist.description!,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editPlaylist(playlist),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _deletePlaylist,
                  ),
                ],
              ),

              // Play / Shuffle Row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        '${songs.length} songs',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const Spacer(),
                      if (songs.isNotEmpty) ...[
                        IconButton(
                          icon: const Icon(Icons.shuffle, size: 28, color: AppTheme.textSecondary),
                          onPressed: () {
                            controller.toggleShuffle();
                            controller.playSong(songs.first, queue: songs);
                          },
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => controller.playSong(songs.first, queue: songs),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryRed,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.glowRed.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Reorderable Song List
              if (songs.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No songs in this playlist yet.\nSearch and add songs using the menu!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                )
              else
                SliverReorderableList(
                  itemCount: songs.length,
                  // ignore: deprecated_member_use
                  onReorder: (oldIdx, newIdx) => _onReorder(songs, oldIdx, newIdx),
                  itemBuilder: (context, idx) {
                    final song = songs[idx];
                    return Dismissible(
                      key: ValueKey(song.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _removeSong(song),
                      child: ListTile(
                        key: ValueKey(song.id),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 44,
                            height: 44,
                            color: AppTheme.surfaceDark,
                            child: song.artworkUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: song.artworkUrl!,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 88,
                                    memCacheHeight: 88,
                                    fadeInDuration: const Duration(milliseconds: 250),
                                    fadeOutDuration: const Duration(milliseconds: 250),
                                  )
                                : const Icon(Icons.music_note, color: AppTheme.textSecondary),
                          ),
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: ReorderableDragStartListener(
                          index: idx,
                          child: const Icon(Icons.drag_handle, color: AppTheme.textSecondary),
                        ),
                        onTap: () => controller.playSong(song, queue: songs),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
