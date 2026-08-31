library misconceptions;

import 'package:cloud_firestore/cloud_firestore.dart';

String? calibrationLabel(double? mastery, double? confidence) {
  if (mastery == null || confidence == null) return null;
  final gap = (mastery - confidence).abs();
  if (gap < 0.25) return 'calibrated';
  return confidence > mastery ? 'overconfident' : 'underconfident';
}

Future<bool> resolveMisconception(FirebaseFirestore db, String uid, String id, {Map<String, dynamic>? evidence}) async {
  try {
    await db.collection('users').doc(uid).collection('misconceptions').doc(id).update({
      'resolved': true,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolutionEvidence': evidence,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  } catch (_) { return false; }
}
