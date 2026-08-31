import 'schema.dart';

const _reasonPriority = ["overdue_review","due_review","misconception_risk","recent_mistakes","low_mastery","low_evidence","priority_goal","review_soon","stable_maintenance"];
const _urgencyMap = {"overdue":1.00,"due":0.85,"practice":0.65,"review_soon":0.45,"not_ready":0.25,"stable":0.05};
const _explanations = {
  "overdue_review":"This topic is overdue for review.",
  "due_review":"This topic is due for review.",
  "misconception_risk":"Review this concept — repeated errors suggest a misconception.",
  "recent_mistakes":"Practice this concept because recent answers show difficulty.",
  "low_mastery":"Practice this concept — mastery is still low despite sufficient evidence.",
  "low_evidence":"Learn this concept because Aquila does not have enough evidence yet.",
  "priority_goal":"Priority for your current goals.",
  "review_soon":"Review soon to keep this fresh.",
  "stable_maintenance":"Stable — no urgent action needed.",
};

double _clamp01(num v)=> v.clamp(0,1).toDouble();

double _goalRelevance(Map<String,dynamic> concept, Map<String,dynamic>? profile){
  final subjects = (profile?['subjects'] is List ? (profile!['subjects'] as List).map((e)=>e.toString().toLowerCase()).toList() : <String>[]);
  final priority = profile?['prioritySubject']?.toString().toLowerCase() ?? (subjects.isNotEmpty ? subjects.first : null);
  final subj = (concept['subject']??concept['subjectId']??"").toString().toLowerCase();
  final topic = (concept['topic']??"").toString().toLowerCase();
  if(priority!=null && subj==priority) return 1.0;
  final goals = profile?['goals'] is List ? profile!['goals'] as List : [];
  for(final g in goals){
    final gs = (g is Map ? (g['subject']??g['title']??"") : g.toString()).toLowerCase();
    if(gs.isNotEmpty && (subj.contains(gs) || gs.contains(subj) || topic.contains(gs))) return 0.8;
  }
  if(subjects.contains(subj)) return 0.5;
  return 0.2;
}

String _chooseAction({required double masteryScore, required double evidenceStrength, required String reviewState, required int recentIncorrectCount}){
  if(evidenceStrength < 0.10) return "diagnostic";
  if(evidenceStrength < 0.35) return "learn";
  if(reviewState=="overdue" || reviewState=="due") return "review";
  if(masteryScore < 0.45 || recentIncorrectCount >=2) return "practice";
  if(reviewState=="review_soon" || reviewState=="practice") return "practice";
  return "review";
}

String _chooseReason({required double masteryScore, required double evidenceStrength, required String reviewState, required int recentIncorrectCount, required bool hasMisconception, required double goalRelevance}){
  if(reviewState=="overdue") return "overdue_review";
  if(reviewState=="due") return "due_review";
  if(hasMisconception) return "misconception_risk";
  if(recentIncorrectCount>=2) return "recent_mistakes";
  if(evidenceStrength>=0.35 && masteryScore<0.45) return "low_mastery";
  if(evidenceStrength<0.35) return "low_evidence";
  if(goalRelevance>=0.8) return "priority_goal";
  if(reviewState=="review_soon") return "review_soon";
  return "stable_maintenance";
}

