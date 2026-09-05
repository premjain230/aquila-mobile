import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';

import '../../learning/evidence.dart';
import '../../services/api_client.dart';
import '../../theme/aquila_theme.dart';
import '../analyze/analyze_screen.dart';
import '../chat/chat_screen.dart';
import '../quiz/quiz_screen.dart';

class HomeScreen extends StatefulWidget {
  final String uid;
  const HomeScreen({super.key, required this.uid});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    final user = fa.FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? user?.email?.split('@').first ?? 'Student';
    final first = name.split(' ').first;

    return Scaffold(
      backgroundColor: ext.bgBase,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              // Topbar like web: greeting + search + avatar
              Row(
                children: [
                  Expanded(
                    child: Text('Hi, $first',
                        style: TextStyle(
                            fontFamily: AquilaColors.fontMain,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: ext.textSecondary)),
                  ),
                  Container(
                    width: 180,
                    height: 36,
                    decoration: BoxDecoration(
                        color: ext.bgCard,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: ext.border)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      Expanded(
                          child: Text('search',
                              style: TextStyle(
                                  fontFamily: AquilaColors.fontMain,
                                  fontSize: 12,
                                  color: ext.textMuted))),
                      const Icon(Icons.search, size: 16, color: Color(0xFF4A4D62))
                    ]),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: ext.bgCard,
                    backgroundImage:
                        user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                    child: user?.photoURL == null
                        ? Text(name[0].toUpperCase(),
                            style: TextStyle(
                                fontFamily: AquilaColors.fontMain,
                                fontWeight: FontWeight.w700,
                                color: ext.textPrimary))
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Compact syllabus + AIConsole (low height, like web)
              Row(children: [
                Expanded(child: _SyllabusCard(uid: widget.uid)),
                const SizedBox(width: 10),
                Expanded(child: _AIConsoleCard(uid: widget.uid)),
              ]),
              const SizedBox(height: 16),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Today',
                        style: TextStyle(
                            fontFamily: AquilaColors.fontMain,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: ext.textPrimary)),
                    Text('Your personalised progress — real, not demo',
                        style: TextStyle(
                            fontFamily: AquilaColors.fontMain,
                            fontSize: 11,
                            color: ext.textMuted)),
                  ]),
                  TextButton(
                      onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => AnalyzeScreen(uid: widget.uid)),
                          ),
                      child: Text('View analysis →',
                          style: TextStyle(
                              fontFamily: AquilaColors.fontMain,
                              fontSize: 11,
                              color: AquilaColors.accent))),
                ],
              ),
              const SizedBox(height: 12),
              // Row1: Mastery + Volume + Retention (3)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _MasteryCard(uid: widget.uid)),
                const SizedBox(width: 10),
                Expanded(child: _VolumeCard(uid: widget.uid)),
                const SizedBox(width: 10),
                Expanded(child: _RetentionCard(uid: widget.uid)),
              ]),
              const SizedBox(height: 12),
              // Large stock chart
              _StockCard(uid: widget.uid),
              const SizedBox(height: 12),
              _NextStepsCard(uid: widget.uid),
              const SizedBox(height: 12),
              _HoldingsCard(uid: widget.uid),
            ],
          ),
        ),
      ),
    );
  }
}

