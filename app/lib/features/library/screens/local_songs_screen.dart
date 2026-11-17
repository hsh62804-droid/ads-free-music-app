import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../player/player_controller.dart';
import '../library_screen.dart';
import 'settings_screen.dart';

class LocalSongsScreen extends ConsumerWidget {
  const LocalSongsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localSongsAsync = ref.watch(localSongsProvider);
    final controller = ref.read(playerControllerProvider.notifier);

    return Scaffold(
      body: localSongsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryRed),
        ),
        error: (err, _) => Center(
          child: Text('Error loading local songs: $err', style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        data: (songs) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppTheme.surfaceDark,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Settings / Rescan',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1E3A8A), AppTheme.pureBlack],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    padding: const EdgeInsets.only(left: 20, bottom: 20, right: 20),
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.folder_special, color: Colors.blueAccent, size: 28),
                            SizedBox(width: 8),
                            Text(
                              'My Music',
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${songs.length} full songs from backend/music/',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Play & Shuffle Action Row
              if (songs.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
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
                    ),
                  ),
                ),

              // Track List
              if (songs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.audio_file_outlined, size: 64, color: AppTheme.surfaceElevated),
                          const SizedBox(height: 16),
                          const Text(
                            'No local music files found yet',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add your favorite MP3, M4A, FLAC, or OPUS files into backend/music/ and tap Rescan.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryRed,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              );
                            },
                            icon: const Icon(Icons.sync_rounded),
                            label: const Text('Open Settings & Rescan'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, idx) {
                      final song = songs[idx];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 48,
                            height: 48,
                            color: AppTheme.surfaceDark,
                            child: song.artworkUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: song.artworkUrl!,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 96,
                                    memCacheHeight: 96,
                                    fadeInDuration: const Duration(milliseconds: 250),
                                    fadeOutDuration: const Duration(milliseconds: 250),
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.music_note,
                                      color: AppTheme.textSecondary,
                                    ),
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
                        subtitle: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade900.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6), width: 0.6),
                              ),
                              child: const Text(
                                'FULL',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            song.isLiked ? Icons.favorite : Icons.favorite_border,
                            color: song.isLiked ? AppTheme.primaryRed : AppTheme.textSecondary,
                          ),
                          onPressed: () async {
                            final repo = ref.read(musicRepositoryProvider);
                            await repo.toggleLike(song.id, song.isLiked);
                            ref.invalidate(localSongsProvider);
                            ref.invalidate(likedSongsProvider);
                          },
                        ),
                        onTap: () => controller.playSong(song, queue: songs),
                      );
                    },
                    childCount: songs.length,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
