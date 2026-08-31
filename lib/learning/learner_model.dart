/// Learner Model orchestrator — parity with web js/learning/learner-model.js
library learner_model;

export 'schema.dart';
export 'contracts.dart';
export 'onboarding.dart';
export 'evidence.dart';
export 'misconceptions.dart';
export 'history.dart';
export 'ai_context.dart';

import 'contracts.dart';

Map<String, dynamic> migrateLegacyProfile(Map<String, dynamic>? raw) {
  if (raw == null) return {'academic': AcademicContext().toMap(), 'preferences': {}};
  final academic = AcademicContext(
    country: raw['academic']?['country']?.toString() ?? raw['country']?.toString(),
    state: raw['academic']?['state']?.toString() ?? raw['state']?.toString(),
    board: raw['academic']?['board']?.toString() ?? raw['board']?.toString() ?? raw['exam']?.toString(),
    grade: raw['academic']?['grade']?.toString() ?? raw['grade']?.toString() ?? raw['class']?.toString(),
    academicYear: raw['academic']?['academicYear']?.toString() ?? raw['academicYear']?.toString(),
    track: raw['academic']?['track']?.toString() ?? raw['track']?.toString(),
  ).toMap();
  return {...raw, 'academic': academic, 'learningSchemaVersion': raw['learningSchemaVersion'] ?? 1};
}
