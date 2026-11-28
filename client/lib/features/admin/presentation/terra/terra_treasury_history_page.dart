import 'package:flutter/material.dart';

import '../../../../core/design/terra_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/api.dart';

/// A dedicated history page for one treasury tile.
class TerraTreasuryHistoryPage extends StatefulWidget {
  const TerraTreasuryHistoryPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.title,
    required this.kind,
    this.icon = Icons.account_balance_wallet_outlined,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String title;
  final String kind;
  final IconData icon;

  @override
  State<TerraTreasuryHistoryPage> createState() => _TerraTreasuryHistoryPageState();
}

class _TerraTreasuryHistoryPageState extends State<TerraTreasuryHistoryPage> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await widget.repository.loadTreasuryHistory(
        widget.estateId,
        widget.kind,
      );
    } catch (_) {
      _items = const [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        appBar: AppBar(
          title: Text(widget.title),
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
                    title: widget.title,
                    trailing: TerraBadge(label: '${_items.length}'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A record of every ${widget.title.toLowerCase()} entry for this estate.',
                    style: const TextStyle(
                        color: TerraColors.muted, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  if (_loading)
                    const Center(
                        child: CircularProgressIndicator(color: TerraColors.forest))
                  else if (_items.isEmpty)
                    const TerraCard(
                      child: TerraEmpty(message: 'No records in this history yet.'),
                    )
                  else
                    TerraCard(
                      child: Column(
                        children: _items.map(
                          (item) {
                            final amount =
                                double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
                            final isCredit = item['type']?.toString() == 'credit';
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                isCredit ? Icons.arrow_downward_rounded : widget.icon,
                                color: isCredit
                                    ? TerraColors.forest
                                    : TerraColors.amber,
                              ),
                              title: Text(
                                item['detail']?.toString() ?? 'Entry',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                '${item['reference'] ?? ''} · '
                                '${AppFormat.date(item['date']?.toString())}'
                                '${item['note'] != null ? ' · ${item['note']}' : ''}',
                                style: const TextStyle(fontSize: 10),
                              ),
                              trailing: Text(
                                '${isCredit ? '+' : ''}₦${AppFormat.amount(amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isCredit
                                      ? TerraColors.forest
                                      : TerraColors.ink,
                                ),
                              ),
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
