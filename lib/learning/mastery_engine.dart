import 'schema.dart';

Map<String, double> calculateMastery(List<Map<String, dynamic>> evidence) {
  if (evidence.isEmpty) return {'masteryScore': 0.5, 'evidenceStrength': 0, 'weightedCorrectness': 0.5, 'effectiveWeight': 0};
  double sumW = 0, sumWC = 0;
  double confSum = 0; int confCount = 0;
  for (final e in evidence) {
    final w = getSourceWeight(e['source']?.toString()) * getHintFactor(e['hintCount']) * getRecencyFactor(e['createdAt']);
    if (w <= 0) continue;
    final perf = e['correct'] == true ? 1.0 : 0.0;
    sumW += w;
    sumWC += perf * w;
    if (e['confidence'] != null) { confSum += normalizeConfidence(e['confidence'] as num); confCount++; }
  }
  if (sumW == 0) return {'masteryScore': 0.5, 'evidenceStrength': 0, 'weightedCorrectness': 0.5, 'effectiveWeight': 0};
  final wc = sumWC / sumW;
  double adj = 0;
  if (confCount > 0) adj = (confSum / confCount - 0.5) * 0.10;
  final raw = (wc + adj).clamp(0, 1);
  final sampleFactor = (sumW / 3).clamp(0, 1);
  final masteryScore = (masteryPrior * (1 - sampleFactor) + raw * sampleFactor).clamp(0, 1);
  final evidenceStrength = (sumW / 5).clamp(0, 1);
  return {'masteryScore': masteryScore, 'evidenceStrength': evidenceStrength, 'weightedCorrectness': wc, 'effectiveWeight': sumW};
}
