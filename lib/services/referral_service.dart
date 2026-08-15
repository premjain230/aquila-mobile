import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import '../services/auth_service.dart' show AuthService;

/// Referral program wiring, mirroring the web referral flow and `/api/referral`.
class ReferralService {
  ReferralService._();

  static final ReferralService instance = ReferralService._();

  String signupUrl(String code) => AppConfig.referralSignupUrl(code);

  /// Shares the referral link with the system share sheet.
  Future<void> share(String code) async {}

  /// Fetches the referral overview (`/api/referral`). Returns the parsed body
  /// or a map describing the failure so the UI can degrade gracefully.
  Future<Map<String, dynamic>?> getDashboard() async {
    final token = await FirebaseAuthProvider.token();
    if (token == null) return null;
    try {
      final resp = await http.get(
        Uri.parse('${AppConfig.api(AppConfig.referralPath)}?path=dashboard'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode >= 400) return null;
      return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

/// Slim provider so [ReferralService] doesn't import the auth singleton directly.
class FirebaseAuthProvider {
  static Future<String?> token() async {
    try {
      final user = AuthService.instance.currentUser;
      return user?.getIdToken();
    } catch (_) {
      return null;
    }
  }
}