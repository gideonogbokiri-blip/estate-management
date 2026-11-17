import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class GateSecurityPage extends StatefulWidget {
  const GateSecurityPage({
    super.key,
    required this.estateId,
    required this.gates,
    required this.repository,
    required this.onBack,
  });
  final String estateId;
  final List<EstateGateRecord> gates;
  final EstateApplicationApiRepository repository;
  final VoidCallback onBack;

  @override
  State<GateSecurityPage> createState() => _GateSecurityPageState();
}

class _GateSecurityPageState extends State<GateSecurityPage> {
  final _credential = TextEditingController();
  EstateGateRecord? _gate;
  List<GateCurrentVisitorRecord> _visitors = const [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _gate = widget.gates.firstOrNull;
    _refresh();
  }

  @override
  void dispose() {
    _credential.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final gate = _gate;
    if (gate == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final visitors = await widget.repository.loadCurrentGateVisitors(
        estateId: widget.estateId,
        gateId: gate.id,
      );
      if (mounted) setState(() => _visitors = visitors);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkIn() async {
    final gate = _gate;
    final credential = _credential.text.trim();
    if (gate == null || credential.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final key = List.generate(
        32,
        (_) => Random.secure().nextInt(16).toRadixString(16),
      ).join();
      final result = await widget.repository.checkInGateVisitor(
        estateId: widget.estateId,
        gateId: gate.id,
        credential: credential,
        idempotencyKey: key,
      );
      _credential.clear();
      await _refresh();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result['visitorName'] ?? 'Visitor'} checked in.'),
          ),
        );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkOut(GateCurrentVisitorRecord visitor) async {
    final gate = _gate;
    if (gate == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.checkOutGateVisitor(
        estateId: widget.estateId,
        gateId: gate.id,
        visitId: visitor.visitId,
      );
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Resident home'),
        ),
      ),
      Text('Gate security', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 5),
      const Text(
        'Verify visitor passes and keep the current gate list up to date.',
      ),
      const SizedBox(height: 20),
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
      if (widget.gates.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No active gate assignment is linked to your security account. Ask an estate manager to assign you to a gate.',
            ),
          ),
        )
      else ...[
        DropdownButtonFormField<String>(
          value: _gate?.id,
          decoration: const InputDecoration(labelText: 'Assigned gate'),
          items: widget.gates
              .map(
                (gate) => DropdownMenuItem(
                  value: gate.id,
                  child: Text('${gate.name} · ${gate.code}'),
                ),
              )
              .toList(),
          onChanged: _busy
              ? null
              : (id) async {
                  setState(
                    () => _gate = widget.gates
                        .where((gate) => gate.id == id)
                        .firstOrNull,
                  );
                  await _refresh();
                },
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Check in visitor',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Scan or enter the credential provided by the resident. Invalid codes receive the same generic response.',
                  style: TextStyle(color: EstateColors.muted, height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _credential,
                  maxLength: 256,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Visitor credential',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                  onSubmitted: (_) => _busy ? null : _checkIn(),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _checkIn,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: Text(_busy ? 'Checking…' : 'Verify and check in'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Currently inside (${_visitors.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            IconButton(
              onPressed: _busy ? null : _refresh,
              tooltip: 'Refresh visitors',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_visitors.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No visitors are currently checked in at this gate.'),
            ),
          ),
        for (final visitor in _visitors)
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE9F2ED),
                child: Icon(Icons.person_outline, color: EstateColors.forest),
              ),
              title: Text(
                visitor.visitorName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${visitor.propertyLabel} · Host: ${visitor.hostDisplayName}\nChecked in ${visitor.checkedInAt}${visitor.vehicleSummary == null ? '' : '\n${visitor.vehicleSummary}'}',
              ),
              isThreeLine: true,
              trailing: TextButton(
                onPressed: _busy ? null : () => _checkOut(visitor),
                child: const Text('Check out'),
              ),
            ),
          ),
      ],
    ],
  );
}
