import 'package:flutter/material.dart';

import '../../models/plan_models.dart';
import '../../models/usage_models.dart';
import '../../services/auth_service.dart';
import '../../services/limits_service.dart';
import '../../services/planner_service.dart';
import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';

/// 3-step onboarding mirroring web planner-onboarding.html:
/// Exam Setup → Subjects → Schedule → POST /api/generate-plan.
class PlannerOnboardingScreen extends StatefulWidget {
  final String uid;
  const PlannerOnboardingScreen({super.key, required this.uid});

  @override
  State<PlannerOnboardingScreen> createState() => _PlannerOnboardingScreenState();
}

class _PlannerOnboardingScreenState extends State<PlannerOnboardingScreen> {
  static const _stepNames = ['', 'Exam Setup', 'Subjects', 'Schedule'];

  int _step = 1;
  bool _generating = false;

  // Step 1 — Exam Setup
  final _studentName = TextEditingController();
  String _examType = 'JEE';
  final _targetScore = TextEditingController();

  // Step 2 — Subjects
  final _subjects = <String>[];
  final _weakTopics = <String>[];
  final _subjectInput = TextEditingController();
  final _weakInput = TextEditingController();

  // Step 3 — Schedule
  final _dailyHours = TextEditingController(text: '3');
  DateTime _startDate = DateTime.now();
  DateTime _examDate = DateTime.now().add(const Duration(days: 90));

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _studentName.dispose();
    _targetScore.dispose();
    _subjectInput.dispose();
    _weakInput.dispose();
    _dailyHours.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _addTag(List<String> list, TextEditingController input, String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    if (list.contains(v)) {
      input.clear();
      return;
    }
    setState(() {
      list.add(v);
      input.clear();
    });
  }

  void _removeTag(List<String> list, String value) {
    setState(() => list.remove(value));
  }

