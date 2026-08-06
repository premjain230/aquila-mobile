import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatMessageRole { user, assistant }

class ChatMessage {
  final String id;
  final ChatMessageRole role;
  final String content;
  final DateTime? timestamp;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.timestamp,
  });

  bool get isUser => role == ChatMessageRole.user;

  ChatMessage copyWith({String? content, DateTime? timestamp}) =>
      ChatMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        timestamp: timestamp ?? this.timestamp,
      );

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final role = (data['role']?.toString() ?? 'user') == 'assistant'
        ? ChatMessageRole.assistant
        : ChatMessageRole.user;
    final ts = data['ts'];
    DateTime? time;
    if (ts is Timestamp) {
      time = ts.toDate();
    } else if (ts is DateTime) {
      time = ts;
    }
    return ChatMessage(
      id: doc.id,
      role: role,
      content: data['content']?.toString() ?? '',
      timestamp: time,
    );
  }
}

class ChatSession {
  final String id;
  final String title;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int messageCount;

  const ChatSession({
    required this.id,
    required this.title,
    this.createdAt,
    this.updatedAt,
    this.messageCount = 0,
  });

  factory ChatSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    DateTime? toDate(Object? v) => v is Timestamp ? v.toDate() : null;
    return ChatSession(
      id: doc.id,
      title: data['title']?.toString() ?? 'Untitled Chat',
      createdAt: toDate(data['createdAt']),
      updatedAt: toDate(data['updatedAt']),
      messageCount: (data['messageCount'] as num?)?.toInt() ?? 0,
    );
  }
}