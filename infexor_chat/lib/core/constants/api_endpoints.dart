class ApiEndpoints {
  ApiEndpoints._();

  // Base URL - change this to your VPS URL in production
  static const String baseUrl = 'http://72.61.171.190:5655/api';
  static const String socketUrl = 'http://72.61.171.190:5655';

  // Auth
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';
  static const String logoutAll = '/auth/logout-all';

  // Users
  static const String profile = '/users/profile';
  static const String updateProfile = '/users/profile';
  static const String privacySettings = '/users/privacy';
  static const String blockUser = '/users/block';
  static const String blockedUsers = '/users/blocked';
  static const String fcmToken = '/auth/fcm-token';
  static const String allMedia = '/users/media';
  static const String deleteMedia = '/users/media';

  // Contacts
  static const String syncContacts = '/contacts/sync';
  static const String contacts = '/contacts';

  // Chats
  static const String chats = '/chats';
  static const String createChat = '/chats/create';

  // Uploads
  static const String uploadImage = '/upload/image';
  static const String uploadVideo = '/upload/video';
  static const String uploadAudio = '/upload/audio';
  static const String uploadVoice = '/upload/voice';
  static const String uploadDocument = '/upload/document';
  static const String markDownloaded = '/upload/mark-downloaded';

  // Media Gallery
  static const String chatMedia = '/chats'; // Use: $chatMedia/$chatId/media

  // Groups
  static const String groups = '/groups';
  static const String createGroup = '/groups/create';

  // Status
  static const String status = '/status';
  static const String myStatuses = '/status/mine';
  static const String contactStatuses = '/status/contacts';

  // Health
  static const String health = '/health';
}