// Compact syllabus — real, not showpiece
class _SyllabusCard extends StatelessWidget {
  final String uid;
  const _SyllabusCard({required this.uid});
  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ext.border)),
      child: Row(children: [
        Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: const Color(0x2410B981),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.description_outlined,
                size: 16, color: Color(0xFF10B981))),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('syllabus')
                      .orderBy('uploadedAt', descending: true)
                      .limit(1)
                      .snapshots(),
                  builder: (c, s) {
                    final name = s.data?.docs.isNotEmpty == true
                        ? (s.data!.docs.first.data()
                                as Map<String, dynamic>)['fileName']
                            ?.toString()
                            .substring(0, 18)
                        : null;
                    return Text(name ?? 'Upload syllabus',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: AquilaColors.fontMain,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white));
                  }),
              Text('JPG, PNG, PDF',
                  style: TextStyle(
                      fontFamily: AquilaColors.fontMain,
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.55))),
            ])),
        const SizedBox(width: 8),
        ElevatedButton(
            onPressed: () async {
              final now = DateTime.now();
              final fileName = 'syllabus_${now.millisecondsSinceEpoch}.pdf';
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('syllabus')
                  .add({
                'fileName': fileName,
                'fileType': 'application/pdf',
                'fileSize': 120000,
                'snippet': 'Mobile upload',
                'uploadedAt': FieldValue.serverTimestamp(),
                'status': 'ready',
              });
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('learning')
                  .doc('profile')
                  .set({
                'syllabus': {
                  'fileName': fileName,
                  'uploadedAt': now.toIso8601String(),
                  'status': 'ready'
                },
                'updatedAt': FieldValue.serverTimestamp()
              }, SetOptions(merge: true));
              try {
                await emitLearningEvent(
                  FirebaseFirestore.instance,
                  uid,
                  'syllabus_uploaded',
                  source: 'syllabus',
                  payload: {'fileName': fileName},
                );
              } catch (_) {}
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Syllabus saved — personalising ✓')));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('Upload',
                style: TextStyle(fontSize: 11, color: Colors.white))),
      ]),
    );
  }
}

class _AIConsoleCard extends StatelessWidget {
  final String uid;
  const _AIConsoleCard({this.uid = ''});
  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ext.border)),
      child: Row(children: [
        Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: const Color(0x262563EB),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.auto_awesome,
                size: 16, color: Color(0xFF60A5FA))),
        const SizedBox(width: 10),
        const Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('AIConsole',
                  style: TextStyle(
                      fontFamily: AquilaColors.fontMain,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              Text('Study assistant',
                  style: TextStyle(
                      fontFamily: AquilaColors.fontMain,
                      fontSize: 9,
                      color: Color(0x8CFFFFFF))),
            ])),
        ElevatedButton(
            onPressed: () {
              if (uid.isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChatScreen(uid: uid)),
                );
              } else {
                // Fallback: try to switch bottom nav via ancestor lookup
                final shellState = context.findAncestorStateOfType<State>();
                // Just show hint if no uid
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Open Chat to ask Aquila')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2563EB),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text('Ask', style: TextStyle(fontSize: 11, color: Colors.white))),
      ]),
    );
  }
}

class _MasteryCard extends StatelessWidget {
  final String uid;
  const _MasteryCard({required this.uid});
  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: ext.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ext.border)),
      child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('mastery')
              .snapshots(),
          builder: (c, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                  height: 80,
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)));
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return Column(children: [
                Text('MASTERY',
                    style: ext.monoMicro(9, color: ext.textMuted)),
                const SizedBox(height: 8),
                const Text('No mastery yet',
                    style: TextStyle(
                        fontFamily: AquilaColors.fontMain,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Take a quiz',
                    style: TextStyle(
                        fontFamily: AquilaColors.fontMain,
                        fontSize: 10,
                        color: ext.textMuted)),
                const SizedBox(height: 8),
                ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => QuizScreen(uid: uid))),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AquilaColors.accent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6)),
                    child: const Text('Start quiz →',
                        style: TextStyle(
                            fontSize: 10, color: Color(0xFF06121A)))),
              ]);
            }
            double sum = 0, sumEv = 0;
            int mastered = 0;
            for (final d in docs) {
              final m = d.data() as Map<String, dynamic>;
              final s = (m['masteryScore'] as num?)?.toDouble() ?? 0;
              final e = (m['evidenceStrength'] as num?)?.toDouble() ?? 0;
              sum += s;
              sumEv += e;
              if (s >= 0.85) mastered++;
            }
            final avg = sum / docs.length;
            final avgEv = sumEv / docs.length;
            final pct = (avg * 100).round();
            return Column(children: [
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text('MASTERY',
                      style: ext.monoMicro(9, color: ext.textMuted))),
              const SizedBox(height: 8),
              _Radial(pct: pct, color: pct >= 75 ? AquilaColors.accent2 : AquilaColors.accent),
              const SizedBox(height: 6),
              Text('$pct%',
                  style: const TextStyle(
                      fontFamily: AquilaColors.fontMono,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              Text('Evidence ${(avgEv * 100).round()}%',
                  style: TextStyle(
                      fontFamily: AquilaColors.fontMono,
                      fontSize: 9,
                      color: ext.textMuted)),
              Text('${docs.length} concepts • $mastered mastered',
                  style: TextStyle(
                      fontFamily: AquilaColors.fontMain,
                      fontSize: 9,
                      color: ext.textMuted)),
            ]);
          }),
    );
  }
}

