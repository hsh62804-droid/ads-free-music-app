import 'dart:math' show min;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_cover_image.dart';
import '../../../core/widgets/scale_button.dart';
import '../../playlist/widgets/add_to_playlist_sheet.dart';
import '../player_controller.dart';
import '../player_state.dart';

class FullPlayerScreen extends ConsumerWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(playerControllerProvider.select((s) => s.currentSong));

    if (song == null) {
      return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: ScaleButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Icon(Icons.keyboard_arrow_down_rounded, size: 34),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryRed),
              SizedBox(height: 16),
              Text(
                'Loading player...',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.playerBackgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: ScaleButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Icon(Icons.keyboard_arrow_down_rounded, size: 34),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PLAYING FROM SOURCE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.source.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: (song.isFull && !song.isPreview)
                          ? Colors.green.shade900.withValues(alpha: 0.4)
                          : Colors.amber.shade900.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: (song.isFull && !song.isPreview)
                            ? Colors.greenAccent.withValues(alpha: 0.6)
                            : Colors.amberAccent.withValues(alpha: 0.6),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      (song.isFull && !song.isPreview) ? 'FULL' : 'PREVIEW',
                      style: TextStyle(
                        color: (song.isFull && !song.isPreview) ? Colors.greenAccent : Colors.amberAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            ScaleButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => AddToPlaylistSheet(song: song),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.playlist_add_rounded, size: 28),
              ),
            ),
          ],
        ),
        // Swipe down anywhere on screen to dismiss player
        body: Dismissible(
          key: const Key('now_playing_screen_dismissible'),
          direction: DismissDirection.down,
          onDismissed: (_) {
            Navigator.of(context).pop();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
                Navigator.of(context).pop();
              }
            },
            child: const SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _PosterSection(),
                    _SongMetaSection(),
                    _ProgressBarSection(),
                    _ControlsSection(),
                    SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Large poster section with horizontal swipe to skip, Hero transition, and glow
class _PosterSection extends ConsumerWidget {
  const _PosterSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(playerControllerProvider.select((s) => s.currentSong));
    if (song == null) return const SizedBox.shrink();

