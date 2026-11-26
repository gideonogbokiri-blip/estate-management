import 'package:flutter/material.dart';

import '../../../../core/design/terra_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../onboarding/data/estate_application_repository.dart';

/// Terra-styled staff invitation overview for an estate manager.
class TerraStaffPage extends StatefulWidget {
  const TerraStaffPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;

  @override
  State<TerraStaffPage> createState() => _TerraStaffPageState();
}

class _TerraStaffPageState extends State<TerraStaffPage> {
  List<EstateStaffInvitationRecord> _invitations = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _invitations =
          await widget.repository.loadStaffInvitations(widget.estateId);
    } catch (_) {
      _error = 'Staff invitations could not be loaded.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _invite() async {
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
                    .hasMatch(email.text.trim())) {
                  Navigator.pop(context, (
                    email: email.text.trim(),
                    role: role,
                  ));
                }
              },
              child: const Text('Create invitation'),
            ),
          ],
        ),
      ),
    );
    email.dispose();
    if (values == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await widget.repository.createStaffInvitation(
        estateId: widget.estateId,
        email: values.email,
        role: values.role,
      );
      if (!mounted) return;
      final code = result['invitationCode']?.toString() ?? '';
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invitation created'),
          content: Text(
            'Share this code privately with ${values.email}. '
            'It expires in seven days.\n\n$code',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'Invitation could not be created.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  TerraBadgeTone _tone(String status) => switch (status) {
        'accepted' || 'active' => TerraBadgeTone.sage,
        'pending' => TerraBadgeTone.amber,
        'revoked' || 'expired' => TerraBadgeTone.danger,
        _ => TerraBadgeTone.outline,
      };

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        appBar: AppBar(
          title: const Text('Staff access'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading || _busy ? null : _load,
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
                    title: widget.estateName,
                    trailing: FilledButton.icon(
                      onPressed: _busy ? null : _invite,
                      icon: const Icon(Icons.person_add_alt, size: 18),
                      label: const Text('Invite staff'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Staff access is role-scoped: each invitation grants only '
                    'the permissions of its assigned estate role.',
                    style: TextStyle(
                      color: TerraColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TerraSectionTitle(
                    title: 'Invitations',
                    trailing: TerraBadge(label: '${_invitations.length}'),
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(color: TerraColors.forest),
                    )
                  else if (_error != null)
                    TerraCard(
                      child: TerraEmpty(
                        message: _error!,
                        icon: Icons.error_outline,
                      ),
                    )
                  else if (_invitations.isEmpty)
                    const TerraCard(
                      child: TerraEmpty(
                        message: 'No staff invitations have been sent yet.',
                        icon: Icons.person_outline,
                      ),
                    )
                  else
                    for (final invitation in _invitations)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TerraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      invitation.email,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: TerraColors.ink,
                                      ),
                                    ),
                                  ),
                                  TerraBadge(
                                    label: invitation.status,
                                    tone: _tone(invitation.status),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${invitation.role.replaceAll('_', ' ')} · '
                                'expires ${AppFormat.date(invitation.expiresAt)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: TerraColors.muted,
                                ),
                              ),
                            ],
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
}
