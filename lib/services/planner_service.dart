import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_config.dart';
import '../models/plan_models.dart';
import '../models/task_model.dart';
import 'api_client.dart';

/// Planner service: generates study plans via the backend AI, persists the
/// plan + tasks to Firestore, and tracks progress (mirrors web planner).
class PlannerService {
  PlannerService._();

  static final PlannerService instance = PlannerService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Calls `/api/generate-plan`; tolerates the backend returning either a bare
  /// array or an object wrapping `weeks`/`plan`.
  Future<List<PlanWeek>> generatePlan(PlanRequest request) async {
    final res = await ApiClient.instance
        .postJson(AppConfig.generatePlanPath, request.toJson());
    final raw = res['plan'] ?? res['weeklyPlan'] ?? res;
    List weeksRaw;
    if (raw is List) {
      weeksRaw = raw;
    } else if (raw is Map && raw['weeklyPlan'] is List) {
      weeksRaw = raw['weeklyPlan'] as List;
    } else if (raw is Map && raw['weeks'] is List) {
      weeksRaw = raw['weeks'] as List;
    } else {
      throw const ApiException('Unexpected plan format from backend');
    }
    final weeks = <PlanWeek>[];
    for (final w in weeksRaw) {
      if (w is Map) {
        weeks.add(PlanWeek.fromJson(
          Map<String, dynamic>.from(w),
          fallbackWeek: weeks.length + 1,
        ));
      }
    }
    if (weeks.isEmpty) throw const ApiException('Backend returned an empty study plan');
    return weeks;
  }

