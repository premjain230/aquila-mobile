import 'package:cloud_firestore/cloud_firestore.dart';

/// Daily progress snapshot — `progress/{uid}`-style doc used by the planner
/// dashboard (mirrors web `updateProgress`).
class ProgressEntry {
  final String date; // YYYY-MM-DD
  final int tasksCompleted;
  final int tasksSkipped;
  final int totalTasks;
  final int minutesStudied;
  final List<String> completedTopics;

  const ProgressEntry({
    required this.date,
    required this.tasksCompleted,
    required this.tasksSkipped,
    required this.totalTasks,
    required this.minutesStudied,
    required this.completedTopics,
  });

  factory ProgressEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return ProgressEntry(
      date: d['date']?.toString() ?? '',
      tasksCompleted: (d['tasksCompleted'] as num?)?.toInt() ?? 0,
      tasksSkipped: (d['tasksSkipped'] as num?)?.toInt() ?? 0,
      totalTasks: (d['totalTasks'] as num?)?.toInt() ?? 0,
      minutesStudied: (d['minutesStudied'] as num?)?.toInt() ?? 0,
      completedTopics:
          (d['completedTopics'] as List?)?.map((e) => e?.toString() ?? '').toList() ?? [],
    );
  }
}

/// Aggregated planner stats — `studyPlans/{planId}/progress` collection.
class PlannerStats {
  final int totalTasks;
  final int completed;
  final int skipped;
  final int remaining;
  final int weeklyTarget;
  final double completionRate;

  const PlannerStats({
    required this.totalTasks,
    required this.completed,
    required this.skipped,
    required this.remaining,
    required this.weeklyTarget,
    required this.completionRate,
  });

  const PlannerStats.empty()
      : totalTasks = 0,
        completed = 0,
        skipped = 0,
        remaining = 0,
        weeklyTarget = 0,
        completionRate = 0;
}