library onboarding;

import 'schema.dart';

class OnboardingQuestion {
  final String id;
  final int tier;
  final String field;
  final String question;
  final String input;
  final List<String>? options;
  final String? optionsFrom;
  final bool required;
  final String? Function(dynamic answer, Map<String, dynamic> all)? next;

  const OnboardingQuestion({
    required this.id,
    required this.tier,
    required this.field,
    required this.question,
    required this.input,
    this.options,
    this.optionsFrom,
    this.required = false,
    this.next,
  });
}

final List<OnboardingQuestion> onboardingQuestions = [
  OnboardingQuestion(id: 'grade', tier: 0, field: 'academic.grade', question: 'Which class / grade are you in?', input: 'single', options: const ['6','7','8','9','10','11','12','UG1','UG2','UG3','Other'], required: true, next: (a, all) => 'board'),
  OnboardingQuestion(id: 'board', tier: 0, field: 'academic.board', question: 'Which board / curriculum?', input: 'single', options: const ['CBSE','ICSE','State','IB','IGCSE','Other','State (specify)'], required: true, next: (a, all) => 'academicYear'),
  OnboardingQuestion(id: 'academicYear', tier: 0, field: 'academic.academicYear', question: 'Academic year?', input: 'single', options: const ['2024-25','2025-26','2026-27'], next: (a, all) => 'country'),
  OnboardingQuestion(id: 'country', tier: 0, field: 'academic.country', question: 'Country?', input: 'single', options: const ['IN','Other'], next: (a, all) => 'track'),
  OnboardingQuestion(id: 'track', tier: 1, field: 'academic.track', question: 'What are you preparing for?', input: 'single', options: const ['school','competitive','both'], required: true, next: (a, all) => a == 'competitive' ? 'competitiveExam' : 'subjects'),
  OnboardingQuestion(id: 'competitiveExam', tier: 1, field: 'goals.competitiveExam', question: 'Which competitive exam?', input: 'single', options: const ['JEE Main','JEE Advanced','NEET','UPSC','Olympiad','Other'], next: (a, all) => 'subjects'),
  OnboardingQuestion(id: 'subjects', tier: 1, field: 'subjects', question: 'Which subjects are you studying?', input: 'multi', options: const ['Mathematics','Physics','Chemistry','Biology','History','Geography','English','Other'], required: true, next: (a, all) => 'goals'),
  OnboardingQuestion(id: 'goals', tier: 1, field: 'goals', question: 'What are you trying to achieve?', input: 'multi', options: const ['Pass the year','Improve a subject','Score 90%+','Board exam','Competitive exam','Deep understanding','Finish syllabus','Consistency'], required: true, next: (a, all) => 'prioritySubject'),
  OnboardingQuestion(id: 'prioritySubject', tier: 1, field: 'prioritySubject', question: 'Which subject should we prioritize first?', input: 'single', required: true, next: (a, all) => 'dailyHours'),
  OnboardingQuestion(id: 'dailyHours', tier: 1, field: 'dailyHours', question: 'Hours per day you can study?', input: 'range', required: true, next: (a, all) => 'difficultSubjects'),
  OnboardingQuestion(id: 'difficultSubjects', tier: 2, field: 'weakTopics', question: 'Which subjects feel most difficult?', input: 'multi', next: (a, all) => (a is List && a.length > 1) ? 'priorityDifficult' : 'confidentTopics'),
  OnboardingQuestion(id: 'priorityDifficult', tier: 2, field: 'weakTopics.priority', question: 'Pick the one to tackle first.', input: 'single', next: (a, all) => 'confidentTopics'),
  OnboardingQuestion(id: 'confidentTopics', tier: 2, field: 'confidentTopics', question: 'Topics you feel confident about? (optional)', input: 'free', next: (a, all) => 'examDate'),
  OnboardingQuestion(id: 'examDate', tier: 2, field: 'examDate', question: 'When is your next big exam?', input: 'free', next: (a, all) => 'learningStyle'),
  OnboardingQuestion(id: 'learningStyle', tier: 2, field: 'preferences.preferredStyle', question: 'How do you prefer to learn?', input: 'single', options: const ['visual','auditory','reading','practice','mixed'], next: (a, all) => 'studyBehavior'),
  OnboardingQuestion(id: 'studyBehavior', tier: 3, field: 'preferences.studyBehavior', question: 'Where do you usually get stuck?', input: 'multi', options: const ['Understanding concepts','Remembering','Solving problems','Time management','Staying consistent'], next: (a, all) => null),
];

final Map<String, OnboardingQuestion> _byId = {for (final q in onboardingQuestions) q.id: q};

OnboardingQuestion? getNextOnboardingQuestion(String? currentId, Map<String, dynamic> answers) {
  if (currentId == null || !_byId.containsKey(currentId)) return _byId['grade'];
  final cur = _byId[currentId]!;
  final ans = answers[cur.field] ?? answers[cur.id];
  final nextId = cur.next?.call(ans, answers);
  if (nextId == null) return null;
  return _byId[nextId];
}

Map<String, dynamic> answersToProfilePatch(Map<String, dynamic> answers) {
  final academic = <String, dynamic>{};
  if (answers['academic.grade'] != null || answers['grade'] != null) academic['grade'] = answers['academic.grade'] ?? answers['grade'];
  if (answers['academic.board'] != null || answers['board'] != null) academic['board'] = answers['academic.board'] ?? answers['board'];
  if (answers['academic.academicYear'] != null) academic['academicYear'] = answers['academic.academicYear'];
  if (answers['academic.country'] != null) academic['country'] = answers['academic.country'];
  if (answers['academic.track'] != null) academic['track'] = answers['academic.track'];
  return {
    'academic': academic,
    'subjects': answers['subjects'] ?? [],
    'dailyHours': answers['dailyHours'] ?? 4,
    'weakTopics': answers['weakTopics'] ?? [],
    'examDate': answers['examDate'],
    'preferences': {'preferredStyle': answers['preferences.preferredStyle'] ?? answers['learningStyle']},
  };
}
