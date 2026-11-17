import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class EstateTenancyCreateApiPage extends StatefulWidget {
  const EstateTenancyCreateApiPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });
  final EstateApplicationApiRepository repository;
  final String estateId, estateName;
  @override
  State<EstateTenancyCreateApiPage> createState() =>
      _EstateTenancyCreateApiPageState();
}

class _EstateTenancyCreateApiPageState
    extends State<EstateTenancyCreateApiPage> {
  final _formKey = GlobalKey<FormState>();
  final _tenant = TextEditingController();
  final _payee = TextEditingController();
  final _rent = TextEditingController();
  final _deposit = TextEditingController();
  final _dueDay = TextEditingController(text: '1');
  final _start = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final _end = TextEditingController();
  final _terms = TextEditingController();
  List<ManagedEstatePropertyChoice> _properties = const [];
  String? _propertyId;
  String _frequency = 'monthly';
  bool _loading = true, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _tenant,
      _payee,
      _rent,
      _deposit,
      _dueDay,
      _start,
      _end,
      _terms,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _properties = await widget.repository.loadManagedEstatePropertyChoices(
        widget.estateId,
      );
    } catch (e) {
      _error = e is EstateApiException
          ? e.message
          : 'Property choices could not be loaded.';
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
          _propertyId ??= _properties
              .where((p) => p.status == 'active')
              .firstOrNull
              ?.id;
        });
    }
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;
  String? _email(String? v) =>
      v == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
      ? 'Enter an account email'
      : null;
  Future<void> _create() async {
    if (!_formKey.currentState!.validate() || _propertyId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createEstateTenancy(
        estateId: widget.estateId,
        propertyId: _propertyId!,
        fields: {
          'tenantEmail': _tenant.text.trim(),
          'payeeEmail': _payee.text.trim(),
          'rentAmount': _rent.text.trim(),
          'currency': 'NGN',
          'rentFrequency': _frequency,
          'rentDueDay': int.parse(_dueDay.text),
          if (_deposit.text.trim().isNotEmpty)
            'depositAmount': _deposit.text.trim(),
          'effectiveFrom': _start.text.trim(),
          if (_end.text.trim().isNotEmpty) 'effectiveTo': _end.text.trim(),
          if (_terms.text.trim().isNotEmpty) 'termsNote': _terms.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tenancy submitted for manager approval.'),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is EstateApiException
              ? e.message
              : 'Tenancy could not be submitted.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: EstateColors.canvas,
    appBar: AppBar(title: const Text('Add tenancy')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      widget.estateName,
                      style: const TextStyle(color: EstateColors.muted),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Create tenancy terms',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        color: EstateColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The tenant and rent payee must already have accounts in this estate. The selected payee must have verified ownership. Submitting creates a pending record; approval activates occupancy.',
                      style: TextStyle(color: EstateColors.muted, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Card(
                        color: const Color(0xFFFFF0EE),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: EstateColors.red),
                          ),
                        ),
                      ),
                    if (_properties.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Add an active property before creating tenancy terms.',
                          ),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _propertyId,
                        decoration: const InputDecoration(
                          labelText: 'Property',
                        ),
                        items: _properties
                            .where((p) => p.status == 'active')
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text('${p.code} · ${p.propertyType}'),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _propertyId = v),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tenant,
                      validator: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Tenant account email',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _payee,
                      validator: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Verified landlord/payee account email',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _rent,
                            validator: _required,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Rent amount (NGN)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _frequency,
                            decoration: const InputDecoration(
                              labelText: 'Frequency',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'monthly',
                                child: Text('Monthly'),
                              ),
                              DropdownMenuItem(
                                value: 'quarterly',
                                child: Text('Quarterly'),
                              ),
                              DropdownMenuItem(
                                value: 'annually',
                                child: Text('Annually'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _frequency = v ?? 'monthly'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _dueDay,
                            validator: (v) {
                              final d = int.tryParse(v ?? '');
                              return d == null || d < 1 || d > 31
                                  ? 'Enter day 1–31'
                                  : null;
                            },
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Rent due day',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _deposit,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Deposit (optional)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _start,
                            validator: _required,
                            decoration: const InputDecoration(
                              labelText: 'Start date (YYYY-MM-DD)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _end,
                            decoration: const InputDecoration(
                              labelText: 'End date (optional, YYYY-MM-DD)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _terms,
                      maxLines: 3,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        labelText: 'Additional terms (optional)',
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _saving || _properties.isEmpty
                          ? null
                          : _create,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                      label: const Text('Submit for approval'),
                    ),
                  ],
                ),
              ),
      ),
    ),
  );
}
