import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../utils/image_url_helper.dart';

/// Standard cover image widget that proxies images through the backend /image endpoint,
/// eliminating CORS blocks in Flutter web and ensuring failed images display a stylish
/// red music-note gradient instead of a black square.
class AppCoverImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double iconSize;

  const AppCoverImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.iconSize = 28,
  });

  Widget _buildFallback({required double size}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2A1012),
            Color(0xFF141414),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: size,
          color: AppTheme.primaryRed.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final proxiedUrl = ImageUrlHelper.formatCoverUrl(url);

    if (proxiedUrl.isEmpty) {
      return _buildFallback(size: iconSize);
    }

    final imageWidget = CachedNetworkImage(
      imageUrl: proxiedUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: 400,
      memCacheHeight: 400,
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 200),
      placeholder: (context, _) => Container(
        width: width,
        height: height,
        color: AppTheme.surfaceElevated,
      ),
      errorWidget: (context, _, __) => _buildFallback(size: iconSize),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
