import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_cover_image.dart';
import '../../core/widgets/scale_button.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../data/models/home_sections_model.dart';
import '../../data/models/song_model.dart';
import '../player/player_controller.dart';

final selectedLanguageProvider = StateProvider<String>((ref) => 'both'); // 'both', 'tamil', 'english'

// Independent section providers - each loads on its own!
final tamilTrendingProvider = FutureProvider<List<SongModel>>((ref) async {
  final repo = ref.watch(musicRepositoryProvider);
  return await repo.getTamilTrending(limit: 15);
});

final englishTrendingProvider = FutureProvider<List<SongModel>>((ref) async {
  final repo = ref.watch(musicRepositoryProvider);
  return await repo.getEnglishTrending(limit: 15);
});

final madeForYouProvider = FutureProvider<List<SongModel>>((ref) async {
  final repo = ref.watch(musicRepositoryProvider);
  return await repo.getMadeForYou(limit: 15);
});

final independentPicksProvider = FutureProvider<List<SongModel>>((ref) async {
  final repo = ref.watch(musicRepositoryProvider);
  return await repo.getIndependentPicks(limit: 15);
});

final myMusicProvider = FutureProvider<List<SongModel>>((ref) async {
  final repo = ref.watch(musicRepositoryProvider);
  return await repo.getLocalSongs(limit: 50);
});

final homeSectionsProvider = FutureProvider<HomeSectionsModel>((ref) async {
  final lang = ref.watch(selectedLanguageProvider);
  final repo = ref.watch(musicRepositoryProvider);
  return await repo.getHomeSections(language: lang);
});

