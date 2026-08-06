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
  Future<String> savePlan(String uid, List<PlanWeek> weeks) async {
    final ref = _db.collection('studyPlans').doc();
    await ref.set({
      'planId': ref.id,
      'uid': uid,
      'title': 'My Study Plan',
      'weeklyPlan': weeks.map(_weekToMap).toList(),
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

  /// Flattens weekly days into dated task docs under `users/{uid}/tasks`
  /// (mirrors createTasksFromPlan).
  Future<void> createTasksFromPlan({
    required String uid,
    required String planId,
    required List<PlanWeek> weeks,
    required String startDateIso,
  }) async {
    final start = DateTime.tryParse(startDateIso) ?? DateTime.now();
    final col = _db.collection('users').doc(uid).collection('tasks');
    var index = 0;
    for (final week in weeks) {
      for (final day in week.days) {
        for (final s in day.sessions) {
          index++;
          final offsetFromStart =
              (week.week - 1) * 7 + _weekdayIndex(day.day);
          final scheduled = start.add(Duration(days: offsetFromStart));
          await col.add({
            'taskId': '$uid-$planId-$index',
            'subject': s.subject,
            'topic': s.topic,
            'durationMinutes': s.durationMinutes,
            'type': s.type,
            'priority': s.priority,
            'status': 'pending',
            'week': week.week,
            'weekDay': day.day,
            'scheduledDate': Timestamp.fromDate(scheduled),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }
  }

  /// Streams tasks for the planner dashboard.
  Stream<List<StudyTask>> tasksStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .orderBy('scheduledDate')
        .snapshots()
        .map((snap) => snap.docs.map(StudyTask.fromDoc).toList(growable: false));
  }

  Future<void> updateTaskStatus(String uid, String docId, String status) async {
    await _db.collection('users').doc(uid).collection('tasks').doc(docId).set(
      {'status': status, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
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
      'examDate': ?examDate,
      'examType': ?examType,
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