import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/resident_estate_repository.dart';

class ResidentVisitorPassesPage extends StatefulWidget {
  const ResidentVisitorPassesPage({
    super.key,
    required this.passes,
    required this.onBack,
    required this.repository,
    required this.onPassesChanged,
    required this.estateId,
  });

  final List<ResidentVisitorPass> passes;
  final VoidCallback onBack;
  final ResidentVisitorPassRepository repository;
  final VoidCallback onPassesChanged;
  final String estateId;

  @override
  State<ResidentVisitorPassesPage> createState() =>
      _ResidentVisitorPassesPageState();
}

class _ResidentVisitorPassesPageState extends State<ResidentVisitorPassesPage> {
  final _search = TextEditingController();
  late List<ResidentVisitorPass> _passes;
  String _filter = 'all';
  List<({String id, String label})> _properties = const [];
  bool _loadingProperties = true;
  final Set<String> _revoking = {};

  @override
  void initState() {
    super.initState();
    _passes = List.of(widget.passes);
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    try {
      final properties = await widget.repository.loadMyVisitorProperties(
        widget.estateId,
      );
      if (mounted)
        setState(() {
          _properties = properties;
          _loadingProperties = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingProperties = false);
    }
  }

  @override
  void didUpdateWidget(covariant ResidentVisitorPassesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.passes, widget.passes)) {
      _passes = List.of(widget.passes);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _passes.where((pass) {
      final matchesSearch =
          query.isEmpty ||
          '${pass.visitorName} ${pass.reference} ${pass.vehicleSummary ?? ''}'
              .toLowerCase()
              .contains(query);
      final matchesFilter = switch (_filter) {
        'active' => pass.status == 'active',
        'exhausted' => pass.status == 'exhausted',
        'ended' => pass.status == 'expired' || pass.status == 'revoked',
        _ => true,
      };
      return matchesSearch && matchesFilter;
    }).toList()..sort((a, b) => b.validFrom.compareTo(a.validFrom));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Community services'),
          ),
        ),
        Text(
          'Visitor passes',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 5),
        const Text('Review guest invitations and their entry status.'),
        const SizedBox(height: 16),
        const _VisitorPassNotice(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loadingProperties || _properties.isEmpty
                ? null
                : _createPreviewDraft,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Invite a visitor'),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search visitor or pass reference',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            _filterChip('All', 'all'),
            _filterChip('Active', 'active'),
            _filterChip('Exhausted', 'exhausted'),
            _filterChip('Ended', 'ended'),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          _EmptyPasses(
            message: _passes.isEmpty
                ? 'No visitor passes yet.'
                : 'No passes match these filters.',
          )
        else
          for (final pass in visible)
            _VisitorPassCard(
              pass: pass,
              revoking: _revoking.contains(pass.reference),
              onRevoke: pass.status == 'active'
                  ? () => _revokePass(pass)
                  : null,
            ),
        if (_properties.isEmpty && !_loadingProperties)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No active home access is linked to this account yet.',
              style: TextStyle(color: EstateColors.muted),
            ),
          ),
      ],
    );
  }

  Widget _filterChip(String label, String value) => ChoiceChip(
    label: Text(label),
    selected: _filter == value,
    onSelected: (_) => setState(() => _filter = value),
  );

  Future<void> _revokePass(ResidentVisitorPass pass) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke visitor pass?'),
        content: TextField(
          controller: reasonController,
          maxLength: 300,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'For example, plans changed',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty)
                Navigator.pop(context, reasonController.text.trim());
            },
            child: const Text('Revoke pass'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || reason.isEmpty || !mounted) return;
    setState(() => _revoking.add(pass.reference));
    try {
      await widget.repository.revokeVisitorPass(
        estateId: widget.estateId,
        passId: pass.reference,
        reason: reason,
      );
      if (!mounted) return;
      setState(() {
        _revoking.remove(pass.reference);
        final index = _passes.indexWhere(
          (item) => item.reference == pass.reference,
        );
        if (index >= 0) {
          final old = _passes[index];
          _passes[index] = ResidentVisitorPass(
            reference: old.reference,
            visitorName: old.visitorName,
            propertyId: old.propertyId,
            propertyLabel: old.propertyLabel,
            validFrom: old.validFrom,
            validUntil: old.validUntil,
            status: 'revoked',
            uses: old.uses,
            useLimit: old.useLimit,
            vehicleSummary: old.vehicleSummary,
          );
        }
      });
      widget.onPassesChanged();
    } catch (error) {
      if (mounted) {
        setState(() => _revoking.remove(pass.reference));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _createPreviewDraft() async {
    final draft =
        await showDialog<
          ({
            String name,
            String vehicle,
            String propertyId,
            DateTime from,
            DateTime until,
          })
        >(
          context: context,
          builder: (context) =>
              _VisitorPassDraftDialog(properties: _properties),
        );
    if (draft == null || !mounted) return;
    try {
      final pass = await widget.repository.createVisitorPassDraft(
        estateId: widget.estateId,
        propertyId: draft.propertyId,
        visitorName: draft.name,
        validFrom: draft.from,
        validUntil: draft.until,
        vehicleSummary: draft.vehicle,
      );
      if (!mounted) return;
      setState(() {
        _passes = [pass, ..._passes];
      });
      widget.onPassesChanged();
      if (pass.credential case final credential?) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Visitor pass issued'),
            content: SelectableText(
              'Share this entry credential with ${pass.visitorName}. It is shown once.\n\n$credential',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _VisitorPassNotice extends StatelessWidget {
  const _VisitorPassNotice();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F6F3),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD7E5DC)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, color: EstateColors.forest, size: 19),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Passes are tied to an authorized home and expire automatically. Share each entry credential privately; it is shown only once.',
            style: TextStyle(
              color: EstateColors.forest,
              height: 1.4,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}

class _VisitorPassCard extends StatelessWidget {
  const _VisitorPassCard({
    required this.pass,
    required this.onRevoke,
    required this.revoking,
  });
  final ResidentVisitorPass pass;
  final VoidCallback? onRevoke;
  final bool revoking;

  @override
  Widget build(BuildContext context) {
    final state = _passState(pass.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFEAF3EE),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: EstateColors.forest,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pass.visitorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        pass.reference,
                        style: const TextStyle(
                          color: EstateColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: state.$2,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    state.$1,
                    style: TextStyle(
                      color: state.$3,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onRevoke != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Revoke visitor pass',
                    onPressed: revoking ? null : onRevoke,
                    icon: revoking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.block_outlined),
                    color: EstateColors.red,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _DetailRow(label: 'Valid from', value: _dateTime(pass.validFrom)),
            const SizedBox(height: 7),
            _DetailRow(label: 'Valid until', value: _dateTime(pass.validUntil)),
            const SizedBox(height: 7),
            _DetailRow(
              label: 'Entries used',
              value: '${pass.uses} of ${pass.useLimit}',
            ),
            if (pass.vehicleSummary != null) ...[
              const SizedBox(height: 7),
              _DetailRow(label: 'Vehicle', value: pass.vehicleSummary!),
            ],
          ],
        ),
      ),
    );
  }
}

