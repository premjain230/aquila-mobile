import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../learning/evidence.dart';
import '../../services/api_client.dart';
import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';

/// Study Session — mirrors web `study-session.html` + `study-session.js`
///
/// Flow: Setup (subject/topic/duration/goal) → Start → POST /api/study-session
/// → creates `users/{uid}/studySessions` doc with plan, starts timer,
/// persists every 10s, allows pause/resume, end completes session.
class StudySessionScreen extends StatefulWidget {
  final String uid;
  const StudySessionScreen({super.key, required this.uid});

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  final _db = FirebaseFirestore.instance;

  // Setup
  final _subject = TextEditingController();
  final _topic = TextEditingController();
  final _goal = TextEditingController();
  int _duration = 25;
  bool _starting = false;

  // Session
  DocumentReference<Map<String, dynamic>>? _sessionRef;
  Map<String, dynamic>? _plan;
  int _elapsed = 0;
  bool _paused = false;
  Timer? _timer;
  DateTime? _startedAt;
  String _sessionSubject = '';
  String _sessionTopic = '';

  @override
  void dispose() {
    _subject.dispose();
    _topic.dispose();
    _goal.dispose();
    _timer?.cancel();
    // If user leaves while session active, mark as abandoned and persist time
    if (_sessionRef != null) {
      _sessionRef!.set({
        'status': 'abandoned',
        'timeFocused': _elapsed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    super.dispose();
  }

  Future<void> _start() async {
    final subject = _subject.text.trim();
    final topic = _topic.text.trim();
    if (subject.isEmpty || topic.isEmpty) {
      showAquilaSnack(context, 'Enter subject and topic', error: true);
      return;
    }
    setState(() => _starting = true);
    try {
      // Call backend to generate guided plan (same as web)
      final res = await ApiClient.instance.postJson(
        '/api/study-session',
        {
          'subject': subject,
          'topic': topic,
          'durationMinutes': _duration,
          'goal': _goal.text.trim(),
        },
        auth: true,
      );
      final plan = res['plan'] ?? res;
      if (plan is! Map) throw const ApiException('Bad plan from server');

      // Create Firestore session doc (mirrors web)
      final ref = _db.collection('users').doc(widget.uid).collection('studySessions').doc();
      await ref.set({
        'subject': subject,
        'topic': topic,
        'durationMinutes': _duration,
        'goal': _goal.text.trim(),
        'plan': Map<String, dynamic>.from(plan as Map),
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'timeFocused': 0,
      });

      // Learning events
      try {
        await emitLearningEvent(_db, widget.uid, 'study_session_started',
            subject: subject, topic: topic, source: 'study_session', payload: {'durationMinutes': _duration});
        await emitLearningEvent(_db, widget.uid, 'lesson_started',
            subject: subject, topic: topic, source: 'study_session');
      } catch (_) {}

      setState(() {
        _sessionRef = ref;
        _plan = Map<String, dynamic>.from(plan);
        _elapsed = 0;
        _paused = false;
        _startedAt = DateTime.now();
        _sessionSubject = subject;
        _sessionTopic = topic;
      });
      _startTimer();
    } on ApiException catch (e) {
      showAquilaSnack(context, e.message, error: true);
    } catch (e) {
      showAquilaSnack(context, 'Could not start session: $e', error: true);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_paused || _sessionRef == null) return;
      _elapsed++;
      if (mounted) setState(() {});
      if (_elapsed % 10 == 0) {
        try {
          await _sessionRef!.set({
            'timeFocused': _elapsed,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }
      if (_elapsed >= _duration * 60) {
        _end(completed: true);
      }
    });
  }

  Future<void> _end({bool completed = true}) async {
    _timer?.cancel();
    if (_sessionRef != null) {
      try {
        await _sessionRef!.set({
          'status': completed ? 'completed' : 'abandoned',
          'timeFocused': _elapsed,
          'completedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (_elapsed >= 60) {
          await emitLearningEvent(_db, widget.uid, 'study_session_completed',
              subject: _sessionSubject, topic: _sessionTopic, source: 'study_session', payload: {'timeFocused': _elapsed});
        }
        if (_elapsed >= 120) {
          await emitLearningEvent(_db, widget.uid, 'topic_reviewed',
              subject: _sessionSubject, topic: _sessionTopic, source: 'study_session');
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _sessionRef = null;
        _plan = null;
        _elapsed = 0;
        _paused = false;
      });
      showAquilaSnack(context, completed ? 'Session completed ✓' : 'Session ended');
    }
  }

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    if (_sessionRef != null && _plan != null) {
      return _sessionView(ext);
    }
    return _setupView(ext);
  }

  Widget _setupView(AquilaThemeExt ext) {
    return Scaffold(
      backgroundColor: ext.bgBase,
      appBar: AppBar(title: const Text('Study Session')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('START A FOCUSED SESSION', style: ext.monoMicro(11, color: AquilaColors.accent)),
            const SizedBox(height: 14),
            const MonoLabel('Subject'),
            const SizedBox(height: 8),
            TextField(controller: _subject, decoration: const InputDecoration(hintText: 'e.g. Physics')),
            const SizedBox(height: 16),
            const MonoLabel('Topic'),
            const SizedBox(height: 8),
            TextField(controller: _topic, decoration: const InputDecoration(hintText: 'e.g. Rotational Motion')),
            const SizedBox(height: 16),
            const MonoLabel('Duration (minutes)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [10, 20, 25, 30, 45, 60].map((d) {
                final sel = _duration == d;
                return ChoiceChip(
                  label: Text('$d'),
                  selected: sel,
                  onSelected: (_) => setState(() => _duration = d),
                  selectedColor: AquilaColors.accent.withValues(alpha: 0.22),
                  backgroundColor: ext.bgCard,
                  side: BorderSide(color: sel ? AquilaColors.accent : ext.border),
                  labelStyle: TextStyle(
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? AquilaColors.accent : ext.textPrimary),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const MonoLabel('Goal (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _goal,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'What do you want to achieve this session?'),
            ),
            const SizedBox(height: 28),
            AquilaGradientButton(
              label: _starting ? 'Building…' : 'Start Session',
              loading: _starting,
              onPressed: _start,
            ),
            const SizedBox(height: 24),
            Divider(color: ext.border),
            const SizedBox(height: 16),
            Text('RECENT SESSIONS', style: ext.monoMicro(11, color: AquilaColors.accent)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('users')
                  .doc(widget.uid)
                  .collection('studySessions')
                  .orderBy('startedAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (c, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Text('No sessions yet — start your first 25 min block above',
                      style: TextStyle(fontSize: 13, color: ext.textSecondary));
                }
                return Column(
                  children: docs.map((d) {
                    final m = d.data() as Map<String, dynamic>;
                    final subj = m['subject']?.toString() ?? '—';
                    final top = m['topic']?.toString() ?? '—';
                    final dur = (m['durationMinutes'] as num?)?.toInt() ?? 0;
                    final status = m['status']?.toString() ?? 'unknown';
                    final secs = (m['timeFocused'] as num?)?.toInt() ?? dur * 60;
                    Color stColor;
                    if (status == 'completed') stColor = AquilaColors.green;
                    else if (status == 'abandoned') stColor = AquilaColors.accent3;
                    else stColor = AquilaColors.accent;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                          color: ext.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: ext.border)),
                      child: Row(
                        children: [
                          Icon(status == 'completed' ? Icons.check_circle : Icons.timer_outlined, color: stColor, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('$subj • $top',
                                  style: TextStyle(
                                      fontFamily: AquilaColors.fontMain,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: ext.textPrimary)),
                              Text('${(secs / 60).ceil()} min • $status',
                                  style: ext.monoMicro(10, color: ext.textMuted)),
                            ]),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionView(AquilaThemeExt ext) {
    final plan = _plan!;
    final title = plan['title']?.toString() ?? '$_sessionSubject — $_sessionTopic';
    final objectives = (plan['objectives'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final keyPoints = (plan['keyPoints'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final practice = (plan['practiceQuestions'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final tips = (plan['focusTips'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final pct = (_elapsed / (_duration * 60)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: ext.bgBase,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 15)),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 168,
                    height: 168,
                    child: CircularProgressIndicator(
                      value: pct,
                      strokeWidth: 10,
                      backgroundColor: ext.bgInput,
                      valueColor: const AlwaysStoppedAnimation(AquilaColors.accent),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_fmt(_duration * 60 - _elapsed),
                          style: TextStyle(
                              fontFamily: AquilaColors.fontMono,
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              color: ext.textPrimary)),
                      Text(_paused ? 'Paused' : 'Focus',
                          style: ext.monoMicro(11, color: ext.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AquilaOutlineButton(
                  label: _paused ? 'Resume' : 'Pause',
                  onPressed: () => setState(() => _paused = !_paused),
                ),
                const SizedBox(width: 12),
                AquilaGradientButton(
                  label: 'End Session',
                  onPressed: () => _end(completed: true),
                  height: 44,
                ),
              ],
            ),
            const SizedBox(height: 28),
            if (objectives.isNotEmpty) ...[
              _sectionHeader(ext, 'Objectives'),
              for (final o in objectives) _checkItem(ext, o),
              const SizedBox(height: 16),
            ],
            if (keyPoints.isNotEmpty) ...[
              _sectionHeader(ext, 'Key Points'),
              for (final k in keyPoints)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                        width: 6, height: 6, margin: const EdgeInsets.only(top: 7, right: 10), decoration: const BoxDecoration(shape: BoxShape.circle, color: AquilaColors.accent)),
                    Expanded(child: Text(k, style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 13.5, height: 1.5, color: ext.textPrimary))),
                  ]),
                ),
              const SizedBox(height: 16),
            ],
            if (practice.isNotEmpty) ...[
              _sectionHeader(ext, 'Practice Questions'),
              for (final q in practice)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: ext.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: ext.border)),
                  child: Text(q, style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 13.5, color: ext.textPrimary)),
                ),
              const SizedBox(height: 16),
            ],
            if (tips.isNotEmpty) ...[
              _sectionHeader(ext, 'Focus Tips'),
              for (final t in tips) _checkItem(ext, t),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(AquilaThemeExt ext, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: AquilaColors.accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: ext.textPrimary)),
      ]),
    );
  }

  Widget _checkItem(AquilaThemeExt ext, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle_outline, size: 18, color: AquilaColors.green),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 13.5, height: 1.4, color: ext.textPrimary))),
      ]),
    );
  }
}
