/// Aquila Learning Engine — Shared Data Contracts (Dart)
/// Mirrors web js/learning/contracts.js. No drift allowed.

import 'schema.dart';

// ---------------------------------------------------------------------------
// UserLearningProfile
// ---------------------------------------------------------------------------
class UserLearningProfile {
  final String uid;
  final int learningSchemaVersion;
  final int onboardingVersion;
  final String displayName;
  final String exam;
  final List<String> subjects;
  final List<String> goals;
  final String? targetScore;
  final String? examDate;
  final int dailyHours;
  final List<String> weakTopics;
  final bool onboardingComplete;
  final String? preferredStyle;
  final String createdAt;
  final String updatedAt;

  const UserLearningProfile({
    required this.uid,
    this.learningSchemaVersion = 1,
    this.onboardingVersion = 1,
    this.displayName = '',
    this.exam = '',
    this.subjects = const [],
    this.goals = const [],
    this.targetScore,
    this.examDate,
    this.dailyHours = 4,
    this.weakTopics = const [],
    this.onboardingComplete = false,
    this.preferredStyle,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserLearningProfile.create(String uid, {Map<String, dynamic>? overrides}) {
    final now = DateTime.now().toIso8601String();
    final o = overrides ?? {};
    return UserLearningProfile(
      uid: uid,
      displayName: o['displayName']?.toString() ?? '',
      exam: o['exam']?.toString() ?? '',
      subjects: (o['subjects'] is List) ? (o['subjects'] as List).map((e) => e.toString()).take(10).toList() : [],
      goals: (o['goals'] is List) ? (o['goals'] as List).map((e) => e.toString()).take(10).toList() : [],
      targetScore: o['targetScore']?.toString(),
      examDate: o['examDate']?.toString(),
      dailyHours: (o['dailyHours'] is num) ? (o['dailyHours'] as num).toInt().clamp(1, 18) : 4,
      weakTopics: (o['weakTopics'] is List) ? (o['weakTopics'] as List).map((e) => e.toString()).take(20).toList() : [],
      onboardingComplete: o['onboardingComplete'] == true,
      preferredStyle: o['preferredStyle']?.toString(),
      createdAt: o['createdAt']?.toString() ?? now,
      updatedAt: o['updatedAt']?.toString() ?? now,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'learningSchemaVersion': learningSchemaVersion,
        'onboardingVersion': onboardingVersion,
        'displayName': displayName,
        'exam': exam,
        'subjects': subjects,
        'goals': goals,
        'targetScore': targetScore,
        'examDate': examDate,
        'dailyHours': dailyHours,
        'weakTopics': weakTopics,
        'onboardingComplete': onboardingComplete,
        'preferredStyle': preferredStyle,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory UserLearningProfile.fromMap(Map<String, dynamic> m) => UserLearningProfile(
        uid: m['uid']?.toString() ?? '',
        displayName: m['displayName']?.toString() ?? '',
        exam: m['exam']?.toString() ?? '',
        subjects: (m['subjects'] is List) ? (m['subjects'] as List).map((e) => e.toString()).toList() : [],
        goals: (m['goals'] is List) ? (m['goals'] as List).map((e) => e.toString()).toList() : [],
        targetScore: m['targetScore']?.toString(),
        examDate: m['examDate']?.toString(),
        dailyHours: (m['dailyHours'] as num?)?.toInt() ?? 4,
        weakTopics: (m['weakTopics'] is List) ? (m['weakTopics'] as List).map((e) => e.toString()).toList() : [],
        onboardingComplete: m['onboardingComplete'] == true,
        preferredStyle: m['preferredStyle']?.toString(),
        createdAt: m['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
        updatedAt: m['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
      );
}

// ---------------------------------------------------------------------------
// StudentModel
// ---------------------------------------------------------------------------
class StudentModel {
  final String uid;
  final int learningSchemaVersion;
  final Map<String, double> conceptMastery;
  final Map<String, double> confidence;
  final double learningVelocity;
  final List<double> confidenceHistory;
  final List<Map<String, dynamic>> misconceptions;
  final int totalInteractions;
  final int sessionCount;
  final String createdAt;
  final String updatedAt;

  const StudentModel({
    required this.uid,
    this.learningSchemaVersion = 1,
    this.conceptMastery = const {},
    this.confidence = const {},
    this.learningVelocity = 0,
    this.confidenceHistory = const [],
    this.misconceptions = const [],
    this.totalInteractions = 0,
    this.sessionCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentModel.create(String uid, {Map<String, dynamic>? overrides}) {
    final now = DateTime.now().toIso8601String();
    final o = overrides ?? {};
    Map<String, double> mastery = {};
    if (o['conceptMastery'] is Map) {
      (o['conceptMastery'] as Map).forEach((k, v) => mastery[k.toString()] = clamp01(v as num?));
    }
    return StudentModel(
      uid: uid,
      conceptMastery: mastery,
      confidence: {},
      learningVelocity: clamp01(o['learningVelocity'] as num?),
      confidenceHistory: (o['confidenceHistory'] is List) ? (o['confidenceHistory'] as List).map((e) => clamp01(e as num?)).toList() : [],
      misconceptions: (o['misconceptions'] is List) ? List<Map<String, dynamic>>.from(o['misconceptions'] as List) : [],
      totalInteractions: (o['totalInteractions'] as num?)?.toInt() ?? 0,
      sessionCount: (o['sessionCount'] as num?)?.toInt() ?? 0,
      createdAt: o['createdAt']?.toString() ?? now,
      updatedAt: o['updatedAt']?.toString() ?? now,
    );
  }

  List<MapEntry<String, double>> weakestConcepts({int limit = 5}) {
    final entries = conceptMastery.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return entries.take(limit).toList();
  }
}

// ---------------------------------------------------------------------------
// Concept / Curriculum
// ---------------------------------------------------------------------------
class Concept {
  final String conceptId;
  final String subject;
  final String topic;
  final String name;
  final String description;
  final List<String> prerequisites;
  final double difficulty;
  final int estimatedMinutes;
  final List<String> tags;

  const Concept({
    required this.conceptId,
    required this.subject,
    required this.topic,
    required this.name,
    this.description = '',
    this.prerequisites = const [],
    this.difficulty = 0.5,
    this.estimatedMinutes = 15,
    this.tags = const [],
  });

  Map<String, dynamic> toMap() => {
        'conceptId': conceptId,
        'subject': subject,
        'topic': topic,
        'name': name,
        'description': description,
        'prerequisites': prerequisites,
        'difficulty': difficulty,
        'estimatedMinutes': estimatedMinutes,
        'tags': tags,
      };
}

// ---------------------------------------------------------------------------
// Mastery
// ---------------------------------------------------------------------------
class Mastery {
  final String uid;
  final String conceptId;
  final double masteryScore;
  final String masteryState;
  final int reviewCount;
  final String? lastReviewed;
  final String? nextReviewDue;
  final List<Map<String, dynamic>> evidence;
  final String updatedAt;
  final int learningSchemaVersion;
  // Prompt 2 additions — confidence separated, evidence counters
  final int attempts;
  final int correct;
  final double accuracy;
  final double confidenceScore;
  final String subject;
  final double evidenceStrength;
  final int masteryModelVersion;

  const Mastery({
    required this.uid,
    required this.conceptId,
    required this.masteryScore,
    required this.masteryState,
    this.reviewCount = 0,
    this.lastReviewed,
    this.nextReviewDue,
    this.evidence = const [],
    required this.updatedAt,
    this.learningSchemaVersion = 1,
    this.attempts = 0,
    this.correct = 0,
    this.accuracy = 0,
    this.confidenceScore = 0,
    this.subject = '',
    this.evidenceStrength = 0,
    this.masteryModelVersion = 2,
  });

  factory Mastery.create(String uid, String conceptId, {Map<String, dynamic>? overrides}) {
    final o = overrides ?? {};
    final score = clamp01(o['masteryScore'] as num?);
    return Mastery(
      uid: uid,
      conceptId: conceptId,
      masteryScore: score,
      masteryState: o['masteryState']?.toString() ?? masteryStateFromScore(score),
      reviewCount: (o['reviewCount'] as num?)?.toInt() ?? 0,
      lastReviewed: o['lastReviewed']?.toString(),
      nextReviewDue: o['nextReviewDue']?.toString(),
      evidence: (o['evidence'] is List) ? List<Map<String, dynamic>>.from(o['evidence'] as List) : [],
      updatedAt: o['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
      attempts: (o['attempts'] as num?)?.toInt() ?? (o['reviewCount'] as num?)?.toInt() ?? 0,
      correct: (o['correct'] as num?)?.toInt() ?? 0,
      accuracy: (o['accuracy'] as num?)?.toDouble() ?? 0,
      confidenceScore: clamp01(o['confidenceScore'] as num?),
      subject: o['subject']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'conceptId': conceptId,
        'masteryScore': masteryScore,
        'masteryState': masteryState,
        'reviewCount': reviewCount,
        'lastReviewed': lastReviewed,
        'nextReviewDue': nextReviewDue,
        'evidence': evidence,
        'updatedAt': updatedAt,
        'learningSchemaVersion': learningSchemaVersion,
        'attempts': attempts,
        'correct': correct,
        'evidenceStrength': evidenceStrength,
        'masteryModelVersion': masteryModelVersion,
        'accuracy': accuracy,
        'confidenceScore': confidenceScore,
        'subject': subject,
      };
}

// ---------------------------------------------------------------------------
// LearningSession
// ---------------------------------------------------------------------------
class LearningSession {
  final String sessionId;
  final String uid;
  final String type;
  final String subject;
  final String topic;
  final List<String> conceptIds;
  final int durationMinutes;
  final int timeFocusedSeconds;
  final String status;
  final String? goal;
  final Map<String, dynamic>? plan;
  final String startedAt;
  final String? completedAt;
  final String updatedAt;
  final int learningSchemaVersion;

  const LearningSession({
    required this.sessionId,
    required this.uid,
    required this.type,
    required this.subject,
    required this.topic,
    this.conceptIds = const [],
    required this.durationMinutes,
    this.timeFocusedSeconds = 0,
    required this.status,
    this.goal,
    this.plan,
    required this.startedAt,
    this.completedAt,
    required this.updatedAt,
    this.learningSchemaVersion = 1,
  });
}

// ---------------------------------------------------------------------------
// Recommendation
// ---------------------------------------------------------------------------
class Recommendation {
  final String recommendationId;
  final String type;
  final String priority;
  final String title;
  final String description;
  final String? conceptId;
  final String? subject;
  final String? topic;
  final String actionLabel;
  final Map<String, dynamic> meta;
  final String generatedAt;
  final int learningSchemaVersion;

  const Recommendation({
    required this.recommendationId,
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    this.conceptId,
    this.subject,
    this.topic,
    required this.actionLabel,
    this.meta = const {},
    required this.generatedAt,
    this.learningSchemaVersion = 1,
  });
}

// ---------------------------------------------------------------------------
// LearningPlan
// ---------------------------------------------------------------------------
class LearningPlan {
  final String planId;
  final String uid;
  final String title;
  final String examType;
  final String status;
  final int daysUntilExam;
  final Map<String, dynamic> subjectAllocation;
  final Map<String, dynamic> revisionSchedule;
  final List<dynamic> milestones;
  final List<dynamic> weeklyPlan;
  final String createdAt;
  final String updatedAt;
  final int learningSchemaVersion;

  const LearningPlan({
    required this.planId,
    required this.uid,
    required this.title,
    required this.examType,
    required this.status,
    required this.daysUntilExam,
    this.subjectAllocation = const {},
    this.revisionSchedule = const {},
    this.milestones = const [],
    this.weeklyPlan = const [],
    required this.createdAt,
    required this.updatedAt,
    this.learningSchemaVersion = 1,
  });
}

// ---------------------------------------------------------------------------
// AcademicContext  (Prompt 2)
// ---------------------------------------------------------------------------
class AcademicContext {
  final String? country;
  final String? state;
  final String? board;
  final String? grade;
  final String? curriculumId;
  final String? academicYear;
  final String? track;
  final String? schoolName;
  const AcademicContext({this.country, this.state, this.board, this.grade, this.curriculumId, this.academicYear, this.track, this.schoolName});
  Map<String, dynamic> toMap() => {'country': country, 'state': state, 'board': board, 'grade': grade, 'curriculumId': curriculumId, 'academicYear': academicYear, 'track': track, 'schoolName': schoolName};
  factory AcademicContext.fromMap(Map<String, dynamic> m) => AcademicContext(country: m['country']?.toString(), state: m['state']?.toString(), board: m['board']?.toString(), grade: m['grade']?.toString(), curriculumId: m['curriculumId']?.toString(), academicYear: m['academicYear']?.toString(), track: m['track']?.toString(), schoolName: m['schoolName']?.toString());
}

class Goal {
  final String goalId;
  final String uid;
  final String type;
  final String title;
  final String? target;
  final String? subject;
  final String priority;
  final double importance;
  final Map<String, dynamic> timeline;
  final String status;
  final String createdAt;
  final String updatedAt;
  const Goal({required this.goalId, required this.uid, required this.type, required this.title, this.target, this.subject, required this.priority, this.importance = 0.5, this.timeline = const {}, required this.status, required this.createdAt, required this.updatedAt});
  Map<String, dynamic> toMap() => {'goalId': goalId, 'uid': uid, 'type': type, 'title': title, 'target': target, 'subject': subject, 'priority': priority, 'importance': importance, 'timeline': timeline, 'status': status, 'createdAt': createdAt, 'updatedAt': updatedAt, 'learningSchemaVersion': 1};
}

class LearningEvent {
  final String eventId;
  final String uid;
  final String type;
  final String? conceptId;
  final String? subject;
  final String? topic;
  final String? source;
  final String? sessionId;
  final String? questionId;
  final Map<String, dynamic> payload;
  final int? confidence;
  final String createdAt;
  const LearningEvent({required this.eventId, required this.uid, required this.type, this.conceptId, this.subject, this.topic, this.source, this.sessionId, this.questionId, this.payload = const {}, this.confidence, required this.createdAt});
  Map<String, dynamic> toMap() => {'eventId': eventId, 'uid': uid, 'type': type, 'conceptId': conceptId, 'subject': subject, 'topic': topic, 'source': source, 'sessionId': sessionId, 'questionId': questionId, 'payload': payload, 'confidence': confidence, 'createdAt': createdAt, 'learningSchemaVersion': 1};
}

class Misconception {
  final String misconceptionId;
  final String uid;
  final String conceptId;
  final String concept;
  final String misconception;
  final String? correction;
  final List<Map<String, dynamic>> evidence;
  final double confidence;
  final String firstDetected;
  final String lastDetected;
  final bool resolved;
  final String? resolvedAt;
  const Misconception({required this.misconceptionId, required this.uid, required this.conceptId, required this.concept, required this.misconception, this.correction, this.evidence = const [], this.confidence = 0.4, required this.firstDetected, required this.lastDetected, this.resolved = false, this.resolvedAt});
}

class SubjectState {
  final String subjectId;
  final double mastery;
  final double confidence;
  final List<String> weakAreas;
  final List<String> strongAreas;
  final double gap;
  const SubjectState({required this.subjectId, required this.mastery, required this.confidence, this.weakAreas = const [], this.strongAreas = const [], this.gap = 0});
  Map<String, dynamic> toMap() => {'subjectId': subjectId, 'mastery': mastery, 'confidence': confidence, 'weakAreas': weakAreas, 'strongAreas': strongAreas, 'gap': gap};
}

class LearnerSnapshot {
  final String uid;
  final AcademicContext academic;
  final List<Goal> goals;
  final Map<String, SubjectState> subjectStates;
  final List<Misconception> activeMisconceptions;
  final List<LearningEvent> recentEvents;
  final Map<String, dynamic> progress;
  final String snapshotAt;
  final Map<String, dynamic> reviewStats;
  final Map<String, dynamic> subjectReviewNeeds;
  const LearnerSnapshot({required this.uid, required this.academic, this.goals = const [], this.subjectStates = const {}, this.activeMisconceptions = const [], this.recentEvents = const [], this.progress = const {}, required this.snapshotAt, this.reviewStats = const {}, this.subjectReviewNeeds = const {}});
}



// ---------------------------------------------------------------------------
// ReviewItem
// ---------------------------------------------------------------------------
class ReviewItem {
  final String uid;
  final String conceptId;
  final String subject;
  final String topic;
  final int intervalDays;
  final double easeFactor;
  final int repetitions;
  final String? lastReviewed;
  final String? nextReviewDue;
  final String? lastResult;
  final int learningSchemaVersion;

  const ReviewItem({
    required this.uid,
    required this.conceptId,
    this.subject = '',
    this.topic = '',
    this.intervalDays = 0,
    this.easeFactor = 2.5,
    this.repetitions = 0,
    this.lastReviewed,
    this.nextReviewDue,
    this.lastResult,
    this.learningSchemaVersion = 1,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'conceptId': conceptId,
        'subject': subject,
        'topic': topic,
        'intervalDays': intervalDays,
        'easeFactor': easeFactor,
        'repetitions': repetitions,
        'lastReviewed': lastReviewed,
        'nextReviewDue': nextReviewDue,
        'lastResult': lastResult,
        'learningSchemaVersion': learningSchemaVersion,
      };
}
