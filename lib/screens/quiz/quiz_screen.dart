import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../data/question_bank.dart';
import '../../services/api_client.dart';
import '../../services/quiz_service.dart';
import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';

class _QuizQuestion {
  final String question;
  final List<String> options;
  final int answer; // -1 for written
  final String explanation;

  const _QuizQuestion({
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
  });

  factory _QuizQuestion.fromJson(Map<String, dynamic> j) {
    final options = (j['options'] is List)
        ? (j['options'] as List).map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
        : <String>[];
    final answerIndex = options.length == 4 ? _letterToIndex(j['answer']?.toString() ?? '') : 0;
    return _QuizQuestion(
      question: j['question']?.toString() ?? '',
      options: options,
      answer: answerIndex,
      explanation: j['explanation']?.toString() ?? '',
    );
  }

  static int _letterToIndex(String s) {
    final t = s.trim().toUpperCase();
    if (t.startsWith('A')) return 0;
    if (t.startsWith('B')) return 1;
    if (t.startsWith('C')) return 2;
    if (t.startsWith('D')) return 3;
    return int.tryParse(s) ?? 0;
  }
}

class QuizScreen extends StatefulWidget {
  final String uid;
  const QuizScreen({super.key, required this.uid});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // Setup state
  String? _subject;
  String? _topic;
  int _count = 5;
  bool _aiMode = false;
  bool _loading = false;

  // Take state
  final List<_QuizQuestion> _questions = [];
  final Map<int, int> _answers = {}; // question index -> selected option
  int _index = 0;
  bool _revealed = false;
  bool _finished = false;

