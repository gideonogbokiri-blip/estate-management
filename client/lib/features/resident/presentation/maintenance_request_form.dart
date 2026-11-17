import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/resident_estate_repository.dart';

class MaintenanceRequestForm extends StatefulWidget {
  const MaintenanceRequestForm({super.key, required this.repository});

  final ResidentEstateRepository repository;

  @override
  State<MaintenanceRequestForm> createState() => _MaintenanceRequestFormState();
}

class _MaintenanceRequestFormState extends State<MaintenanceRequestForm> {
  static const _categories = <String, String>{
    'plumbing': 'Plumbing',
    'electrical': 'Electrical',
    'security': 'Security',
    'cleaning': 'Cleaning',
    'other': 'Other',
  };
  static const _priorities = <String, String>{
    'normal': 'Normal',
    'high': 'High',
    'urgent': 'Urgent',
  };
  static const _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~-';

  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _secureRandom = Random.secure();
  String _category = 'plumbing';
  String _priority = 'normal';
  String _idempotencyKey = '';
  String? _errorMessage;
  String? _lastSubmittedPayload;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = _newRequestKey();
    _descriptionController.addListener(_onDescriptionChanged);
  }

  @override
  void dispose() {
    _descriptionController
      ..removeListener(_onDescriptionChanged)
      ..dispose();
    super.dispose();
  }

  String _newRequestKey() => List.generate(
    32,
    (_) => _alphabet[_secureRandom.nextInt(_alphabet.length)],
  ).join();

  String get _payload =>
      '$_category|$_priority|${_descriptionController.text.trim()}';

  void _onDescriptionChanged() => _invalidateRetryIfChanged();

  void _invalidateRetryIfChanged() {
    if (_lastSubmittedPayload != null && _lastSubmittedPayload != _payload) {
      _lastSubmittedPayload = null;
      _idempotencyKey = _newRequestKey();
    }
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    final submittedPayload = _payload;
    try {
      final request = await widget.repository.submitMaintenanceRequest(
        category: _category,
        priority: _priority,
        description: _descriptionController.text.trim(),
        idempotencyKey: _idempotencyKey,
      );
      if (mounted) Navigator.of(context).pop(request);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _lastSubmittedPayload = submittedPayload;
        _errorMessage = 'We could not submit this request. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      8,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'New maintenance request',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 5),
            const Text(
              'Tell your estate team what needs attention.',
              style: TextStyle(color: EstateColors.muted),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _category = value);
                      _invalidateRetryIfChanged();
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: _priorities.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _priority = value);
                      _invalidateRetryIfChanged();
                    },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              enabled: !_submitting,
              minLines: 4,
              maxLines: 6,
              maxLength: 700,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Describe the issue',
                hintText: 'Include where it is and what you noticed.',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                final description = value?.trim() ?? '';
                if (description.isEmpty) return 'Add a short description.';
                if (description.length > 700) {
                  return 'Use 700 characters or fewer.';
                }
                return null;
              },
            ),
            if (_priority == 'urgent') ...[
              const SizedBox(height: 8),
              const _UrgentNotice(),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              _SubmissionError(message: _errorMessage!),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit request'),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'This preview keeps requests in memory for this session.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: EstateColors.muted),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _UrgentNotice extends StatelessWidget {
  const _UrgentNotice();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: EstateColors.amberWash,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Text(
      'Urgent requests are not emergency dispatch. For immediate danger, contact local emergency services and your estate security desk.',
      style: TextStyle(fontSize: 12, color: EstateColors.ink),
    ),
  );
}

class _SubmissionError extends StatelessWidget {
  const _SubmissionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEFED),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      message,
      style: const TextStyle(color: EstateColors.red, fontSize: 12),
    ),
  );
}
