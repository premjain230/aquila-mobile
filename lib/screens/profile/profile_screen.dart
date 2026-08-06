import 'package:flutter/material.dart';

import '../../models/aquila_user.dart';
import '../../services/auth_service.dart';
import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';

const _personalities = [
  ('mentor', '🧭', 'Mentor', 'Clear, structured guidance'),
  ('friendly', '🤝', 'Friendly', 'Warm and approachable'),
  ('motivator', '⚡', 'Motivator', 'Pushes you to keep going'),
  ('deep-thinker', '🧠', 'Deep Thinker', 'Rigorous, conceptual depth'),
  ('coach', '🎯', 'Coach', 'Goal-focused and tactical'),
  ('calm-guide', '🌿', 'Calm Guide', 'Gentle, patient pacing'),
  ('inspirational', '✨', 'Inspirational', 'Encouraging and uplifting'),
];

class ProfileScreen extends StatefulWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in anytime. Your data is saved.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) {
      await AuthService.instance.signOut();
    }
  }

  Future<void> _setPersonality(String value) async {
    await AuthService.instance.updatePersonality(widget.uid, value);
    if (mounted) showAquilaSnack(context, 'AI personality updated');
  }

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Scaffold(
      backgroundColor: ext.bgBase,
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<AquilaUser?>(
        stream: AuthService.instance.userStream(widget.uid),
        builder: (context, snap) {
          final user = snap.data ?? AquilaUser.empty();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _header(ext, user),
              const SizedBox(height: 20),
              Text('STATS', style: ext.monoMicro(11, color: AquilaColors.accent)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _stat(ext, '🔥', '${user.streak}', 'Day streak'),
                  const SizedBox(width: 10),
                  _stat(ext, '💬', '${user.topics.length}', 'Topics'),
                  const SizedBox(width: 10),
                  _stat(ext, '🎯', user.isPro ? 'PRO' : 'FREE', 'Plan'),
                ],
              ),
              const SizedBox(height: 24),
              _section(ext, 'AI PERSONALITY',
                  'The personality that shapes how Aquila talks to you.'),
              const SizedBox(height: 10),
              for (final p in _personalities) _personalityTile(ext, p, user),
              const SizedBox(height: 20),
              _section(ext, 'FUTURE ME LETTER',
                  'Write to your future self — Aquila keeps it safe.'),
              const SizedBox(height: 10),
              _futureMeTile(ext, user),
            ],
          );
        },
      ),
    );
  }

  Widget _header(AquilaThemeExt ext, AquilaUser user) {
    final initial = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : (user.email.isNotEmpty ? user.email[0].toUpperCase() : 'A');
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AquilaColors.accent, AquilaColors.accent2],
            ),
          ),
          child: Text(
            initial,
            style: const TextStyle(
              fontFamily: AquilaColors.fontMain,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AquilaColors.avatarText,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName.isEmpty ? 'Aquila Learner' : user.displayName,
                style: const TextStyle(
                  fontFamily: AquilaColors.fontMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AquilaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                style: TextStyle(
                  fontFamily: AquilaColors.fontMono,
                  fontSize: 11,
                  color: ext.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: (user.isPro ? AquilaColors.accent2 : AquilaColors.accent)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user.isPro ? 'PRO MEMBER' : 'FREE',
                  style: TextStyle(
                    fontFamily: AquilaColors.fontMono,
                    fontSize: 9,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w700,
                    color: user.isPro ? AquilaColors.accent2 : AquilaColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: _logout,
          icon: const Icon(Icons.logout),
        ),
      ],
    );
  }

  Widget _stat(AquilaThemeExt ext, String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: ext.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ext.border),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontFamily: AquilaColors.fontMono,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AquilaColors.accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(label.toUpperCase(), style: ext.monoMicro(9)),
          ],
        ),
      ),
    );
  }

  Widget _section(AquilaThemeExt ext, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: ext.monoMicro(11, color: AquilaColors.accent)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12.5, color: ext.textSecondary),
        ),
      ],
    );
  }

  Widget _futureMeTile(AquilaThemeExt ext, AquilaUser user) {
    final hasLetter = user.futureMeLetter.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ext.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border),
      ),
      child: Row(
        children: [
          Icon(Icons.mail_outline, color: hasLetter ? AquilaColors.green : AquilaColors.accent2),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasLetter
                  ? 'Your Future Me letter is saved. (Not editable in this build.)'
                  : 'Your Future Me letter is saved.',
              style: TextStyle(
                fontFamily: AquilaColors.fontMain,
                fontSize: 13.5,
                color: ext.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _personalityTile(
      AquilaThemeExt ext, (String, String, String, String) p, AquilaUser user) {
    final (id, emoji, name, desc) = p;
    final selected = user.personality == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _setPersonality(selected ? '' : id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AquilaColors.accent.withValues(alpha: 0.08)
                : ext.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AquilaColors.accent : ext.border,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontFamily: AquilaColors.fontMain,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ext.textPrimary,
                      ),
                    ),
                    Text(
                      desc,
                      style: TextStyle(fontSize: 12, color: ext.textSecondary),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AquilaColors.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}