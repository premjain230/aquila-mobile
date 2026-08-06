import 'package:cloud_firestore/cloud_firestore.dart';

/// Input payload sent to `/api/generate-plan` (mirrors web payload).
class PlanRequest {
  final String studentName;
  final String examType;
  final String targetScore;
  final List<String> subjects;
  final List<String> weakTopics;
  final int dailyHours;
  final String startDate; // YYYY-MM-DD
  final String examDate; // YYYY-MM-DD

  const PlanRequest({
    required this.studentName,
    required this.examType,
    required this.targetScore,
    required this.subjects,
    required this.weakTopics,
    required this.dailyHours,
    required this.startDate,
    required this.examDate,
  });

  Map<String, dynamic> toJson() => {
        'studentName': studentName,
        'examType': examType,
        'targetScore': targetScore,
        'subjects': subjects,
        'weakTopics': weakTopics,
        'dailyHours': dailyHours,
        'startDate': startDate,
        'examDate': examDate,
      };
}

/// Weekly plan element. The backend AI may return either a
/// `days[{day,date,sessions[]}]` shape (used by planner UI) or a
/// `subjects[{name,topics,hours}]` shape; the app handles both defensively,
/// just like renderers must.
class PlanWeek {
  final int week;
  final String theme;
  final String title;
  final String focus;
  final List<PlanDay> days;
  final List<PlanSubjectAlloc> subjects;

  const PlanWeek({
    required this.week,
    required this.theme,
    required this.title,
    required this.focus,
    required this.days,
    required this.subjects,
  });

  factory PlanWeek.fromJson(Map<String, dynamic> json, {int fallbackWeek = 1}) {
    final week = (json['week'] as num?)?.toInt() ?? fallbackWeek;

    final List<PlanDay> days = [];
    if (json['days'] is List) {
      for (final d in json['days'] as List) {
        if (d is Map) days.add(PlanDay.fromJson(Map<String, dynamic>.from(d)));
      }
    }

    final List<PlanSubjectAlloc> subjects = [];
    if (json['subjects'] is List) {
      for (final s in json['subjects'] as List) {
        if (s is Map) {
          subjects
              .add(PlanSubjectAlloc.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }

    // If the backend returned a subjects-only shape, synthesize weekday rows
    // so the week grid still renders meaningfully.
    if (days.isEmpty && subjects.isNotEmpty) {
      const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      for (var i = 0; i < weekdays.length; i++) {
        final allocated = subjects.where((s) => i < s.topics.length).toList();
        days.add(PlanDay(
          day: weekdays[i],
          date: null,
          sessions: allocated
              .map((s) => PlanSession(
                    subject: s.name,
                    topic: s.topics[i],
                    durationMinutes: 60,
                    type: 'learn',
                    priority: 'medium',
                  ))
              .toList(),
        ));
      }
    }

    return PlanWeek(
      week: week,
      theme: json['theme']?.toString() ?? json['title']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Week $week',
      focus: json['focus']?.toString() ?? '',
      days: days,
      subjects: subjects,
    );
  }
}

class PlanDay {
  final String day;
  final String? date;
  final List<PlanSession> sessions;

  const PlanDay({required this.day, this.date, required this.sessions});

  factory PlanDay.fromJson(Map<String, dynamic> json) {
    final sessions = <PlanSession>[];
    if (json['sessions'] is List) {
      for (final s in json['sessions'] as List) {
        if (s is Map) {
          sessions.add(PlanSession.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }
    return PlanDay(
      day: json['day']?.toString() ?? '',
      date: json['date']?.toString(),
      sessions: sessions,
    );
  }
}

class PlanSession {
  final String subject;
  final String topic;
  final int durationMinutes;
  final String type; // learn | revise | practice | test
  final String priority; // high | medium | low

  const PlanSession({
    required this.subject,
    required this.topic,
    required this.durationMinutes,
    required this.type,
    required this.priority,
  });

  factory PlanSession.fromJson(Map<String, dynamic> json) => PlanSession(
        subject: json['subject']?.toString() ?? '',
        topic: json['topic']?.toString() ?? '',
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 60,
        type: json['type']?.toString() ?? 'learn',
        priority: json['priority']?.toString() ?? 'medium',
      );
}

class PlanSubjectAlloc {
  final String name;
  final List<String> topics;
  final num hours;

  const PlanSubjectAlloc({required this.name, required this.topics, required this.hours});

  factory PlanSubjectAlloc.fromJson(Map<String, dynamic> json) => PlanSubjectAlloc(
        name: json['name']?.toString() ?? '',
        topics: (json['topics'] as List?)?.map((e) => e?.toString() ?? '').toList() ?? [],
        hours: (json['hours'] as num?) ?? 0,
      );
}

/// Full study plan document — `studyPlans/{planId}`.
class StudyPlan {
  final String planId;
  final String title;
  final String examType;
  final String summary;
  final int daysUntilExam;
  final List<PlanWeek> weeklyPlan;
  final Map<String, dynamic> subjectAllocation;
  final Map<String, dynamic> revisionSchedule;
  final List<dynamic> milestones;
  final String status;

  const StudyPlan({
    required this.planId,
    required this.title,
    required this.examType,
    required this.summary,
    required this.daysUntilExam,
    required this.weeklyPlan,
    required this.subjectAllocation,
    required this.revisionSchedule,
    required this.milestones,
    required this.status,
  });

  factory StudyPlan.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};

    final List<PlanWeek> weeks = [];
    if (d['weeklyPlan'] is List) {
      for (final w in d['weeklyPlan'] as List) {
        if (w is Map) {
          weeks.add(PlanWeek.fromJson(
            Map<String, dynamic>.from(w),
            fallbackWeek: weeks.length + 1,
          ));
        }
      }
    }

    return StudyPlan(
      planId: d['planId']?.toString() ?? doc.id,
      title: d['title']?.toString() ?? 'My Study Plan',
      examType: d['examType']?.toString() ?? '',
      summary: d['summary']?.toString() ?? '',
      daysUntilExam: (d['daysUntilExam'] as num?)?.toInt() ?? 0,
      weeklyPlan: weeks,
      subjectAllocation:
          d['subjectAllocation'] is Map ? Map<String, dynamic>.from(d['subjectAllocation'] as Map) : {},
      revisionSchedule:
          d['revisionSchedule'] is Map ? Map<String, dynamic>.from(d['revisionSchedule'] as Map) : {},
      milestones: d['milestones'] is List ? d['milestones'] as List : [],
      status: d['status']?.toString() ?? 'active',
    );
  }
}