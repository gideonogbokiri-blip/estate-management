import 'package:flutter/material.dart';

import '../../../../core/design/terra_shell.dart';
import '../../../../core/design/terra_theme.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/api.dart';
import '../../../services/presentation/resident_service_pages.dart';

/// Services tab — a catalogue and order history. Intentionally has no wallet
/// balance: the balance belongs on Home and in the wallet flow.
class TerraServicesTab extends StatefulWidget {
  const TerraServicesTab({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
    required this.serviceContext,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;
  final ServicePageContext serviceContext;

  @override
  State<TerraServicesTab> createState() => _TerraServicesTabState();
}

class _TerraServicesTabState extends State<TerraServicesTab> {
  List<EstateServiceOrderRecord> _orders = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _orders = await widget.repository.loadEstateServiceOrders(widget.estateId);
    } catch (_) {
      _orders = const [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TerraSectionTitle(
          title: 'Services',
          trailing: TerraBadge(label: '${residentServices().length} available'),
        ),
        const SizedBox(height: 4),
        const Text(
          'Everything you can do in your estate, in one place.',
          style: TextStyle(color: TerraColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        TerraCard(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 560 ? 4 : 3;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.25,
                children: [
                  for (final service in residentServices())
                    TerraServiceTile(
                      icon: service.icon,
                      label: service.label,
                      danger: service.id == 'emergency',
                      onTap: () => AppNavigation.push(context, service.open(widget.serviceContext)),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        TerraSectionTitle(title: 'Your service orders'),
        const SizedBox(height: 10),
        TerraCard(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: TerraColors.forest))
              : _orders.isEmpty
                  ? const TerraEmpty(message: 'No services ordered yet.')
                  : Column(
                      children: _orders.take(8).map(
                        (order) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.receipt_long_outlined,
                              color: TerraColors.forest),
                          title: Text(
                            '₦${AppFormat.amount(order.amount)} · ${order.status}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${order.provider} · ${order.createdAt}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ).toList(),
                    ),
        ),
      ],
    );
  }
}

/// Kinship tab — household members and their access status.
class TerraKinshipTab extends StatefulWidget {
  const TerraKinshipTab({
    super.key,
    required this.repository,
    required this.serviceContext,
  });

  final EstateApplicationApiRepository repository;
  final ServicePageContext serviceContext;

  @override
  State<TerraKinshipTab> createState() => _TerraKinshipTabState();
}

class _TerraKinshipTabState extends State<TerraKinshipTab> {
  List<HouseholdMemberRecord> _members = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _members = await widget.repository.loadMyHousehold();
    } catch (_) {
      _members = const [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMember() async {
    final name = TextEditingController();
    var relationship = 'SPOUSE';
    var memberType = 'ADULT';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add household member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: relationship,
                  decoration: const InputDecoration(labelText: 'Relationship'),
                  items: const ['SPOUSE', 'CHILD', 'PARENT', 'DEPENDENT', 'OTHER']
                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) => setState(() => relationship = value ?? 'SPOUSE'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: memberType,
                  decoration: const InputDecoration(labelText: 'Member type'),
                  items: const ['ADULT', 'CHILD', 'RESTRICTED']
                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) => setState(() => memberType = value ?? 'ADULT'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return;
    try {
      await widget.repository.addHouseholdMember(
        estateId: widget.serviceContext.estateId,
        propertyId: widget.serviceContext.properties.firstOrNull?.id ?? '',
        fullName: name.text.trim(),
        relationship: relationship,
        memberType: memberType,
        effectiveFrom: DateTime.now().toIso8601String().substring(0, 10),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add member.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _members.where((member) => member.status == 'pending_approval').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TerraSectionTitle(
          title: 'Kinship',
          trailing: FilledButton.icon(
            onPressed: _addMember,
            icon: const Icon(Icons.person_add_outlined, size: 16),
            label: const Text('Add member'),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$pending member(s) awaiting approval · ${_members.length} total',
          style: const TextStyle(color: TerraColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        TerraCard(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: TerraColors.forest))
              : _members.isEmpty
                  ? const TerraEmpty(message: 'No household members are linked yet.')
                  : Column(
                      children: _members.map(
                        (member) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: TerraColors.sage,
                            child: Text(
                              member.fullName
                                  .trim()
                                  .split(RegExp(r'\s+'))
                                  .take(2)
                                  .map((part) => part.isEmpty ? '' : part[0])
                                  .join()
                                  .toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: TerraColors.forest),
                            ),
                          ),
                          title: Text(member.fullName,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            '${member.relationship.toLowerCase()} · ${member.propertyCode} · ${member.status}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: TerraBadge(
                            label: member.memberType,
                            tone: member.financialAccess
                                ? TerraBadgeTone.amber
                                : TerraBadgeTone.sage,
                          ),
                        ),
                      ).toList(),
                    ),
        ),
      ],
    );
  }
}

/// Profile tab — account details and session controls. There is no
/// profile-update API in this product yet, so fields are read-only.
class TerraProfileTab extends StatelessWidget {
  const TerraProfileTab({
    super.key,
    required this.account,
    required this.estateName,
    required this.propertyLabel,
    required this.onSignOut,
  });

  final EstateAccount account;
  final String estateName;
  final String propertyLabel;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TerraSectionTitle(title: 'Profile'),
        const SizedBox(height: 4),
        const Text(
          'Your account and how you are linked to the estate.',
          style: TextStyle(color: TerraColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        TerraCard(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: TerraColors.sage,
                child: Text(
                  account.displayName
                      .trim()
                      .split(RegExp(r'\s+'))
                      .take(2)
                      .map((part) => part.isEmpty ? '' : part[0])
                      .join()
                      .toUpperCase(),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: TerraColors.forest),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                account.displayName,
                style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(account.email,
                  style: const TextStyle(color: TerraColors.muted, fontSize: 12)),
              const SizedBox(height: 18),
              _profileRow(Icons.apartment_outlined, 'Estate', estateName),
              _profileRow(Icons.home_outlined, 'Property', propertyLabel),
              _profileRow(Icons.verified_user_outlined, 'Access', 'Resident Tier 1'),
              _profileRow(Icons.key_outlined, 'Gateway key', 'TC-ADE-9021'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TerraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TerraSectionTitle(title: 'Session'),
              const SizedBox(height: 8),
              const Text(
                'Profile details are managed by estate administration. Contact your '
                'estate office to change your name or email.',
                style: TextStyle(color: TerraColors.muted, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout_outlined),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: TerraColors.forest),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(color: TerraColors.muted, fontSize: 12)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      );
}
