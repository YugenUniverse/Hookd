import 'package:flutter/material.dart' hide Badge;

import '../models/badge.dart';
import '../models/event.dart';
import '../services/api_service.dart';

class BadgeWizardPage extends StatefulWidget {
  const BadgeWizardPage({super.key, required this.event, this.existingBadge});
  final Event event;
  final Badge? existingBadge;

  @override
  State<BadgeWizardPage> createState() => _BadgeWizardPageState();
}

class _BadgeWizardPageState extends State<BadgeWizardPage> {
  int _currentStep = 0;
  bool _submitting = false;

  // Step 1: Details
  final _detailsFormKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _scoreCtrl = TextEditingController(text: '10');
  final _levelCtrl = TextEditingController(text: '4');

  // Step 2: Metric
  String _metric = 'rank'; // rank, score, sessions

  // Step 3: Operator and Value
  final _conditionFormKey = GlobalKey<FormState>();
  String _operator = 'top'; // top, gte, lte, eq
  final _valueCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    if (widget.existingBadge != null) {
      final b = widget.existingBadge!;
      _nameCtrl.text = b.name;
      _descCtrl.text = b.description ?? '';
      _scoreCtrl.text = b.score.toString();
      _levelCtrl.text = b.level.toString();

      if (b.winningCondition != null) {
        _metric = b.winningCondition!.metric;
        _operator = b.winningCondition!.operator;
        _valueCtrl.text = b.winningCondition!.value.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _scoreCtrl.dispose();
    _levelCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_detailsFormKey.currentState!.validate()) return;
    } else if (_currentStep == 2) {
      if (!_conditionFormKey.currentState!.validate()) return;
      _submit();
      return;
    }
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final condition = WinningCondition(
        metric: _metric,
        operator: _operator,
        value: int.parse(_valueCtrl.text),
      );

      if (widget.existingBadge != null) {
        await ApiService().updateEventBadge(
          widget.existingBadge!.id,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          score: int.parse(_scoreCtrl.text),
          level: int.parse(_levelCtrl.text),
          winningCondition: condition,
        );
      } else {
        await ApiService().createEventBadge(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          score: int.parse(_scoreCtrl.text),
          level: int.parse(_levelCtrl.text),
          eventId: widget.event.id,
          winningCondition: condition,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create badge: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.existingBadge != null ? 'Edit Event Badge' : 'Create Event Badge';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: _nextStep,
        onStepCancel: _prevStep,
        controlsBuilder: (context, details) {
          final isLast = _currentStep == 2;
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                FilledButton(
                  onPressed: _submitting ? null : details.onStepContinue,
                  child: _submitting && isLast
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(isLast ? 'Create Badge' : 'Next'),
                ),
                const SizedBox(width: 8),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: _submitting ? null : details.onStepCancel,
                    child: const Text('Back'),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Badge Details'),
            content: Form(
              key: _detailsFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name *'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(labelText: 'Description *'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _scoreCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Score Points *'),
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _levelCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Badge Level *'),
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Winning Metric'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RadioListTile<String>(
                  title: const Text('Rank (Leaderboard placement)'),
                  value: 'rank',
                  groupValue: _metric,
                  onChanged: (v) => setState(() => _metric = v!),
                ),
                RadioListTile<String>(
                  title: const Text('Score (Total event points)'),
                  value: 'score',
                  groupValue: _metric,
                  onChanged: (v) => setState(() => _metric = v!),
                ),
                RadioListTile<String>(
                  title: const Text('Sessions (Number of visits)'),
                  value: 'sessions',
                  groupValue: _metric,
                  onChanged: (v) => setState(() => _metric = v!),
                ),
              ],
            ),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Condition Value'),
            content: Form(
              key: _conditionFormKey,
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _operator,
                      decoration: const InputDecoration(labelText: 'Operator *'),
                      items: const [
                        DropdownMenuItem(value: 'top', child: Text('Top N')),
                        DropdownMenuItem(value: 'gte', child: Text('≥ (Greater/Eq)')),
                        DropdownMenuItem(value: 'lte', child: Text('≤ (Less/Eq)')),
                        DropdownMenuItem(value: 'eq', child: Text('= (Equals)')),
                      ],
                      onChanged: (v) => setState(() => _operator = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _valueCtrl,
                      decoration: const InputDecoration(labelText: 'Value *'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
            ),
            isActive: _currentStep >= 2,
            state: _currentStep == 2 ? StepState.editing : StepState.indexed,
          ),
        ],
      ),
    );
  }
}
