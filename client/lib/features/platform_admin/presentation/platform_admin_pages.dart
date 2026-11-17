import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/platform_application_repository.dart';

class PlatformEstatesPage extends StatefulWidget {
  const PlatformEstatesPage({
    super.key,
    required this.estates,
    required this.onRefresh,
  });
  final Future<List<PlatformEstateRecord>> estates;
  final VoidCallback onRefresh;

  @override
  State<PlatformEstatesPage> createState() => _PlatformEstatesPageState();
}

class _PlatformEstatesPageState extends State<PlatformEstatesPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Estates',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          IconButton(
            tooltip: 'Refresh estates',
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: 5),
      const Text(
        'Active estates registered through the platform review flow.',
        style: TextStyle(color: EstateColors.muted),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Search name, code or state',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 16),
      FutureBuilder<List<PlatformEstateRecord>>(
        future: widget.estates,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text('Estates could not be loaded: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.requireData.where((estate) {
            final term = _search.text.toLowerCase().trim();
            return term.isEmpty ||
                '${estate.name} ${estate.estateCode} ${estate.location}'
                    .toLowerCase()
                    .contains(term);
          }).toList();
          if (items.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No estates match this view.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: EstateColors.muted),
                ),
              ),
            );
          }
          return Column(
            children: items
                .map(
                  (estate) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEAF3EE),
                        child: Icon(Icons.apartment_outlined,
                            color: EstateColors.forest),
                      ),
                      title: Text(
                        estate.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${estate.estateCode} · ${estate.location}\n'
                        '${estate.propertyCount} properties · ${estate.memberCount} members',
                        style: const TextStyle(fontSize: 11, height: 1.5),
                      ),
                      isThreeLine: true,
                      trailing: Chip(
                        label: Text(estate.status),
                        backgroundColor: estate.status == 'ACTIVE'
                            ? const Color(0xFFE4EFE8)
                            : const Color(0xFFFFF1DA),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class PlatformTeamPage extends StatefulWidget {
  const PlatformTeamPage({
    super.key,
    required this.repository,
    required this.team,
    required this.onChanged,
  });
  final PlatformApplicationApiRepository repository;
  final Future<List<PlatformTeamMember>> team;
  final VoidCallback onChanged;

  @override
  State<PlatformTeamPage> createState() => _PlatformTeamPageState();
}

class _PlatformTeamPageState extends State<PlatformTeamPage> {
  Future<void> _grant() async {
    final choice = await showDialog<_RoleGrant>(
      context: context,
      builder: (context) =>
          _GrantRoleDialog(repository: widget.repository),
    );
    if (choice == null || !mounted) return;
    try {
      await widget.repository.grantPlatformRole(
        userId: choice.userId,
        roleKey: choice.roleKey,
      );
      widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Platform role granted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not grant the role: $error')),
      );
    }
  }

  Future<void> _revoke(PlatformTeamMember member, String roleKey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke platform role?'),
        content: Text('Remove $roleKey from ${member.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.revokePlatformRole(
        userId: member.userId,
        roleKey: roleKey,
      );
      widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not revoke the role: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Platform team',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          FilledButton.icon(
            onPressed: _grant,
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Grant role'),
          ),
        ],
      ),
      const SizedBox(height: 5),
      const Text(
        'Platform roles are global. Granting access is audited and takes effect on the next request.',
        style: TextStyle(color: EstateColors.muted),
      ),
      const SizedBox(height: 16),
      FutureBuilder<List<PlatformTeamMember>>(
        future: widget.team,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text('Platform team could not be loaded: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.requireData.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No platform roles have been granted yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Column(
            children: snapshot.requireData
                .map(
                  (member) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            member.email,
                            style: const TextStyle(
                              color: EstateColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: member.roles
                                .map(
                                  (role) => InputChip(
                                    label: Text(role),
                                    onDeleted: () => _revoke(member, role),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class _RoleGrant {
  const _RoleGrant({required this.userId, required this.roleKey});
  final String userId;
  final String roleKey;
}

class _GrantRoleDialog extends StatefulWidget {
  const _GrantRoleDialog({required this.repository});
  final PlatformApplicationApiRepository repository;

  @override
  State<_GrantRoleDialog> createState() => _GrantRoleDialogState();
}

class _GrantRoleDialogState extends State<_GrantRoleDialog> {
  final _search = TextEditingController();
  late Future<List<PlatformUserChoice>> _candidates;
  String? _selectedUserId;
  String _roleKey = 'platform_application_reviewer';

  @override
  void initState() {
    super.initState();
    _candidates = widget.repository.loadPlatformUserCandidates('');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    setState(() {
      _selectedUserId = null;
      _candidates = widget.repository.loadPlatformUserCandidates(value);
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Grant a platform role'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _search,
            onChanged: _searchChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Find an account by name or email',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _roleKey,
            decoration: const InputDecoration(labelText: 'Role'),
            items: const [
              DropdownMenuItem(
                value: 'platform_application_reviewer',
                child: Text('Platform reviewer'),
              ),
              DropdownMenuItem(
                value: 'platform_super_admin',
                child: Text('Platform super administrator'),
              ),
            ],
            onChanged: (value) => setState(() => _roleKey = value ?? _roleKey),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: FutureBuilder<List<PlatformUserChoice>>(
              future: _candidates,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.requireData.isEmpty) {
                  return const Center(
                    child: Text('No matching active accounts.'),
                  );
                }
                return ListView(
                  children: snapshot.requireData
                      .map(
                        (user) => ListTile(
                          dense: true,
                          selected: _selectedUserId == user.userId,
                          title: Text(user.displayName),
                          subtitle: Text(user.email),
                          onTap: () =>
                              setState(() => _selectedUserId = user.userId),
                        ),
                      )
                      .toList(),
                );
              },
            ),
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
        onPressed: _selectedUserId == null
            ? null
            : () => Navigator.pop(
                context,
                _RoleGrant(userId: _selectedUserId!, roleKey: _roleKey),
              ),
        child: const Text('Grant'),
      ),
    ],
  );
}