    final controller = ref.read(playerControllerProvider.notifier);
    final size = MediaQuery.of(context).size;
    final posterSize = min(size.width * 0.78, size.height * 0.38).clamp(160.0, 360.0);


    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -200) {
            // Swiped left: skip to next track
            controller.next();
          } else if (details.primaryVelocity! > 200) {
            // Swiped right: skip to previous track
            controller.previous();
          }
        }
      },
      child: Center(
        child: Hero(
          tag: 'player_poster_${song.id}',
          child: Container(
            width: posterSize,
            height: posterSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              boxShadow: AppTheme.posterGlowShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              child: AppCoverImage(
                url: song.artworkUrl,
                width: posterSize,
                height: posterSize,
                iconSize: 72,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Song Title, Artist, Source badge, and Like button with ScaleButton
class _SongMetaSection extends ConsumerWidget {
  const _SongMetaSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(playerControllerProvider.select((s) => s.currentSong));
    if (song == null) return const SizedBox.shrink();

    final controller = ref.read(playerControllerProvider.notifier);
    final isYouTube = song.source == 'youtube';
    final isLocal = song.source == 'local';
    final isAudius = song.source == 'audius';
    final isPreview = !song.isFull || song.isPreview;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (isYouTube) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppTheme.primaryRed.withValues(alpha: 0.8),
                          width: 0.8,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.smart_display_rounded, color: AppTheme.primaryRed, size: 11),
                          SizedBox(width: 3),
                          Text(
                            'YOUTUBE FULL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (isLocal) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade900.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.greenAccent.withValues(alpha: 0.6),
                          width: 0.6,
                        ),
                      ),
                      child: const Text(
                        'LOCAL FULL',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ] else if (isAudius) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.cyan.shade900.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.cyanAccent.withValues(alpha: 0.6),
                          width: 0.6,
                        ),
                      ),
                      child: const Text(
                        'AUDIUS FULL',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ] else if (isPreview) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.amberAccent.withValues(alpha: 0.6),
                          width: 0.6,
                        ),
                      ),
                      child: const Text(
                        'PREVIEW (30s)',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
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
                        fontSize: 15,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (isYouTube) ...[
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.tv_rounded, size: 13, color: AppTheme.textSecondary),
                    SizedBox(width: 4),
                    Text(
                      'Official YouTube playback • Keep screen on for continuous play',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ] else if (isPreview) ...[
                const SizedBox(height: 6),
                ScaleButton(
                  onPressed: () => controller.playFullVersion(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.glowRed.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.smart_display_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'Play Full on YouTube',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ScaleButton(
          onPressed: () => controller.toggleLikeCurrentSong(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              song.isLiked ? Icons.favorite : Icons.favorite_border,
              color: song.isLiked ? AppTheme.primaryRed : AppTheme.textSecondary,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}

/// Isolated progress bar and duration counter
class _ProgressBarSection extends ConsumerWidget {
  const _ProgressBarSection();

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (position, duration) = ref.watch(
      playerControllerProvider.select((s) => (s.position, s.duration)),
    );
    final controller = ref.read(playerControllerProvider.notifier);

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: AppTheme.primaryRed,
            inactiveTrackColor: AppTheme.surfaceElevated,
            thumbColor: AppTheme.primaryRed,
            overlayColor: AppTheme.glowRed.withValues(alpha: 0.25),
          ),
          child: Slider(
            value: position.inSeconds
                .toDouble()
                .clamp(0.0, duration.inSeconds.toDouble()),
            max: duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0,
            onChanged: (val) {
              controller.seek(Duration(seconds: val.toInt()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '-${_formatDuration(duration - position)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 5-button control cluster with ScaleButton and AnimatedSwitcher
class _ControlsSection extends ConsumerWidget {
  const _ControlsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (isPlaying, isBuffering, isShuffle, repeatMode) = ref.watch(
      playerControllerProvider.select(
        (s) => (s.isPlaying, s.isBuffering, s.isShuffle, s.repeatMode),
      ),
    );
    final controller = ref.read(playerControllerProvider.notifier);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Shuffle toggle
        ScaleButton(
          onPressed: () => controller.toggleShuffle(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              Icons.shuffle,
              color: isShuffle ? AppTheme.primaryRed : AppTheme.textSecondary,
              size: 24,
            ),
          ),
        ),

        // Previous
        ScaleButton(
          onPressed: () => controller.previous(),
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.skip_previous_rounded, size: 36, color: AppTheme.textPrimary),
          ),
        ),

        // Rewind 10s
        ScaleButton(
          onPressed: () => controller.rewind10(),
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.replay_10_rounded, size: 32, color: AppTheme.textPrimary),
          ),
        ),

        // Big Circular Play / Pause Button in Red with AnimatedSwitcher & Glow
        ScaleButton(
          onPressed: () => controller.togglePlayPause(),
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.glowRed.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: isBuffering
                    ? const Padding(
                        key: ValueKey('full_buffering'),
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        key: ValueKey(isPlaying),
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
              ),
            ),
          ),
        ),

        // Forward 10s
        ScaleButton(
          onPressed: () => controller.forward10(),
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.forward_10_rounded, size: 32, color: AppTheme.textPrimary),
          ),
        ),

        // Next
        ScaleButton(
          onPressed: () => controller.next(),
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.skip_next_rounded, size: 36, color: AppTheme.textPrimary),
          ),
        ),

        // Repeat toggle
        ScaleButton(
          onPressed: () => controller.toggleRepeat(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              repeatMode == RepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
              color: repeatMode != RepeatMode.off ? AppTheme.primaryRed : AppTheme.textSecondary,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}