  Widget _tagWrap(List<String> list, TextEditingController input,
      {required String hint}) {
    final ext = AquilaThemeExt.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in list)
              InputChip(
                label: Text(t),
                onDeleted: () => _removeTag(list, t),
                backgroundColor: ext.bgCard,
                deleteIconColor: ext.textSecondary,
                side: BorderSide(color: ext.border),
                labelStyle: TextStyle(color: ext.textPrimary, fontSize: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: input,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => _addTag(list, input, v),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;

    // Planner usage gate (mirrors web daily planner minutes).
    final result = await LimitsService.instance.consume(
      widget.uid,
      type: UsageType.planner,
      amount: 30,
    );
    if (!mounted) return;
    if (!result.allowed) {
      showAquilaSnack(context, 'Daily planner time used up — upgrade for more.', error: true);
      return;
    }

    setState(() => _generating = true);
    try {
      final request = PlanRequest(
        studentName: _studentName.text.trim(),
        examType: _examType,
        targetScore: _targetScore.text.trim(),
        subjects: _subjects,
        weakTopics: _weakTopics,
        dailyHours: int.tryParse(_dailyHours.text.trim()) ?? 3,
        startDate: _ymd(_startDate),
        examDate: _ymd(_examDate),
      );
      final weeks = await PlannerService.instance.generatePlan(request);
      if (!mounted) return;
      await PlannerService.instance.saveExamProfile(widget.uid, request);
      final planId =
          await PlannerService.instance.savePlan(widget.uid, weeks);
      await PlannerService.instance.createTasksFromPlan(
        uid: widget.uid,
        planId: planId,
        weeks: weeks,
        startDateIso: _ymd(_startDate),
      );
      await AuthService.instance.completeOnboarding(widget.uid);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showAquilaSnack(
          context,
          'Could not generate your plan (${e.toString()}). Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _next() {
    if (_step < 3) {
      if (_step == 1) {
        if (_formKey.currentState!.validate()) setState(() => _step = 2);
      } else if (_step == 2) {
        if (_subjects.isEmpty) {
          showAquilaSnack(context, 'Add at least one subject.', error: true);
          return;
        }
        setState(() => _step = 3);
      } else {
        _generate();
      }
    } else {
      _generate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Scaffold(
      backgroundColor: ext.bgBase,
      appBar: AppBar(
        title: Text('STEP $_step / 3', style: ext.monoMicro(11, color: AquilaColors.accent)),
        centerTitle: true,
        leading: IconButton(
          onPressed: _step > 1
              ? () => setState(() => _step--)
              : () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back, color: ext.textSecondary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _stepNames[_step],
                  style: TextStyle(
                    fontFamily: AquilaColors.fontMain,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: ext.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _subtitle(),
                  style: TextStyle(
                    fontFamily: AquilaColors.fontMain,
                    fontSize: 13.5,
                    height: 1.4,
                    color: ext.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                if (_step == 1) _step1(ext),
                if (_step == 2) _step2(ext),
                if (_step == 3) _step3(ext),
                const SizedBox(height: 32),
                AquilaGradientButton(
                  label: _generating
                      ? 'Generating…'
                      : _step < 3
                          ? 'Continue'
                          : 'Build My Plan',
                  loading: _generating,
                  onPressed: _next,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    switch (_step) {
      case 1:
        return 'Tell us about your exam so Aquila can build the right roadmap.';
      case 2:
        return 'Add the subjects and topics you find hardest.';
      default:
        return 'Set your daily hours and exam date.';
    }
  }

  Widget _step1(AquilaThemeExt ext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MonoLabel('Your name'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _studentName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Aarav'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
        ),
        const SizedBox(height: 18),
        const MonoLabel('Exam type'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _examType,
          dropdownColor: ext.bgCard,
          items: const [
            'JEE', 'NEET', 'Boards', 'Olympiads', 'UPSC', 'SAT',
            'University Course', 'Other',
          ]
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _examType = v ?? 'JEE'),
        ),
        const SizedBox(height: 18),
        const MonoLabel('Target score'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _targetScore,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g. 95% or 1500'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your target' : null,
        ),
      ],
    );
  }

  Widget _step2(AquilaThemeExt ext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MonoLabel('Subjects'),
        const SizedBox(height: 8),
        _tagWrap(_subjects, _subjectInput, hint: 'Type a subject, press Enter'),
        const SizedBox(height: 24),
        const MonoLabel('Weak topics (optional)'),
        const SizedBox(height: 8),
        _tagWrap(_weakTopics, _weakInput,
            hint: 'e.g. Thermodynamics, Organic Chemistry'),
      ],
    );
  }

  Widget _step3(AquilaThemeExt ext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MonoLabel('Daily study hours'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _dailyHours,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g. 3'),
          validator: (v) {
            final n = int.tryParse(v ?? '');
            return (n == null || n < 1 || n > 14) ? 'Between 1 and 14 hours' : null;
          },
        ),
        const SizedBox(height: 20),
        const MonoLabel('Start date'),
        const SizedBox(height: 8),
        _datePicker(_startDate, (d) => setState(() => _startDate = d)),
        const SizedBox(height: 20),
        const MonoLabel('Exam date'),
        const SizedBox(height: 8),
        _datePicker(_examDate, (d) => setState(() => _examDate = d)),
        const SizedBox(height: 12),
        Text(
          '${_ymd(_startDate)} → ${_ymd(_examDate)}',
          style: ext.monoMicro(11, color: ext.textSecondary),
        ),
      ],
    );
  }

  Widget _datePicker(DateTime value, ValueChanged<DateTime> onChanged) {
    final ext = AquilaThemeExt.of(context);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime.now().subtract(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              dialogTheme: DialogThemeData(
                backgroundColor: ext.bgCard,
                titleTextStyle: TextStyle(
                  fontFamily: AquilaColors.fontMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ext.textPrimary,
                ),
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: ext.bgInput,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ext.border),
        ),
        child: Row(
          children: [
            Icon(Icons.event, size: 18, color: ext.textSecondary),
            const SizedBox(width: 10),
            Text(
              _ymd(value),
              style: TextStyle(fontFamily: AquilaColors.fontMain, fontSize: 14, color: ext.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}