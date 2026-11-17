import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/estate_admin_repository.dart';

class EstateTeamPage extends StatefulWidget {
  const EstateTeamPage({
    super.key,
    required this.members,
    required this.repository,
  });
  final List<EstateTeamMember> members;
  final EstateAdminRepository repository;

  @override
  State<EstateTeamPage> createState() => _EstateTeamPageState();
}

class _EstateTeamPageState extends State<EstateTeamPage> {
  final _search = TextEditingController();
  late List<EstateTeamMember> _members;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _members = List.of(widget.members);
  }

  @override
  void didUpdateWidget(covariant EstateTeamPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.members, widget.members)) {
      _members = List.of(widget.members);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _members.where((item) => item.status == 'active').length;
    final invited = _members.where((item) => item.status == 'invited').length;
    final suspended = _members
        .where((item) => item.status == 'suspended')
        .length;
    final query = _search.text.trim().toLowerCase();
    final visible = _members.where((item) {
      final matchesQuery =
          query.isEmpty ||
          '${item.displayName} ${item.email ?? ''} ${item.roleLabel ?? ''} ${item.accessScopeLabel ?? ''}'
              .toLowerCase()
              .contains(query);
      return matchesQuery && (_status == 'all' || item.status == _status);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 40),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14,
          runSpacing: 14,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Staff and permissions',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Review estate staff memberships and pending invitations.',
                  style: TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: _inviteStaff,
              icon: const Icon(Icons.person_add_alt_rounded),
              label: const Text('Invite staff'),
            ),
          ],
        ),
        const SizedBox(height: 19),
        const _TeamPreviewNote(),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _TeamMetric(
                label: 'Active members',
                value: '$active',
                icon: Icons.verified_user_outlined,
                color: EstateColors.forest,
              ),
              _TeamMetric(
                label: 'Pending invitations',
                value: '$invited',
                icon: Icons.mail_outline_rounded,
                color: const Color(0xFF476B91),
              ),
              _TeamMetric(
                label: 'Suspended access',
                value: '$suspended',
                icon: Icons.person_off_outlined,
                color: const Color(0xFF984B43),
              ),
            ];
            return constraints.maxWidth < 750
                ? Column(
                    children: [
                      for (final card in cards)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: card,
                        ),
                    ],
                  )
                : Row(
                    children: [
                      for (var i = 0; i < cards.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: i == cards.length - 1 ? 0 : 12,
                            ),
                            child: cards[i],
                          ),
                        ),
                    ],
                  );
          },
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                'Estate team',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              '${visible.length} records',
              style: const TextStyle(color: EstateColors.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 360,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search name, role or email',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Membership status',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All statuses')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'invited', child: Text('Invited')),
                  DropdownMenuItem(
                    value: 'suspended',
                    child: Text('Suspended'),
                  ),
                  DropdownMenuItem(value: 'revoked', child: Text('Revoked')),
                  DropdownMenuItem(value: 'expired', child: Text('Expired')),
                ],
                onChanged: (value) => setState(() => _status = value ?? 'all'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const _TeamEmpty()
        else
          for (final member in visible) _TeamMemberCard(member: member),
      ],
    );
  }

  Future<void> _inviteStaff() async {
    final invite = await showDialog<({String email, String role})>(
      context: context,
      builder: (context) => const _StaffInvitationPreviewDialog(),
    );
    if (invite == null || !mounted) return;
    try {
      final member = await widget.repository.createEstateStaffInvitationPreview(
        email: invite.email,
        roleLabel: invite.role,
      );
      if (!mounted) return;
      setState(() => _members = [member, ..._members]);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation preview added. No email was sent.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message
          : 'The invitation preview could not be added.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _StaffInvitationPreviewDialog extends StatefulWidget {
  const _StaffInvitationPreviewDialog();

  @override
  State<_StaffInvitationPreviewDialog> createState() =>
      _StaffInvitationPreviewDialogState();
}

class _StaffInvitationPreviewDialogState
    extends State<_StaffInvitationPreviewDialog> {
  static const _roles = <String>[
    'Estate accountant',
    'Security supervisor',
    'Facility manager',
    'Maintenance officer',
  ];
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  String _role = _roles.first;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Invite estate staff'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                labelText: 'Account email',
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                    ? null
                    : 'Enter a valid email address.';
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Preview role'),
              items: _roles
                  .map(
                    (role) => DropdownMenuItem(value: role, child: Text(role)),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _role = value ?? _roles.first),
            ),
            const SizedBox(height: 12),
            const Text(
              'Preview only. The account is not looked up, the role is not granted and no invitation is sent.',
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
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.of(context).pop((email: _email.text.trim(), role: _role));
        },
        child: const Text('Add preview invitation'),
      ),
    ],
  );
}