class _VisitorPassDraftDialog extends StatefulWidget {
  const _VisitorPassDraftDialog({required this.properties});
  final List<({String id, String label})> properties;

  @override
  State<_VisitorPassDraftDialog> createState() =>
      _VisitorPassDraftDialogState();
}

class _VisitorPassDraftDialogState extends State<_VisitorPassDraftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _vehicle = TextEditingController();
  DateTime _from = DateTime.now().add(const Duration(minutes: 30));
  DateTime _until = DateTime.now().add(const Duration(hours: 3));
  String? _propertyId;

  @override
  void dispose() {
    _name.dispose();
    _vehicle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Invite a visitor'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _propertyId ?? widget.properties.first.id,
                decoration: const InputDecoration(labelText: 'Home'),
                items: widget.properties
                    .map(
                      (p) =>
                          DropdownMenuItem(value: p.id, child: Text(p.label)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _propertyId = value),
              ),
              TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Visitor name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the visitor name.'
                    : null,
              ),
              TextFormField(
                controller: _vehicle,
                maxLength: 80,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Vehicle details (optional)',
                ),
              ),
              const SizedBox(height: 8),
              _dateField(
                context,
                label: 'Valid from',
                value: _from,
                onChanged: (value) => setState(() => _from = value),
              ),
              _dateField(
                context,
                label: 'Valid until',
                value: _until,
                onChanged: (value) => setState(() => _until = value),
              ),
              const SizedBox(height: 10),
              const Text(
                'Single use · valid for up to 24 hours · credentials are shown once.',
                style: TextStyle(
                  color: EstateColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Issue visitor pass')),
    ],
  );

  Widget _dateField(
    BuildContext context, {
    required String label,
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: EstateColors.muted),
      ),
      subtitle: Text(_dateTime(value)),
      trailing: const Icon(Icons.calendar_month_outlined),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date == null || !context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value),
        );
        if (time == null || !context.mounted) return;
        onChanged(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
      },
    ),
  );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_until.isAfter(_from) || _from.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose a future validity window with an end after its start.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop((
      name: _name.text.trim(),
      vehicle: _vehicle.text.trim(),
      from: _from,
      until: _until,
      propertyId: _propertyId ?? widget.properties.first.id,
    ));
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 100,
        child: Text(
          label,
          style: const TextStyle(color: EstateColors.muted, fontSize: 12),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}

class _EmptyPasses extends StatelessWidget {
  const _EmptyPasses({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 44),
    child: Center(
      child: Column(
        children: [
          const Icon(
            Icons.qr_code_2_rounded,
            size: 38,
            color: EstateColors.muted,
          ),
          const SizedBox(height: 10),
          Text(message),
        ],
      ),
    ),
  );
}

(String, Color, Color) _passState(String status) => switch (status) {
  'preview_draft' => (
    'Draft · preview only',
    const Color(0xFFFFF2D8),
    const Color(0xFF8A5B13),
  ),
  'active' => ('Active', const Color(0xFFE9F4ED), EstateColors.forest),
  'exhausted' => (
    'Uses exhausted',
    const Color(0xFFEAF1F8),
    const Color(0xFF476B91),
  ),
  'expired' => ('Expired', const Color(0xFFF0F1F2), EstateColors.muted),
  'revoked' => ('Revoked', const Color(0xFFF9EDEC), const Color(0xFF984B43)),
  _ => (status, const Color(0xFFF0F1F2), EstateColors.muted),
};

String _dateTime(DateTime value) =>
    '${value.day}/${value.month}/${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
