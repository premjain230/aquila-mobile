/// Aquila Learning — Mobile service stubs (Prompt 1)
/// Mirrors web js/learning/*.js. Full logic in later prompts.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'contracts.dart';
import 'schema.dart';

class LearningProfileService {
  final FirebaseFirestore db;
  LearningProfileService(this.db);

  DocumentReference<Map<String, dynamic>> _ref(String uid) => db.collection('users').doc(uid).collection('learning').doc('profile');

  Future<UserLearningProfile> load(String uid) async {
    try {
      final snap = await _ref(uid).get();
      if (!snap.exists || snap.data() == null) return UserLearningProfile.create(uid);
      return UserLearningProfile.fromMap(snap.data()!);
    } catch (_) {
      return UserLearningProfile.create(uid);
    }
  }

  Future<bool> save(String uid, Map<String, dynamic> patch) async {
    try {
      await _ref(uid).set({...patch, 'learningSchemaVersion': learningSchemaVersion, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }
}

class StudentModelService {
  final FirebaseFirestore db;
  StudentModelService(this.db);
  DocumentReference<Map<String, dynamic>> _ref(String uid) => db.collection('users').doc(uid).collection('learning').doc('studentModel');

  Future<StudentModel> load(String uid) async {
    try {
      final snap = await _ref(uid).get();
      if (!snap.exists || snap.data() == null) return StudentModel.create(uid);
      final d = snap.data()!;
      return StudentModel.create(uid, overrides: d);
    } catch (_) {
      return StudentModel.create(uid);
    }
  }

  Future<bool> save(String uid, Map<String, dynamic> patch) async {
    try {
      await _ref(uid).set({...patch, 'learningSchemaVersion': learningSchemaVersion, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }
}

class MasteryService {
  final FirebaseFirestore db;
  MasteryService(this.db);

  CollectionReference<Map<String, dynamic>> _col(String uid) => db.collection('users').doc(uid).collection('mastery');

  Future<List<Mastery>> list(String uid) async {
    try {
      final snap = await _col(uid).get();
      return snap.docs.map((d) {
        final m = d.data();
        return Mastery.create(uid, m['conceptId']?.toString() ?? d.id, overrides: m);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Mastery?> get(String uid, String conceptId) async {
    try {
      final snap = await _col(uid).doc(conceptId).get();
      if (!snap.exists || snap.data() == null) return null;
      return Mastery.create(uid, conceptId, overrides: snap.data()!);
    } catch (_) {
      return null;
    }
  }

  // TODO Prompt 5: route through /api/mastery (server-authoritative)
  Future<bool> save(String uid, Mastery mastery) async {
    try {
      await _col(uid).doc(mastery.conceptId).set({...mastery.toMap(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }
}

class SessionService {
  final FirebaseFirestore db;
  SessionService(this.db);
  CollectionReference<Map<String, dynamic>> _col(String uid) => db.collection('users').doc(uid).collection('sessions');

  Future<List<Map<String, dynamic>>> list(String uid, {int limit = 20}) async {
    try {
      final snap = await _col(uid).orderBy('startedAt', descending: true).limit(limit).get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }
}

class CurriculumService {
  final FirebaseFirestore db;
  CurriculumService(this.db);
  // TODO Prompt 5: fetch from curriculum/{exam}
  Future<Map<String, dynamic>> getCurriculum(String exam) async => {'exam': exam, 'curriculumVersion': curriculumVersion, 'subjects': []};
}
