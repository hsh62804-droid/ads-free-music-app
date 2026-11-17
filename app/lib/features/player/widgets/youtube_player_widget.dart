import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/scale_button.dart';

class YouTubePlayerWidget extends StatefulWidget {
  final String videoId;
  final String title;
  final String artist;
  final String? artworkUrl;
  final double width;
  final double height;

  const YouTubePlayerWidget({
    super.key,
    required this.videoId,
    required this.title,
    required this.artist,
    this.artworkUrl,
    required this.width,
    required this.height,
  });

  @override
  State<YouTubePlayerWidget> createState() => _YouTubePlayerWidgetState();
}

class _YouTubePlayerWidgetState extends State<YouTubePlayerWidget> {
  YoutubePlayerController? _controller;
  bool _hasError = false;
  bool _supportsIframe = false;

  @override
  void initState() {
    super.initState();
    _checkSupportAndInit();
  }

  void _checkSupportAndInit() {
    // Web and mobile OS (Android, iOS) support the iframe webview directly
    final isSupportedPlatform = kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    _supportsIframe = isSupportedPlatform;

    if (_supportsIframe) {
      try {
        _controller = YoutubePlayerController.fromVideoId(
          videoId: widget.videoId,
          autoPlay: true,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: true,
            mute: false,
            color: 'red',
            strictRelatedVideos: true,
          ),
        );
      } catch (e) {
        _hasError = true;
      }
    }
  }

  @override
  void didUpdateWidget(covariant YouTubePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _controller?.close();
      _checkSupportAndInit();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  Future<void> _openExternalYouTube() async {
    final url = Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = widget.artworkUrl ?? 'https://i.ytimg.com/vi/${widget.videoId}/hqdefault.jpg';

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: AppTheme.primaryRed.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: AppTheme.posterGlowShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: Stack(
          children: [
            if (_supportsIframe && _controller != null && !_hasError)
              Center(
                child: YoutubePlayer(
                  controller: _controller!,
                  aspectRatio: 16 / 9,
                ),
              )
            else
              // Fallback for Windows desktop or if webview fails
              Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: thumbUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppTheme.surfaceDark),
                    errorWidget: (_, __, ___) => Container(
                      color: AppTheme.surfaceDark,
                      child: const Icon(Icons.music_note, size: 48, color: AppTheme.textSecondary),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Center(
                    child: ScaleButton(
                      onPressed: _openExternalYouTube,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.glowRed.withValues(alpha: 0.6),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                            SizedBox(width: 6),
                            Text(
                              'Play on YouTube',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            // Top Official YouTube badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryRed.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.smart_display_rounded, color: AppTheme.primaryRed, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'YouTube Full Song',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
