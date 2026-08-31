import 'schema.dart';

const int reviewModelVersion = 1;
const retentionConfig = {
  'minIntervalDays': 1,
  'maxIntervalDays': 30,
};

class ReviewState {
  static const String notReady = 'not_ready';
  static const String practice = 'practice';
  static const String reviewSoon = 'review_soon';
  static const String due = 'due';
  static const String overdue = 'overdue';
  static const String stable = 'stable';
}

int _baseInterval(double mastery){
  if(mastery <=0.30) return 1;
  if(mastery <=0.45) return 2;
  if(mastery <=0.60) return 3;
  if(mastery <=0.75) return 7;
  if(mastery <=0.85) return 14;
  return 21;
}

int calculateInterval({required double masteryScore, required double evidenceStrength, int recentIncorrectCount=0, String? lastOutcome, int reviewCount=0}){
  int interval = _baseInterval(masteryScore.clamp(0,1));
  final es = evidenceStrength.clamp(0,1);
  final factor = 0.6 + 0.4*es;
  interval = (interval * factor).round();
  if(recentIncorrectCount>=3) interval = interval.clamp(1,2);
  else if(recentIncorrectCount>=2) interval = interval.clamp(1,3);
  if(lastOutcome=='correct') interval = (interval*1.6).round()+1;
  else if(lastOutcome=='incorrect') interval = (interval*0.5).round();
  if(interval<1) interval=1;
  if(interval>30) interval=30;
  return interval;
}

double calculateRetentionScore({required double masteryScore, required double evidenceStrength, int attempts=0, int recentIncorrectCount=0, dynamic lastReviewed, required dynamic now}){
  final m = masteryScore.clamp(0,1);
  final e = evidenceStrength.clamp(0,1);
  final base = m*(0.6+0.4*e);
  final bonus = attempts>=5 ? 0.05 : 0.0;
  final penalty = (recentIncorrectCount*0.08).clamp(0,0.3);
  final recency = getRecencyFactor(lastReviewed ?? now);
  final raw = (base+bonus-penalty)*(0.7+0.3*recency);
  return raw.clamp(0,1).toDouble();
}

double calculatePriority({required double masteryScore, required double evidenceStrength, int recentIncorrectCount=0, dynamic nextReviewAt, dynamic lastReviewed, required dynamic now, double goalRelevance=0}){
  DateTime parse(dynamic v){ if(v is DateTime) return v; return DateTime.tryParse(v.toString()) ?? DateTime.now(); }
  final overdueDays = nextReviewAt==null?0: (DateTime.now().difference(parse(nextReviewAt)).inMilliseconds/(1000*60*60*24)).clamp(0, 1000).toDouble();
  final overdueFactor = (overdueDays/14).clamp(0,1);
  final weakness = (1-masteryScore.clamp(0,1));
  final evidenceWeak = (1-evidenceStrength.clamp(0,1));
  final recent = (recentIncorrectCount/5).clamp(0,1);
  return (overdueFactor*0.30 + weakness*0.30 + evidenceWeak*0.15 + recent*0.20 + goalRelevance*0.05).clamp(0,1).toDouble();
}

String deriveReviewState({required double masteryScore, required double evidenceStrength, required int intervalDays, dynamic nextReviewAt, dynamic lastReviewed, required dynamic now, int recentIncorrectCount=0, int reviewCount=0}){
  final es = evidenceStrength.clamp(0,1);
  if(es<0.10) return ReviewState.notReady;
  if(masteryScore.clamp(0,1)<0.45) return ReviewState.practice;
  if(nextReviewAt==null) return ReviewState.reviewSoon;
  final nowMs = (now is DateTime? now : DateTime.tryParse(now.toString()) ?? DateTime.now()).millisecondsSinceEpoch;
  final nextMs = DateTime.tryParse(nextReviewAt.toString())?.millisecondsSinceEpoch ?? nowMs;
  final diffDays = (nextMs - nowMs)/(1000*60*60*24);
  if(diffDays <= -3) return ReviewState.overdue;
  if(diffDays <= 0) return ReviewState.due;
  if(diffDays <= 2) return ReviewState.reviewSoon;
  if(masteryScore>=0.75 && es>=0.70 && reviewCount>=2 && diffDays>7) return ReviewState.stable;
  return ReviewState.reviewSoon;
}
