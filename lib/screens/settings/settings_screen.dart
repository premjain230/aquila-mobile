import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/theme_store.dart';
import '../../services/update_service.dart';
import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/update_dialog.dart';
import '../referral/referral_screen.dart';
import '../subscription/subscription_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String uid;
  const SettingsScreen({super.key, required this.uid});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _dark = true;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _dark = Theme.of(context).brightness == Brightness.dark;
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version} (${info.buildNumber})');
    }
  }

  Future<void> _toggleTheme(bool value) async {
    setState(() => _dark = value);
    await ThemeStore().save(value);
    // Rebuild with the new theme mode: simplest is to toggle via root. The
    // theme is keyed off ThemeMode in app.dart, so we persist here and let
    // the app restart pick it up; for a live switch the shell owns a callback.
  }

  Future<void> _checkUpdate() async {
    final info = await UpdateService.instance.check();
    if (!mounted) return;
    if (info.requirement == UpdateRequirement.available ||
        info.requirement == UpdateRequirement.required) {
      await showUpdateDialog(context, info);
    } else if (mounted) {
      showAquilaSnack(context, 'You\'re on the latest version.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Scaffold(
      backgroundColor: ext.bgBase,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text('PREFERENCES', style: ext.monoMicro(11, color: AquilaColors.accent)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: ext.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ext.border),
            ),
            child: SwitchListTile(
              value: _dark,
              onChanged: _toggleTheme,
              title: const Text('Dark mode'),
              subtitle: Text(
                'Aquila looks best in dark — switch anytime.',
                style: TextStyle(fontSize: 12, color: ext.textSecondary),
              ),
              activeThumbColor: AquilaColors.accent,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 24),
          Text('ACCOUNT', style: ext.monoMicro(11, color: AquilaColors.accent)),
          const SizedBox(height: 10),
          _tile(ext, Icons.workspace_premium, 'Subscription & Limits', () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SubscriptionScreen(uid: widget.uid),
              ),
            );
          }),
          _tile(ext, Icons.link, 'Invite friends — earn free chat days', () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReferralScreen(uid: widget.uid),
              ),
            );
          }),
          const SizedBox(height: 24),
          Text('ABOUT', style: ext.monoMicro(11, color: AquilaColors.accent)),
          const SizedBox(height: 10),
          _tile(ext, Icons.info_outline, 'About Aquila', () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            );
          }),
          _tile(ext, Icons.system_update_alt, 'Check for updates', _checkUpdate),
          _tile(ext, Icons.support_agent, 'Support & Community', _openDiscord),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Aquila AI v$_version',
              style: ext.monoMicro(10, color: ext.textMuted),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => AuthService.instance.signOut(),
              child: const Text(
                'Sign out',
                style: TextStyle(color: AquilaColors.accent3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
      AquilaThemeExt ext, IconData icon, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: ext.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ext.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AquilaColors.accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: AquilaColors.fontMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: ext.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: ext.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDiscord() async {
    final uri = Uri.parse(AppConfig.discordUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}