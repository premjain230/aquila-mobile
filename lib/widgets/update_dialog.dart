import 'package:flutter/material.dart';

import '../services/update_service.dart';
import '../theme/aquila_theme.dart';

/// In-app update flow: shows release notes, downloads the new APK with a live
/// progress bar, then opens the Android system installer. Falls back to the
/// browser download if the in-app installer is unavailable.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  if (info.downloadUrl == null || info.downloadUrl!.isEmpty) return;
  final isRequired = info.requirement == UpdateRequirement.required;
  await showDialog<void>(
    context: context,
    barrierDismissible: !isRequired,
    builder: (_) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _busy = false;
  double _progress = 0;
  String? _error;

  Future<void> _start() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      await UpdateService.instance.downloadAndInstall(
        widget.info.downloadUrl!,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      // The system installer has been opened — close the dialog so the native
      // update flow takes over.
      if (mounted) Navigator.of(context).pop();
    } on UpdateInstallException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            'Something went wrong while downloading. Please try again.';
      });
    }
  }

  Future<void> _browser() async {
    await UpdateService.instance.openDownload(widget.info.downloadUrl);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    final isRequired = widget.info.requirement == UpdateRequirement.required;

    return AlertDialog(
      title: Text(isRequired ? 'Update required' : 'Update available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _busy
                ? 'Downloading the latest Aquila…'
                : widget.info.notes?.isNotEmpty == true
                    ? widget.info.notes!
                    : 'A newer version of Aquila is ready. Update in-app to keep using your chats.',
            style: TextStyle(
                fontFamily: AquilaColors.fontMain,
                fontSize: 13.5,
                height: 1.5,
                color: ext.textSecondary),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: ext.bgInput,
                color: AquilaColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).round()}%',
              style: TextStyle(
                  fontFamily: AquilaColors.fontMono,
                  fontSize: 11,
                  color: ext.textSecondary),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(
                  fontFamily: AquilaColors.fontMain,
                  fontSize: 13,
                  height: 1.4,
                  color: Color(0xFFFF6B6B)),
            ),
          ],
        ],
      ),
      actions: [
        if (!_busy && !isRequired)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AquilaColors.accent,
              foregroundColor: AquilaColors.onAccentText,
            ),
            onPressed: _start,
            icon: const Icon(Icons.download, size: 18),
            label: Text(_error != null ? 'Retry update' : 'Update now'),
          ),
        if (_error != null && !_busy)
          TextButton(
            onPressed: _browser,
            child: const Text('Open in browser'),
          ),
      ],
    );
  }
}