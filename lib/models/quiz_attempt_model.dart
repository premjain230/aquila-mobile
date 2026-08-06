import 'package:cloud_firestore/cloud_firestore.dart';

/// A completed quiz attempt — `users/{uid}/quizAttempts/{id}`.
class QuizAttempt {
  final String id;
  final String subject;
  final String topic;
  final int correctCount;
  final int totalQuestions;
  final DateTime takenAt;
  final List<Map<String, dynamic>> answers;
  final String type; // standard | ai
  final num score;

  const QuizAttempt({
    required this.id,
    required this.subject,
    required this.topic,
    required this.correctCount,
    required this.totalQuestions,
    required this.takenAt,
    required this.answers,
    required this.type,
    required this.score,
  });

  double get percentage => totalQuestions == 0 ? 0 : (score / totalQuestions) * 100;

  factory QuizAttempt.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};

    List<Map<String, dynamic>> answers = [];
    if (d['answers'] is List) {
      for (final a in d['answers'] as List) {
        if (a is Map) answers.add(Map<String, dynamic>.from(a));
      }
    }

    DateTime takenAt = DateTime.now();
    final t = d['takenAt'];
    if (t is Timestamp) {
      takenAt = t.toDate();
    } else if (t is DateTime) {
      takenAt = t;
    }

    return QuizAttempt(
      id: doc.id,
      subject: d['subject']?.toString() ?? '',
      topic: d['topic']?.toString() ?? '',
      correctCount: (d['correctCount'] as num?)?.toInt() ?? 0,
      totalQuestions: (d['totalQuestions'] as num?)?.toInt() ?? 0,
      takenAt: takenAt,
      answers: answers,
      type: d['type']?.toString() ?? 'standard',
      score: (d['score'] as num?) ?? 0,
    );
  }
}