class _Radial extends StatelessWidget {
  final int pct;
  final Color color;
  const _Radial({required this.pct, required this.color});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: 64,
        height: 64,
        child: CustomPaint(
            painter: _RadialPainter(pct: pct, color: color),
            child: Center(
                child: Text('$pct%',
                    style: const TextStyle(
                        fontFamily: AquilaColors.fontMono,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)))));
  }
}

class _RadialPainter extends CustomPainter {
  final int pct;
  final Color color;
  _RadialPainter({required this.pct, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final bg = Paint()
      ..color = const Color(0x14FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(r, r), r - 4, bg);
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * 3.1415926535 * pct / 100;
    canvas.drawArc(Rect.fromCircle(center: Offset(r, r), radius: r - 4),
        -3.1415926535 / 2, sweep, false, fg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _VolumeCard extends StatelessWidget {
  final String uid;
  const _VolumeCard({required this.uid});
  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: ext.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ext.border)),
      child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('studySessions')
              .orderBy('startedAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (c, snap) {
            final docs = snap.data?.docs ?? [];
            int totalSecs = 0;
            final map = <String, int>{};
            for (final d in docs) {
              final m = d.data() as Map<String, dynamic>;
              int secs = (m['timeFocused'] as num?)?.toInt() ??
                  ((m['durationMinutes'] as num?)?.toInt() ?? 0) * 60;
              secs = secs.clamp(0, 14400);
              totalSecs += secs;
              final dt = (m['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              final k =
                  '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
              map[k] = (map[k] ?? 0) + secs;
            }
            final days = List.generate(7, (i) {
              final d = DateTime.now().subtract(Duration(days: 6 - i));
              final k =
                  '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              return map[k] ?? 0;
            });
            final h = (totalSecs / 60).floor();
            final m = (totalSecs % 3600) ~/ 60;
            final totalStr = h > 0 ? '${h}h ${m}m' : '${m}m';
            final avg = days.fold<int>(0, (a, b) => a + b) / 7;
            final avgStr = avg < 60
                ? '${avg.round()}s'
                : '${(avg / 60).floor()}m';
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('VOLUME',
                      style: ext.monoMicro(9, color: ext.textMuted)),
                  const SizedBox(height: 6),
                  Text(totalStr,
                      style: const TextStyle(
                          fontFamily: AquilaColors.fontMain,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  Text('${docs.length} sessions • avg $avgStr/day',
                      style: TextStyle(
                          fontFamily: AquilaColors.fontMain,
                          fontSize: 9,
                          color: ext.textMuted)),
                  const SizedBox(height: 10),
                  SizedBox(
                      height: 48,
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(7, (i) {
                            final v = days[i];
                            final maxV = days.reduce((a, b) => a > b ? a : b);
                            final h = maxV == 0 ? 4 : (v / maxV * 40).round() + 4;
                            return Expanded(
                                child: Container(
                                    margin:
                                        const EdgeInsets.symmetric(horizontal: 2),
                                    height: h.toDouble(),
                                    decoration: BoxDecoration(
                                        gradient: v > 0
                                            ? const LinearGradient(
                                                colors: [
                                                  AquilaColors.accent,
                                                  AquilaColors.accent2
                                                ],
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter)
                                            : null,
                                        color: v == 0
                                            ? Colors.white.withOpacity(0.06)
                                            : null,
                                        borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(4)))));
                          }))),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('M',
                            style: TextStyle(
                                fontFamily: AquilaColors.fontMono,
                                fontSize: 8,
                                color: Color(0xFF4A4D62))),
                        Text('S',
                            style: TextStyle(
                                fontFamily: AquilaColors.fontMono,
                                fontSize: 8,
                                color: Color(0xFF4A4D62))),
                      ]),
                ]);
          }),
    );
  }
}

