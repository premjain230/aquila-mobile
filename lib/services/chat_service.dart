import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_config.dart';
import '../models/chat_models.dart';
import 'api_client.dart';
import 'memory_service.dart';

/// Web search + chat, mirroring the web `chat.js` flow: system prompt for the
/// neuroscience-powered learning model, capped history, optional web search,
/// and Firestore-backed chat sessions.
class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// The exact system prompt used by the web app (ported verbatim).
  static const String systemPrompt = r'''
# Aquila AI — Neuroscience-Powered Learning System Prompt

## Identity

You are **Aquila AI**, an elite AI learning companion designed to maximize understanding, retention, and problem-solving for students preparing for JEE, NEET, Olympiads, Boards, UPSC, SAT, university courses, and any academic subject.

Your objective is **not simply to answer questions**.

Your objective is to build deep conceptual understanding while minimizing unnecessary cognitive load and helping students remember information for the long term.

You combine the best available evidence from neuroscience, cognitive psychology, learning science, education research, and expert teaching practices.

Never present speculative neuroscience as established fact. Use neuroscience only when it genuinely improves learning or explains why a study strategy works.

---

# Core Mission

Every response should improve one or more of these:

* Understanding
* Memory
* Reasoning
* Transfer of knowledge
* Long-term retention
* Motivation
* Confidence through competence

Success is measured by what the student can explain independently after learning—not by how impressive the explanation sounds.

---

# Primary Learning Principles

Prioritize:

1. Understanding before memorization
2. Concepts before formulas
3. Relationships before isolated facts
4. Active recall over passive reading
5. Retrieval over rereading
6. Spaced review
7. Deliberate practice
8. Error correction
9. Knowledge connections
10. Progressive difficulty

Never overload the learner with unnecessary information.

---

# Cognitive Load Management

Continuously estimate cognitive load. If load becomes high: simplify language, reduce steps, remove unnecessary terminology, explain one idea at a time, provide small checkpoints, summarize frequently.

Avoid teaching five concepts simultaneously. Teach in manageable chunks.

---

# Adaptive Teaching Engine

Infer the student's level from questions, mistakes, wording, confidence, speed, and context. Adjust vocabulary, depth, pace, examples, abstraction. Never make students feel unintelligent.

---

# Concept Construction

Whenever introducing a new concept: state the big idea, why it exists, intuition, mechanism, examples, edge cases, applications, connections to previous knowledge, then check understanding.

---

# Multi-Level Explanation Framework

Every concept can be explained at multiple levels: one-sentence intuition, real-life analogy, visual mental model, school level, competitive level, expert level. Only increase depth when needed.

---

# Neuroscience Integration (Use Only When Helpful)

Use neuroscience selectively to explain effective learning strategies (retrieval practice, spaced repetition, sleep and consolidation, prior knowledge, limited attention). Never overstate biological certainty or invent mechanisms.

---

# Analogies, Mental Models, Active Learning

Provide accurate, memorable analogies. Use mental models (systems, flows, cause-effect, feedback loops, constraints). Never keep the student passive—invite predictions and self-explanation.

---

# Misconception Detection

Watch for incorrect assumptions, common misconceptions, memorized-but-misunderstood facts, and logical gaps. Correct misconceptions respectfully by explaining why they are wrong and replacing them with the correct mental model.

---

# Exam Optimization & Problem Solving

Explain what is essential for the exam, common traps, patterns, efficient strategies. For numerical problems (JEE/NEET): identify the concept, explain why it applies, plan, solve step-by-step, highlight common mistakes, suggest faster approaches, generalize. Never skip reasoning.

---

# Safety and Accuracy

* Prefer correctness over confidence.
* Distinguish facts from theories.
* Cite uncertainty when appropriate.
* Never invent formulas, mechanisms, or scientific results.

---

# Final Objective

The ultimate goal is to help students become independent learners who can reason through unfamiliar problems, retain knowledge, and apply concepts flexibly.
''';

  /// Merges learner-profile context (weak topics, mastery, recent activity)
  /// into the prompt, mirroring `aquila-integration.js`.
  Future<String> buildSystemPrompt(String uid) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('learning')
        .doc('profile')
        .get();
    if (!doc.exists) return systemPrompt;

    final d = doc.data() ?? const <String, dynamic>{};
    final buffer = StringBuffer(systemPrompt);

    final mastery = d['conceptMastery'];
    if (mastery is Map && mastery.isNotEmpty) {
      final weak = mastery.entries.toList()
        ..sort((a, b) => (a.value is num ? a.value as num : 0)
            .compareTo(b.value is num ? b.value as num : 0));
      final weakest = weak.take(3);
      buffer.write('\n\nAREAS NEEDING ATTENTION:');
      var i = 1;
      for (final e in weakest) {
        final pct = (e.value is num ? e.value as num : 0) * 100;
        buffer.write('\n$i. ${e.key} (${pct.round()}% mastery)');
        i++;
      }
    }

    final velocity = d['learningVelocity'];
    if (velocity is num) {
      buffer.write('\n\nLearning velocity: ${velocity.toStringAsFixed(2)}.');
      if (velocity < 0.5) {
        buffer.write(' Keep explanations simple and step-by-step.');
      }
    }

    final preferredStyle = d['preferredStyle'];
    if (preferredStyle != null && preferredStyle.toString().isNotEmpty) {
      buffer.write('\n\nPrefers explanations as: $preferredStyle.');
    }

    // Long-term memory (shared with the web app). Inject the most recent
    // entries so Aquila can recall the student's saved facts & preferences
    // across conversations and devices.
    final memories = await MemoryService.instance.load(uid);
    if (memories.isNotEmpty) {
      buffer.write('\n\nMEMORY (long-term facts the student asked you to remember):');
      final top = memories.take(8).toList(growable: false);
      for (var i = 0; i < top.length; i++) {
        buffer.write('\n${i + 1}. ${top[i].text}');
      }
    }

    return buffer.toString();
  }

  /// Streams chat sessions (mirrors web sidebar list).
  Stream<List<ChatSession>> sessionsStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('chats')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(ChatSession.fromDoc).toList(growable: false));
  }

  /// Streams messages of a session.
  Stream<List<ChatMessage>> messagesStream(String uid, String chatId) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('ts', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map(ChatMessage.fromDoc).toList(growable: false));
  }

  /// Reads the last [AppConfig.maxHistory] messages of a session for context.
  Future<List<Map<String, String>>> loadHistory(String uid, String chatId) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('ts', descending: false)
        .limitToLast(AppConfig.maxHistory)
        .get();
    return snap.docs.map((doc) {
      final d = doc.data();
      final role = d['role']?.toString() == 'assistant' ? 'assistant' : 'user';
      return {'role': role, 'content': d['content']?.toString() ?? ''};
    }).toList();
  }

  /// Loads the full message list of a session (for chat-history resumption).
  Future<List<ChatMessage>> loadSessionMessages(String uid, String chatId) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('ts', descending: false)
        .get();
    return snap.docs.map(ChatMessage.fromDoc).toList(growable: false);
  }

  Future<String> createSession(String uid, {String? title}) async {
    final ref = _db.collection('users').doc(uid).collection('chats').doc();
    await ref.set({
      'title': title?.trim().isNotEmpty == true ? title!.trim() : 'New Chat',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'messageCount': 0,
    });
    return ref.id;
  }

  Future<void> renameChat(String uid, String chatId, String title) async {
    await _db.collection('users').doc(uid).collection('chats').doc(chatId).set(
      {'title': title, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> saveMessage(
    String uid,
    String chatId,
    String role,
    String content,
  ) async {
    final chatRef =
        _db.collection('users').doc(uid).collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();
    await msgRef.set({
      'role': role,
      'content': content,
      'ts': FieldValue.serverTimestamp(),
    });
    await chatRef.set(
      {
        'updatedAt': FieldValue.serverTimestamp(),
        'messageCount': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deleteSession(String uid, String chatId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(chatId)
        .delete();
  }

  /// Searches the web via the backend `/api/search` and formats the results
  /// the same way the web app feeds them to the model.
  Future<String?> buildSearchContext(String query) async {
    try {
      final res = await ApiClient.instance
          .postJson(AppConfig.searchPath, {'query': query});
      final results = res['results'];
      if (results is! List || results.isEmpty) return null;
      final parts = <String>[];
      for (var i = 0; i < results.length; i++) {
        final r = results[i] is Map ? results[i] as Map : const {};
        final title = r['title']?.toString() ?? 'Untitled';
        final snippet = r['snippet']?.toString() ?? '';
        final link = r['url']?.toString() ?? '';
        parts.add('[${i + 1}] "$title" - $snippet\nSource: $link');
      }
      return '\n\nCurrent web search results (use these to answer accurately):\n${parts.join('\n')}\n\nAnswer directly using these results where relevant. If the results don\'t contain enough information, say so. Always cite sources naturally.';
    } catch (_) {
      return null;
    }
  }
}