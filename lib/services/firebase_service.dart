import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';
import 'api_client.dart';

/// Bootstraps the Firebase app using configuration fetched at runtime from
/// `/api/firebase-config` — the app never compiles in API keys or Firebase
/// secrets (mirrors web `firebase-config.js`).
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  FirebaseApp? _app;
  bool _initialized = false;
  bool _initializing = false;

  bool _valid(Map<String, dynamic> c) =>
      (c['apiKey']?.toString().isNotEmpty ?? false) &&
      (c['projectId']?.toString().isNotEmpty ?? false);

  Future<Map<String, dynamic>> _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConfig.prefFirebaseConfig);
    if (raw == null) return const {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  Future<void> _saveCache(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.prefFirebaseConfig, jsonEncode(config));
    await prefs.setInt(
        AppConfig.prefConfigFetchedAt, DateTime.now().millisecondsSinceEpoch);
  }

  Future<Map<String, dynamic>> fetchConfig({bool force = false}) async {
    if (AppConfig.apiBase.isEmpty) return const {};
    // Prefer the live backend config so the app always uses the same Firebase
    // project the backend verifies ID tokens against. A stale cached config
    // (different project) would mint tokens the server rejects with 401.
    if (!force) {
      try {
        final config =
            await ApiClient.instance.getJson(AppConfig.firebaseConfigPath);
        if (_valid(config)) {
          await _saveCache(config);
          return config;
        }
      } catch (_) {
        // Backend unreachable — fall through to the cached config below.
      }
      final cached = await _loadCached();
      if (_valid(cached)) return cached;
      throw const ApiException('Could not reach the Aquila backend');
    }
    try {
      final config = await ApiClient.instance.getJson(AppConfig.firebaseConfigPath);
      if (_valid(config)) {
        await _saveCache(config);
        return config;
      }
    } catch (e) {
      // Network failure — fall back to cache, else rethrow for the UI.
      final cached = await _loadCached();
      if (_valid(cached)) return cached;
      throw ApiException('Could not reach the Aquila backend ($e)');
    }
    throw const ApiException('Backend returned an incomplete Firebase config');
  }

  Future<FirebaseApp> initialize() async {
    if (_initialized && _app != null) return _app!;
    if (_initializing) {
      // Wait for the in-flight init with a bounded timeout so a stalled first
      // init never hangs callers indefinitely.
      var waited = 0;
      while (_initializing && waited < 10000) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        waited += 50;
      }
      if (_initialized && _app != null) return _app!;
      // Fall through and retry init if the waiter timed out.
    }
    _initializing = true;
    try {
      final config = await fetchConfig();
      // If the backend now points at a different Firebase project, discard the
      // old app so tokens are minted against the correct project.
      final existing = _app;
      if (existing != null &&
          existing.options.projectId != config['projectId']?.toString()) {
        try {
          await existing.delete();
        } catch (_) {}
        _app = null;
        _initialized = false;
      }
      final options = FirebaseOptions(
        apiKey: config['apiKey']?.toString() ?? '',
        appId: config['appId']?.toString() ?? '',
        messagingSenderId: config['messagingSenderId']?.toString() ?? '',
        projectId: config['projectId']?.toString() ?? '',
        authDomain: config['authDomain']?.toString(),
        storageBucket: config['storageBucket']?.toString(),
        measurementId: config['measurementId']?.toString(),
      );
      // Use the DEFAULT app so FirebaseAuth/FirebaseFirestore `.instance`
      // singletons bind correctly. A named app breaks every service that
      // reads FirebaseAuth.instance / FirebaseFirestore.instance.
      try {
        _app = await Firebase.initializeApp(options: options);
      } on StateError {
        // Already initialized earlier in this process — reuse it.
        _app = Firebase.app();
      }
      _initialized = true;
      if (_app == null) {
        throw ApiException('Firebase could not be initialized');
      }
      return _app!;
    } finally {
      _initializing = false;
    }
  }

  Future<void> refresh() async {
    try {
      final config = await fetchConfig(force: true);
      // Re-create app if the remote config changed materially.
      if (_app != null && _app!.options.projectId != config['projectId']) {
        await _app!.delete();
        _app = null;
        _initialized = false;
        await initialize();
      }
    } catch (_) {
      // Keep using the existing app on failure.
    }
  }
}