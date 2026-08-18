/// App-wide configuration.
///
/// The API base URL points at the existing Aquila AI backend. It can be
/// overridden at build time with:
///   flutter build apk --dart-define=AQUILA_API_BASE=https://your.domain
class AppConfig {
  AppConfig._();

  static const String apiBase = String.fromEnvironment(
    'AQUILA_API_BASE',
    defaultValue: 'https://aquila-sand.vercel.app',
  );

  static String api(String path) => '$apiBase$path';

  // Backend endpoints (shared with the web app — no AI keys ever in the app).
  static const String groqProxyPath = '/api/groq-proxy';
  static const String searchPath = '/api/search';
  static const String generatePlanPath = '/api/generate-plan';
  static const String replanPath = '/api/replan';
  static const String referralPath = '/api/referral';
  static const String addContactPath = '/api/add-contact';
  static const String versionPath = '/api/version';
  static const String firebaseConfigPath = '/api/firebase-config';

  /// Chat model used by the web app (server-side Groq model).
  static const String chatModel = 'openai/gpt-oss-120b';

  /// Max conversation turns the web app keeps in context.
  static const int maxHistory = 60;

  /// Max characters per stored message (mirrors Firestore rule).
  static const int messageContentLimit = 32000;

  /// Shared preferences keys.
  static const String prefTheme = 'aquila-theme';
  static const String prefReferred = 'aquila_ref';
  static const String prefFirebaseConfig = 'aquila_firebase_config';
  static const String prefConfigFetchedAt = 'aquila_firebase_config_fetched_at';

  /// Web share helpers for referral links.
  static String referralSignupUrl(String code) => '$apiBase/signup.html?ref=$code';

  static const String supportEmail = 'aiaquilaoffical@gmail.com';
  static const String discordUrl = 'https://discord.gg/vDvrJhUzud';
}