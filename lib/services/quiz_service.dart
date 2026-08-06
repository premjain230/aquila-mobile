import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/quiz_attempt_model.dart';

class QuizService {
  QuizService._();

  static final QuizService instance = QuizService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Persists a finished attempt to `users/{uid}/quizAttempts` (mirrors web
  /// finishQuiz).
  Future<void> saveAttempt(
    String uid, {
    required String subject,
    required String topic,
    required int correctCount,
    required int totalQuestions,
    required num score,
    required List<Map<String, dynamic>> answers,
    required String type,
  }) async {
    await _db.collection('users').doc(uid).collection('quizAttempts').add({
      'subject': subject,
      'topic': topic,
      'correctCount': correctCount,
      'totalQuestions': totalQuestions,
      'score': score,
      'answers': answers,
      'type': type,
      'takenAt': FieldValue.serverTimestamp(),
    });
  }

  /// Most recent attempts (mirrors analyze.html limit 500 desc).
  Future<List<QuizAttempt>> loadAttempts(String uid, {int limit = 500}) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('quizAttempts')
        .orderBy('takenAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(QuizAttempt.fromDoc).toList();
  }

  Stream<List<QuizAttempt>> attemptsStream(String uid, {int limit = 500}) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('quizAttempts')
        .orderBy('takenAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(QuizAttempt.fromDoc).toList(growable: false));
  }
}