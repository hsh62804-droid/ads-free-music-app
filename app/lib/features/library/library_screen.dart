import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/song_model.dart';
import '../player/player_controller.dart';
import '../playlist/widgets/add_to_playlist_sheet.dart';
import '../playlist/screens/playlist_detail_screen.dart';
import 'screens/liked_songs_screen.dart';
import 'screens/local_songs_screen.dart';
import 'screens/play_history_screen.dart';
import 'screens/settings_screen.dart';

final likedSongsProvider = FutureProvider<List<SongModel>>((ref) async {
  final repo = ref.watch(musicRepositoryProvider);
  return await repo.getLikedSongs(limit: 50);
});

final localSongsProvider = FutureProvider<List<SongModel>>((ref) async {
  final repo = ref.watch(musicRepositoryProvider);
  return await repo.getLocalSongs(limit: 100);
});

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('New playlist'),
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
      await repo.createPlaylist(name);
      ref.invalidate(userPlaylistsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedSongsAsync = ref.watch(likedSongsProvider);
    final playlistsAsync = ref.watch(userPlaylistsProvider);
    final localSongsAsync = ref.watch(localSongsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings & Rescan',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Recently Played',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlayHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create playlist',
            onPressed: () => _createPlaylist(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryRed,
        onRefresh: () async {
          ref.invalidate(likedSongsProvider);
          ref.invalidate(localSongsProvider);
          ref.invalidate(userPlaylistsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // Liked Songs Tile
            likedSongsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (likedSongs) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryRed, AppTheme.darkRed],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 28),
                ),
                title: const Text(
                  'Liked Songs',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  'Playlist • ${likedSongs.length} songs',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LikedSongsScreen()),
                  );
                },
              ),
            ),

            // My Music (Local Files) Tile
            localSongsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (localSongs) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.folder_special_rounded, color: Colors.blueAccent, size: 28),
                ),
                title: Row(
                  children: [
                    const Text(
                      'My Music',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.green.shade900.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6), width: 0.6),
                      ),
                      child: const Text(
                        'FULL FILES',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  'backend/music/ • ${localSongs.length} songs',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.sync_rounded, color: AppTheme.textSecondary),
                  tooltip: 'Rescan backend/music/',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LocalSongsScreen()),
                  );
                },
              ),
            ),

            const Divider(color: AppTheme.dividerColor, height: 16),

            // User Playlists Section Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Playlists',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),

            // Playlists List
            playlistsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: AppTheme.primaryRed),
                ),
              ),
              error: (err, _) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('Could not load playlists', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ),
              data: (playlists) {
                if (playlists.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.queue_music, size: 48, color: AppTheme.surfaceElevated),
                          const SizedBox(height: 12),
                          const Text(
                            'Create your first playlist',
                            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryRed,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _createPlaylist(context, ref),
                            child: const Text('New Playlist'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: playlists.length,
                  itemBuilder: (context, idx) {
                    final playlist = playlists[idx];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: 52,
                          height: 52,
                          color: AppTheme.surfaceElevated,
                          child: playlist.coverUrl != null
                              ? CachedNetworkImage(imageUrl: playlist.coverUrl!, fit: BoxFit.cover)
                              : const Icon(Icons.music_note, color: AppTheme.textSecondary),
                        ),
                      ),
                      title: Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Playlist • ${playlist.songCount} songs',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
