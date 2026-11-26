import 'package:flutter/material.dart';

import '../../../../core/design/terra_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../onboarding/data/estate_application_repository.dart';

/// Versioned estate charges, issued invoices and bank instructions, presented
/// in the Terra Crest visual language.
class TerraChargesPage extends StatefulWidget {
  const TerraChargesPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;

  @override
  State<TerraChargesPage> createState() => _TerraChargesPageState();
}

class _TerraChargesPageState extends State<TerraChargesPage> {
  List<EstateChargeRecord> _charges = const [];
  List<EstateInvoiceDraftRecord> _invoices = const [];
  List<EstateSettlementPolicyRecord> _policies = const [];
  List<ManagedEstatePropertyChoice> _properties = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Each read is independent: one failing request must not blank the page.
    Future<void> load<T>(Future<T> Function() read, void Function(T) apply) async {
      try {
        apply(await read());
      } catch (_) {
        // Keep the previous value for this section.
      }
      if (mounted) setState(() {});
    }

    await Future.wait([
      load(
        () => widget.repository.loadEstateCharges(widget.estateId),
        (value) => _charges = value,
      ),
      load(
        () => widget.repository.loadEstateInvoiceDrafts(widget.estateId),
        (value) => _invoices = value,
      ),
      load(
        () => widget.repository.loadEstateSettlementPolicies(widget.estateId),
        (value) => _policies = value,
      ),
      load(
        () => widget.repository.loadManagedEstatePropertyChoices(widget.estateId),
        (value) => _properties = value,
      ),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static String? _dateValidator(String? value) =>
      value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value.trim())
          ? 'Use YYYY-MM-DD.'
          : null;

  Future<void> _createCharge() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final description = TextEditingController();
    final category = TextEditingController(text: 'estate_fee');
    final amount = TextEditingController();
    final currency = TextEditingController(text: 'NGN');
    final effectiveFrom = TextEditingController(text: _today());
    final dueDay = TextEditingController(text: '1');
    final graceDays = TextEditingController(text: '0');
    final propertyType = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var recurrence = 'MONTHLY';
    var scope = 'ESTATE';
    String? propertyId;
    var saving = false;
    String? dialogError;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Create charge'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'A charge is saved as a draft first. Activate it before it can be used for invoices.',
                      style: TextStyle(
                        color: TerraColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: code,
                      decoration: const InputDecoration(labelText: 'Charge code'),
                      validator: (value) => value == null || value.trim().length < 2
                          ? 'Enter a code.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Charge name'),
                      validator: (value) => value == null || value.trim().length < 2
                          ? 'Enter a charge name.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: description,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter a category.'
                          : null,
                    ),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: currency,
                      maxLength: 3,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Currency (ISO code)',
                      ),
                      validator: (value) => value == null ||
                              !RegExp(r'^[A-Za-z]{3}$').hasMatch(value.trim())
                          ? 'Enter a three-letter currency code.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: recurrence,
                      decoration: const InputDecoration(labelText: 'Recurrence'),
                      items: const [
                        DropdownMenuItem(value: 'ONE_TIME', child: Text('One time')),
                        DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                        DropdownMenuItem(
                          value: 'QUARTERLY',
                          child: Text('Quarterly'),
                        ),
                        DropdownMenuItem(value: 'ANNUALLY', child: Text('Annually')),
                      ],
                      onChanged: (value) =>
                          refresh(() => recurrence = value ?? recurrence),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: scope,
                      decoration: const InputDecoration(labelText: 'Applies to'),
                      items: const [
                        DropdownMenuItem(
                          value: 'ESTATE',
                          child: Text('All estate properties'),
                        ),
                        DropdownMenuItem(value: 'PROPERTY', child: Text('One property')),
                        DropdownMenuItem(
                          value: 'PROPERTY_TYPE',
                          child: Text('Property type'),
                        ),
                      ],
                      onChanged: (value) => refresh(() => scope = value ?? scope),
                    ),
                    if (scope == 'PROPERTY') ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String?>(
                        initialValue: propertyId,
                        decoration: const InputDecoration(labelText: 'Property'),
                        items: _properties
                            .map(
                              (property) => DropdownMenuItem<String?>(
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
                        onChanged: (value) => refresh(() => propertyId = value),
                      ),
                      if (_properties.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Add a property to this estate before choosing a single-property charge.',
                            style: TextStyle(
                              color: TerraColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                    if (scope == 'PROPERTY_TYPE') ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: propertyType,
                        decoration: const InputDecoration(labelText: 'Property type'),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Enter a property type.'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: effectiveFrom,
                      decoration: const InputDecoration(
                        labelText: 'Effective from (YYYY-MM-DD)',
                      ),
                      validator: _dateValidator,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: dueDay,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Due day (1–31)',
                            ),
                            validator: (value) {
                              final parsed = int.tryParse(value ?? '');
                              return parsed == null || parsed < 1 || parsed > 31
                                  ? 'Use 1 to 31.'
                                  : null;
                            },
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
                            validator: (value) {
                              final parsed = int.tryParse(value ?? '');
                              return parsed == null || parsed < 0 || parsed > 90
                                  ? 'Use 0 to 90.'
                                  : null;
                            },
                          ),
                        ),
                      ],
                    ),
                    if (dialogError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          dialogError!,
                          style: const TextStyle(
                            color: TerraColors.danger,
                            fontSize: 12,
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
              onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      refresh(() {
                        saving = true;
                        dialogError = null;
                      });
                      final fields = <String, dynamic>{
                        'code': code.text.trim(),
                        'name': name.text.trim(),
                        'description': description.text.trim().isEmpty
                            ? null
                            : description.text.trim(),
                        'category': category.text.trim(),
                        'amount': amount.text.trim(),
                        'currency': currency.text.trim().toUpperCase(),
                        'recurrence': recurrence,
                        'effectiveFrom': effectiveFrom.text.trim(),
                        'dueDay': int.parse(dueDay.text),
                        'graceDays': int.parse(graceDays.text),
                        'appliesTo': scope,
                        if (scope == 'PROPERTY') 'propertyId': propertyId,
                        if (scope == 'PROPERTY_TYPE')
                          'propertyType': propertyType.text.trim(),
                      };
                      try {
                        await widget.repository.createEstateCharge(
                          estateId: widget.estateId,
                          fields: fields,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                      } catch (_) {
                        refresh(() {
                          saving = false;
                          dialogError = 'The charge could not be saved.';
                        });
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Create charge'),
            ),
          ],
        ),
      ),
    );

    for (final controller in [
      code,
      name,
      description,
      category,
      amount,
      currency,
      effectiveFrom,
      dueDay,
      graceDays,
      propertyType,
    ]) {
      controller.dispose();
    }
    if (created != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Charge draft created.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  TerraBadgeTone _tone(String status) => switch (status.toLowerCase()) {
        'active' || 'issued' || 'paid' || 'settled' => TerraBadgeTone.sage,
        'draft' || 'pending' || 'partially_paid' => TerraBadgeTone.amber,
        _ => TerraBadgeTone.outline,
      };

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        appBar: AppBar(
          title: const Text('Charges'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading || _saving ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  TerraSectionTitle(
                    title: 'Charge definitions',
                    trailing: FilledButton.icon(
                      onPressed: _loading || _saving ? null : _createCharge,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Create charge'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.estateName,
                    style: const TextStyle(
                      color: TerraColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Versioned fee definitions drive recurring levies. A draft must be activated before it can be issued.',
                    style: TextStyle(
                      color: TerraColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loading && _charges.isEmpty)
                    const Center(
                      child: CircularProgressIndicator(color: TerraColors.forest),
                    )
                  else if (_charges.isEmpty)
                    const TerraCard(
                      child: TerraEmpty(
                        message: 'No charge definitions yet. Create a draft to configure an estate fee.',
                        icon: Icons.receipt_long_outlined,
                      ),
                    )
                  else
                    ..._charges.map(
                      (charge) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TerraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TerraLabel('Charge code'),
                              const SizedBox(height: 3),
                              Text(
                                charge.code,
                                style: const TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: TerraColors.ink,
                                ),
                              ),
                              if (charge.versions.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 10),
                                  child: TerraEmpty(
                                    message: 'No version records for this charge.',
                                  ),
                                )
                              else
                                ...charge.versions.map(
                                  (version) => Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: TerraColors.surfaceMuted,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'v${version.versionNumber} · ${version.name}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: TerraColors.ink,
                                                  ),
                                                ),
                                              ),
                                              TerraBadge(
                                                label: version.status,
                                                tone: _tone(version.status),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 22,
                                            runSpacing: 10,
                                            children: [
                                              _term(
                                                'Amount',
                                                AppFormat.money(
                                                  version.amount,
                                                  currency: version.currency,
                                                ),
                                              ),
                                              _term(
                                                'Recurrence',
                                                version.recurrence.replaceAll('_', ' '),
                                              ),
                                              _term(
                                                'Scope',
                                                version.appliesTo.replaceAll('_', ' '),
                                              ),
                                              _term(
                                                'Effective from',
                                                AppFormat.date(version.effectiveFrom),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 26),
                  TerraSectionTitle(
                    title: 'Issued invoices',
                    trailing: TerraBadge(
                      label: '${_invoices.length} invoices',
                      tone: TerraBadgeTone.outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_invoices.isEmpty)
                    const TerraCard(
                      child: TerraEmpty(
                        message: 'No invoices have been drafted for this estate.',
                        icon: Icons.receipt_outlined,
                      ),
                    )
                  else
                    ..._invoices.map(
                      (invoice) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TerraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      invoice.invoiceNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: TerraColors.ink,
                                      ),
                                    ),
                                  ),
                                  TerraBadge(
                                    label: invoice.status.replaceAll('_', ' '),
                                    tone: _tone(invoice.status),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 22,
                                runSpacing: 10,
                                children: [
                                  _term(
                                    'Property',
                                    invoice.propertyCode.isEmpty
                                        ? '—'
                                        : invoice.propertyCode,
                                  ),
                                  _term(
                                    'Total',
                                    AppFormat.money(
                                      invoice.total,
                                      currency: invoice.currency,
                                    ),
                                  ),
                                  _term(
                                    'Balance',
                                    AppFormat.money(
                                      invoice.balance ?? invoice.total,
                                      currency: invoice.currency,
                                    ),
                                  ),
                                  _term(
                                    'Due',
                                    AppFormat.date(invoice.dueDate),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 26),
                  const TerraSectionTitle(title: 'Bank instructions'),
                  const SizedBox(height: 4),
                  const Text(
                    'Active instructions are shown on invoices. Changing them later does not alter invoices already issued.',
                    style: TextStyle(
                      color: TerraColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_policies.isEmpty)
                    const TerraCard(
                      child: TerraEmpty(
                        message: 'No bank instructions have been configured for this estate.',
                        icon: Icons.account_balance_outlined,
                      ),
                    )
                  else
                    ..._policies.map(
                      (policy) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TerraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${policy.currency} · ${policy.bankName}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: TerraColors.ink,
                                      ),
                                    ),
                                  ),
                                  TerraBadge(
                                    label: policy.status,
                                    tone: _tone(policy.status),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${policy.accountName} · ${policy.accountNumber}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Transfer reference: ${policy.paymentReferenceFormat}',
                                style: const TextStyle(
                                  color: TerraColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _term(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TerraLabel(label),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: TerraColors.ink,
            ),
          ),
        ],
      );
}
