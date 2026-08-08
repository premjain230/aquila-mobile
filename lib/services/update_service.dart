import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';
import 'api_client.dart';

enum UpdateRequirement { none, available, required }

/// Thrown by [UpdateService.downloadAndInstall] when the update can't be
/// fetched or handed to the system installer.
class UpdateInstallException implements Exception {
  final String message;
  const UpdateInstallException(this.message);

  @override
  String toString() => message;
}

class UpdateInfo {
  final UpdateRequirement requirement;
  final int currentVersion;
  final int? latestVersion;
  final int? minimumVersion;
  final String? downloadUrl;
  final String? notes;

  const UpdateInfo({
    required this.requirement,
    required this.currentVersion,
    this.latestVersion,
    this.minimumVersion,
    this.downloadUrl,
    this.notes,
  });

  const UpdateInfo.upToDate(int current)
      : requirement = UpdateRequirement.none,
        currentVersion = current,
        latestVersion = null,
        minimumVersion = null,
        downloadUrl = null,
        notes = null;
}

/// Checks for app updates against `/api/version` (a new endpoint to be added
/// to the web backend). Compares numeric version codes, not strings.
class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  /// Returns the local built version code as an int.
  Future<int> currentVersionCode() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 1;
  }

  Future<int?> _parseToInt(Object? v) {
    if (v is num) return Future.value(v.toInt());
    if (v is String) {
      final n = int.tryParse(v.trim());
      if (n != null) return Future.value(n);
    }
    return Future.value(null);
  }

  /// Fetches the latest version info from the backend.
  Future<UpdateInfo> check() async {
    final current = await currentVersionCode();
    Map<String, dynamic> res;
    try {
      res = await ApiClient.instance.getJson(AppConfig.versionPath);
    } catch (_) {
      // If the endpoint isn't deployed yet, treat as up-to-date.
      return UpdateInfo.upToDate(current);
    }

    final latest = await _parseToInt(res['latestVersion']);
    final minimum = await _parseToInt(res['minimumVersion']);
    final downloadUrl = res['downloadUrl']?.toString();
    final notes = res['notes']?.toString();

    final requirement = (minimum != null && current < minimum)
        ? UpdateRequirement.required
        : (latest != null && current < latest
            ? UpdateRequirement.available
            : UpdateRequirement.none);

    return UpdateInfo(
      requirement: requirement,
      currentVersion: current,
      latestVersion: latest,
      minimumVersion: minimum,
      downloadUrl: downloadUrl,
      notes: notes,
    );
  }

  Future<void> openDownload(String? url) async {
    final target = url;
    if (target == null || target.isEmpty) return;
    final uri = Uri.parse(target);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Downloads the APK from [url] into the app's writable cache and opens the
  /// Android system installer so the user can update in-place — no manual
  /// redownload of "the same file".
  ///
  /// [onProgress] receives 0..1 as bytes arrive. Once the file is downloaded it
  /// is handed to the native installer via a content URI; the user confirms the
  /// install in the system screen (Android "install unknown apps" must be
  /// enabled for Aquila — REQUEST_INSTALL_PACKAGES is declared in the manifest).
  Future<String> downloadAndInstall(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      throw const UpdateInstallException('Invalid download link.');
    }

    final dir = await getTemporaryDirectory();
    await dir.create(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}aquila-update.apk');

    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      final resp = await client.send(request).timeout(const Duration(minutes: 10));
      if (resp.statusCode != 200) {
        throw UpdateInstallException('Download failed (HTTP ${resp.statusCode}).');
      }

      final total = resp.contentLength ?? 0;
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in resp.stream) {
          received += chunk.length;
          sink.add(chunk);
          if (total > 0) onProgress?.call(received / total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (!await file.exists() || file.lengthSync() == 0) {
        throw const UpdateInstallException('Downloaded file appears empty.');
      }

      // Hand the APK to the system installer.
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        final detail =
            result.message.isNotEmpty ? ': ${result.message}' : '';
        throw UpdateInstallException(
            'Could not open the installer$detail. If prompted, allow '
            '"Install unknown apps" for Aquila in your phone settings.');
      }
      return file.path;
    } finally {
      client.close();
    }
  }
}