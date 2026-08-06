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

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final idToken = await fa.FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken != null) h['Authorization'] = 'Bearer $idToken';
    }
    return h;
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final resp = await _client
        .post(
          Uri.parse(AppConfig.api(path)),
          headers: await _headers(auth: auth),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
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
    final resp = await _client
        .get(uri, headers: await _headers(auth: auth))
        .timeout(_timeout);
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
    final request = http.Request('POST', Uri.parse(AppConfig.api(path)))
      ..headers.addAll(await _headers(auth: auth))
      ..body = jsonEncode(body);
    // Ask the proxy for a streaming response.
    request.headers['Accept'] = 'text/event-stream';

    final response = await _client.send(request).timeout(_timeout);
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

  /// Handles proxies that send raw text chunks vs JSON `{content:...}`.
  String? _extractDelta(String payload) {
    if (payload.isEmpty) return null;
    try {
      final m = jsonDecode(payload);
      if (m is Map) {
        final content = m['content']?.toString();
        if (content != null && content.isNotEmpty) return content;
      }
    } catch (_) {}
    return payload;
  }
}