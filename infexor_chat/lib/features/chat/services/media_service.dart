import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService(ref.read(apiClientProvider));
});

class MediaService {
  final ApiClient _apiClient;

  MediaService(this._apiClient);

  /// Uploads an image file to the server.
  ///
  /// Returns a Map containing: url, thumbnail, mimeType, size, width, height, fileName.
  Future<Map<String, dynamic>> uploadImage(
    String filePath, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
      ),
    });

    final response = await _apiClient.dio.post(
      ApiEndpoints.uploadImage,
      data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
      ),
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );

    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  /// Uploads a video file to the server.
  Future<Map<String, dynamic>> uploadVideo(
    String filePath, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final formData = FormData.fromMap({
      'video': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
      ),
    });

    final response = await _apiClient.dio.post(
      ApiEndpoints.uploadVideo,
      data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 5),
      ),
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );

    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  /// Uploads an audio file to the server.
  Future<Map<String, dynamic>> uploadAudio(
    String filePath, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
      ),
    });

    final response = await _apiClient.dio.post(
      ApiEndpoints.uploadAudio,
      data: formData,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );

    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  /// Uploads a voice recording to the server.
  Future<Map<String, dynamic>> uploadVoice(
    String filePath, {
    int durationSeconds = 0,
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final formData = FormData.fromMap({
      'voice': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
        // Explicitly set MIME type for .m4a AAC recordings
        contentType: DioMediaType('audio', 'mp4'),
      ),
    });

    final response = await _apiClient.dio.post(
      ApiEndpoints.uploadVoice,
      data: formData,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );

    final data = response.data;
    Map<String, dynamic> result;
    if (data is Map && data.containsKey('data')) {
      result = Map<String, dynamic>.from(data['data'] as Map);
    } else {
      result = Map<String, dynamic>.from(data as Map);
    }
    // Inject client-side duration since server can't extract it without FFprobe
    if (durationSeconds > 0) {
      result['duration'] = durationSeconds;
    }
    return result;
  }

  /// Uploads a document file to the server.
  Future<Map<String, dynamic>> uploadDocument(
    String filePath,
    String fileName, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    String type = 'application';
    String subtype = 'octet-stream';

    switch (ext) {
      case 'pdf':
        subtype = 'pdf';
        break;
      case 'doc':
        subtype = 'msword';
        break;
      case 'docx':
        subtype = 'vnd.openxmlformats-officedocument.wordprocessingml.document';
        break;
      case 'xls':
        subtype = 'vnd.ms-excel';
        break;
      case 'xlsx':
        subtype = 'vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        break;
      case 'ppt':
        subtype = 'vnd.ms-powerpoint';
        break;
      case 'pptx':
        subtype =
            'vnd.openxmlformats-officedocument.presentationml.presentation';
        break;
      case 'zip':
        subtype = 'zip';
        break;
      case 'rar':
        subtype = 'x-rar-compressed';
        break;
      case '7z':
        subtype = 'x-7z-compressed';
        break;
      case 'txt':
        type = 'text';
        subtype = 'plain';
        break;
      case 'csv':
        type = 'text';
        subtype = 'csv';
        break;
      case 'json':
        subtype = 'json';
        break;
      case 'xml':
        subtype = 'xml';
        break;
    }

    final formData = FormData.fromMap({
      'document': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: DioMediaType(type, subtype),
      ),
    });

    final response = await _apiClient.dio.post(
      ApiEndpoints.uploadDocument,
      data: formData,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );

    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  /// Fetches media gallery for a chat.
  Future<Map<String, dynamic>> getChatMedia(
    String chatId, {
    String type = 'all',
    int page = 1,
    int limit = 30,
  }) async {
    final response = await _apiClient.dio.get(
      '${ApiEndpoints.chats}/$chatId/media',
      queryParameters: {'type': type, 'page': page, 'limit': limit},
    );

    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  /// Fetches all media for current user across all chats.
  Future<Map<String, dynamic>> getAllMedia({
    int page = 1,
    int limit = 30,
  }) async {
    final response = await _apiClient.dio.get(
      ApiEndpoints.allMedia,
      queryParameters: {'page': page, 'limit': limit},
    );

    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  /// Tells the server that this media was downloaded, so it can be cleaned up
  /// after 1 day to save disk space.
  Future<void> markDownloaded(String fileUrl) async {
    try {
      await _apiClient.dio.post(
        ApiEndpoints.markDownloaded,
        data: {'fileUrl': fileUrl},
      );
    } catch (e) {
      // It's a best-effort background call, we can ignore failure
    }
  }

  /// Deletes multiple media messages for the user locally.
  Future<void> deleteBulkMedia(List<String> messageIds) async {
    await _apiClient.dio.delete(
      ApiEndpoints.deleteMedia,
      data: {'messageIds': messageIds},
    );
  }
}
