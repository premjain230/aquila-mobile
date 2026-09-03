import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../learning/onboarding.dart';
import '../../learning/learner_model.dart';
import '../../services/auth_service.dart';
import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';

/// Adaptive onboarding — one question at a time, same graph as Web.
/// Persists each answer to users/{uid}/learning/profile (merge:true) + emits learningEvents.
/// Resume: reconstructs answers from Firestore so closing/reopening preserves progress.
class OnboardingScreen extends StatefulWidget {
  final String uid;
  const OnboardingScreen({super.key, required this.uid});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;
  String? _currentId;
  final _history = <String>[];
  Map<String, dynamic> _answers = {};
  Map<String, dynamic> _profileRaw = {};
  String? _error;
  // transient UI state for current question
  String? _single;
  final _multi = <String>{};
  final _free = TextEditingController();
  double _range = 4;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _free.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await _db.collection('users').doc(widget.uid).collection('learning').doc('profile').get();
      _profileRaw = snap.data() ?? {};
      _answers = _reconstructAnswers(_profileRaw);
      // try goals subcollection for goals
      try {
        final gSnap = await _db.collection('users').doc(widget.uid).collection('learning').collection('goals').get();
        // Actually path is users/{uid}/learning/goals — handle both
      } catch (_) {}
      try {
        final g2 = await _db.collection('users').doc(widget.uid).collection('goals').get();
        if (g2.docs.isNotEmpty) {
          _answers['goals'] = g2.docs.map((d) => d.data()['title']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
        }
      } catch (_) {}

      if (_profileRaw['onboardingComplete'] == true) {
        if (mounted) setState(() { _loading = false; _currentId = null; });
        return;
      }
      // build history up to resume point
      String? cur;
      var nxt = getNextOnboardingQuestion(null, _answers);
      while (nxt != null) {
        final v = _answers[nxt.field] ?? _answers[nxt.id];
        final has = v != null && (v is List ? v.isNotEmpty : v.toString().trim().isNotEmpty);
        _history.add(nxt.id);
        if ((!has && nxt.required) || (!has && !nxt.required)) {
          cur = nxt.id;
          break;
        }
        cur = nxt.id;
        nxt = getNextOnboardingQuestion(cur, _answers);
        if (nxt == null) { cur = null; break; }
      }
      _currentId = cur;
      _hydrateForCurrent();
      if (mounted) setState(() => _loading = false);
      _emit('onboarding_started', {});
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Map<String, dynamic> _reconstructAnswers(Map<String, dynamic> p) {
    final m = <String, dynamic>{};
    final ac = p['academic'] is Map ? Map<String, dynamic>.from(p['academic'] as Map) : <String, dynamic>{};
    if (ac['grade'] != null) m['academic.grade'] = ac['grade'].toString();
    if (ac['board'] != null) m['academic.board'] = ac['board'].toString();
    if (ac['academicYear'] != null) m['academic.academicYear'] = ac['academicYear'].toString();
    if (ac['country'] != null) m['academic.country'] = ac['country'].toString();
    if (ac['track'] != null) m['academic.track'] = ac['track'].toString();
    if (p['subjects'] is List) m['subjects'] = List<String>.from((p['subjects'] as List).map((e) => e.toString()));
    if (p['dailyHours'] != null) m['dailyHours'] = p['dailyHours'];
    if (p['examDate'] != null) m['examDate'] = p['examDate'].toString();
    if (p['weakTopics'] is List) m['weakTopics'] = List<String>.from((p['weakTopics'] as List).map((e) => e.toString()));
    if (p['preferences'] is Map) {
      final pref = Map<String, dynamic>.from(p['preferences'] as Map);
      if (pref['preferredStyle'] != null) m['preferences.preferredStyle'] = pref['preferredStyle'].toString();
    }
    return m;
  }

  void _hydrateForCurrent() {
    _single = null;
    _multi.clear();
    _free.text = '';
    _error = null;
    if (_currentId == null) return;
    final q = onboardingQuestions.firstWhere((e) => e.id == _currentId, orElse: () => onboardingQuestions.first);
    final v = _answers[q.field] ?? _answers[q.id];
    if (q.input == 'single' && v is String) _single = v;
    if (q.input == 'multi' && v is List) _multi.addAll(v.map((e) => e.toString()));
    if (q.input == 'free' && v is String) _free.text = v;
    if (q.input == 'range' && v is num) _range = v.toDouble();
  }

  Future<void> _emit(String type, Map<String, dynamic> payload) async {
    try {
      await _db.collection('users').doc(widget.uid).collection('learningEvents').add({
        'uid': widget.uid,
        'type': type,
        'payload': payload,
        'createdAt': FieldValue.serverTimestamp(),
        'learningSchemaVersion': 1,
      });
    } catch (_) {}
  }

  Future<void> _persist(String field, dynamic value) async {
    final patch = answersToProfilePatch({field: value});
    final toSave = <String, dynamic>{};
    if (patch['academic'] is Map && (patch['academic'] as Map).isNotEmpty) {
      final existingAc = _profileRaw['academic'] is Map ? Map<String, dynamic>.from(_profileRaw['academic'] as Map) : <String, dynamic>{};
      toSave['academic'] = {...existingAc, ...Map<String, dynamic>.from(patch['academic'] as Map)};
    }
    if (patch['subjects'] is List && (patch['subjects'] as List).isNotEmpty) toSave['subjects'] = value;
    if (patch['dailyHours'] != null) toSave['dailyHours'] = value;
    if (value is List && field == 'weakTopics') toSave['weakTopics'] = value;
    if (field == 'examDate') toSave['examDate'] = value;
    if (patch['preferences'] is Map) toSave['preferences'] = {...(_profileRaw['preferences'] is Map ? Map<String, dynamic>.from(_profileRaw['preferences'] as Map) : {}), ...Map<String, dynamic>.from(patch['preferences'] as Map)};
    toSave['updatedAt'] = FieldValue.serverTimestamp();
    toSave['learningSchemaVersion'] = 1;
    await _db.collection('users').doc(widget.uid).collection('learning').doc('profile').set(toSave, SetOptions(merge: true));
    _profileRaw = {..._profileRaw, ...toSave};
    // goals subcollection
    if (field == 'goals' && value is List) {
      for (final t in value.map((e) => e.toString())) {
        final gid = 'g_${t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').substring(0, t.length.clamp(0, 30))}';
        await _db.collection('users').doc(widget.uid).collection('goals').doc(gid).set({
          'goalId': gid,
          'uid': widget.uid,
          'title': t,
          'type': 'custom',
          'priority': 'high',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'learningSchemaVersion': 1,
        }, SetOptions(merge: true));
      }
    }
    await _emit('onboarding_question_answered', {'field': field, 'source': 'self_report'});
  }

  bool _isComplete() {
    return _answers['academic.grade'] != null && _answers['academic.board'] != null && (_answers['subjects'] is List && (_answers['subjects'] as List).isNotEmpty) && (_answers['goals'] is List && (_answers['goals'] as List).isNotEmpty) && _answers['prioritySubject'] != null && _answers['dailyHours'] != null;
  }

  Future<void> _next({bool skip = false}) async {
    if (_currentId == null) return;
    final q = onboardingQuestions.firstWhere((e) => e.id == _currentId);
    dynamic val;
    if (!skip) {
      if (q.input == 'single') val = _single ?? (_free.text.trim().isNotEmpty ? _free.text.trim() : null);
      if (q.input == 'multi') {
        final list = _multi.toList();
        if (_free.text.trim().isNotEmpty) list.add(_free.text.trim());
        val = list;
      }
      if (q.input == 'range') val = _range.round();
      if (q.input == 'free') val = _free.text.trim().isEmpty ? null : _free.text.trim();
      if (q.required) {
        final empty = val == null || (val is List && val.isEmpty) || (val is String && val.trim().isEmpty);
        if (empty) { setState(() => _error = 'Please answer to continue.'); return; }
      }
      if (val != null && !(val is List && val.isEmpty)) {
        _answers[q.field] = val;
        await _persist(q.field, val);
        if(q.id=='competitiveExam' && (_answers['subjects']==null || (_answers['subjects'] is List && (_answers['subjects'] as List).isEmpty))){
          if(val.toString().contains('NEET')) _answers['subjects']=['Physics','Chemistry','Biology'];
          else if(val.toString().contains('JEE')) _answers['subjects']=['Physics','Chemistry','Mathematics'];
        }
      }
    }
    final nxt = getNextOnboardingQuestion(_currentId, _answers);
    if (nxt != null) {
      if (!_history.contains(nxt.id)) _history.add(nxt.id);
      setState(() { _currentId = nxt.id; _error = null; });
      _hydrateForCurrent();
      setState(() {});
    } else {
      if (_isComplete()) {
        await _db.collection('users').doc(widget.uid).collection('learning').doc('profile').set({'onboardingComplete': true, 'onboardingVersion': 1, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        await _emit('onboarding_completed', {'subjects': (_answers['subjects'] as List?)?.length ?? 0});
        if (mounted) setState(() => _currentId = null);
      } else {
        setState(() => _error = 'Please complete required fields.');
      }
    }
  }

  void _back() {
    final idx = _history.indexOf(_currentId ?? '');
    if (idx <= 0) return;
    setState(() { _currentId = _history[idx - 1]; _error = null; });
    _hydrateForCurrent();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    if (_loading) {
      return Scaffold(backgroundColor: ext.bgBase, body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3)), const SizedBox(height: 12), Text('Loading your profile', style: ext.monoMicro(11, color: ext.textSecondary)) ])));
    }
    if (_currentId == null) {
      // summary
      final subjects = (_answers['subjects'] is List ? (_answers['subjects'] as List).join(', ') : '—');
      final goals = (_answers['goals'] is List ? (_answers['goals'] as List).join(', ') : '—');
      final pri = _answers['prioritySubject']?.toString() ?? '—';
      final diff = (_answers['weakTopics'] is List ? (_answers['weakTopics'] as List).join(', ') : '—');
      final hrs = _answers['dailyHours']?.toString() ?? '—';
      return Scaffold(
        backgroundColor: ext.bgBase,
        appBar: AppBar(title: Text('Your starting profile', style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 16, fontWeight: FontWeight.w700, color: ext.textPrimary)), backgroundColor: ext.bgBase),
        body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_profileRaw['onboardingComplete'] == true ? 'Welcome back' : 'You’re all set', style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 22, fontWeight: FontWeight.w800, color: ext.textPrimary)),
          const SizedBox(height: 8),
          Text('Aquila will use this as your starting point and keep learning from your actual work. Challenges below are self-report until confirmed by practice.', style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 12.5, color: ext.textSecondary, height: 1.5)),
          const SizedBox(height: 18),
          _sumCard('Primary priority', pri, ext),
          _sumCard('Subjects', subjects, ext),
          _sumCard('Goals', goals, ext),
          _sumCard('Self-reported challenges', '$diff  (self-report, not mastery)', ext),
          _sumCard('Available time', '$hrs hrs/day', ext),
          Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: ext.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: ext.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Aquila will initially prioritize $pri and check fundamentals.', style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 13, fontWeight: FontWeight.w600, color: ext.textPrimary)), const SizedBox(height: 4), Text('Mastery stays evidence-driven.', style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 11.5, color: ext.textSecondary))])),
          const SizedBox(height: 20),
          AquilaGradientButton(label: 'Start learning →', onPressed: () => Navigator.of(context).pop(true)),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Take a 5-min assessment (optional)', style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 12.5, color: AquilaColors.accent2)))),
        ])),
      );
    }
    final q = onboardingQuestions.firstWhere((e) => e.id == _currentId);
    final opts = q.options ?? [];
    // dynamic optionsFrom for prioritySubject etc
    List<String> displayOpts = opts;
    if (q.optionsFrom != null) {
      final src = _answers[q.optionsFrom!] ?? _answers['subjects'] ?? [];
      if (src is List) displayOpts = src.map((e) => e.toString()).toList();
    }
    final tierLabel = q.tier == 0 ? 'Academic' : q.tier == 1 ? 'Goals & Priorities' : q.tier == 2 ? 'Difficulties' : 'Preferences';
    final progress = (_history.indexOf(q.id) + 1) / onboardingQuestions.length;
    return Scaffold(
      backgroundColor: ext.bgBase,
      appBar: AppBar(backgroundColor: ext.bgBase, title: Text(tierLabel, style: ext.monoMicro(10, color: ext.textSecondary)), centerTitle: true, leading: IconButton(icon: Icon(Icons.arrow_back, color: ext.textSecondary), onPressed: _history.indexOf(q.id) > 0 ? _back : () => Navigator.of(context).pop())),
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LinearProgressIndicator(value: progress, backgroundColor: ext.border, color: AquilaColors.accent, minHeight: 4),
        const SizedBox(height: 18),
        Text(q.question, style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 20, fontWeight: FontWeight.w700, color: ext.textPrimary)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AquilaColors.accent.withOpacity(0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: AquilaColors.accent.withOpacity(0.15))), child: Text(_why(q.id), style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 11.5, color: ext.textSecondary))),
        const SizedBox(height: 18),
        if (q.input == 'single') Wrap(spacing: 8, runSpacing: 8, children: displayOpts.map((o) => ChoiceChip(label: Text(o), selected: _single == o, onSelected: (_) => setState(() => _single = o))).toList()),
        if (q.input == 'single' && q.id == 'board' && _single != null) Padding(padding: const EdgeInsets.only(top: 12), child: TextField(controller: _free, decoration: const InputDecoration(hintText: 'Specify state board (optional)'))),
        if (q.input == 'multi') ...[
          Wrap(spacing: 8, runSpacing: 8, children: displayOpts.map((o) => FilterChip(label: Text(o), selected: _multi.contains(o), onSelected: (v) => setState(() { if (v) _multi.add(o); else _multi.remove(o); }))).toList()),
          const SizedBox(height: 12),
          TextField(controller: _free, decoration: const InputDecoration(hintText: 'Add custom and press Enter'), onSubmitted: (v) { if (v.trim().isNotEmpty) setState(() { _multi.add(v.trim().slice(0, 60)); _free.clear(); }); }),
        ],
        if (q.input == 'range') Row(children: [Text('${_range.round()}', style: TextStyle(fontFamily: AquilaColors.fontMono, fontSize: 22, fontWeight: FontWeight.w700, color: AquilaColors.accent)), const SizedBox(width: 12), Expanded(child: Slider(value: _range, min: 1, max: 18, divisions: 17, label: _range.round().toString(), onChanged: (v) => setState(() => _range = v)))]),
        if (q.input == 'free') TextField(controller: _free, decoration: const InputDecoration(hintText: 'Type your answer')),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 12, color: AquilaColors.accent3))),
        const SizedBox(height: 22),
        Row(children: [
          if (_history.indexOf(q.id) > 0) Expanded(child: OutlinedButton(onPressed: _back, child: const Text('Back'))),
          if (_history.indexOf(q.id) > 0) const SizedBox(width: 10),
          if (!q.required) Expanded(child: OutlinedButton(onPressed: () => _next(skip: true), child: const Text('Skip'))),
          if (!q.required) const SizedBox(width: 10),
          Expanded(child: FilledButton(onPressed: () => _next(), child: Text(q.id == _history.last ? 'Finish' : 'Continue'))),
        ]),
      ]))),
    );
  }

  String _why(String id) {
    const m = {'grade':'Helps Aquila pick the right level.','board':'Matches your syllabus.','track':'School vs competitive focus.','subjects':'Tracked per subject.','goals':'What matters most.','dailyHours':'For realistic planning.','difficultSubjects':'Stored as self-report — not mastery yet.'};
    return m[id] ?? 'This helps Aquila personalize your learning.';
  }

  Widget _sumCard(String label, String val, AquilaThemeExt ext) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: ext.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: ext.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: ext.monoMicro(9, color: ext.textSecondary)), const SizedBox(height: 4), Text(val, style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 13, fontWeight: FontWeight.w500, color: ext.textPrimary))]));
}

extension _Slice on String { String slice(int s,int e)=> substring(s, e.clamp(0,length)); }

