import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/quiz_attempt_model.dart';

class QuizService {
  QuizService._();

  static final QuizService instance = QuizService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Persists a finished attempt to `users/{uid}/quizAttempts`.
  ///
  /// Mirrors web `finishQuiz` shape exactly so `firestore.rules` allow the write
  /// and the website's Analyze page reads the same fields.
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
    final incorrect = (totalQuestions - correctCount).clamp(0, totalQuestions);
    final title = '$subject • $topic';
    await _db.collection('users').doc(uid).collection('quizAttempts').add({
      // Fields required by firestore.rules + web analyze
      'subject': subject,
      'topic': topic,
      'title': title,
      'totalQ': totalQuestions,
      'correct': correctCount,
      'incorrect': incorrect,
      'skipped': 0,
      'score': score,
      'maxScore': totalQuestions,
      'mode': type,
      // Mobile-compat aliases (so mobile readers don't need to change)
      'correctCount': correctCount,
      'totalQuestions': totalQuestions,
      'type': type,
      'answers': answers,
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