class CallLog {
  final String id;
  final Map<String, dynamic>? caller; // Populated Map
  final String callerId;
  final Map<String, dynamic>? receiver; // Populated Map
  final String receiverId;
  final String type; // 'audio' or 'video'
  final String status; // 'missed', 'completed', 'declined'
  final int duration;
  final DateTime timestamp;

  CallLog({
    required this.id,
    this.caller,
    required this.callerId,
    this.receiver,
    required this.receiverId,
    required this.type,
    required this.status,
    required this.duration,
    required this.timestamp,
  });

  factory CallLog.fromJson(Map<String, dynamic> json) {
    // Backend populates callerId and receiverId as objects if requested
    final isCallerObj = json['callerId'] is Map;
    final isReceiverObj = json['receiverId'] is Map;

    return CallLog(
      id: json['_id'] ?? '',
      caller: isCallerObj ? json['callerId'] as Map<String, dynamic> : null,
      callerId: isCallerObj
          ? json['callerId']['_id']
          : (json['callerId'] ?? ''),
      receiver: isReceiverObj
          ? json['receiverId'] as Map<String, dynamic>
          : null,
      receiverId: isReceiverObj
          ? json['receiverId']['_id']
          : (json['receiverId'] ?? ''),
      type: json['type'] ?? 'audio',
      status: json['status'] ?? 'completed',
      duration: json['duration'] ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp']).toLocal()
          : DateTime.now(),
    );
  }
}
