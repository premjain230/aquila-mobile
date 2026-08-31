const int curriculumModelVersion = 1;
final RegExp _idRe = RegExp(r'^[a-z][a-z0-9]*(\.[a-z0-9_]+)+$');

bool isValidConceptId(String id)=> id.length>=3 && id.length<=80 && _idRe.hasMatch(id);
bool isValidSubject(String s)=> s.length>=2 && s.length<=40;
bool isValidTopic(String t)=> t.length>=2 && t.length<=60;

List<String> validateConcept(Map<String,dynamic> c, Set<String> allIds){
  final errors=<String>[];
  if(!isValidConceptId(c['conceptId']?.toString()??'')) errors.add('conceptId invalid');
  if(!isValidSubject(c['subject']?.toString()??'')) errors.add('subject invalid');
  if(!isValidTopic(c['topic']?.toString()??'')) errors.add('topic invalid');
  if((c['name']?.toString()??'').trim().isEmpty) errors.add('name required');
  final d = c['difficulty'];
  if(d is! num || d<0 || d>1) errors.add('difficulty 0..1');
  final prereqs = c['prerequisites'];
  if(prereqs is! List) errors.add('prerequisites must be array');
  else {
    for(final p in prereqs){
      if(p==c['conceptId']) errors.add('self-prerequisite');
      if(!allIds.contains(p.toString())) errors.add('missing prerequisite: $p');
    }
  }
  return errors;
}
