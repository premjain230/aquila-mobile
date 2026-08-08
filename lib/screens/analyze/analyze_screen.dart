import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/quiz_attempt_model.dart';
import '../../services/quiz_service.dart';
import '../../theme/aquila_theme.dart';

class AnalyzeScreen extends StatelessWidget {
  final String uid;
  const AnalyzeScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Scaffold(
      backgroundColor: ext.bgBase,
      appBar: AppBar(title: const Text('Analyze')),
      body: StreamBuilder<List<QuizAttempt>>(
        stream: QuizService.instance.attemptsStream(uid),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.active) {
            return Center(
              child: CircularProgressIndicator(color: AquilaColors.accent),
            );
          }
          return _Dashboard(attempts: snap.data ?? []);
        },
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  final List<QuizAttempt> attempts;
  const _Dashboard({required this.attempts});

  _Stats get _stats {
    final scores = attempts.map((a) => a.percentage).toList();
    final total = scores.length;
    final avg = total == 0
        ? 0.0
        : scores.reduce((a, b) => a + b) / total;
    final best = scores.isEmpty ? 0.0 : scores.reduce(math.max);
    return _Stats(attempts: total, avg: avg, best: best);
  }

  Map<String, num> get _subjectBreakdown {
    final sums = <String, num>{};
    final counts = <String, int>{};
    for (final a in attempts) {
      sums[a.subject] = (sums[a.subject] ?? 0) + a.percentage;
      counts[a.subject] = (counts[a.subject] ?? 0) + 1;
    }
    return sums.map((k, v) => MapEntry(k, v / counts[k]!));
  }

  List<_Achievement> get _achievements {
    final total = attempts.length;
    final avg = _stats.avg;
    final highScore = attempts.any((a) => a.percentage >= 90);
    return [
      _Achievement('First Steps', 'Complete 1 quiz', total >= 1),
      _Achievement('Getting Serious', 'Complete 5 quizzes', total >= 5),
      _Achievement('Elite Learner', 'Complete 15 quizzes', total >= 15),
      _Achievement('Sharp Mind', 'Average 75%+', avg >= 75),
      _Achievement('High Roller', 'Score 90%+ once', highScore),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    if (attempts.isEmpty) return _empty(ext);

    final stats = _stats;
    final subjects = _subjectBreakdown;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text('OVERVIEW', style: ext.monoMicro(11, color: AquilaColors.accent)),
        const SizedBox(height: 10),
        Row(
          children: [
            _statCard(ext, '${stats.attempts}', 'Attempts'),
            const SizedBox(width: 10),
            _statCard(ext, '${stats.avg.round()}%', 'Avg Score'),
            const SizedBox(width: 10),
            _statCard(ext, '${stats.best.round()}%', 'Best'),
          ],
        ),
        const SizedBox(height: 20),
        Text('SCORE TREND', style: ext.monoMicro(11, color: AquilaColors.accent)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ext.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ext.border),
          ),
          child: _Sparkline(
            values: attempts
                .map((a) =>
                    a.totalQuestions == 0 ? 0.0 : a.score / a.totalQuestions)
                .toList(),
          ),
        ),
        if (subjects.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('BY SUBJECT', style: ext.monoMicro(11, color: AquilaColors.accent)),
          const SizedBox(height: 10),
          for (final e in subjects.entries)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ext.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ext.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AquilaColors.subjectColor(e.key.codeUnitAt(0))
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      e.key.toUpperCase(),
                      style: TextStyle(
                        fontFamily: AquilaColors.fontMono,
                        fontSize: 10,
                        color: AquilaColors.subjectColor(e.key.codeUnitAt(0)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (e.value / 100).clamp(0.0, 1.0),
                        minHeight: 7,
                        backgroundColor: ext.bgInput,
                        valueColor: AlwaysStoppedAnimation(
                          AquilaColors.subjectColor(e.key.codeUnitAt(0)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${e.value.round()}%',
                      style: ext.monoMicro(11, color: ext.textSecondary)),
                ],
              ),
            ),
        ],
        const SizedBox(height: 20),
        Text('ACHIEVEMENTS', style: ext.monoMicro(11, color: AquilaColors.accent)),
        const SizedBox(height: 10),
        for (final a in _achievements)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: ext.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: a.earned
                    ? AquilaColors.accent.withValues(alpha: 0.5)
                    : ext.border,
              ),
            ),
            child: Row(
              children: [
                Icon(a.earned ? Icons.emoji_events : Icons.lock_outline,
                    color: a.earned ? AquilaColors.accent4 : ext.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    a.title,
                    style: TextStyle(
                      fontFamily: AquilaColors.fontMain,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: a.earned ? ext.textPrimary : ext.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _statCard(AquilaThemeExt ext, String value, String label) {
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
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AquilaColors.accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(label.toUpperCase(),
                style: ext.monoMicro(9, color: ext.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _empty(AquilaThemeExt ext) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights, size: 56,
                color: AquilaColors.accent.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'No data yet',
              style: TextStyle(
                fontFamily: AquilaColors.fontMain,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ext.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Finish a quiz to see your analytics here.',
              style: TextStyle(
                fontFamily: AquilaColors.fontMain,
                fontSize: 14,
                color: ext.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stats {
  final int attempts;
  final double avg;
  final double best;
  const _Stats({required this.attempts, required this.avg, required this.best});
}

class _Achievement {
  final String title;
  final String label;
  final bool earned;
  const _Achievement(this.title, this.label, this.earned);
}

/// Small custom-painted trend area chart (no third-party chart dependency).
class _Sparkline extends StatelessWidget {
  final List<double> values;
  const _Sparkline({required this.values});

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    if (values.isEmpty) {
      return SizedBox(
        height: 70,
        child: Center(
          child:
              Text('No trend yet', style: ext.monoMicro(11, color: ext.textMuted)),
        ),
      );
    }
    return CustomPaint(
      size: const Size(double.infinity, 70),
      painter: _SparkPainter(values, ext.border, AquilaColors.accent),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final Color grid;
  final Color line;
  _SparkPainter(this.values, this.grid, this.line);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid;
    canvas.drawLine(
        Offset(0, size.height - 1), Offset(size.width, size.height - 1), gridPaint);
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), gridPaint);

    final stepX = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i].clamp(0.0, 1.0) * (size.height - 4));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = line;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.values != values;
}