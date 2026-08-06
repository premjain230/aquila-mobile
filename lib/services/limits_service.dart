import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/usage_models.dart';

/// Client-side usage limiting, mirroring the web `limits.js` + `subscription.js`.
/// Counters live in `usage/{uid}` (a single doc carrying a `date` + counters,
/// reset each local day).
class LimitsService {
  LimitsService._();

  static final LimitsService instance = LimitsService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String _todayKey() =>
      DateTime.now().toUtc().toIso8601String().substring(0, 10);

  Future<UsageInfo> getUsage(String uid, {String plan = 'free'}) async {
    final ref = _db.collection('usage').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'date': _todayKey(),
        'dailyChatCount': 0,
        'dailyAnalysisCount': 0,
        'plannerUsageMinutes': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return UsageInfo(
        date: _todayKey(),
        chatCount: 0,
        analysisCount: 0,
        plannerMinutes: 0,
        plan: plan,
      );
    }
    return UsageInfo.fromDoc(snap, plan: plan);
  }

  Stream<UsageInfo> usageStream(String uid, {String plan = 'free'}) {
    return _db.collection('usage').doc(uid).snapshots().map((snap) {
      if (!snap.exists) {
        return UsageInfo(
          date: _todayKey(),
          chatCount: 0,
          analysisCount: 0,
          plannerMinutes: 0,
          plan: plan,
        );
      }
      return UsageInfo.fromDoc(snap, plan: plan);
    });
  }

  /// Returns a [LimitResult] for the given action type and (if allowed) persists
  /// the increment, atomically resetting the day's counters when needed.
  Future<LimitResult> consume(
    String uid, {
    required UsageType type,
    String plan = 'free',
    int amount = 1,
    int bonusChats = 0,
  }) async {
    final ref = _db.collection('usage').doc(uid);
    final snap = await ref.get();
    final today = _todayKey();
    final docDate = snap.data()?['date']?.toString() ?? '';

    // Reset counters when the day rolled over.
    if (snap.exists && docDate != today) {
      await ref.set({
        'date': today,
        'dailyChatCount': 0,
        'dailyAnalysisCount': 0,
        'plannerUsageMinutes': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final current = snap.exists && docDate == today
        ? UsageInfo.fromDoc(snap, plan: plan)
        : UsageInfo(
            date: today, chatCount: 0, analysisCount: 0, plannerMinutes: 0, plan: plan);

    final limit = current.getLimit(type);
    final used = current.usedOf(type);
    final effectiveLimit = limit == -1 ? -1 : limit + bonusChats;
    if (effectiveLimit != -1 && used + amount > effectiveLimit) {
      return LimitResult(
        type: type,
        plan: plan,
        used: used,
        limit: limit,
        bonusChats: bonusChats,
      );
    }

    // Allow — persist the increment.
    final field = switch (type) {
      UsageType.chat => 'dailyChatCount',
      UsageType.analysis => 'dailyAnalysisCount',
      UsageType.planner => 'plannerUsageMinutes',
    };
    await ref.set(
      {
        'date': today,
        field: FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return LimitResult(
      type: type,
      plan: plan,
      used: used + amount,
      limit: limit,
      bonusChats: bonusChats,
    );
  }
}