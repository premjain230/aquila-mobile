/// Aquila Learning Engine — Schema versioning & constants
/// Mirrors web js/learning/schema.js — must stay identical.

// Versioning
const int learningSchemaVersion = 1;
const int onboardingVersion = 1;
const int curriculumVersion = 1;

const String learningVersionField = 'learningSchemaVersion';
const String onboardingVersionField = 'onboardingVersion';

// Mastery states — same thresholds as web masteryStateFromScore()
class MasteryState {
  static const String unseen = 'unseen';
  static const String learning = 'learning';
  static const String developing = 'developing';
  static const String proficient = 'proficient';
  static const String mastered = 'mastered';
  static const List<String> values = [unseen, learning, developing, proficient, mastered];
}

class EvidenceType {
  static const String quiz = 'quiz';
  static const String recall = 'recall';
  static const String apply = 'apply';
  static const String explain = 'explain';
  static const String revise = 'revise';
  static const String session = 'session';
  static const String diagnostic = 'diagnostic';
}

class RecommendationType {
  static const String review = 'review';
  static const String strengthen = 'strengthen';
  static const String learn = 'learn';
  static const String practice = 'practice';
  static const String revise = 'revise';
  static const String catchUp = 'catch_up';
  static const String extend = 'extend';
}

class SessionType {
  static const String learn = 'learn';
  static const String review = 'review';
  static const String practice = 'practice';
  static const String diagnostic = 'diagnostic';
  static const String revise = 'revise';
}

class SessionStatus {
  static const String active = 'active';
  static const String completed = 'completed';
  static const String abandoned = 'abandoned';
}

class ReviewResult {
  static const String again = 'again';
  static const String hard = 'hard';
  static const String good = 'good';
  static const String easy = 'easy';
}

/// Single source of truth — must match web masteryStateFromScore()
String masteryStateFromScore(double score) {
  if (score >= 0.85) return MasteryState.mastered;
  if (score >= 0.70) return MasteryState.proficient;
  if (score >= 0.40) return MasteryState.developing;
  if (score > 0) return MasteryState.learning;
  return MasteryState.unseen;
}

double clamp01(num? v) {
  if (v == null) return 0;
  final d = v.toDouble();
  if (d.isNaN) return 0;
  return d.clamp(0, 1).toDouble();
}

class Board {
  static const String cbse = 'CBSE';
  static const String icse = 'ICSE';
  static const String state = 'State';
  static const String ib = 'IB';
  static const String igcse = 'IGCSE';
  static const String other = 'Other';
  static const List<String> values = [cbse, icse, state, ib, igcse, other];
}

class Track {
  static const String school = 'school';
  static const String competitive = 'competitive';
  static const String both = 'both';
}

class GoalType {
  static const String passYear = 'pass_year';
  static const String improveSubject = 'improve_subject';
  static const String scoreTarget = 'score_target';
  static const String boardExam = 'board_exam';
  static const String competitiveExam = 'competitive_exam';
  static const String deepUnderstanding = 'deep_understanding';
  static const String finishSyllabus = 'finish_syllabus';
  static const String consistency = 'consistency';
  static const String custom = 'custom';
}

class GoalStatus {
  static const String active = 'active';
  static const String paused = 'paused';
  static const String completed = 'completed';
  static const String abandoned = 'abandoned';
}

class LearningStyle {
  static const String visual = 'visual';
  static const String auditory = 'auditory';
  static const String reading = 'reading';
  static const String practice = 'practice';
  static const String mixed = 'mixed';
}

class Priority {
  static const String high = 'high';
  static const String medium = 'medium';
  static const String low = 'low';
}

class LearningEventType {
  static const String lessonStarted = 'lesson_started';
  static const String lessonCompleted = 'lesson_completed';
  static const String questionAnswered = 'question_answered';
  static const String questionCorrect = 'question_correct';
  static const String questionIncorrect = 'question_incorrect';
  static const String quizStarted = 'quiz_started';
  static const String quizCompleted = 'quiz_completed';
  static const String assessmentCompleted = 'assessment_completed';
  static const String hintRequested = 'hint_requested';
  static const String explanationRequested = 'explanation_requested';
  static const String mistakeDetected = 'mistake_detected';
  static const String misconceptionDetected = 'misconception_detected';
  static const String topicReviewed = 'topic_reviewed';
  static const String studySessionStarted = 'study_session_started';
  static const String studySessionCompleted = 'study_session_completed';
  static const String goalCreated = 'goal_created';
  static const String goalCompleted = 'goal_completed';
  static const String onboardingStarted = 'onboarding_started';
  static const String onboardingQuestionAnswered = 'onboarding_question_answered';
  static const String onboardingAnswered = 'onboarding_answered';
  static const String onboardingCompleted = 'onboarding_completed';
  static const String diagnosticStarted = 'diagnostic_started';
  static const String diagnosticAnswered = 'diagnostic_answered';
  static const String diagnosticCompleted = 'diagnostic_completed';
  static const String reviewStarted = 'review_started';
  static const String reviewCompleted = 'review_completed';
  static const String recommendationClicked = 'recommendation_clicked';
}

class EventSource {
  static const String quiz = 'quiz';
  static const String studySession = 'study_session';
  static const String diagnostic = 'diagnostic';
  static const String chat = 'chat';
  static const String onboarding = 'onboarding';
  static const String selfReport = 'self_report';
}

bool isValidMasteryScore(dynamic v) => v is num && v >= 0 && v <= 1;
bool isValidMasteryState(String s) => MasteryState.values.contains(s);

const Map<String, double> evidenceSourceWeights = {
  'diagnostic': 1.0,
  'quiz': 0.90,
  'study_session': 0.65,
  'self_report': 0.20,
  'onboarding': 0.20,
};
double getSourceWeight(String? s) => evidenceSourceWeights[s] ?? 0;
double getHintFactor(num? h) {
  final n = (h ?? 0).toInt().clamp(0, 20);
  if (n == 0) return 1.0;
  if (n == 1) return 0.85;
  if (n == 2) return 0.70;
  if (n == 3) return 0.55;
  return 0.40;
}
double getRecencyFactor(dynamic t) {
  try {
    DateTime d;
    if (t is DateTime) d = t;
    else d = DateTime.parse(t.toString());
    final ageDays = DateTime.now().difference(d).inMilliseconds / (1000 * 60 * 60 * 24);
    if (ageDays <= 7) return 1.0;
    if (ageDays <= 30) return 0.90;
    if (ageDays <= 90) return 0.75;
    if (ageDays <= 180) return 0.60;
    return 0.45;
  } catch (_) { return 1.0; }
}
double normalizeConfidence(num? c) => c == null ? 0.5 : ((c.clamp(1, 5) - 1) / 4);

class MasteryStateV2 {
  static const String unknown = 'unknown';
  static const String emerging = 'emerging';
  static const String developing = 'developing';
  static const String proficient = 'proficient';
  static const String strong = 'strong';
}
String masteryStateV2(double score, double evidenceStrength) {
  final s = score.clamp(0, 1);
  final e = evidenceStrength.clamp(0, 1);
  if (e < 0.10) return MasteryStateV2.unknown;
  if (e < 0.35) {
    if (s < 0.30) return MasteryStateV2.emerging;
    return MasteryStateV2.developing;
  }
  if (s < 0.30) return MasteryStateV2.emerging;
  if (s < 0.50) return MasteryStateV2.developing;
  if (s < 0.70) return MasteryStateV2.proficient;
  return MasteryStateV2.strong;
}
const double masteryPrior = 0.5;
const int masteryModelVersion = 2;
