import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class EstateStaffInvitationsApiPage extends StatefulWidget {
  const EstateStaffInvitationsApiPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });
  final EstateApplicationApiRepository repository;
  final String estateId, estateName;
  @override
  State<EstateStaffInvitationsApiPage> createState() =>
      _EstateStaffInvitationsApiPageState();
}

class _EstateStaffInvitationsApiPageState
    extends State<EstateStaffInvitationsApiPage> {
  late Future<List<EstateStaffInvitationRecord>> _items;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _items = widget.repository.loadStaffInvitations(widget.estateId);
  }

  Future<void> _reload() async {
    setState(() {
      _items = widget.repository.loadStaffInvitations(widget.estateId);
      _error = null;
    });
    try {
      await _items;
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  String _message(Object e) => e is EstateApiException
      ? e.message
      : 'Staff invitations are unavailable.';
  Future<void> _create() async {
    final email = TextEditingController();
    var role = 'ESTATE_MANAGER';
    final values = await showDialog<({String email, String role})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Invite estate staff'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: email,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Account email'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Estate role'),
                  items: const [
                    DropdownMenuItem(
                      value: 'ESTATE_MANAGER',
                      child: Text('Estate manager'),
                    ),
                    DropdownMenuItem(
                      value: 'FINANCE_MANAGER',
                      child: Text('Finance manager'),
                    ),
                    DropdownMenuItem(
                      value: 'SECURITY_OFFICER',
                      child: Text('Security officer'),
                    ),
                  ],
                  onChanged: (value) => setDialog(() => role = value ?? role),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The invite code is shown once. Share it privately; no email is sent.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                    .hasMatch(email.text.trim()))
                  Navigator.pop(context, (
                    email: email.text.trim(),
                    role: role,
                  ));
              },
              child: const Text('Create invitation'),
            ),
          ],
        ),
      ),
    );
    email.dispose();
    if (values == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.repository.createStaffInvitation(
        estateId: widget.estateId,
        email: values.email,
        role: values.role,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          final code = result['invitationCode'] as String? ?? '';
          return AlertDialog(
            title: const Text('Invitation created'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send the estate ID and this code to ${values.email}. It expires in seven days and can be accepted only by signing in with that email.',
                  ),
                  const SizedBox(height: 14),
                  SelectableText('Estate ID: ${result['estateId']}'),
                  const SizedBox(height: 8),
                  SelectableText(
                    code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: code)),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy code'),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      await _reload();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revoke(EstateStaffInvitationRecord invitation) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.revokeStaffInvitation(
        estateId: widget.estateId,
        invitationId: invitation.id,
      );
      await _reload();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _date(String raw) {
    final d = DateTime.tryParse(raw)?.toLocal();
    return d == null ? raw : '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: EstateColors.canvas,
    appBar: AppBar(
      title: Text('${widget.estateName} · Staff access'),
      actions: [
        IconButton(
          onPressed: _saving ? null : _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<EstateStaffInvitationRecord>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final items = snapshot.data ?? const <EstateStaffInvitationRecord>[];
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Staff and access',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _create,
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Invite staff'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Only estate administrators can create or revoke invitations. Codes expire after seven days and are stored as hashes.',
            ),
            if (_saving) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: EstateColors.red),
                ),
              ),
            const SizedBox(height: 18),
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Text('No staff invitations yet.'),
                ),
              ),
            for (final item in items)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: item.status == 'pending'
                        ? const Color(0xFFFFF2D8)
                        : const Color(0xFFE9F0EA),
                    child: Icon(
                      item.status == 'pending'
                          ? Icons.schedule
                          : Icons.verified_user_outlined,
                      color: EstateColors.forest,
                    ),
                  ),
                  title: Text(
                    item.email,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${item.role.replaceAll('_', ' ')} · ${item.status} · expires ${_date(item.expiresAt)}',
                  ),
                  trailing: item.status == 'pending'
                      ? IconButton(
                          tooltip: 'Revoke invitation',
                          onPressed: _saving ? null : () => _revoke(item),
                          icon: const Icon(Icons.cancel_outlined),
                        )
                      : null,
                ),
              ),
          ],
        );
      },
    ),
  );
}
