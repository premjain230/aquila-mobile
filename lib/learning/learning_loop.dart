double calculateStuckScore({List<dynamic> recentEvents = const [], int recentIncorrectCount = 0, List<dynamic> misconceptions = const [], int explicitStruggle = 0, int hintCount = 0}){
  final repeatedIncorrect = (recentIncorrectCount / 3).clamp(0,1).toDouble() * 0.3;
  final repeatedExplain = (recentEvents.where((e)=> (e is Map && e['type']=='explanation_requested')).length / 3).clamp(0,1).toDouble() * 0.2;
  final sameMisconception = misconceptions.where((m)=> m is Map && m['resolved']!=true).isNotEmpty ? 0.2 : 0.0;
  final explicit = (explicitStruggle.clamp(0,1)).toDouble() * 0.2;
  final hints = (hintCount / 5).clamp(0,1).toDouble() * 0.1;
  return (repeatedIncorrect + repeatedExplain + sameMisconception + explicit + hints).clamp(0,1).toDouble();
}
bool shouldOfferLoop(double score, int depth)=> score >= 0.6 && depth < 3;
