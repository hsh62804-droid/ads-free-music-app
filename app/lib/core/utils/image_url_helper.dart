import '../constants/api_constants.dart';

/// Helper utility to route external images through backend /image proxy for CORS headers and caching.
class ImageUrlHelper {
  static String formatCoverUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return '';
    }
    final clean = rawUrl.trim();

    // Already routed through proxy or local backend endpoint
    if (clean.contains('/image?url=') || clean.contains('/images?url=') || clean.contains('/songs/local:')) {
      return clean;
    }

    // Proxy external HTTP/HTTPS CDN URLs through backend
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      // If it's pointing to localhost or 127.0.0.1 directly, keep as is
      final uri = Uri.tryParse(clean);
      if (uri != null && (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
        return clean;
      }
      return '${ApiConstants.baseUrl}/image?url=${Uri.encodeComponent(clean)}';
    }

    return clean;
  }
}
