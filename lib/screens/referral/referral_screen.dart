import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_config.dart';
import '../../models/aquila_user.dart';
import '../../services/auth_service.dart';
import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';

/// Referral screen: shows the user's referral code, share link, and (when the
/// backend dashboard responds) earnings summary.
class ReferralScreen extends StatefulWidget {
  final String uid;
  const ReferralScreen({super.key, required this.uid});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  AquilaUser? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AuthService.instance.userOnce(widget.uid);
    if (!mounted) return;
    setState(() => _user = user);
  }

  Future<void> _share(String code) async {
    final url = AppConfig.referralSignupUrl(code);
    await Share.share(
      'Join me on Aquila AI — an AI study companion that actually remembers. '
      'Use my code $code:\n$url',
    );
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: AppConfig.referralSignupUrl(code)));
    if (mounted) showAquilaSnack(context, 'Referral link copied!');
  }

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    final code = _user?.referralCode ?? '';
    return Scaffold(
      backgroundColor: ext.bgBase,
      appBar: AppBar(title: const Text('Referrals')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AquilaColors.accent.withValues(alpha: 0.18),
                  AquilaColors.accent2.withValues(alpha: 0.18),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AquilaColors.accent.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                const Text('YOUR REFERRAL CODE',
                    style: TextStyle(
                      fontFamily: AquilaColors.fontMono,
                      fontSize: 10,
                      letterSpacing: 0.5,
                      color: AquilaColors.textSecondary,
                    )),
                const SizedBox(height: 10),
                Text(
                  code.isEmpty ? '—' : code,
                  style: const TextStyle(
                    fontFamily: AquilaColors.fontMono,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: AquilaColors.accent,
                  ),
                ),
                const SizedBox(height: 16),
                if (code.isNotEmpty) ...[
                  AquilaGradientButton(
                    label: 'Share Invite',
                    onPressed: () => _share(code),
                  ),
                  const SizedBox(height: 8),
                  AquilaOutlineButton(
                    label: 'Copy Link',
                    onPressed: () => _copy(code),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('HOW IT WORKS', style: ext.monoMicro(11, color: AquilaColors.accent)),
          const SizedBox(height: 10),
          _step(ext, '1', 'Share your code with friends.'),
          _step(ext, '2', 'They sign up with your code.'),
          _step(ext, '3', 'You earn free chat days + more.'),
          const SizedBox(height: 24),
          Text('YOUR REWARDS', style: ext.monoMicro(11, color: AquilaColors.accent)),
          const SizedBox(height: 10),
          Row(
            children: [
              _reward(ext, '${_user?.bonusChats ?? 0}', 'Bonus chats'),
              const SizedBox(width: 10),
              _reward(ext, '${_user?.proDays ?? 0}', 'Pro days'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _step(AquilaThemeExt ext, String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AquilaColors.accent.withValues(alpha: 0.15),
            ),
            child: Text(
              n,
              style: const TextStyle(
                fontFamily: AquilaColors.fontMono,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AquilaColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14, color: ext.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _reward(AquilaThemeExt ext, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: ext.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ext.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: AquilaColors.fontMono,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AquilaColors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(label.toUpperCase(), style: ext.monoMicro(9)),
          ],
        ),
      ),
    );
  }
}