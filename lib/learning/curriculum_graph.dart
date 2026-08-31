import 'curriculum_data.dart';
import 'curriculum_schema.dart';

final _byId = {for(final c in curriculumConcepts) c['conceptId'].toString(): c};

Map<String,dynamic>? getConcept(String id){ return _byId[resolveConceptId(id)]; }
List<String> getPrerequisites(String id){ final c=getConcept(id); return c==null?[]: List<String>.from(c['prerequisites']??[]); }
List<String> getDependents(String id){
  final target=resolveConceptId(id);
  return curriculumConcepts.where((c)=> (c['prerequisites'] as List).contains(target)).map((c)=>c['conceptId'].toString()).toList();
}
List<String> getRelated(String id){ final c=getConcept(id); return c==null?[]: List<String>.from(c['relatedConcepts']??[]); }
List<String> getAncestors(String id){
  final visited=<String>{}; final stack=[resolveConceptId(id)]; final res=<String>[];
  while(stack.isNotEmpty){ final cur=stack.removeLast(); for(final p in getPrerequisites(cur)){ if(!visited.contains(p)){ visited.add(p); res.add(p); stack.add(p); } } }
  return res.toSet().toList();
}
List<String> getDescendants(String id){
  final visited=<String>{}; final stack=[resolveConceptId(id)]; final res=<String>[];
  while(stack.isNotEmpty){ final cur=stack.removeLast(); for(final d in getDependents(cur)){ if(!visited.contains(d)){ visited.add(d); res.add(d); stack.add(d); } } }
  return res.toSet().toList();
}
bool hasPrerequisite(String a, String b)=> getAncestors(a).contains(resolveConceptId(b));
List<String> getSubjectConcepts(String s)=> curriculumConcepts.where((c)=>c['subject']==s).map((c)=>c['conceptId'].toString()).toList();

List<String> validateGraph(){
  final errors=<String>[];
  final allIds=curriculumConcepts.map((c)=>c['conceptId'].toString()).toSet();
  if(allIds.length != curriculumConcepts.length) errors.add('duplicate');
  for(final c in curriculumConcepts) errors.addAll(validateConcept(c, allIds));
  // circular
  final visiting=<String>{}, visited=<String>{};
  void dfs(String id, List<String> path){
    if(visiting.contains(id)){ errors.add('circular '+[...path,id].join('->')); return; }
    if(visited.contains(id)) return;
    visiting.add(id);
    for(final p in getPrerequisites(id)) dfs(p, [...path,id]);
    visiting.remove(id); visited.add(id);
  }
  for(final c in curriculumConcepts) dfs(c['conceptId'].toString(), []);
  return errors;
}

List<Map<String,dynamic>> getPrerequisiteReadiness(String id, Map<String,dynamic> masteryMap){
  return getPrerequisites(id).map((pid){
    final m=masteryMap[pid]??masteryMap[resolveConceptId(pid)];
    final ms = (m?['masteryScore'] as num?)?.toDouble() ?? 0;
    final es = (m?['evidenceStrength'] as num?)?.toDouble() ?? 0;
    final ready = es>=0.35 && ms>=0.60;
    String reason="unknown"; if(es<0.35) reason="low_evidence"; else if(ms<0.60) reason="low_mastery"; else reason="ready";
    return {'conceptId':pid,'masteryScore':ms,'evidenceStrength':es,'ready':ready,'reason':reason};
  }).toList();
}

List<String> getLearningPath(String target, Map<String,dynamic> masteryMap){
  final t=resolveConceptId(target);
  final ordered=<String>[]; final visited=<String>{};
  void visit(String id){ if(visited.contains(id)) return; for(final p in getPrerequisites(id)) visit(p); visited.add(id); if(id!=t) ordered.add(id); }
  visit(t);
  return [...ordered, t];
}
