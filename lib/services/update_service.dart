import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';
import 'api_client.dart';

enum UpdateRequirement { none, available, required }

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
}