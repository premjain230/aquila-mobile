import 'package:cloud_firestore/cloud_firestore.dart';

/// Daily usage counters — mirrors `usage/{uid}` in Firestore and the web's
/// `subscription.js` PLANS constants (free: 20 chats / 20 analyses / 30 min).
enum UsageType { chat, analysis, planner }

class UsageInfo {
  final String date; // YYYY-MM-DD (UTC, like the web app)
  final int chatCount;
  final int analysisCount;
  final int plannerMinutes;
  final String plan; // free | pro

  const UsageInfo({
    required this.date,
    required this.chatCount,
    required this.analysisCount,
    required this.plannerMinutes,
    required this.plan,
  });

  factory UsageInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc,
      {String plan = 'free'}) {
    final d = doc.data() ?? const {};
    return UsageInfo(
      date: d['date']?.toString() ?? _today(),
      chatCount: (d['dailyChatCount'] as num?)?.toInt() ?? 0,
      analysisCount: (d['dailyAnalysisCount'] as num?)?.toInt() ?? 0,
      plannerMinutes: (d['plannerUsageMinutes'] as num?)?.toInt() ?? 0,
      plan: plan,
    );
  }

  static String _today() => DateTime.now().toUtc().toIso8601String().substring(0, 10);

  int getLimit(UsageType type) {
    if (plan == 'pro') return -1; // unlimited
    switch (type) {
      case UsageType.chat:
        return 20;
      case UsageType.analysis:
        return 20;
      case UsageType.planner:
        return 30;
    }
  }

  int usedOf(UsageType type) {
    switch (type) {
      case UsageType.chat:
        return chatCount;
      case UsageType.analysis:
        return analysisCount;
      case UsageType.planner:
        return plannerMinutes;
    }
  }
}

/// Info shown in the upgrade modal when a limit is hit.
class LimitResult {
  final UsageType type;
  final String plan;
  final int used;
  final int limit; // -1 => unlimited
  final int bonusChats;

  const LimitResult({
    required this.type,
    required this.plan,
    required this.used,
    required this.limit,
    this.bonusChats = 0,
  });

  /// Chat limit can be boosted by referral bonus chats (web `checkLimitWithBonus`).
  int get effectiveLimit => limit == -1 ? -1 : limit + bonusChats;

  bool get allowed {
    final lim = effectiveLimit;
    return lim == -1 || used < lim;
  }
}