import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:http/http.dart' as http;

import '../core/app_config.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Thin client over the existing Vercel backend.
///
/// Security: the app never holds API keys — AI keys stay in server env vars.
/// Firebase ID tokens are sent as Bearer credentials for authenticated routes.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  final http.Client _client = http.Client();
  static const _timeout = Duration(seconds: 90);

  /// Obtains a fresh Firebase ID token. When `force` is true the SDK is told to
  /// ignore its cached token and mint a new one (used to recover from a 401).
  Future<String?> _idToken({bool force = false}) async {
    try {
      final user = fa.FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return await user.getIdToken(force);
    } catch (_) {
      return null;
    }
  }

  /// Builds request headers. For authenticated requests a valid Firebase ID
  /// token is REQUIRED: if none can be obtained the request throws a 401
  /// ApiException instead of silently going out without credentials (which is
  /// what caused an authenticated user to be told "Not authenticated").
  Future<Map<String, String>> _headers({bool auth = false, bool forceToken = false}) async {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final idToken = await _idToken(force: forceToken);
      if (idToken == null) {
        throw const ApiException('Your session expired. Please sign in again.',
            statusCode: 401);
      }
      h['Authorization'] = 'Bearer $idToken';
    }
    return h;
  }

  /// Sends an authenticated request, retrying exactly once with a freshly
  /// minted token when the server reports an expired/invalid session. This
  /// guarantees a legitimately signed-in user is never told they're
  /// unauthenticated just because their token expired mid-conversation.
  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function(Map<String, String> headers) send, {
    required bool auth,
  }) async {
    var headers = await _headers(auth: auth);
    var resp = await send(headers);
    if (auth && resp.statusCode == 401) {
      headers = await _headers(auth: auth, forceToken: true);
      resp = await send(headers);
    }
    return resp;
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final resp = await _sendWithRetry(
      (headers) => _client
          .post(
            Uri.parse(AppConfig.api(path)),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout),
      auth: auth,
    );
    if (resp.statusCode >= 400) {
      throw ApiException(_decodeError(resp), statusCode: resp.statusCode);
    }
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getJson(String path,
      {bool auth = false, Map<String, String>? query}) async {
    var uri = Uri.parse(AppConfig.api(path));
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final resp = await _sendWithRetry(
      (headers) => _client.get(uri, headers: headers).timeout(_timeout),
      auth: auth,
    );
    if (resp.statusCode >= 400) {
      throw ApiException(_decodeError(resp), statusCode: resp.statusCode);
    }
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  String _decodeError(http.Response resp) {
    try {
      final m = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final msg = m['error']?.toString() ?? m['message']?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
    } catch (_) {}
    return 'Request failed (HTTP ${resp.statusCode})';
  }

  /// Streams a Server-Sent Events (SSE) response from the Groq proxy.
  ///
  /// Yields each incrementally parsed content delta so the UI can type out
  /// text as it arrives (mirrors the web `handleStream` parser).
  Stream<String> streamJson(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async* {
    http.StreamedResponse? response = await _openStream(path, body, auth: auth);
    // If the session expired, force a token refresh and retry exactly once.
    if (auth && response.statusCode == 401) {
      await response.stream.drain();
      await _idToken(force: true);
      response = await _openStream(path, body, auth: auth);
    }
    if (response.statusCode >= 400) {
      final raw = await response.stream.bytesToString();
      throw ApiException(raw, statusCode: response.statusCode);
    }

    var buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      var idx = buffer.indexOf('\n');
      while (idx != -1) {
        final line = buffer.substring(0, idx).trim();
        buffer = buffer.substring(idx + 1);
        if (line.isNotEmpty && line.startsWith('data:')) {
          final payload = line.substring(5).trim();
          if (payload == '[DONE]') {
            buffer = '';
            return;
          }
          final raw = _extractDelta(payload);
          if (raw != null) yield raw;
        }
        idx = buffer.indexOf('\n');
      }
    }
  }

  Future<http.StreamedResponse> _openStream(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final request = http.Request('POST', Uri.parse(AppConfig.api(path)))
      ..headers.addAll(await _headers(auth: auth))
      ..body = jsonEncode(body);
    request.headers['Accept'] = 'text/event-stream';
    return _client.send(request).timeout(_timeout);
  }

  /// Parses a single SSE `data:` payload.
  ///
  /// Groq streams chunks of the form
  /// `{"choices":[{"delta":{"content":"..."}}]}`. Plain `{content:...}` payloads
  /// (a shortcut used by some proxies) are also supported. Returns `null` for
  /// anything that doesn't carry content (metadata/metrics frames) so those
  /// are skipped rather than rendered.
  String? _extractDelta(String payload) {
    if (payload.isEmpty) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } catch (_) {
      // Not JSON — take it as a raw text delta.
      return payload;
    }
    if (decoded is! Map) return null;

    // Groq / OpenAI SSE: content is nested under choices[].delta.
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final delta = first['delta'];
        if (delta is Map) {
          final content = delta['content']?.toString();
          if (content != null && content.isNotEmpty) return content;
        }
        final text = first['text']?.toString();
        if (text != null && text.isNotEmpty) return text;
      }
    }

    // Flat `{content: "..."}` shape.
    final flat = decoded['content']?.toString();
    if (flat != null && flat.isNotEmpty) return flat;

    return null;
  }
}