void refreshAllHomeSections(WidgetRef ref) {
  ref.invalidate(homeSectionsProvider);
  ref.invalidate(tamilTrendingProvider);
  ref.invalidate(englishTrendingProvider);
  ref.invalidate(madeForYouProvider);
  ref.invalidate(independentPicksProvider);
  ref.invalidate(myMusicProvider);
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _refreshAll(WidgetRef ref) async {
    ref.invalidate(tamilTrendingProvider);
    ref.invalidate(englishTrendingProvider);
    ref.invalidate(madeForYouProvider);
    ref.invalidate(independentPicksProvider);
    ref.invalidate(myMusicProvider);
  }

  Future<void> _rescanMusicFolder(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scanning backend/music/ folder for full songs...'),
        duration: Duration(seconds: 1),
      ),
    );

    final repo = ref.read(musicRepositoryProvider);
    final res = await repo.rescanLibrary();
    final count = res['total_tracks'] ?? 0;
    ref.invalidate(myMusicProvider);
    ref.invalidate(madeForYouProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surfaceElevated,
          content: Text(
            'Found $count full local song(s) in backend/music/',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(selectedLanguageProvider);

    // Watch all individual providers independently
    final tamilAsync = ref.watch(tamilTrendingProvider);
    final englishAsync = ref.watch(englishTrendingProvider);
    final madeForYouAsync = ref.watch(madeForYouProvider);
    final independentAsync = ref.watch(independentPicksProvider);
    final myMusicAsync = ref.watch(myMusicProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getGreeting(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Rescan my music folder',
            onPressed: () => _rescanMusicFolder(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh all sections',
            onPressed: () => _refreshAll(ref),
          ),
        ],
      ),
      // On wide screens (over 700 px) limit content width to 1100 px and center it
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: RefreshIndicator(
            color: AppTheme.primaryRed,
            onRefresh: () => _refreshAll(ref),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                // Language Selection Filter Bar (Both, Tamil, English)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      _LanguageChip(
                        label: 'Both (Tamil + English)',
                        value: 'both',
                        selected: currentLanguage == 'both',
                        onSelected: (val) => ref.read(selectedLanguageProvider.notifier).state = val,
                      ),
                      const SizedBox(width: 8),
                      _LanguageChip(
                        label: 'Tamil',
                        value: 'tamil',
                        selected: currentLanguage == 'tamil',
                        onSelected: (val) => ref.read(selectedLanguageProvider.notifier).state = val,
                      ),
                      const SizedBox(width: 8),
                      _LanguageChip(
                        label: 'English',
                        value: 'english',
                        selected: currentLanguage == 'english',
                        onSelected: (val) => ref.read(selectedLanguageProvider.notifier).state = val,
                      ),
                    ],
                  ),
                ),

                // Quick-Pick Rows (wide cards with fixed height of 64 px)
                _QuickPickSection(
                  myMusicAsync: myMusicAsync,
                  tamilAsync: tamilAsync,
                  englishAsync: englishAsync,
                ),

                // Section 1: My music (if user has local audio files in backend/music/)
                myMusicAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (localSongs) {
                    if (localSongs.isEmpty) return const SizedBox.shrink();
                    return _SectionBlock(
                      title: 'My music',
                      subtitle: 'Full songs in your backend/music/ folder',
                      asyncSongs: myMusicAsync,
                      onRetry: () => ref.invalidate(myMusicProvider),
                      trailing: ScaleButton(
                        onPressed: () => _rescanMusicFolder(context, ref),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.surfaceBorder, width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh, size: 14, color: AppTheme.textSecondary),
                              SizedBox(width: 4),
                              Text('Rescan', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Section 2: Tamil trending
                if (currentLanguage == 'tamil' || currentLanguage == 'both')
                  _SectionBlock(
                    title: 'Tamil trending',
                    subtitle: 'Top Kollywood hits, Anirudh, A.R. Rahman & YouTube full tracks',
                    asyncSongs: tamilAsync,
                    onRetry: () => ref.invalidate(tamilTrendingProvider),
                  ),

                // Section 3: English trending
                if (currentLanguage == 'english' || currentLanguage == 'both')
                  _SectionBlock(
                    title: 'English trending',
                    subtitle: 'Chart-toppers, The Weeknd, Dua Lipa & YouTube full tracks',
                    asyncSongs: englishAsync,
                    onRetry: () => ref.invalidate(englishTrendingProvider),
                  ),

                // Section 4: Made for you
                _SectionBlock(
                  title: 'Made for you',
                  subtitle: 'Curated based on your favorites and playback history',
                  asyncSongs: madeForYouAsync,
                  onRetry: () => ref.invalidate(madeForYouProvider),
                ),

                // Section 5: Independent picks
                _SectionBlock(
                  title: 'Independent picks',
                  subtitle: 'Full songs from independent artists on Audius & Jamendo',
                  asyncSongs: independentAsync,
                  onRetry: () => ref.invalidate(independentPicksProvider),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick-Pick 64px Fixed-Height Rows
class _QuickPickSection extends ConsumerWidget {
  final AsyncValue<List<SongModel>> myMusicAsync;
  final AsyncValue<List<SongModel>> tamilAsync;
  final AsyncValue<List<SongModel>> englishAsync;

  const _QuickPickSection({
    required this.myMusicAsync,
    required this.tamilAsync,
    required this.englishAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playerControllerProvider.notifier);

    // Pick available tracks from loaded sections
    final localList = myMusicAsync.valueOrNull ?? [];
    final tamilList = tamilAsync.valueOrNull ?? [];
    final englishList = englishAsync.valueOrNull ?? [];

    final pool = localList.isNotEmpty
        ? localList
        : (tamilList.isNotEmpty ? tamilList : englishList);

    if (pool.isEmpty) {
      // Show skeleton quick-picks while loading
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 360,
            mainAxisExtent: 64, // Exact fixed height of 64 px
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (_, __) => Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                ShimmerBox(width: 64, height: 64, borderRadius: 6),
                SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 90, height: 12),
                      SizedBox(height: 6),
                      ShimmerBox(width: 60, height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final quickSongs = pool.take(min(pool.length, 6)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: quickSongs.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360,
          mainAxisExtent: 64, // Exact fixed height of 64 px
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (context, idx) {
          final song = quickSongs[idx];
          return ScaleButton(
            onPressed: () => controller.playSong(song, queue: quickSongs),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.surfaceBorder, width: 0.6),
              ),
              child: Row(
                children: [
                  AppCoverImage(
                    url: song.artworkUrl,
                    width: 64,
                    height: 64,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomLeft: Radius.circular(6),
                    ),
                    iconSize: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.play_circle_fill, color: AppTheme.primaryRed, size: 28),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Independent Section with title, horizontal scroll list, and shimmer while loading
class _SectionBlock extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final AsyncValue<List<SongModel>> asyncSongs;
  final VoidCallback onRetry;
  final Widget? trailing;

  const _SectionBlock({
    required this.title,
    this.subtitle,
    required this.asyncSongs,
    required this.onRetry,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playerControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title, subtitle: subtitle, action: trailing),
        asyncSongs.when(
          loading: () => const _HorizontalShimmerList(),
          error: (err, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                const Text('Could not load section', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry', style: TextStyle(color: AppTheme.primaryRed, fontSize: 12)),
                ),
              ],
            ),
          ),
          data: (songs) {
            if (songs.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: songs.length,
                itemBuilder: (context, idx) {
                  final song = songs[idx];
                  return _SpotifySongCard(
                    song: song,
                    onTap: () => controller.playSong(song, queue: songs),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Clean Spotify-style Song Card: small square cover, title (1 line), artist (1 line)
class _SpotifySongCard extends StatelessWidget {
  final SongModel song;
  final VoidCallback onTap;

  const _SpotifySongCard({required this.song, required this.onTap});

  Widget _buildBadge(SongModel song) {
    final isYouTube = song.source == 'youtube';
    final isLocal = song.source == 'local';
    final isAudius = song.source == 'audius';
    final isFull = song.isFull;

    final text = isYouTube
        ? 'YOUTUBE'
        : (isLocal ? 'LOCAL' : (isAudius ? 'AUDIUS' : (isFull ? 'FULL' : 'PREVIEW')));

    final textColor = isYouTube
        ? Colors.white
        : (isLocal ? Colors.greenAccent : (isAudius ? Colors.cyanAccent : (isFull ? Colors.greenAccent : Colors.white)));

    final bgColor = isYouTube
        ? AppTheme.primaryRed.withValues(alpha: 0.9)
        : (isLocal
            ? Colors.green.shade900.withValues(alpha: 0.8)
            : (isAudius
                ? Colors.cyan.shade900.withValues(alpha: 0.8)
                : (isFull ? Colors.black.withValues(alpha: 0.75) : AppTheme.primaryRed.withValues(alpha: 0.9))));

    final borderColor = isYouTube
        ? AppTheme.primaryRed
        : (isLocal
            ? Colors.greenAccent.withValues(alpha: 0.6)
            : (isAudius
                ? Colors.cyanAccent.withValues(alpha: 0.6)
                : (isFull ? Colors.greenAccent.withValues(alpha: 0.6) : Colors.white38)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 0.6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onPressed: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AppCoverImage(
                  url: song.artworkUrl,
                  width: 140,
                  height: 140,
                  borderRadius: BorderRadius.circular(8),
                  iconSize: 44,
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: _buildBadge(song),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer Horizontal Placeholder List while section is loading
class _HorizontalShimmerList extends StatelessWidget {
  const _HorizontalShimmerList();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 14),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(
                  width: 140,
                  height: 140,
                  borderRadius: 8,
                ),
                SizedBox(height: 8),
                ShimmerBox(
                  width: 110,
                  height: 12,
                  borderRadius: 4,
                ),
                SizedBox(height: 6),
                ShimmerBox(
                  width: 75,
                  height: 10,
                  borderRadius: 4,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const _SectionHeader({required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.4,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onSelected;

  const _LanguageChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onPressed: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryRed : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.glowRed.withValues(alpha: 0.5) : AppTheme.surfaceBorder,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