class _TeamPreviewNote extends StatelessWidget {
  const _TeamPreviewNote();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7E8),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFFF0DCA9)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.admin_panel_settings_outlined,
          size: 19,
          color: Color(0xFF8A5B13),
        ),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Sample team data. Invite previews are kept in this session only; no account lookup, email or access grant occurs. Invitations require an existing account, a delegable role, estate policy checks and an audit record.',
            style: TextStyle(
              color: Color(0xFF795416),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TeamMetric extends StatelessWidget {
  const _TeamMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .1),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: EstateColors.muted),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _TeamMemberCard extends StatelessWidget {
  const _TeamMemberCard({required this.member});
  final EstateTeamMember member;
  @override
  Widget build(BuildContext context) {
    final status = _teamStatus(member.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 18,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 255,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFEAF3EE),
                    foregroundColor: EstateColors.forest,
                    child: Text(_initials(member.displayName)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (member.email != null)
                          Text(
                            member.email!,
                            style: const TextStyle(
                              color: EstateColors.muted,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 190,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.roleLabel ?? 'No role assigned',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  if (member.accessScopeLabel != null)
                    Text(
                      member.accessScopeLabel!,
                      style: const TextStyle(
                        color: EstateColors.muted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 155,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.kind.contains('invitation')
                        ? 'Invited ${member.invitedAt ?? '—'}'
                        : 'Last active ${member.lastActiveAt ?? '—'}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  if (member.expiresAt != null)
                    Text(
                      'Expires ${member.expiresAt}',
                      style: const TextStyle(
                        color: EstateColors.muted,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            _TeamStatusChip(
              label: status.$1,
              color: status.$2,
              background: status.$3,
            ),
            Tooltip(
              message: 'Role changes are managed by estate permissions.',
              child: IconButton(
                onPressed: null,
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamStatusChip extends StatelessWidget {
  const _TeamStatusChip({
    required this.label,
    required this.color,
    required this.background,
  });
  final String label;
  final Color color;
  final Color background;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}

class _TeamEmpty extends StatelessWidget {
  const _TeamEmpty();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Column(
        children: [
          Icon(Icons.groups_outlined, size: 38, color: EstateColors.muted),
          SizedBox(height: 10),
          Text('No team records match these filters.'),
        ],
      ),
    ),
  );
}

(String, Color, Color) _teamStatus(String status) => switch (status) {
  'active' => ('Active', EstateColors.forest, const Color(0xFFE9F4ED)),
  'invited' => (
    'Invitation pending',
    const Color(0xFF476B91),
    const Color(0xFFEAF1F8),
  ),
  'suspended' => (
    'Suspended',
    const Color(0xFF8A5B13),
    const Color(0xFFFFF2D8),
  ),
  'revoked' => ('Revoked', const Color(0xFF984B43), const Color(0xFFF9EDEC)),
  'expired' => ('Expired', EstateColors.muted, const Color(0xFFF0F1F2)),
  _ => (status, EstateColors.muted, const Color(0xFFF0F1F2)),
};

String _initials(String value) => value
    .trim()
    .split(RegExp(r'\s+'))
    .take(2)
    .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
    .join();
