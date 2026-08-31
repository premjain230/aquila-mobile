library ai_context;

import 'contracts.dart';

Map<String, dynamic> buildLearningContext({
  required LearnerSnapshot snapshot,
  String? currentSubject,
  String? currentConceptId,
  int tokenBudget = 800,
}) {
  final key = currentSubject?.toLowerCase().replaceAll(' ', '_');
  final subjectState = key != null ? snapshot.subjectStates[key] : null;
  final goals = snapshot.goals.where((g) => g.status == 'active').take(3).map((g) => {'title': g.title, 'priority': g.priority}).toList();
  final misconceptions = snapshot.activeMisconceptions
      .where((m) => currentConceptId == null || m.conceptId == currentConceptId)
      .take(3).map((m) => {'conceptId': m.conceptId, 'misconception': m.misconception}).toList();
  final recentEvidence = snapshot.recentEvents
      .where((e) => currentConceptId == null || e.conceptId == currentConceptId)
      .take(5).map((e) => {'type': e.type, 'conceptId': e.conceptId}).toList();
  final reviewState = {
    'due': snapshot.reviewStats['due'] ?? 0,
    'overdue': snapshot.reviewStats['overdue'] ?? 0,
    'practice': snapshot.reviewStats['practice'] ?? 0,
    'reviewSoon': snapshot.reviewStats['reviewSoon'] ?? 0,
  };
  final ctx = {
    'academic': {'board': snapshot.academic.board, 'grade': snapshot.academic.grade, 'track': snapshot.academic.track},
    'goals': goals,
    'subjectState': subjectState?.toMap(),
    'reviewState': reviewState,
    'activeMisconceptions': misconceptions,
    'recentEvidence': recentEvidence,
    'meta': {'snapshotAt': snapshot.snapshotAt},
  };
  return ctx;
}
