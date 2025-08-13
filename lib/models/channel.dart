// models/channel.dart
class Channel {
  final int id;
  final String name;
  final String? topic;
  final String? description;
  final int? createdBy;
  final String? createdByName;
  final int memberCount;
  final bool isJoined;
  final DateTime createdAt;
  final DateTime updatedAt;

  Channel({
    required this.id,
    required this.name,
    this.topic,
    this.description,
    this.createdBy,
    this.createdByName,
    this.memberCount = 0,
    this.isJoined = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      topic: json['topic'],
      description: json['description'],
      createdBy: json['created_by'] ?? json['createdBy'],
      createdByName: json['created_by_name'] ?? json['createdByName'],
      memberCount: json['member_count'] ?? json['memberCount'] ?? 0,
      isJoined: json['is_joined'] ?? json['isJoined'] ?? false,
      createdAt: DateTime.parse(json['created_at'] ??
          json['createdAt'] ??
          DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ??
          json['updatedAt'] ??
          DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'topic': topic,
      'description': description,
      'created_by': createdBy,
      'created_by_name': createdByName,
      'member_count': memberCount,
      'is_joined': isJoined,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper method to get display name with #
  String get displayName => '#$name';

  // Helper method to check if channel has topic
  bool get hasTopic => topic != null && topic!.isNotEmpty;

  // Helper method to get member count text
  String get memberCountText {
    if (memberCount == 0) return 'No members';
    if (memberCount == 1) return '1 member';
    return '$memberCount members';
  }

  // Copy with method for updating channel data
  Channel copyWith({
    int? id,
    String? name,
    String? topic,
    String? description,
    int? createdBy,
    String? createdByName,
    int? memberCount,
    bool? isJoined,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Channel(
      id: id ?? this.id,
      name: name ?? this.name,
      topic: topic ?? this.topic,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      memberCount: memberCount ?? this.memberCount,
      isJoined: isJoined ?? this.isJoined,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Channel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Channel(id: $id, name: $name, memberCount: $memberCount, isJoined: $isJoined)';
  }
}
