// models/message.dart
class Message {
  final int id;
  final int senderId;
  final String senderFullName;
  final String? senderUsername;
  final int? receiverId;
  final int? channelId;
  final String? text;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isRead; // ⬅️ NEW: Field untuk status read

  Message({
    required this.id,
    required this.senderId,
    required this.senderFullName,
    this.senderUsername,
    this.receiverId,
    this.channelId,
    this.text,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    this.isRead = false, // ⬅️ NEW: Default false
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      channelId: json['channel_id'],
      text: json['text'],
      imageUrl: json['image_url'],
      isRead: json['is_read'] == 1,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.parse(json['created_at']),
      senderUsername: json['username'] ?? '',
      senderFullName: json['full_name'] ?? '',
      // senderProfilePhotoUrl: json['profile_photo_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'sender_full_name': senderFullName,
      'sender_username': senderUsername,
      'receiver_id': receiverId,
      'channel_id': channelId,
      'text': text,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_read': isRead, // ⬅️ NEW: Include isRead in JSON
    };
  }

  // Helper method to check if message is from current user
  bool isFromCurrentUser(int currentUserId) {
    return senderId == currentUserId;
  }

  // Helper method to check if message has content
  bool get hasContent {
    return (text != null && text!.isNotEmpty) || imageUrl != null;
  }

  // ⬅️ NEW: Helper getter untuk content (diperlukan di home screen)
  String get content {
    if (text != null && text!.isNotEmpty) {
      return text!;
    } else if (imageUrl != null) {
      return '📷 Photo';
    }
    return '';
  }

  // ⬅️ NEW: Helper getter untuk timestamp (diperlukan di home screen)
  DateTime get timestamp {
    return createdAt;
  }

  // Helper method to get display time
  String get displayTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // ⬅️ NEW: Helper method untuk format waktu yang lebih detail
  String get formattedTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(createdAt.year, createdAt.month, createdAt.day);

    if (messageDate == today) {
      // Today - show time
      return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(Duration(days: 1))) {
      // Yesterday
      return 'Yesterday';
    } else if (now.difference(createdAt).inDays < 7) {
      // This week - show day name
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[createdAt.weekday - 1];
    } else {
      // Older - show date
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  // ⬅️ NEW: Method untuk membuat copy dengan field yang diupdate
  Message copyWith({
    int? id,
    int? senderId,
    String? senderFullName,
    String? senderUsername,
    int? receiverId,
    int? channelId,
    String? text,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderFullName: senderFullName ?? this.senderFullName,
      senderUsername: senderUsername ?? this.senderUsername,
      receiverId: receiverId ?? this.receiverId,
      channelId: channelId ?? this.channelId,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Message(id: $id, senderId: $senderId, text: $text, createdAt: $createdAt, isRead: $isRead)';
  }
}
