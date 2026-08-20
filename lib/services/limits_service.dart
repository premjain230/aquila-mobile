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

  /// Returns a [LimitResult] for the given action type WITHOUT writing usage.
  ///
  /// Usage counters are owned by the server: `firestore.rules` deny client
  /// writes to `usage/{uid}` and `/api/groq-proxy` enforces + increments them
  /// via the Admin SDK (mirrors the web `checkAndGate`/`incrementUsage` no-op).
  /// Writing here previously threw a permission error before the caller's
  /// try block, which silently blocked sending chat messages.
  ///
  /// [plan] defaults to `null` so the user's *actual* plan is read from
  /// `users/{uid}` (previously callers hard-coded `'free'`, which incorrectly
  /// limited Pro subscribers).
  Future<LimitResult> consume(
    String uid, {
    required UsageType type,
    String? plan,
    int amount = 1,
    int bonusChats = 0,
  }) async {
    final resolvedPlan = plan ?? await _resolvePlan(uid);
    final ref = _db.collection('usage').doc(uid);
    final snap = await ref.get();
    final today = _todayKey();
    final docDate = snap.data()?['date']?.toString() ?? '';

    // Server rolls the counter over when the date changes; surface zeros for a
    // stale/missing doc (mirrors web ensureUsageDoc).
    final current = snap.exists && docDate == today
        ? UsageInfo.fromDoc(snap, plan: resolvedPlan)
        : UsageInfo(
            date: today,
            chatCount: 0,
            analysisCount: 0,
            plannerMinutes: 0,
            plan: resolvedPlan);

    final limit = current.getLimit(type);
    final used = current.usedOf(type);
    final effectiveLimit = limit == -1 ? -1 : limit + bonusChats;
    if (effectiveLimit != -1 && used + amount > effectiveLimit) {
      return LimitResult(
        type: type,
        plan: resolvedPlan,
        used: used,
        limit: limit,
        bonusChats: bonusChats,
      );
    }

    // Allow — the server is the source of truth and returns a 429 when the
    // authoritative limit is reached, so nothing is persisted client-side.
    return LimitResult(
      type: type,
      plan: resolvedPlan,
      used: used + amount,
      limit: limit,
      bonusChats: bonusChats,
    );
  }

  /// Reads the user's plan from `users/{uid}` (defaults to `free`).
  Future<String> _resolvePlan(String uid) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      if (snap.data()?['plan']?.toString() == 'pro') return 'pro';
    } catch (_) {}
    return 'free';
  }
}