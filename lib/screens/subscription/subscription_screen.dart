import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';

/// Subscription screen: compares Free vs Aquila Pro and lets the user request
/// Pro access (mirrors web subscription plan + `proRequests/{uid}`).
class SubscriptionScreen extends StatefulWidget {
  final String uid;
  const SubscriptionScreen({super.key, required this.uid});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _db = FirebaseFirestore.instance;
  bool _requesting = false;
  bool _alreadyRequested = false;

  @override
  void initState() {
    super.initState();
    _checkRequested();
  }

  Future<void> _checkRequested() async {
    final snap =
        await _db.collection('proRequests').doc(widget.uid).get();
    if (mounted) setState(() => _alreadyRequested = snap.exists);
  }

  Future<void> _requestPro() async {
    setState(() => _requesting = true);
    try {
      final user = await AuthService.instance.userOnce(widget.uid);
      await _db.collection('proRequests').doc(widget.uid).set({
        'uid': widget.uid,
        'email': user?.email ?? '',
        'name': user?.displayName ?? '',
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      if (mounted) {
        setState(() => _alreadyRequested = true);
        showAquilaSnack(context, 'Pro access requested. We\'ll upgrade you soon!');
      }
    } catch (e) {
      if (mounted) {
        showAquilaSnack(context, 'Could not submit request.', error: true);
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Scaffold(
      backgroundColor: ext.bgBase,
      appBar: AppBar(title: const Text('Subscription')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('CHOOSE YOUR PLAN', style: ext.monoMicro(11, color: AquilaColors.accent)),
          const SizedBox(height: 14),
          _freeCard(ext),
          const SizedBox(height: 14),
          _proCard(ext),
        ],
      ),
    );
  }

  Widget _freeCard(AquilaThemeExt ext) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ext.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ext.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('FREE',
                  style: TextStyle(
                    fontFamily: AquilaColors.fontMono,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ext.textPrimary,
                  )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ext.bgInput,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('CURRENT', style: ext.monoMicro(9, color: ext.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₹0 / lifetime',
            style: TextStyle(
              fontFamily: AquilaColors.fontMain,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: ext.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _perk(ext, '20 AI chat messages / day'),
          _perk(ext, '20 daily analyses'),
          _perk(ext, '30 planner minutes / day'),
        ],
      ),
    );
  }

  Widget _proCard(AquilaThemeExt ext) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ext.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AquilaColors.accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AquilaColors.accent.withValues(alpha: 0.12),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('AQUILA PRO',
                  style: TextStyle(
                    fontFamily: AquilaColors.fontMono,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AquilaColors.accent,
                  )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AquilaColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('UNLIMITED', style: ext.monoMicro(9, color: AquilaColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Unlock everything',
            style: TextStyle(
              fontFamily: AquilaColors.fontMain,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: ext.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _perk(ext, 'Unlimited chat messages'),
          _perk(ext, 'Unlimited analyses'),
          _perk(ext, 'Unlimited planner time'),
          _perk(ext, 'Priority responses'),
          const SizedBox(height: 18),
          AquilaGradientButton(
            label: _alreadyRequested
                ? 'Request Submitted'
                : _requesting
                    ? 'Requesting…'
                    : 'Request Pro Access',
            loading: _requesting,
            onPressed: _alreadyRequested ? null : _requestPro,
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Paid billing is coming soon — request early access today.',
              style: TextStyle(fontSize: 12, color: ext.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _perk(AquilaThemeExt ext, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: AquilaColors.green),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, color: ext.textPrimary))),
        ],
      ),
    );
  }
}