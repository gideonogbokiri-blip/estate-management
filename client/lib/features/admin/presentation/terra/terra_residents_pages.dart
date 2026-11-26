import 'package:flutter/material.dart';

import '../../../../core/design/terra_theme.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/api.dart';

/// Estate-manager directory of residents, grouped by the landlord linked to
/// each tenancy. Older sub-pages only showed pending reviews; this shows the
/// actual people in the estate and who they belong to.
class TerraResidentsPage extends StatefulWidget {
  const TerraResidentsPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;

  @override
  State<TerraResidentsPage> createState() => _TerraResidentsPageState();
}

class _TerraResidentsPageState extends State<TerraResidentsPage> {
  List<Map<String, dynamic>> _residents = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _residents = await widget.repository.loadEstateResidents(widget.estateId);
    } catch (error) {
      _error = 'Residents could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Iterable<MapEntry<String?, List<Map<String, dynamic>>>> get _grouped {
    final groups = <String?, List<Map<String, dynamic>>>{};
    for (final resident in _residents) {
      final key = resident['landlordName']?.toString();
      groups.putIfAbsent(key, () => []).add(resident);
    }
    return groups.entries;
  }

  String _groupLabel(String? key) =>
      key == null ? 'Residents without a linked landlord' : 'Under $key';

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        appBar: AppBar(
          title: const Text('Residents'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
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
                    title: 'Residents',
                    trailing: TerraBadge(label: '${_residents.length} total'),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Everyone linked to this estate. Open a resident to see their own bills, wallet, rent, services and household.',
                    style: TextStyle(color: TerraColors.muted, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  if (_loading)
                    const Center(child: CircularProgressIndicator(color: TerraColors.forest))
                  else if (_error != null)
                    TerraCard(child: TerraEmpty(message: _error!, icon: Icons.error_outline))
                  else if (_residents.isEmpty)
                    const TerraCard(child: TerraEmpty(message: 'No residents are linked to this estate yet.'))
                  else
                    ..._grouped.map(
                      (group) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TerraLabel(_groupLabel(group.key)),
                          const SizedBox(height: 8),
                          ...group.value.map(
                            (resident) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: TerraCard(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: TerraColors.sage,
                                    child: Text(
                                      (resident['name']?.toString() ?? 'R')
                                          .split(RegExp(r'\s+'))
                                          .take(2)
                                          .map((p) => p.isEmpty ? '' : p[0])
                                          .join()
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: TerraColors.forest),
                                    ),
                                  ),
                                  title: Text(
                                    resident['name']?.toString() ?? 'Resident',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Text(
                                    '${resident['propertyCode'] ?? 'No property'} · '
                                    '${resident['relationship'] ?? 'resident'} · '
                                    '${resident['accessStatus'] ?? ''}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: const Icon(Icons.chevron_right, color: TerraColors.forest),
                                  onTap: () => AppNavigation.push(
                                    context,
                                    TerraResidentHistoryPage(
                                      repository: widget.repository,
                                      estateId: widget.estateId,
                                      residentUserId: resident['userId'] as String,
                                      residentName: resident['name']?.toString() ?? 'Resident',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
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

/// Per-customer history. Each resident gets their own bills, wallet movements,
/// rent receipts, service orders and household — never a generic estate feed.
class TerraResidentHistoryPage extends StatefulWidget {
  const TerraResidentHistoryPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.residentUserId,
    required this.residentName,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String residentUserId;
  final String residentName;

  @override
  State<TerraResidentHistoryPage> createState() => _TerraResidentHistoryPageState();
}

class _TerraResidentHistoryPageState extends State<TerraResidentHistoryPage> {
  Map<String, dynamic> _data = const {};
  bool _loading = true;
  String? _error;
  int _section = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _data = await widget.repository.loadResidentHistory(
        widget.estateId,
        widget.residentUserId,
      );
    } catch (error) {
      _error = 'This resident’s history could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _currentRows {
    final key = const ['invoices', 'wallet', 'rent', 'services', 'household'][_section];
    return (_data[key] as List? ?? const []).toList();
  }

  Map<String, String> _row(dynamic item) {
    final row = item is Map<String, dynamic> ? item : <String, dynamic>{};
    switch (_section) {
      case 0:
        return {
          'title': '${row['reference'] ?? 'Invoice'} · ₦${AppFormat.amount(row['balance'] ?? row['amount'] ?? '0')}',
          'subtitle': '${row['status'] ?? ''} · due ${AppFormat.date(row['dueDate']?.toString())}',
        };
      case 1:
        return {
          'title': '${row['type']?.toString().toUpperCase() ?? 'WALLET'} · ₦${AppFormat.amount(row['amount'] ?? '0')}',
          'subtitle': '${row['description'] ?? ''} · ${AppFormat.date(row['date']?.toString())}',
        };
      case 2:
        return {
          'title': 'Rent receipt ${row['receipt'] ?? ''}',
          'subtitle': '₦${AppFormat.amount(row['amount'] ?? '0')} · ${AppFormat.date(row['date']?.toString())}',
        };
      case 3:
        return {
          'title': '${row['provider'] ?? 'Service'} · ₦${AppFormat.amount(row['amount'] ?? '0')}',
          'subtitle': '${row['status'] ?? ''}${row['voucher'] != null ? ' · ${row['voucher']}' : ''}',
        };
      default:
        return {
          'title': row['name']?.toString() ?? 'Household member',
          'subtitle': '${row['relationship'] ?? ''} · ${row['type'] ?? ''} · ${row['status'] ?? ''}',
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        appBar: AppBar(
          title: Text(widget.residentName),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
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
                  TerraSectionTitle(title: widget.residentName),
                  const SizedBox(height: 4),
                  Text(
                    (_data['resident'] as Map? ?? const {})['email']?.toString() ?? '',
                    style: const TextStyle(color: TerraColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: const [
                        'Bills', 'Wallet', 'Rent receipts', 'Services', 'Household',
                      ].asMap().entries.map((entry) {
                        final selected = entry.key == _section;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(entry.value),
                            selected: selected,
                            onSelected: (_) => setState(() => _section = entry.key),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Center(child: CircularProgressIndicator(color: TerraColors.forest))
                  else if (_error != null)
                    TerraCard(child: TerraEmpty(message: _error!, icon: Icons.error_outline))
                  else if (_currentRows.isEmpty)
                    const TerraCard(child: TerraEmpty(message: 'No records in this section.'))
                  else
                    TerraCard(
                      child: Column(
                        children: _currentRows.map(
                          (item) {
                            final row = _row(item);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.receipt_long_outlined,
                                  color: TerraColors.forest),
                              title: Text(row['title'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(row['subtitle'] ?? '',
                                  style: const TextStyle(fontSize: 11)),
                            );
                          },
                        ).toList(),
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
