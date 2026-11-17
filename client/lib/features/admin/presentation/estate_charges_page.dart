import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class EstateChargesPage extends StatefulWidget {
  const EstateChargesPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
    required this.canReconcileSettlements,
  });
  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;
  final bool canReconcileSettlements;

  @override
  State<EstateChargesPage> createState() => _EstateChargesPageState();
}

class _EstateChargesPageState extends State<EstateChargesPage> {
  List<EstateChargeRecord> _charges = const [];
  List<ManagedEstatePropertyChoice> _properties = const [];
  List<EstateInvoiceDraftRecord> _invoiceDrafts = const [];
  List<EstateSettlementPolicyRecord> _settlementPolicies = const [];
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.repository.loadEstateCharges(widget.estateId),
        widget.repository.loadManagedEstatePropertyChoices(widget.estateId),
        widget.repository.loadEstateInvoiceDrafts(widget.estateId),
        widget.repository.loadEstateSettlementPolicies(widget.estateId),
      ]);
      _charges = results[0] as List<EstateChargeRecord>;
      _properties = results[1] as List<ManagedEstatePropertyChoice>;
      _invoiceDrafts = results[2] as List<EstateInvoiceDraftRecord>;
      _settlementPolicies = results[3] as List<EstateSettlementPolicyRecord>;
    } catch (error) {
      _error = error is EstateApiException
          ? error.message
          : 'Charges could not be loaded.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _today() {
    final date = DateTime.now();
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _dateString(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _newIdempotencyKey() => List.generate(
    48,
    (_) => Random.secure().nextInt(16).toRadixString(16),
  ).join();

  Future<void> _createSettlementPolicy() async {
    final formKey = GlobalKey<FormState>();
    final bank = TextEditingController();
    final accountName = TextEditingController();
    final accountNumber = TextEditingController();
    final reference = TextEditingController(
      text: 'Estate invoice {{invoiceNumber}}',
    );
    final currency = TextEditingController(text: 'NGN');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bank transfer instructions'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'These account details will be shown on issued invoices. They do not confirm or record payments.',
                    style: TextStyle(color: EstateColors.muted, fontSize: 12),
                  ),
                  TextFormField(
                    controller: currency,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Currency (ISO code)',
                    ),
                    validator: (v) =>
                        v == null ||
                            !RegExp(r'^[A-Za-z]{3}$').hasMatch(v.trim())
                        ? 'Enter a three-letter code.'
                        : null,
                  ),
                  TextFormField(
                    controller: bank,
                    decoration: const InputDecoration(labelText: 'Bank name'),
                    validator: _requiredText,
                  ),
                  TextFormField(
                    controller: accountName,
                    decoration: const InputDecoration(
                      labelText: 'Account name',
                    ),
                    validator: _requiredText,
                  ),
                  TextFormField(
                    controller: accountNumber,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Account number',
                    ),
                    validator: (v) =>
                        v == null ||
                            !RegExp(r'^[A-Za-z0-9 -]{6,34}$').hasMatch(v.trim())
                        ? 'Enter 6 to 34 letters or digits.'
                        : null,
                  ),
                  TextFormField(
                    controller: reference,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Transfer reference (use {{invoiceNumber}})',
                    ),
                    validator: _requiredText,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate())
                Navigator.pop(dialogContext, true);
            },
            child: const Text('Save draft'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      setState(() => _busy = true);
      try {
        await widget.repository.createEstateSettlementPolicy(
          estateId: widget.estateId,
          fields: {
            'currency': currency.text.trim().toUpperCase(),
            'bankName': bank.text.trim(),
            'accountName': accountName.text.trim(),
            'accountNumber': accountNumber.text.trim(),
            'paymentReferenceFormat': reference.text.trim(),
          },
        );
        await _load();
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save instructions: $error')),
          );
      }
    }
    bank.dispose();
    accountName.dispose();
    accountNumber.dispose();
    reference.dispose();
    currency.dispose();
  }

  String? _requiredText(String? value) =>
      value == null || value.trim().length < 2
      ? 'Enter at least two characters.'
      : null;

  Future<void> _activateSettlementPolicy(
    EstateSettlementPolicyRecord policy,
  ) async {
    setState(() => _busy = true);
    try {
      await widget.repository.activateEstateSettlementPolicy(
        estateId: widget.estateId,
        policyId: policy.id,
      );
      await _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not activate instructions: $error')),
        );
    }
  }

  Future<void> _issueInvoice(EstateInvoiceDraftRecord draft) async {
    setState(() => _busy = true);
    try {
      await widget.repository.issueEstateInvoiceDraft(
        estateId: widget.estateId,
        invoiceDraftId: draft.id,
      );
      await _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not issue invoice: $error')),
        );
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordSettlement(EstateInvoiceDraftRecord invoice) async {
    final formKey = GlobalKey<FormState>();
    final amount = TextEditingController();
    final reference = TextEditingController();
    final note = TextEditingController();
    var receivedAt = DateTime.now();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reconcile bank transfer'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Outstanding: ${invoice.currency} ${invoice.balance ?? invoice.total}',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Record this only after matching the transfer in the bank statement.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount received (${invoice.currency})',
                    ),
                    validator: (value) =>
                        value == null ||
                            !RegExp(r'^(0|[1-9]\d{0,9})\.\d{2}$')
                                .hasMatch(value.trim())
                        ? 'Enter an amount with two decimal places.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: reference,
                    decoration: const InputDecoration(
                      labelText: 'Bank transaction reference',
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 2
                        ? 'Enter the bank reference.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: receivedAt,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null)
                        setDialogState(() => receivedAt = picked);
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      'Transfer date: ${receivedAt.toIso8601String().substring(0, 10)}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: note,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'How was the transfer verified?',
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 10
                        ? 'Add at least 10 characters.'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext, {
                  'amount': amount.text.trim(),
                  'bankReference': reference.text.trim(),
                  'receivedAt': receivedAt.toIso8601String().substring(0, 10),
                  'verificationNote': note.text.trim(),
                });
              },
              child: const Text('Record verified transfer'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    reference.dispose();
    note.dispose();
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.recordEstateInvoiceSettlement(
        estateId: widget.estateId,
        invoiceId: invoice.id,
        fields: result,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Transfer reconciled. The resident receipt is now available.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reconcile transfer: $error')),
        );
      }
    }
  }

  Future<void> _draftInvoice(
    EstateChargeRecord charge,
    EstateChargeVersionRecord version,
  ) async {
    final applicable = _properties
        .where((property) {
          if (version.appliesTo == 'property')
            return property.id == version.propertyId;
          if (version.appliesTo == 'property_type')
            return property.propertyType.toLowerCase() ==
                (version.propertyType ?? '').toLowerCase();
          return true;
        })
        .toList(growable: false);
    if (applicable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active property matches this charge scope.'),
        ),
      );
      return;
    }
    final now = DateTime.now();
    late DateTime startDate;
    late DateTime endDate;
    switch (version.recurrence) {
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0);
      case 'quarterly':
        final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        startDate = DateTime(now.year, quarterMonth, 1);
        endDate = DateTime(now.year, quarterMonth + 3, 0);
      case 'annually':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31);
      default:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = startDate;
    }
    if (version.effectiveFrom.compareTo(_dateString(startDate)) > 0) {
      startDate = DateTime.parse(version.effectiveFrom);
      if (version.recurrence == 'monthly')
        startDate = DateTime(startDate.year, startDate.month, 1);
    }
    final payerEmail = TextEditingController();
    final periodStart = TextEditingController(text: _dateString(startDate));
    final periodEnd = TextEditingController(text: _dateString(endDate));
    final formKey = GlobalKey<FormState>();
    String? propertyId = applicable.first.id;
    var saving = false;
    String? error;
    String? priorPayload;
    String? idempotencyKey;
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text('Draft invoice · ${charge.code}'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: propertyId,
                      decoration: const InputDecoration(labelText: 'Property'),
                      items: applicable
                          .map(
                            (property) => DropdownMenuItem(
                              value: property.id,
                              child: Text(
                                '${property.code} · ${property.propertyType}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => refresh(() => propertyId = value),
                    ),
                    TextFormField(
                      controller: payerEmail,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Payer account email',
                      ),
                      validator: (value) =>
                          value == null ||
                              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(value.trim())
                          ? 'Enter the payer’s registered account email.'
                          : null,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: periodStart,
                            decoration: const InputDecoration(
                              labelText: 'Period from (YYYY-MM-DD)',
                            ),
                            validator: _dateValidator,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: periodEnd,
                            decoration: const InputDecoration(
                              labelText: 'Period to (YYYY-MM-DD)',
                            ),
                            validator: _dateValidator,
                          ),
                        ),
                      ],
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'The amount and due day come from this charge version. The server confirms the payer’s property relationship for this period.',
                          style: TextStyle(
                            color: EstateColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    if (error != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            error!,
                            style: const TextStyle(color: EstateColors.red),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final fields = {
                        'chargeVersionId': version.id,
                        'propertyId': propertyId,
                        'payerEmail': payerEmail.text.trim().toLowerCase(),
                        'periodStart': periodStart.text.trim(),
                        'periodEnd': periodEnd.text.trim(),
                      };
                      final payload = jsonEncode(fields);
                      if (payload != priorPayload) {
                        priorPayload = payload;
                        idempotencyKey = _newIdempotencyKey();
                      }
                      refresh(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await widget.repository.createEstateInvoiceDraft(
                          estateId: widget.estateId,
                          fields: fields,
                          idempotencyKey: idempotencyKey!,
                        );
                        if (dialogContext.mounted)
                          Navigator.pop(dialogContext, true);
                      } catch (exception) {
                        refresh(() {
                          saving = false;
                          error = exception is EstateApiException
                              ? exception.message
                              : 'Invoice draft could not be created.';
                        });
                      }
                    },
              child: Text(saving ? 'Creating…' : 'Create draft'),
            ),
          ],
        ),
      ),
    );
    payerEmail.dispose();
    periodStart.dispose();
    periodEnd.dispose();
    if (created == true && mounted) await _load();
  }

  Future<void> _edit({
    EstateChargeRecord? charge,
    EstateChargeVersionRecord? version,
  }) async {
    final code = TextEditingController(text: charge?.code ?? '');
    final name = TextEditingController(text: version?.name ?? '');
    final description = TextEditingController(text: version?.description ?? '');
    final category = TextEditingController(
      text: version?.category ?? 'estate_fee',
    );
    final amount = TextEditingController(text: version?.amount ?? '0.00');
    final currency = TextEditingController(text: version?.currency ?? 'NGN');
    final effectiveFrom = TextEditingController(
      text: charge == null ? version?.effectiveFrom ?? _today() : _today(),
    );
    final effectiveTo = TextEditingController(
      text: charge == null ? version?.effectiveTo ?? '' : '',
    );
    final dueDay = TextEditingController(text: '${version?.dueDay ?? 1}');
    final graceDays = TextEditingController(text: '${version?.graceDays ?? 0}');
    final propertyType = TextEditingController(
      text: version?.propertyType ?? '',
    );
    final formKey = GlobalKey<FormState>();
    var recurrence = (version?.recurrence ?? 'monthly').toUpperCase();
    var scope = (version?.appliesTo ?? 'estate').toUpperCase();
    String? propertyId = version?.propertyId;
    var saving = false;
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text(
            charge == null
                ? 'Add estate charge'
                : 'New version · ${charge.code}',
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (charge == null)
                      TextFormField(
                        controller: code,
                        decoration: const InputDecoration(
                          labelText: 'Charge code',
                        ),
                        validator: (value) =>
                            value == null || value.trim().length < 2
                            ? 'Enter a code.'
                            : null,
                      ),
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Charge name',
                      ),
                      validator: (value) =>
                          value == null || value.trim().length < 2
                          ? 'Enter a charge name.'
                          : null,
                    ),
                    TextFormField(
                      controller: description,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                    ),
                    TextFormField(
                      controller: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      validator: (value) =>
                          value == null || value.trim().length < 2
                          ? 'Enter a category.'
                          : null,
                    ),
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount (exactly 2 decimals)',
                      ),
                      validator: (value) =>
                          value == null ||
                              !RegExp(r'^(0|[1-9]\d{0,9})\.\d{2}$')
                                  .hasMatch(value.trim()) ||
                              double.tryParse(value) == 0
                          ? 'Enter a positive amount, e.g. 15000.00.'
                          : null,
                    ),
                    TextFormField(
                      controller: currency,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 3,
                      decoration: const InputDecoration(
                        labelText: 'Currency (ISO code)',
                      ),
                      validator: (value) =>
                          value == null ||
                              !RegExp(r'^[A-Z]{3}$')
                                  .hasMatch(value.trim().toUpperCase())
                          ? 'Enter a three-letter currency code.'
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: recurrence,
                      decoration: const InputDecoration(
                        labelText: 'Recurrence',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ONE_TIME',
                          child: Text('One time'),
                        ),
                        DropdownMenuItem(
                          value: 'MONTHLY',
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem(
                          value: 'QUARTERLY',
                          child: Text('Quarterly'),
                        ),
                        DropdownMenuItem(
                          value: 'ANNUALLY',
                          child: Text('Annually'),
                        ),
                      ],
                      onChanged: (value) =>
                          refresh(() => recurrence = value ?? recurrence),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: scope,
                      decoration: const InputDecoration(
                        labelText: 'Applies to',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ESTATE',
                          child: Text('All estate properties'),
                        ),
                        DropdownMenuItem(
                          value: 'PROPERTY',
                          child: Text('One property'),
                        ),
                        DropdownMenuItem(
                          value: 'PROPERTY_TYPE',
                          child: Text('Property type'),
                        ),
                      ],
                      onChanged: (value) => refresh(() {
                        scope = value ?? scope;
                        propertyId = version?.propertyId;
                      }),
                    ),
                    if (scope == 'PROPERTY')
                      DropdownButtonFormField<String>(
                        initialValue: propertyId,
                        decoration: const InputDecoration(
                          labelText: 'Property',
                        ),
                        items: _properties
                            .map(
                              (property) => DropdownMenuItem(
                                value: property.id,
                                child: Text(
                                  '${property.code} · ${property.propertyType}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        validator: (value) =>
                            value == null ? 'Select a property.' : null,
                        onChanged: _properties.isEmpty
                            ? null
                            : (value) => refresh(() => propertyId = value),
                      ),
                    if (scope == 'PROPERTY' && _properties.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Add a property to this estate before configuring a single-property charge.',
                            style: TextStyle(
                              color: EstateColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    if (scope == 'PROPERTY_TYPE')
                      TextFormField(
                        controller: propertyType,
                        decoration: const InputDecoration(
                          labelText: 'Property type',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter a property type.'
                            : null,
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: effectiveFrom,
                            decoration: const InputDecoration(
                              labelText: 'Effective from (YYYY-MM-DD)',
                            ),
                            validator: _dateValidator,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: effectiveTo,
                            decoration: const InputDecoration(
                              labelText: 'Effective to (optional)',
                            ),
                            validator: _dateValidator,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: dueDay,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Due day (1–31)',
                            ),
                            validator: (v) =>
                                int.tryParse(v ?? '') == null ||
                                    int.parse(v!) < 1 ||
                                    int.parse(v) > 31
                                ? 'Use 1 to 31.'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: graceDays,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Grace days (0–90)',
                            ),
                            validator: (v) =>
                                int.tryParse(v ?? '') == null ||
                                    int.parse(v!) < 0 ||
                                    int.parse(v) > 90
                                ? 'Use 0 to 90.'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    if (error != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            error!,
                            style: const TextStyle(color: EstateColors.red),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      refresh(() {
                        saving = true;
                        error = null;
                      });
                      final fields = <String, dynamic>{
                        'code': charge?.code ?? code.text.trim(),
                        'name': name.text.trim(),
                        'description': description.text.trim().isEmpty
                            ? null
                            : description.text.trim(),
                        'category': category.text.trim(),
                        'amount': amount.text.trim(),
                        'currency': currency.text.trim().toUpperCase(),
                        'recurrence': recurrence,
                        'effectiveFrom': effectiveFrom.text.trim(),
                        if (effectiveTo.text.trim().isNotEmpty)
                          'effectiveTo': effectiveTo.text.trim(),
                        'dueDay': int.parse(dueDay.text),
                        'graceDays': int.parse(graceDays.text),
                        'appliesTo': scope,
                        if (scope == 'PROPERTY') 'propertyId': propertyId,
                        if (scope == 'PROPERTY_TYPE')
                          'propertyType': propertyType.text.trim(),
                      };
                      try {
                        if (charge == null) {
                          await widget.repository.createEstateCharge(
                            estateId: widget.estateId,
                            fields: fields,
                          );
                        } else {
                          await widget.repository.createEstateChargeVersion(
                            estateId: widget.estateId,
                            chargeId: charge.id,
                            fields: fields,
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (exception) {
                        refresh(() {
                          saving = false;
                          error = exception is EstateApiException
                              ? exception.message
                              : 'The charge could not be saved.';
                        });
                      }
                    },
              child: Text(
                saving
                    ? 'Saving…'
                    : charge == null
                    ? 'Save draft'
                    : 'Save version',
              ),
            ),
          ],
        ),
      ),
    );
    for (final field in [
      code,
      name,
      description,
      category,
      amount,
      currency,
      effectiveFrom,
      effectiveTo,
      dueDay,
      graceDays,
      propertyType,
    ]) {
      field.dispose();
    }
    if (saved == true && mounted) await _load();
  }

  String? _dateValidator(String? value) =>
      value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value.trim())
      ? 'Use YYYY-MM-DD.'
      : null;

  Future<void> _activate(
    EstateChargeRecord charge,
    EstateChargeVersionRecord version,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Activate ${charge.code} v${version.versionNumber}?'),
        content: const Text(
          'This makes the version eligible for future invoice generation. Existing issued invoices will not change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Activate version'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.activateEstateChargeVersion(
        estateId: widget.estateId,
        chargeId: charge.id,
        versionId: version.id,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is EstateApiException
              ? error.message
              : 'Charge version could not be activated.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${widget.estateName} · Charges'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          tooltip: 'Refresh charges',
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estate charges',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: EstateColors.ink,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Versioned charges, settlement instructions and invoice issue controls.',
                        style: TextStyle(color: EstateColors.muted),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _edit(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add charge'),
                ),
              ],
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
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Settlement instructions',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: EstateColors.ink,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _createSettlementPolicy,
                  icon: const Icon(Icons.account_balance_outlined),
                  label: const Text('Add bank details'),
                ),
              ],
            ),
            const SizedBox(height: 7),
            const Text(
              'Invoices use the active bank details for their currency. Changing instructions later does not change issued invoices.',
              style: TextStyle(color: EstateColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (_settlementPolicies.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Add and activate transfer instructions before issuing invoices.',
                  ),
                ),
              )
            else
              ..._settlementPolicies.map(
                (policy) => Card(
                  child: ListTile(
                    leading: Icon(
                      policy.status == 'active'
                          ? Icons.verified_outlined
                          : Icons.account_balance_outlined,
                      color: policy.status == 'active'
                          ? EstateColors.forest
                          : EstateColors.muted,
                    ),
                    title: Text('${policy.currency} · ${policy.bankName}'),
                    subtitle: Text(
                      '${policy.accountName} · ${policy.accountNumber}',
                    ),
                    trailing: policy.status == 'draft'
                        ? TextButton(
                            onPressed: _busy
                                ? null
                                : () => _activateSettlementPolicy(policy),
                            child: const Text('Activate'),
                          )
                        : Chip(
                            label: Text(
                              policy.status == 'active' ? 'Active' : 'Retired',
                            ),
                          ),
                  ),
                ),
              ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            if (!_busy && _charges.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No charge definitions yet. Create a draft to configure an estate fee.',
                  ),
                ),
              ),
            ..._charges.map(
              (charge) => Card(
                margin: const EdgeInsets.only(top: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              charge.code,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _edit(
                                    charge: charge,
                                    version: charge.versions.firstOrNull,
                                  ),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('New version'),
                          ),
                        ],
                      ),
                      if (charge.versions.isEmpty)
                        const Text(
                          'No version records.',
                          style: TextStyle(color: EstateColors.muted),
                        ),
                      ...charge.versions.map(
                        (version) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${version.name} · ${version.currency} ${version.amount} · ${version.recurrence}',
                          ),
                          subtitle: Text(
                            'v${version.versionNumber} · ${version.status} · ${version.appliesTo}${version.propertyType == null ? '' : ' (${version.propertyType})'} · from ${version.effectiveFrom}${version.effectiveTo == null ? '' : ' to ${version.effectiveTo}'} · due day ${version.dueDay}',
                          ),
                          trailing: version.status == 'draft'
                              ? FilledButton.tonal(
                                  onPressed: _busy
                                      ? null
                                      : () => _activate(charge, version),
                                  child: const Text('Activate'),
                                )
                              : version.status == 'active'
                              ? OutlinedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _draftInvoice(charge, version),
                                  icon: const Icon(Icons.receipt_long_outlined),
                                  label: const Text('Draft invoice'),
                                )
                              : const Icon(
                                  Icons.check_circle_outline,
                                  color: EstateColors.forest,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Invoice register',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: EstateColors.ink,
                    ),
                  ),
                ),
                Text(
                  '${_invoiceDrafts.where((invoice) => invoice.status == 'draft').length} drafts',
                  style: const TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_busy && _invoiceDrafts.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No invoice drafts yet. Activate a charge version, then draft an invoice for a property and an approved payer.',
                  ),
                ),
              ),
            ..._invoiceDrafts.map(
              (draft) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.receipt_long_outlined),
                  ),
                  title: Text(
                    '${draft.invoiceNumber} · ${draft.currency} ${draft.total}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${draft.chargeCode} · ${draft.propertyCode} · ${draft.payerName}\n${draft.periodStart} – ${draft.periodEnd} · Due ${draft.dueDate}',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (draft.status == 'draft')
                        OutlinedButton(
                          onPressed: _busy ? null : () => _issueInvoice(draft),
                          child: const Text('Issue invoice'),
                        ),
                      if (widget.canReconcileSettlements &&
                          (draft.status == 'issued' ||
                              draft.status == 'partially_paid'))
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _recordSettlement(draft),
                          icon: const Icon(Icons.account_balance_outlined),
                          label: const Text('Reconcile transfer'),
                        ),
                      Chip(label: Text(draft.status.toUpperCase())),
                    ],
                  ),
                ),
              ),
            ),
            if (_invoiceDrafts.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Issuing snapshots the active bank transfer instructions and makes the demand available in the resident billing view. No notification is sent, and payment remains unverified until a trusted settlement is recorded.',
                  style: TextStyle(color: EstateColors.muted, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
