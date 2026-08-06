/// User-facing model synthesised from Firebase Auth + the Firestore
/// `users/{uid}` document (shape mirrors the web app's `ensureUserDoc`).
class AquilaUser {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final String exam;
  final String plan; // "free" | "pro"
  final String personality;
  final String referralCode;
  final int streak;
  final List<String> topics;
  final int bonusChats; // from referralRewards.bonusChats
  final int proDays;
  final int premiumQuizDays;
  final bool onboardingComplete;
  final String futureMeLetter;

  const AquilaUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.exam,
    required this.plan,
    required this.personality,
    required this.referralCode,
    required this.streak,
    required this.topics,
    required this.bonusChats,
    required this.proDays,
    required this.premiumQuizDays,
    required this.onboardingComplete,
    required this.futureMeLetter,
  });

  bool get isPro => plan == 'pro';

  factory AquilaUser.empty() => const AquilaUser(
        uid: '',
        email: '',
        displayName: '',
        photoUrl: '',
        exam: '',
        plan: 'free',
        personality: '',
        referralCode: '',
        streak: 0,
        topics: [],
        bonusChats: 0,
        proDays: 0,
        premiumQuizDays: 0,
        onboardingComplete: false,
        futureMeLetter: '',
      );

  factory AquilaUser.fromMap(String uid, Map<String, dynamic> data) {
    Map<String, dynamic> rewards = {};
    final rawRewards = data['referralRewards'];
    if (rawRewards is Map) rewards = Map<String, dynamic>.from(rawRewards);

    List<String> topics = [];
    if (data['topics'] is List) {
      topics = (data['topics'] as List)
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return AquilaUser(
      uid: uid,
      email: data['email']?.toString() ?? '',
      displayName: data['displayName']?.toString() ?? '',
      photoUrl: data['photoURL']?.toString() ?? '',
      exam: data['exam']?.toString() ?? '',
      plan: data['plan']?.toString() ?? 'free',
      personality: data['personality']?.toString() ?? '',
      referralCode: data['referralCode']?.toString() ?? '',
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      topics: topics,
      bonusChats: (rewards['bonusChats'] as num?)?.toInt() ?? 0,
      proDays: (rewards['proDays'] as num?)?.toInt() ?? 0,
      premiumQuizDays: (rewards['premiumQuizDays'] as num?)?.toInt() ?? 0,
      onboardingComplete: data['onboardingComplete'] == true,
      futureMeLetter: data['futureMeLetter']?.toString() ?? '',
    );
  }

  AquilaUser copyWith({
    String? displayName,
    String? exam,
    String? plan,
    String? personality,
    int? streak,
    List<String>? topics,
  }) {
    return AquilaUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl,
      exam: exam ?? this.exam,
      plan: plan ?? this.plan,
      personality: personality ?? this.personality,
      referralCode: referralCode,
      streak: streak ?? this.streak,
      topics: topics ?? this.topics,
      bonusChats: bonusChats,
      proDays: proDays,
      premiumQuizDays: premiumQuizDays,
      onboardingComplete: onboardingComplete,
      futureMeLetter: futureMeLetter,
    );
  }
}