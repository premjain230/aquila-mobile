library history;

import 'contracts.dart';
import 'recommendation_engine.dart';

LearnerSnapshot buildLearnerSnapshot({
  required String uid,
  AcademicContext? academic,
  List<Goal>? goals,
  Map<String, Mastery>? masteryMap,
  List<Misconception>? misconceptions,
  List<LearningEvent>? recentEvents,
  Map<String, dynamic>? progress,
}) {
  final bySubject = <String, List<Mastery>>{};
  for (final m in (masteryMap ?? {}).values) {
    final key = (m.subject.isNotEmpty ? m.subject : m.conceptId.split('_').first).toLowerCase();
    (bySubject[key] = bySubject[key] ?? []).add(m);
  }
  final subjectStates = <String, SubjectState>{};
  for (final e in bySubject.entries) {
    final withEvidence = e.value.where((m) => (m.evidenceStrength > 0 || m.attempts > 0)).toList();
    double? mastery;
    double? evidenceStrengthAvg;
    if (withEvidence.isEmpty) {
      mastery = null;
    } else {
      double sumW = 0, sumWM = 0, sumE = 0;
      for (final m in withEvidence) {
        final w = m.evidenceStrength > 0 ? m.evidenceStrength : 0.05;
        sumW += w;
        sumWM += m.masteryScore * w;
        sumE += m.evidenceStrength;
      }
      mastery = sumW > 0 ? sumWM / sumW : null;
      evidenceStrengthAvg = sumE / withEvidence.length;
    }
    final confs = e.value.map((m) => m.confidenceScore).toList();
    final confidence = confs.isEmpty ? 0.0 : confs.reduce((a, b) => a + b) / confs.length;
    final weakCandidates = e.value.where((m) => m.evidenceStrength >= 0.35 && m.masteryScore < 0.45).toList();
    final strongCandidates = e.value.where((m) => m.evidenceStrength >= 0.35 && m.masteryScore >= 0.75).toList();
    final sorted = List<Mastery>.from(e.value)..sort((a, b) => a.masteryScore.compareTo(b.masteryScore));
    subjectStates[e.key] = SubjectState(
      subjectId: e.key,
      mastery: mastery ?? 0,
      confidence: confidence,
      weakAreas: weakCandidates.take(3).map((m) => m.conceptId).toList(),
      strongAreas: strongCandidates.take(3).map((m) => m.conceptId).toList(),
      gap: mastery == null ? 0 : (mastery - confidence).abs(),
    );
  }
  return LearnerSnapshot(
    uid: uid,
    academic: academic ?? AcademicContext(),
    goals: goals ?? [],
    subjectStates: subjectStates,
    activeMisconceptions: (misconceptions ?? []).where((m) => !m.resolved).take(20).toList(),
    recentEvents: (recentEvents ?? []).take(20).toList(),
    progress: progress ?? {},
    snapshotAt: DateTime.now().toIso8601String(),
  );
}
