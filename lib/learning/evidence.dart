library evidence;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/api_client.dart';
import 'contracts.dart';

bool validateLearningEvent(LearningEvent e) {
  if (e.conceptId != null && e.conceptId!.length > 120) return false;
  if (e.confidence != null && (e.confidence! < 1 || e.confidence! > 5)) return false;
  return true;
}

Future<LearningEvent> emitLearningEvent(FirebaseFirestore db, String uid, String type, {String? conceptId, String? subject, String? topic, String? source, String? sessionId, String? questionId, Map<String, dynamic>? payload, int? confidence}) async {
  final e = LearningEvent(
    eventId: DateTime.now().millisecondsSinceEpoch.toString(),
    uid: uid,
    type: type,
    conceptId: conceptId,
    subject: subject,
    topic: topic,
    source: source,
    sessionId: sessionId,
    questionId: questionId,
    payload: payload ?? {},
    confidence: confidence,
    createdAt: DateTime.now().toIso8601String(),
  );
  if (!validateLearningEvent(e)) throw Exception('Invalid event');
  // Prefer server endpoint (authoritative)
  try {
    final res = await ApiClient.instance.postJson('/api/learning-event', {
      'eventId': e.eventId,
      'type': type,
      'conceptId': conceptId,
      'subject': subject,
      'topic': topic,
      'source': source,
      'sessionId': sessionId,
      'questionId': questionId,
      'payload': payload ?? {},
      if (confidence != null) 'confidence': confidence,
    }, auth: true);
    final id = res['eventId']?.toString() ?? e.eventId;
    return LearningEvent(eventId: id, uid: uid, type: type, conceptId: conceptId, subject: subject, topic: topic, source: source, sessionId: sessionId, questionId: questionId, payload: payload ?? {}, confidence: confidence, createdAt: DateTime.now().toIso8601String());
  } catch (_) {
    // Fallback direct (offline) — mastery will reconcile on next server write
    try {
      final ref = db.collection('users').doc(uid).collection('learningEvents').doc(e.eventId);
      await ref.set({...e.toMap(), 'createdAt': FieldValue.serverTimestamp()});
      return e;
    } catch (_) {
      return e;
    }
  }
}

Mastery? aggregateEvidenceStub(Mastery? mastery, LearningEvent event) {
  if (mastery == null) return null;
  final answered = ['question_correct','question_incorrect','question_answered','diagnostic_answered'].contains(event.type);
  var attempts = mastery.attempts;
  var correct = mastery.correct;
  if (answered) {
    attempts += 1;
    final isCorrect = event.type == 'question_correct' || (event.type == 'diagnostic_answered' && event.payload['correct'] == true);
    if (isCorrect) correct += 1;
  }
  return Mastery(
    uid: mastery.uid,
    conceptId: mastery.conceptId,
    masteryScore: mastery.masteryScore,
    masteryState: mastery.masteryState,
    attempts: attempts,
    correct: correct,
    accuracy: attempts > 0 ? correct / attempts : 0,
    confidenceScore: event.confidence != null ? (event.confidence! - 1) / 4 : mastery.confidenceScore,
    updatedAt: DateTime.now().toIso8601String(),
  );
}
