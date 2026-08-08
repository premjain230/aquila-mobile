import 'package:cloud_firestore/cloud_firestore.dart';

/// A single long-term memory entry.
class MemoryItem {
  final String id;
  final String text;
  final DateTime createdAt;

  const MemoryItem({
    required this.id,
    required this.text,
    required this.createdAt,
  });
}

/// Long-term AI memory, shared with the web app.
///
/// Stores items in `users/{uid}/learning/memory` — a doc under the owner-only
/// `learning` profile path, so no Firestore rules changes are needed. Both the
/// web chat and the mobile app read the latest entries and inject them into the
/// system prompt so Aquila "remembers" the student across conversations and
/// devices.
class MemoryService {
  MemoryService._();

  static final MemoryService instance = MemoryService._();

  static const int maxItems = 60;
  static const int _maxTextLength = 2000;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      _db.collection('users').doc(uid).collection('learning').doc('memory');

  Future<List<MemoryItem>> load(String uid) async {
    try {
      final snap = await _ref(uid).get();
      final items = snap.data()?['items'];
      if (items is! List) return const [];
      final out = <MemoryItem>[];
      for (final raw in items) {
        if (raw is! Map) continue;
        final text = raw['text']?.toString() ?? '';
        if (text.isEmpty) continue;
        final ts = raw['t'];
        out.add(MemoryItem(
          id: raw['id']?.toString() ?? '',
          text: text,
          createdAt: ts is num
              ? DateTime.fromMillisecondsSinceEpoch(ts.toInt())
              : DateTime.fromMillisecondsSinceEpoch(0),
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Adds a new memory (newest first). Returns false on failure or empty text.
  Future<bool> add(String uid, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    try {
      final items = await load(uid);
      items.insert(
        0,
        MemoryItem(
          id: _newId(),
          text: trimmed.length > _maxTextLength
              ? trimmed.substring(0, _maxTextLength)
              : trimmed,
          createdAt: DateTime.now(),
        ),
      );
      if (items.length > maxItems) items.removeRange(maxItems, items.length);
      await _persist(uid, items);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Removes a memory by its id.
  Future<void> remove(String uid, String id) async {
    try {
      final items = await load(uid);
      items.removeWhere((e) => e.id == id);
      await _persist(uid, items);
    } catch (_) {}
  }

  Future<void> _persist(String uid, List<MemoryItem> items) async {
    await _ref(uid).set({
      'items': items
          .map((e) => {
                'id': e.id,
                'text': e.text,
                't': e.createdAt.millisecondsSinceEpoch,
              })
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static String _newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '$now-${(now * 31 & 0x7fffffff).toRadixString(16)}';
  }
}