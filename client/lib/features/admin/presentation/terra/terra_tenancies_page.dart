import 'package:flutter/material.dart';

import '../../../../core/design/terra_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../onboarding/data/estate_application_repository.dart';

/// Tenancy approvals queue in the Terra Crest visual language.
///
/// Shows the tenancies that are waiting for an estate decision, with the
/// agreed rent, property and payee for each one.
class TerraTenanciesPage extends StatefulWidget {
  const TerraTenanciesPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;

  @override
  State<TerraTenanciesPage> createState() => _TerraTenanciesPageState();
}

class _TerraTenanciesPageState extends State<TerraTenanciesPage> {
  List<TenancyApprovalRecord> _items = const [];
  bool _loading = true;
  String? _workingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items =
          await widget.repository.loadPendingTenancyApprovals(widget.estateId);
    } catch (_) {
      // Keep the previous list; a failed refresh must not blank the page.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(TenancyApprovalRecord record) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve tenancy'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Approval reason',
            hintText: 'Record what you checked.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: controller.text.trim().isEmpty
                ? null
                : () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Confirm approval'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;

    setState(() => _workingId = record.id);
    try {
      await widget.repository.approveTenancy(
        estateId: widget.estateId,
        tenancyId: record.id,
        reason: reason,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tenancy approved. Resident access is now active.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The tenancy could not be approved.')),
      );
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  void _showRejectGuidance() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tenancy rejection is not available in this workspace. Review the agreed terms with the landlord before approving.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        appBar: AppBar(
          title: const Text('Tenancies'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading || _workingId != null ? null : _load,
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
                    title: 'Tenancy approvals',
                    trailing: TerraBadge(
                      label: '${_items.length} pending',
                      tone: _items.isEmpty
                          ? TerraBadgeTone.sage
                          : TerraBadgeTone.amber,
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
                    'Review the tenant, property and agreed rent before activating a tenancy. Approval grants the tenant resident access.',
                    style: TextStyle(
                      color: TerraColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(color: TerraColors.forest),
                    )
                  else if (_items.isEmpty)
                    const TerraCard(
                      child: TerraEmpty(
                        message: 'No tenancies are waiting for approval.',
                        icon: Icons.home_outlined,
                      ),
                    )
                  else
                    ..._items.map(
                      (record) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TerraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: TerraColors.sage,
                                    child: Icon(
                                      Icons.key_outlined,
                                      size: 18,
                                      color: TerraColors.forest,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          record.tenantName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: TerraColors.ink,
                                          ),
                                        ),
                                        Text(
                                          record.propertyCode,
                                          style: const TextStyle(
                                            color: TerraColors.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const TerraBadge(
                                    label: 'Pending approval',
                                    tone: TerraBadgeTone.amber,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 24,
                                runSpacing: 12,
                                children: [
                                  _term(
                                    'Rent',
                                    '${AppFormat.money(record.amount, currency: record.currency)} / ${record.frequency}',
                                  ),
                                  _term('Payee', record.payeeName),
                                  _term('Due day', 'Day ${record.dueDay}'),
                                  _term(
                                    'Effective from',
                                    AppFormat.date(record.effectiveFrom),
                                  ),
                                ],
                              ),
                              if (record.termsNote != null &&
                                  record.termsNote!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  record.termsNote!,
                                  style: const TextStyle(
                                    color: TerraColors.muted,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _workingId != null
                                        ? null
                                        : _showRejectGuidance,
                                    icon: const Icon(Icons.close_outlined,
                                        size: 16),
                                    label: const Text('Reject'),
                                  ),
                                  const SizedBox(width: 10),
                                  FilledButton.icon(
                                    onPressed: _workingId != null
                                        ? null
                                        : () => _approve(record),
                                    icon: _workingId == record.id
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: TerraColors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.check_circle_outline,
                                            size: 16,
                                          ),
                                    label: const Text('Approve'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  const TerraCard(
                    child: TerraEmpty(
                      message:
                          'View all tenancies — this queue lists only those awaiting an estate decision.',
                      icon: Icons.list_alt_outlined,
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
