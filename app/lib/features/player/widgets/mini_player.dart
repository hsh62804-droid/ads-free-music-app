import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/nav_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_cover_image.dart';
import '../../../core/widgets/scale_button.dart';
import '../player_controller.dart';
import '../screens/full_player_screen.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  void _openNowPlaying(BuildContext context) {
    debugPrint('[MiniPlayer] Tapped: Opening Now Playing screen');
    final navigator = Navigator.maybeOf(context, rootNavigator: true) ?? rootNavigatorKey.currentState;
    if (navigator != null) {
      navigator.push(
        PageRouteBuilder(
          fullscreenDialog: true,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (context, animation, secondaryAnimation) => const FullPlayerScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            );
          },
        ),
      );
    } else {
      debugPrint('[MiniPlayer] Error: Root navigator not found');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Select only currentSong so position updates do NOT rebuild the main player card
    final song = ref.watch(playerControllerProvider.select((s) => s.currentSong));

    if (song == null) return const SizedBox.shrink();

    final controller = ref.read(playerControllerProvider.notifier);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.surfaceBorder, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          onTap: () => _openNowPlaying(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    // Album art thumbnail with Hero animation to FullPlayer
                    Hero(
                      tag: 'player_poster_${song.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        child: AppCoverImage(
                          url: song.artworkUrl,
                          width: 46,
                          height: 46,
                          iconSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Song title & artist
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (song.source == 'youtube') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryRed.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: AppTheme.primaryRed, width: 0.6),
                                  ),
                                  child: const Text(
                                    'YOUTUBE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ] else if (song.source == 'local') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade900.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: Colors.greenAccent, width: 0.6),
                                  ),
                                  child: const Text(
                                    'LOCAL',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ] else if (!song.isFull || song.isPreview) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade900.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: Colors.amber.shade400.withValues(alpha: 0.6), width: 0.6),
                                  ),
                                  child: const Text(
                                    'PREVIEW',
                                    style: TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                              Expanded(
                                child: Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Like button with scale-on-press
                    ScaleButton(
                      onPressed: () => controller.toggleLikeCurrentSong(),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          song.isLiked ? Icons.favorite : Icons.favorite_border,
                          color: song.isLiked ? AppTheme.primaryRed : AppTheme.textSecondary,
                          size: 22,
                        ),
                      ),
                    ),

                    // Isolated Play / Pause button with AnimatedSwitcher
                    const _MiniPlayerPlayPauseButton(),

                    // Next track button
                    ScaleButton(
                      onPressed: () => controller.next(),
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.skip_next_rounded,
                          color: AppTheme.textPrimary,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Isolated bottom progress indicator (only rebuilds on position tick)
              const _MiniPlayerProgressLine(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dedicated widget for play/pause toggle with AnimatedSwitcher and ScaleButton
class _MiniPlayerPlayPauseButton extends ConsumerWidget {
  const _MiniPlayerPlayPauseButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (isPlaying, isBuffering) = ref.watch(
      playerControllerProvider.select((s) => (s.isPlaying, s.isBuffering)),
    );
    final controller = ref.read(playerControllerProvider.notifier);

    return ScaleButton(
      onPressed: () => controller.togglePlayPause(),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: isBuffering
              ? const SizedBox(
                  key: ValueKey('mini_buffering'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryRed,
                  ),
                )
              : Icon(
                  key: ValueKey(isPlaying),
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: AppTheme.textPrimary,
                  size: 32,
                ),
        ),
      ),
    );
  }
}

/// Dedicated widget for mini-player progress bar to isolate rebuilds on tick
class _MiniPlayerProgressLine extends ConsumerWidget {
  const _MiniPlayerProgressLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(playerControllerProvider.select((s) => s.progress));

    return LinearProgressIndicator(
      value: progress,
      minHeight: 2,
      backgroundColor: AppTheme.surfaceDark,
      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryRed),
    );
  }
}