List<Map<String,dynamic>> getRecommendations({Map<String,dynamic> masteryMap={}, Map<String,dynamic> reviewsMap={}, List<dynamic> misconceptions=[], Map<String,dynamic>? profile, int limit=5}){
  limit = limit.clamp(1,10);
  final misconceptionSet = misconceptions.where((m)=> m is Map && m['resolved']!=true).map((m)=> (m as Map)['conceptId'].toString()).toSet();
  final conceptIds = <String>{...masteryMap.keys, ...reviewsMap.keys, ...misconceptionSet};
  if(conceptIds.isEmpty && profile?['subjects'] is List){
    for(final s in (profile!['subjects'] as List)){ final cid = s.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), "_"); if(cid.isNotEmpty) conceptIds.add(cid); }
  }
  for(final wt in (profile?['weakTopics'] is List ? profile!['weakTopics'] as List : [])){ final cid=wt.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), "_"); if(cid.isNotEmpty) conceptIds.add(cid); }

  final candidates=<Map<String,dynamic>>[];
  for(final cid in conceptIds){
    final mastery = masteryMap[cid] is Map ? Map<String,dynamic>.from(masteryMap[cid]) : {'conceptId':cid,'subject':cid.split('_').first,'topic':cid,'masteryScore':0.5,'evidenceStrength':0.0,'recentIncorrectCount':0};
    final review = reviewsMap[cid] is Map ? Map<String,dynamic>.from(reviewsMap[cid]) : {'reviewState':'not_ready','priority':0};
    final subject = (mastery['subject']??review['subject']??cid.split('_').first).toString();
    final topic = (mastery['topic']??review['topic']??cid).toString();
    final masteryScore = _clamp01((mastery['masteryScore'] as num?)??0.5);
    final evidenceStrength = _clamp01((mastery['evidenceStrength'] as num?)?? (review['evidenceStrength'] as num?)??0);
    final recentIncorrectCount = (mastery['recentIncorrectCount'] as num? ?? review['recentIncorrectCount'] as num? ?? 0).toInt();
    final reviewState = (review['reviewState']??'not_ready').toString();
    final reviewPriority = _clamp01((review['priority'] as num?)??0);
    final hasMisconception = misconceptionSet.contains(cid);
    final goalRelevance = _goalRelevance({'subject':subject,'topic':topic,'conceptId':cid}, profile);
    final urgency = _urgencyMap[reviewState] ?? 0.25;
    final weakness = 1 - masteryScore;
    final evidenceGap = 1 - evidenceStrength;
    double misconceptionRisk = (recentIncorrectCount/5).clamp(0,1).toDouble();
    if(hasMisconception) misconceptionRisk = (misconceptionRisk+0.3).clamp(0,1).toDouble();
    final score = (urgency*0.25 + weakness*0.25 + evidenceGap*0.15 + misconceptionRisk*0.15 + goalRelevance*0.10 + reviewPriority*0.10).clamp(0,1).toDouble();
    final action = _chooseAction(masteryScore:masteryScore, evidenceStrength:evidenceStrength, reviewState:reviewState, recentIncorrectCount:recentIncorrectCount);
    final reason = _chooseReason(masteryScore:masteryScore, evidenceStrength:evidenceStrength, reviewState:reviewState, recentIncorrectCount:recentIncorrectCount, hasMisconception:hasMisconception, goalRelevance:goalRelevance);
    candidates.add({
      'conceptId':cid,'subject':subject,'topic':topic,'action':action,'score':score,'reason':reason,'explanation':_explanations[reason]??_explanations['low_evidence']!,
      'masteryScore':masteryScore,'evidenceStrength':evidenceStrength,'reviewState':reviewState,'reviewPriority':reviewPriority,'recentIncorrectCount':recentIncorrectCount,'misconceptionRisk':misconceptionRisk,'goalRelevance':goalRelevance,'urgency':urgency,'generatedAt':DateTime.now().toIso8601String()
    });
  }
  candidates.sort((a,b){
    if(b['score']!=a['score']) return (b['score'] as double).compareTo(a['score'] as double);
    if(b['urgency']!=a['urgency']) return (b['urgency'] as double).compareTo(a['urgency'] as double);
    if(a['masteryScore']!=b['masteryScore']) return (a['masteryScore'] as double).compareTo(b['masteryScore'] as double);
    if(a['evidenceStrength']!=b['evidenceStrength']) return (a['evidenceStrength'] as double).compareTo(b['evidenceStrength'] as double);
    if(b['recentIncorrectCount']!=a['recentIncorrectCount']) return (b['recentIncorrectCount'] as int).compareTo(a['recentIncorrectCount'] as int);
    return (a['conceptId'] as String).compareTo(b['conceptId'] as String);
  });
  final perSubject=<String,int>{};
  final diversified=<Map<String,dynamic>>[];
  for(final c in candidates){
    final subj=c['subject'].toString().toLowerCase();
    perSubject[subj]=(perSubject[subj]??0);
    if((perSubject[subj]??0) <3){ diversified.add(c); perSubject[subj]=perSubject[subj]!+1; }
    if(diversified.length>=limit) break;
  }
  return diversified.take(limit).toList();
}

Map<String,dynamic>? getNextBestAction({Map<String,dynamic> masteryMap={}, Map<String,dynamic> reviewsMap={}, List<dynamic> misconceptions=[], Map<String,dynamic>? profile}){
  final recs=getRecommendations(masteryMap:masteryMap, reviewsMap:reviewsMap, misconceptions:misconceptions, profile:profile, limit:1);
  return recs.isEmpty? null : recs.first;
}
