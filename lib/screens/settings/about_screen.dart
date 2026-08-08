import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _mail() async {
    final uri = Uri.parse('mailto:${AppConfig.supportEmail}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _discord() async {
    final uri = Uri.parse(AppConfig.discordUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Scaffold(
      backgroundColor: ext.bgBase,
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: AquilaLogo(size: 72)),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Aquila AI',
              style: TextStyle(
                fontFamily: AquilaColors.fontMain,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Neuroscience-powered learning companion\nfor JEE, NEET, Olympiads, Boards & more.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AquilaColors.fontMain,
                fontSize: 13.5,
                height: 1.5,
                color: ext.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 28),
          _tile(ext, Icons.mail_outline, 'Email Support', AppConfig.supportEmail, _mail),
          _tile(ext, Icons.people_outline, 'Community Discord',
              'Join the Aquila community', _discord),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Made for learners, everywhere.',
              style: ext.monoMicro(10, color: ext.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(AquilaThemeExt ext, IconData icon, String title, String subtitle,
      VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ext.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ext.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AquilaColors.accent, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AquilaColors.fontMain,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ext.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: ext.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: ext.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}