  /// Persists the exam profile on the user document (mirrors saveExamProfile).
  Future<void> saveExamProfile(String uid, PlanRequest request) async {
    await _db.collection('users').doc(uid).set(
      {
        'examType': request.examType,
        'targetScore': request.targetScore,
        'subjects': request.subjects,
        'weakTopics': request.weakTopics,
        'dailyHours': request.dailyHours,
        'startDate': request.startDate,
        'examDate': request.examDate,
        'onboardingComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Saves the weekly plan as a `studyPlans/{planId}` doc and returns its id.
  /// Mirrors web `saveStudyPlan` shape so the website planner reads the same doc.
  Future<String> savePlan(String uid, List<PlanWeek> weeks,
      {String examType = '', String summary = ''}) async {
    final ref = _db.collection('studyPlans').doc();
    await ref.set({
      'planId': ref.id,
      'userId': uid,
      'uid': uid, // legacy compat for older mobile builds
      'title': 'My Study Plan',
      'examType': examType,
      'summary': summary,
      'daysUntilExam': 0,
      'weeklyPlan': weeks.map(_weekToMap).toList(),
      'subjectAllocation': <String, dynamic>{},
      'revisionSchedule': <String, dynamic>{},
      'milestones': <dynamic>[],
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Map<String, dynamic> _weekToMap(PlanWeek w) => {
        'week': w.week,
        'title': w.title,
        'theme': w.theme,
        'focus': w.focus,
        'days': w.days
            .map((d) => {
                  'day': d.day,
                  'date': d.date,
                  'sessions': d.sessions
                      .map((s) => {
                            'subject': s.subject,
                            'topic': s.topic,
                            'durationMinutes': s.durationMinutes,
                            'type': s.type,
                            'priority': s.priority,
                          })
                      .toList(),
                })
            .toList(),
        'subjects': w.subjects
            .map((s) => {'name': s.name, 'topics': s.topics, 'hours': s.hours})
            .toList(),
      };

  /// Flattens weekly days into dated task docs in top-level `tasks`
  /// (mirrors web `createTasksFromPlan` — same collection + shape so the
  /// website sees the mobile-created plan and vice versa).
  Future<void> createTasksFromPlan({
    required String uid,
    required String planId,
    required List<PlanWeek> weeks,
    required String startDateIso,
  }) async {
    final start = DateTime.tryParse(startDateIso) ?? DateTime.now();
    final batch = _db.batch();
    var index = 0;
    for (final week in weeks) {
      for (final day in week.days) {
        for (final s in day.sessions) {
          index++;
          final offsetFromStart =
              (week.week - 1) * 7 + _weekdayIndex(day.day);
          final scheduled = start.add(Duration(days: offsetFromStart));
          final scheduledIso =
              '${scheduled.year.toString().padLeft(4, '0')}-${scheduled.month.toString().padLeft(2, '0')}-${scheduled.day.toString().padLeft(2, '0')}';
          final ref = _db.collection('tasks').doc();
          batch.set(ref, {
            'taskId': ref.id,
            'planId': planId,
            'userId': uid,
            // Scheduled date as ISO string for web compatibility (planner.html
            // compares string < today), plus Timestamp for mobile sorting.
            'scheduledDate': scheduledIso,
            'scheduledAt': Timestamp.fromDate(scheduled),
            'day': day.day,
            'weekDay': day.day, // compat for older mobile builds
            'week': week.week,
            'subject': s.subject,
            'topic': s.topic,
            'durationMinutes': s.durationMinutes,
            'type': s.type,
            'priority': s.priority,
            'status': 'pending',
            'completedAt': null,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }
    await batch.commit();
  }

  /// Streams tasks for the planner dashboard (top-level `tasks` collection
  /// filtered by userId — compatible with web planner).
  Stream<List<StudyTask>> tasksStream(String uid) {
    return _db
        .collection('tasks')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(StudyTask.fromDoc).toList(growable: false);
          list.sort((a, b) {
            final c = a.week.compareTo(b.week);
            if (c != 0) return c;
            return a.scheduledDate.compareTo(b.scheduledDate);
          });
          return list;
        });
  }

  Future<void> updateTaskStatus(String uid, String docId, String status) async {
    final ref = _db.collection('tasks').doc(docId);
    final snap = await ref.get();
    if (snap.exists && snap.data()?['userId'] == uid) {
      final update = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (status == 'completed') update['completedAt'] = FieldValue.serverTimestamp();
      await ref.update(update);
      // Mirror web _updateProgressCounters
      try {
        final data = snap.data()!;
        final progressRef = _db.collection('progress').doc(uid);
        final updates = <String, dynamic>{'lastUpdated': FieldValue.serverTimestamp()};
        if (status == 'completed') {
          final subject = data['subject']?.toString() ?? 'general';
          final dur = (data['durationMinutes'] as num?)?.toDouble() ?? 60;
          updates['subjectHours.$subject'] = FieldValue.increment(dur / 60);
          updates['totalMinutesStudied'] = FieldValue.increment(dur);
          updates['tasksCompleted'] = FieldValue.increment(1);
        }
        if (status == 'skipped') {
          updates['tasksSkipped'] = FieldValue.increment(1);
        }
        await progressRef.set(updates, SetOptions(merge: true));
      } catch (_) {}
    } else {
      // Fallback for old users/{uid}/tasks docs (legacy mobile path)
      await _db
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc(docId)
          .set(
        {'status': status, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
  }

  /// Triggers replanning via `/api/replan` and applies returned adjustments.
  Future<Map<String, dynamic>?> replan(String uid, {
    List<String> missedTasks = const [],
    int dailyHours = 3,
    String? examDate,
    String? examType,
  }) async {
    final res = await ApiClient.instance.postJson(AppConfig.replanPath, {
      if (missedTasks.isNotEmpty) 'missedTasks': missedTasks,
      'dailyHours': dailyHours,
      if (examDate != null) 'examDate': examDate,
      if (examType != null) 'examType': examType,
    });
    return res;
  }

  int _weekdayIndex(String day) {
    const map = {
      'Monday': 0,
      'Tuesday': 1,
      'Wednesday': 2,
      'Thursday': 3,
      'Friday': 4,
      'Saturday': 5,
      'Sunday': 6,
    };
    return map[day] ?? 0;
  }
}

/// Legacy alias kept for source-compat call sites.
typedef StudyPlanAlias = StudyPlan;