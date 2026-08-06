import 'dart:collection';

import 'package:flutter/material.dart';

import '../../models/task_model.dart';
import '../../services/auth_service.dart';
import '../../services/planner_service.dart';
import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';
import 'planner_onboarding.dart';

class PlannerScreen extends StatefulWidget {
  final String uid;
  const PlannerScreen({super.key, required this.uid});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  bool _onboarding = false;
  bool _checking = true;
  bool _replanning = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = await AuthService.instance.userOnce(widget.uid);
    if (!mounted) return;
    setState(() {
      _onboarding = user == null || !user.onboardingComplete;
      _checking = false;
    });
  }

  Future<void> _openOnboarding() async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlannerOnboardingScreen(uid: widget.uid),
      ),
    );
    if (done == true && mounted) {
      setState(() => _onboarding = false);
    }
  }

  Future<void> _replan() async {
    setState(() => _replanning = true);
    try {
      final res = await PlannerService.instance.replan(widget.uid);
      if (!mounted) return;
      final message = res?['message']?.toString() ?? 'Plan refreshed.';
      showAquilaSnack(context, message);
    } catch (e) {
      if (mounted) {
        showAquilaSnack(context, 'Could not replan right now.', error: true);
      }
    } finally {
      if (mounted) setState(() => _replanning = false);
    }
  }

  Future<void> _completeTask(String docId, String status) async {
    await PlannerService.instance.updateTaskStatus(widget.uid, docId, status);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    if (_checking) {
      return Scaffold(
        backgroundColor: ext.bgBase,
        body: Center(
          child: CircularProgressIndicator(color: AquilaColors.accent),
        ),
      );
    }
    if (_onboarding) {
      return Scaffold(
        backgroundColor: ext.bgBase,
        appBar: AppBar(title: const Text('Study Planner')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AquilaLogo(size: 60),
                const SizedBox(height: 22),
                const Text(
                  'Build your study plan',
                  style: TextStyle(
                    fontFamily: AquilaColors.fontMain,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AquilaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'A 3-step setup generates a week-by-week roadmap\npowered by AI.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AquilaColors.fontMain,
                    fontSize: 14,
                    height: 1.5,
                    color: ext.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                AquilaGradientButton(
                  label: 'Get Started',
                  onPressed: _openOnboarding,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ext.bgBase,
      appBar: AppBar(
        title: const Text('Study Planner'),
        actions: [
          IconButton(
            tooltip: 'Replan',
            onPressed: _replanning ? null : _replan,
            icon: _replanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AquilaColors.accent),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<List<StudyTask>>(
        stream: PlannerService.instance.tasksStream(widget.uid),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.active) {
            return Center(
              child: CircularProgressIndicator(color: AquilaColors.accent),
            );
          }
          final tasks = snap.data ?? [];
          if (tasks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'No tasks yet — build your plan to see a week-by-week schedule.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AquilaColors.fontMain,
                        fontSize: 14,
                        height: 1.5,
                        color: ext.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AquilaOutlineButton(
                      label: 'Create Plan',
                      onPressed: _openOnboarding,
                    ),
                  ],
                ),
              ),
            );
          }

          final weeks = _groupByWeek(tasks);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _weekHeader(ext, 'WEEKLY PLAN'),
              const SizedBox(height: 6),
              _progressSummary(ext, tasks),
              for (final entry in weeks.entries) ...[
                const SizedBox(height: 20),
                _weekCard(ext, entry.key, entry.value),
              ],
            ],
          );
        },
      ),
    );
  }

  Map<int, List<StudyTask>> _groupByWeek(List<StudyTask> tasks) {
    final map = <int, List<StudyTask>>{};
    for (final t in tasks) {
      map.putIfAbsent(t.week, () => []).add(t);
    }
    final sorted = SplayTreeMap<int, List<StudyTask>>();
    sorted.addAll(map);
    return sorted;
  }

  Widget _weekHeader(AquilaThemeExt ext, String text) {
    return Text(text, style: ext.monoMicro(11, color: AquilaColors.accent));
  }

  Widget _progressSummary(AquilaThemeExt ext, List<StudyTask> tasks) {
    final completed = tasks.where((t) => t.isCompleted).length;
    final total = tasks.length;
    final pct = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ext.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completed / $total tasks done',
                  style: const TextStyle(
                    fontFamily: AquilaColors.fontMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AquilaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: ext.bgInput,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AquilaColors.accent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekCard(AquilaThemeExt ext, int week, List<StudyTask> tasks) {
    final completed = tasks.where((t) => t.isCompleted).length;
    return Container(
      decoration: BoxDecoration(
        color: ext.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ext.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Text(
                  'WEEK $week',
                  style: ext.monoMicro(11, color: AquilaColors.accent),
                ),
                const Spacer(),
                Text(
                  '$completed/${tasks.length}',
                  style: ext.monoMicro(10, color: ext.textMuted),
                ),
              ],
            ),
          ),
          Divider(color: ext.border, height: 1),
          for (final t in tasks) _taskTile(ext, t),
        ],
      ),
    );
  }

  Widget _taskTile(AquilaThemeExt ext, StudyTask t) {
    final color = AquilaColors.subjectColor(_subjectsIndex(t.subject));
    final done = t.isCompleted;
    return InkWell(
      onTap: () => _completeTask(
        t.docId,
        done ? 'pending' : 'completed',
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: done ? color.withValues(alpha: 0.06) : Colors.transparent,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? AquilaColors.green : ext.textMuted,
                  size: 22,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t.subject.toUpperCase(),
                          style: TextStyle(
                            fontFamily: AquilaColors.fontMono,
                            fontSize: 10,
                            letterSpacing: 0.05,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (t.priority == 'high')
                        const Icon(Icons.local_fire_department,
                            size: 14, color: AquilaColors.accent3),
                      if (t.priority == 'medium')
                        const Icon(Icons.remove, size: 14, color: AquilaColors.accent4),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.topic,
                    style: TextStyle(
                      fontFamily: AquilaColors.fontMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: done ? ext.textMuted : ext.textPrimary,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: ext.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${t.durationMinutes} min · ${t.type} · ${_fmtDate(t.scheduledDate)}',
                    style: ext.monoMicro(10, color: ext.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Skip',
              onPressed: () => _completeTask(t.docId, 'skipped'),
              icon: const Icon(Icons.more_horiz),
              color: ext.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  int _subjectsIndex(String subject) {
    if (subject.isEmpty) return 0;
    return subject.codeUnitAt(0);
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}