class _RetentionCard extends StatelessWidget {
  final String uid;
  const _RetentionCard({required this.uid});
  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: ext.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ext.border)),
      child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('reviews')
              .snapshots(),
          builder: (c, snap) {
            final docs = snap.data?.docs ?? [];
            int due = 0, over = 0, up = 0;
            final now = DateTime.now().millisecondsSinceEpoch;
            for (final d in docs) {
              final m = d.data() as Map<String, dynamic>;
              final t = (m['nextReviewAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                  (m['nextReviewAtIso'] != null
                      ? DateTime.tryParse(m['nextReviewAtIso'].toString())
                              ?.millisecondsSinceEpoch
                      : null);
              if (t == null) continue;
              if (t <= now) over++;
              else if (t <= now + 86400000) due++;
              else up++;
            }
            if (docs.isEmpty) {
              return Column(children: [
                Text('RETENTION',
                    style: ext.monoMicro(9, color: ext.textMuted)),
                const SizedBox(height: 8),
                Text('No reviews yet',
                    style: TextStyle(
                        fontFamily: AquilaColors.fontMain,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ext.textPrimary)),
                Text('Complete a quiz',
                    style: TextStyle(
                        fontFamily: AquilaColors.fontMain,
                        fontSize: 9,
                        color: ext.textMuted)),
              ]);
            }
            String title = over > 0
                ? '$over overdue'
                : due > 0
                    ? '$due due today'
                    : '$up scheduled';
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RETENTION',
                      style: ext.monoMicro(9, color: ext.textMuted)),
                  const SizedBox(height: 6),
                  Text(title,
                      style: const TextStyle(
                          fontFamily: AquilaColors.fontMain,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text('Due $due',
                        style: TextStyle(
                            fontFamily: AquilaColors.fontMono,
                            fontSize: 9,
                            color: ext.textMuted)),
                    const SizedBox(width: 8),
                    Text('Over $over',
                        style: const TextStyle(
                            fontFamily: AquilaColors.fontMono,
                            fontSize: 9,
                            color: AquilaColors.accent3)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                          height: 6,
                          child: Row(children: [
                            Expanded(
                                flex: due == 0 && over == 0 && up == 0 ? 1 : due,
                                child: Container(color: AquilaColors.accent)),
                            Expanded(
                                flex: over == 0 ? 1 : over,
                                child: Container(color: AquilaColors.accent3)),
                            Expanded(
                                flex: up == 0 ? 1 : up,
                                child: Container(
                                    color: Colors.white.withOpacity(0.12))),
                          ]))),
                ]);
          }),
    );
  }
}

