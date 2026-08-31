import 'package:cloud_firestore/cloud_firestore.dart';
import 'diagnostic_bank.dart';
import 'evidence.dart';

const diagnosticConfig = {'minQuestions':8,'maxQuestions':15,'defaultTarget':12};

String toConceptId(String? s, String? t){
  String c(String? x)=> (x??"").toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), "_").replaceAll(RegExp(r'^_+|_+$'), "");
  final a=c(s), b=c(t);
  return b.isNotEmpty ? "${a}_$b" : a;
}

List<String> prioritizeConcepts({Map<String,dynamic>? profile, Map<String, dynamic>? masteryMap, List<dynamic>? misconceptions, Map<String,dynamic>? scope}){
  final subjects = scope?['subject']!=null ? [scope!['subject'].toString()] : (profile?['subjects'] is List ? (profile!['subjects'] as List).map((e)=>e.toString()).toList() : ["Mathematics"]);
  final candidates = diagnosticBank.where((q){
    if(scope?['topic']!=null && q['topic']!=scope!['topic']) return false;
    if(scope?['subject']!=null && q['subject']!=scope!['subject']) return false;
    if(!subjects.contains(q['subject'])) return false;
    return true;
  }).toList();
  final uniq = {...candidates.map((c)=>c['conceptId'].toString())}.toList();
  // simple priority: no evidence first
  uniq.sort((a,b){
    final ma = masteryMap?[a]; final mb = masteryMap?[b];
    final hasA = ma!=null && (ma['attempts']??0)>0;
    final hasB = mb!=null && (mb['attempts']??0)>0;
    if(hasA!=hasB) return hasA?1:-1;
    return 0;
  });
  return uniq;
}

List<Map<String,dynamic>> pickQuestions({required List<String> conceptOrder, required int count}){
  final byConcept = <String,List<Map<String,dynamic>>>{};
  for(final q in diagnosticBank){ (byConcept[q['conceptId'].toString()]=byConcept[q['conceptId'].toString()]??[]).add(Map<String,dynamic>.from(q)); }
  final picked=<Map<String,dynamic>>[];
  int round=0;
  while(picked.length < count){
    bool added=false;
    for(final cid in conceptOrder){
      final pool=byConcept[cid]??[];
      if(pool.length>round && !picked.any((p)=>p['questionId']==pool[round]['questionId'])){ picked.add(pool[round]); added=true; if(picked.length>=count) break; }
    }
    if(!added) break;
    round++;
    if(round>5) break;
  }
  return picked.take(count).toList();
}

Future<String> createDiagnostic({required FirebaseFirestore db, required String uid, String? subject, Map<String,dynamic>? scope, Map<String,dynamic>? masteryMap, Map<String,dynamic>? profile}) async {
  final order = prioritizeConcepts(profile:profile, masteryMap:masteryMap, scope:scope);
  final qs = pickQuestions(conceptOrder:order, count:12);
  final id = "${DateTime.now().millisecondsSinceEpoch}-${uid.substring(0,4)}";
  await db.collection('users').doc(uid).collection('diagnostics').doc(id).set({
    'diagnosticId': id, 'uid': uid, 'subject': subject??scope?['subject']??"", 'scope': scope, 'status':'active',
    'questionCount': qs.length, 'answeredCount':0, 'correct':0, 'questionIds': qs.map((q)=>q['questionId']).toList(),
    'startedAt': FieldValue.serverTimestamp(), 'learningSchemaVersion':1
  });
  await emitLearningEvent(db, uid, 'diagnostic_started', subject: subject, source:'diagnostic', sessionId:id, payload:{'scope':scope, 'targetQuestionCount': qs.length});
  return id;
}