  int get _correct =>
      _questions.asMap().entries.where((e) => _answers[e.key] == e.value.answer).length;

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    if (_loading) {
      return Scaffold(
        backgroundColor: ext.bgBase,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AquilaColors.accent),
              const SizedBox(height: 14),
              Text('Preparing questions…', style: ext.monoMicro(11, color: ext.textSecondary)),
            ],
          ),
        ),
      );
    }
    if (_finished) return _resultView(ext);
    if (_questions.isNotEmpty) return _takeView(ext);
    return _setupView(ext);
  }

  // ── Setup ──────────────────────────────────────────────────
  Widget _setupView(AquilaThemeExt ext) {
    final subjects = QuestionBank.subjects();
    return Scaffold(
      backgroundColor: ext.bgBase,
      appBar: AppBar(title: const Text('Quiz')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text('SUBJECT', style: ext.monoMicro(11, color: AquilaColors.accent)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in subjects)
                _choiceChip(s, _subject == s, () => setState(() {
                      _subject = s;
                      _topic = null;
                    })),
            ],
          ),
          if (_subject != null) ...[
            const SizedBox(height: 24),
            Text('TOPIC', style: ext.monoMicro(11, color: AquilaColors.accent)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _choiceChip('Mixed', _topic == null, () => setState(() => _topic = null)),
                for (final t in QuestionBank.topicsFor(_subject!))
                  _choiceChip(t, _topic == t, () => setState(() => _topic = t)),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text('QUESTIONS', style: ext.monoMicro(11, color: AquilaColors.accent)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final n in const [5, 10])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _choiceChip('$n', _count == n, () => setState(() => _count = n)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            value: _aiMode,
            onChanged: (v) => setState(() => _aiMode = v),
            title: const Text('AI-generated questions'),
            subtitle: Text(
              'Fresh questions created on the fly (requires connection)',
              style: TextStyle(fontSize: 12, color: ext.textSecondary),
            ),
            activeTrackColor: AquilaColors.accent.withValues(alpha: 0.4),
            activeThumbColor: AquilaColors.accent,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 28),
          AquilaGradientButton(
            label: 'Start Quiz',
            onPressed: _subject == null ? null : _start,
          ),
        ],
      ),
    );
  }

  Widget _choiceChip(String label, bool selected, VoidCallback onTap) {
    final ext = AquilaThemeExt.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AquilaColors.accent.withValues(alpha: 0.22),
      backgroundColor: ext.bgCard,
      side: BorderSide(color: selected ? AquilaColors.accent : ext.border),
      labelStyle: TextStyle(
        fontSize: 13,
        color: selected ? AquilaColors.accent : ext.textPrimary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Future<void> _start() async {
    if (_subject == null) return;
    setState(() => _loading = true);
    try {
      final List<_QuizQuestion> qs;
      if (_aiMode) {
        qs = await _loadAIQuestions();
      } else {
        qs = (_topic == null
                ? QuestionBank.questionsForSubject(_subject!)
                : QuestionBank.questionsFor(_subject!, _topic!))
            .take(_count)
            .map((b) => _QuizQuestion(
                  question: b.question,
                  options: b.options,
                  answer: b.answer,
                  explanation: b.explanation,
                ))
            .toList();
      }
      if (qs.isEmpty) throw Exception('No questions available for this topic.');
      if (!mounted) return;
      setState(() {
        _questions
          ..clear()
          ..addAll(qs.take(_count));
        _answers.clear();
        _index = 0;
        _revealed = false;
        _finished = false;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showAquilaSnack(context, 'Could not load questions: ${e.toString()}', error: true);
      }
    }
  }

  Future<List<_QuizQuestion>> _loadAIQuestions() async {
    try {
      final prompt = 'Generate $_count multiple-choice quiz questions for subject "${_subject!}"'
          '${_topic != null ? ' topic "$_topic"' : ''} for a competitive exam student. '
          'Return ONLY a JSON array. Each object: {"question": "...", "options": ["A", "B", "C", "D"], '
          '"answer": "A"|"B"|"C"|"D", "explanation": "..."}. No extra text.';
      var acc = '';
      await for (final delta in ApiClient.instance.streamJson(
        AppConfig.groqProxyPath,
        {
          'model': AppConfig.chatModel,
          'messages': [
            {'role': 'system', 'content': 'You generate JSON only. No prose. Valid JSON array.'},
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 2500,
          'temperature': 0.8,
          'stream': true,
        },
        auth: true,
      )) {
        acc += delta;
      }
      final cleaned = acc.substring(acc.indexOf('['), acc.lastIndexOf(']') + 1);
      final list = jsonDecode(cleaned) as List;
      final qs = <_QuizQuestion>[];
      for (final e in list) {
        if (e is Map) {
          final q = _QuizQuestion.fromJson(Map<String, dynamic>.from(e));
          if (q.question.isNotEmpty && q.options.length >= 2) qs.add(q);
        }
      }
      if (qs.isEmpty) throw Exception('AI returned no valid questions');
      return qs;
    } catch (_) {
      // Fall back to the embedded bank.
      return (_topic == null
              ? QuestionBank.questionsForSubject(_subject!)
              : QuestionBank.questionsFor(_subject!, _topic!))
          .take(_count)
          .map((b) => _QuizQuestion(
                question: b.question,
                options: b.options,
                answer: b.answer,
                explanation: b.explanation,
              ))
          .toList();
    }
  }

  // ── Taking ────────────────────────────────────────────────
  Widget _takeView(AquilaThemeExt ext) {
    final q = _questions[_index];
    final answered = _answers[_index];
    return Scaffold(
      backgroundColor: ext.bgBase,
      appBar: AppBar(
        title: Text(
          '${_index + 1} / ${_questions.length}',
          style: ext.monoMicro(11, color: AquilaColors.accent),
        ),
        actions: [
          TextButton(
            onPressed: _finished ? null : _submit,
            child: const Text(
              'Finish',
              style: TextStyle(color: AquilaColors.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_index + 1) / _questions.length,
            backgroundColor: ext.bgInput,
            valueColor: const AlwaysStoppedAnimation<Color>(AquilaColors.accent),
            minHeight: 3,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AquilaColors.subjectColor(_subject!.codeUnitAt(0)).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_subject!.toUpperCase()} · ${(_topic ?? 'Mixed').toUpperCase()}',
                      style: ext.monoMicro(10,
                          color: AquilaColors.subjectColor(_subject!.codeUnitAt(0))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    q.question,
                    style: TextStyle(
                      fontFamily: AquilaColors.fontMain,
                      fontSize: 19,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                      color: ext.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  for (var i = 0; i < q.options.length; i++)
                    _optionTile(ext, q, i, answered),
                  if (_revealed) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AquilaColors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AquilaColors.green.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, color: AquilaColors.green, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              q.explanation,
                              style: TextStyle(
                                fontFamily: AquilaColors.fontMain,
                                fontSize: 13.5,
                                height: 1.5,
                                color: ext.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (_index > 0)
                        AquilaOutlineButton(
                          label: 'Previous',
                          onPressed: () => setState(() {
                            _index--;
                            _revealed = false;
                          }),
                        )
                      else
                        const SizedBox.shrink(),
                      const Spacer(),
                      AquilaGradientButton(
                        label: _index == _questions.length - 1 ? 'See Results' : 'Next',
                        height: 48,
                        onPressed: () => setState(() {
                          if (_index == _questions.length - 1) {
                            _submit();
                          } else {
                            _index++;
                            _revealed = false;
                          }
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionTile(AquilaThemeExt ext, _QuizQuestion q, int i, int? answered) {
    const letters = ['A', 'B', 'C', 'D'];
    final selected = answered == i;
    Color? border;
    if (_revealed) {
      if (i == q.answer) {
        border = AquilaColors.green;
      } else if (selected) {
        border = AquilaColors.accent3;
      }
    } else if (selected) {
      border = AquilaColors.accent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? AquilaColors.accent.withValues(alpha: 0.10) : ext.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: border ?? ext.border,
          width: border != null ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _revealed
            ? null
            : () => setState(() {
                  _answers[_index] = i;
                  _revealed = false;
                }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AquilaColors.accent : ext.bgInput,
                ),
                child: Text(
                  letters.length > i ? letters[i] : '${i + 1}',
                  style: TextStyle(
                    fontFamily: AquilaColors.fontMono,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? AquilaColors.onAccentText : ext.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  q.options[i],
                  style: TextStyle(
                    fontFamily: AquilaColors.fontMain,
                    fontSize: 14.5,
                    height: 1.4,
                    color: ext.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final answeredAll = _answers.length == _questions.length;
    if (!answeredAll) {
      if (!await _confirmSkip()) return;
    }
    setState(() => _finished = true);

    final answers = <Map<String, dynamic>>[];
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final a = _answers[i];
      answers.add({
        'question': q.question,
        'selected': a,
        'correct': a == q.answer,
        'explanation': q.explanation,
      });
    }
    try {
      await QuizService.instance.saveAttempt(
        widget.uid,
        subject: _subject!,
        topic: _topic ?? 'Mixed',
        correctCount: _correct,
        totalQuestions: _questions.length,
        score: _correct * 1.0,
        answers: answers,
        type: _aiMode ? 'ai' : 'standard',
      );
    } catch (_) {
      // Result still shows locally even if saving failed.
    }
  }

  Future<bool> _confirmSkip() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Submit anyway?'),
            content: Text('You have ${_questions.length - _answers.length} unanswered '
                'question(s). Unanswered questions count as incorrect.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Keep going'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Submit'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Result ────────────────────────────────────────────────
  Widget _resultView(AquilaThemeExt ext) {
    final pct = _questions.isEmpty ? 0 : (_correct / _questions.length * 100).round();
    final Color accent = pct >= 75
        ? AquilaColors.green
        : pct >= 50
            ? AquilaColors.accent4
            : AquilaColors.accent3;
    return Scaffold(
      backgroundColor: ext.bgBase,
      appBar: AppBar(
        title: const Text('Results'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.10),
                border: Border.all(color: accent, width: 2.5),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$pct%',
                    style: TextStyle(
                      fontFamily: AquilaColors.fontMain,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  Text(
                    '$_correct / ${_questions.length}',
                    style: ext.monoMicro(11, color: ext.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _messageFor(pct),
              style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 15, color: ext.textSecondary),
            ),
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < _questions.length; i++) _reviewTile(ext, i),
          const SizedBox(height: 20),
          AquilaGradientButton(
            label: 'Take Another Quiz',
            onPressed: () => setState(() {
              _questions.clear();
              _answers.clear();
              _finished = false;
              _subject = null;
              _topic = null;
            }),
          ),
        ],
      ),
    );
  }

  String _messageFor(int pct) {
    if (pct >= 90) return 'Outstanding! Concept mastery unlocked.';
    if (pct >= 75) return 'Great work — solid understanding.';
    if (pct >= 50) return 'Good start — review the weak spots below.';
    return 'Keep going — review these and try again.';
  }

  Widget _reviewTile(AquilaThemeExt ext, int i) {
    final q = _questions[i];
    final selected = _answers[i];
    final correct = selected == q.answer;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ext.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ext.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle : Icons.cancel,
                color: correct ? AquilaColors.green : AquilaColors.accent3,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Q${i + 1}. ${q.question}',
                  style: TextStyle(
                    fontFamily: AquilaColors.fontMain,
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: ext.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            selected == null
                ? 'Not answered. Correct: ${q.options[q.answer]}'
                : correct
                    ? 'Correct'
                    : 'You chose: ${q.options[selected]} · Correct: ${q.options[q.answer]}',
            style: TextStyle(
              fontFamily: AquilaColors.fontMono,
              fontSize: 11,
              color: correct ? AquilaColors.green : ext.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}