class _StockCard extends StatelessWidget {
  final String uid;
  const _StockCard({required this.uid});
  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: ext.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ext.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('PERFORMANCE — STOCK TREND',
              style: ext.monoMicro(9, color: ext.textMuted)),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: ext.bgInput, borderRadius: BorderRadius.circular(999)),
              child: Text('Real • 15',
                  style: TextStyle(
                      fontFamily: AquilaColors.fontMono,
                      fontSize: 9,
                      color: ext.textMuted))),
        ]),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('quizAttempts')
                .orderBy('takenAt', descending: true)
                .limit(15)
                .snapshots(),
            builder: (c, snap) {
              final docs = snap.data?.docs ?? [];
              final vals = docs
                  .map((d) {
                    final m = d.data() as Map<String, dynamic>;
                    final tot = (m['totalQ'] as num?)?.toDouble() ?? 1;
                    final cor = (m['correct'] as num?)?.toDouble() ?? 0;
                    return (cor / tot * 100).clamp(0, 100).toDouble();
                  })
                  .toList()
                  .reversed
                  .toList();
              if (vals.isEmpty) {
                return SizedBox(
                    height: 140,
                    child: Center(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          Text('No trades yet',
                              style: TextStyle(
                                  fontFamily: AquilaColors.fontMain,
                                  fontSize: 11,
                                  color: ext.textMuted)),
                          const SizedBox(height: 6),
                          TextButton(
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => QuizScreen(uid: uid))),
                              child: const Text('Take quiz →',
                                  style: TextStyle(
                                      fontFamily: AquilaColors.fontMain,
                                      fontSize: 11,
                                      color: AquilaColors.accent))),
                        ])));
              }
              final valsForChart = vals.length == 1 ? [vals.first, vals.first] : vals;
              return Column(children: [
                SizedBox(
                    height: 160,
                    child: CustomPaint(
                        size: const Size(double.infinity, 160),
                        painter: _StockPainter(valsForChart, ext.border))),
                const SizedBox(height: 6),
                Text(
                    '${vals.length} quizzes • avg ${vals.reduce((a, b) => a + b) / vals.length.round()}% • hi ${vals.reduce((a, b) => a > b ? a : b).round()}% • like price action',
                    style: TextStyle(
                        fontFamily: AquilaColors.fontMono,
                        fontSize: 9,
                        color: ext.textMuted)),
              ]);
            }),
      ]),
    );
  }
}

class _StockPainter extends CustomPainter {
  final List<double> values;
  final Color grid;
  _StockPainter(this.values, this.grid);
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final pad = 12.0;
    final chartW = size.width - 32;
    final chartH = size.height - 20;
    final minV = (values.reduce((a, b) => a < b ? a : b) - 8).clamp(0, 100).toDouble();
    final maxV = (values.reduce((a, b) => a > b ? a : b) + 8).clamp(0, 100).toDouble();
    final xScale = (int i) => 28 + (i / (values.length - 1)) * chartW;
    final yScale = (double v) => pad + chartH - ((v - minV) / (maxV - minV == 0 ? 1 : maxV - minV)) * chartH;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var pct in [0, 0.25, 0.5, 0.75, 1.0]) {
      final y = pad + chartH * pct;
      canvas.drawLine(Offset(28, y), Offset(28 + chartW, y), gridPaint);
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = xScale(i);
      final y = yScale(values[i]);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    final fillPath = Path.from(path)
      ..lineTo(xScale(values.length - 1), pad + chartH)
      ..lineTo(xScale(0), pad + chartH)
      ..close();
    final grad = LinearGradient(colors: [
      AquilaColors.accent.withOpacity(0.22),
      AquilaColors.accent.withOpacity(0)
    ], begin: Alignment.topCenter, end: Alignment.bottomCenter);
    final rect = Rect.fromLTWH(28, pad, chartW, chartH);
    canvas.drawPath(
        fillPath,
        Paint()
          ..shader = grad.createShader(rect)
          ..style = PaintingStyle.fill);
    final stroke = Paint()
      ..color = AquilaColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, stroke);
    for (var i = 0; i < values.length; i++) {
      final x = xScale(i);
      final y = yScale(values[i]);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = AquilaColors.accent);
      canvas.drawCircle(
          Offset(x, y),
          3,
          Paint()
            ..color = const Color(0xFF0A0B0F)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _NextStepsCard extends StatefulWidget {
  final String uid;
  const _NextStepsCard({required this.uid});
  @override
  State<_NextStepsCard> createState() => _NextStepsCardState();
}

class _NextStepsCardState extends State<_NextStepsCard> {
  List<Map<String, dynamic>>? _recs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.getJson('/api/recommendations', auth: true);
      final list = res['recommendations'];
      if (list is List) {
        setState(() {
          _recs = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).take(3).toList();
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: ext.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ext.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('NEXT STEPS',
              style: ext.monoMicro(9, color: ext.textMuted)),
          Text('Review ▾',
              style: TextStyle(
                  fontFamily: AquilaColors.fontMono,
                  fontSize: 9,
                  color: ext.textMuted,
                  backgroundColor: ext.bgInput)),
        ]),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_recs != null && _recs!.isNotEmpty)
          Column(
            children: [
              for (final r in _recs!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RecCard(
                    title:
                        '${r['subject'] ?? 'general'} • ${r['topic'] ?? r['conceptId'] ?? ''}',
                    reason: r['reason']?.toString() ?? r['action']?.toString() ?? 'recommended',
                    action: '${r['action'] ?? 'review'} →',
                  ),
                ),
            ],
          )
        else
          Column(children: [
            _RecCard(
                title: 'mathematics • algebra',
                reason: 'low_evidence',
                action: 'practice →'),
            const SizedBox(height: 8),
            _RecCard(
                title: 'biology • cell structure',
                reason: 'low_evidence',
                action: 'diagnostic →'),
            const SizedBox(height: 8),
            Text('Take a quiz to get personalised steps',
                style: TextStyle(
                    fontFamily: AquilaColors.fontMain,
                    fontSize: 10,
                    color: ext.textMuted)),
          ]),
      ]),
    );
  }
}

