import '../constants/api_endpoints.dart';

class UrlUtils {
  static String getFullUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    // Remove /api if present in baseUrl to get root
    final baseUrl = ApiEndpoints.baseUrl.replaceAll('/api', '');
    // Ensure path starts with /
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$normalizedPath';
  }
}