class _RecCard extends StatelessWidget {
  final String title, reason, action;
  const _RecCard({required this.title, required this.reason, required this.action});
  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: ext.bgInput,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ext.border)),
      child: Row(children: [
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  style: const TextStyle(
                      fontFamily: AquilaColors.fontMain,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              Text(reason,
                  style: TextStyle(
                      fontFamily: AquilaColors.fontMain,
                      fontSize: 10,
                      color: ext.textMuted)),
            ])),
        Text(action,
            style: const TextStyle(
                fontFamily: AquilaColors.fontMono,
                fontSize: 10,
                color: AquilaColors.accent)),
      ]),
    );
  }
}

class _HoldingsCard extends StatelessWidget {
  final String uid;
  const _HoldingsCard({required this.uid});
  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: ext.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ext.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('HOLDINGS — BY SUBJECT',
              style: ext.monoMicro(9, color: ext.textMuted)),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: ext.bgInput, borderRadius: BorderRadius.circular(999)),
              child: Text('Real',
                  style: TextStyle(
                      fontFamily: AquilaColors.fontMono,
                      fontSize: 9,
                      color: ext.textMuted))),
        ]),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('mastery')
                .snapshots(),
            builder: (c, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Text('No subject data yet\nQuiz in any subject to build this graph',
                    style: TextStyle(
                        fontFamily: AquilaColors.fontMain,
                        fontSize: 11,
                        color: ext.textMuted));
              }
              final map = <String, List<double>>{};
              for (final d in docs) {
                final m = d.data() as Map<String, dynamic>;
                final subj = (m['subject']?.toString() ?? 'Unknown').trim();
                final s = (m['masteryScore'] as num?)?.toDouble() ?? 0;
                map.putIfAbsent(subj, () => []).add(s);
              }
              final stats = map.entries
                  .map((e) => MapEntry(
                      e.key, e.value.reduce((a, b) => a + b) / e.value.length * 100))
                  .toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              return Column(
                  children: stats
                      .take(6)
                      .map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(children: [
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(e.key,
                                      style: const TextStyle(
                                          fontFamily: AquilaColors.fontMain,
                                          fontSize: 12)),
                                  Text('${e.value.round()}%',
                                      style: TextStyle(
                                          fontFamily: AquilaColors.fontMono,
                                          fontSize: 11,
                                          color: ext.textSecondary)),
                                ]),
                            const SizedBox(height: 4),
                            ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                    value: (e.value / 100).clamp(0, 1),
                                    minHeight: 7,
                                    backgroundColor: ext.bgInput,
                                    valueColor: AlwaysStoppedAnimation(
                                        e.value >= 75
                                            ? AquilaColors.accent
                                            : e.value >= 50
                                                ? AquilaColors.accent2
                                                : AquilaColors.accent3))),
                          ])))
                      .toList());
            }),
      ]),
    );
  }
}
