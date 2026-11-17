import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/estate_admin_repository.dart';

class EstateSettingsPage extends StatelessWidget {
  const EstateSettingsPage({super.key, required this.settings});
  final EstateSettingsSummary settings;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(26, 26, 26, 40),
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 14,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estate settings',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 5),
              const Text(
                'Review the operating identity and locale configured for this estate.',
                style: TextStyle(color: EstateColors.muted),
              ),
            ],
          ),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit settings'),
          ),
        ],
      ),
      const SizedBox(height: 18),
      const _SettingsPreviewNotice(),
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1EC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      size: 25,
                      color: EstateColors.forest,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settings.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_label(settings.type)} · ${settings.status.toUpperCase()}',
                          style: const TextStyle(
                            color: EstateColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.verified_outlined,
                    color: EstateColors.forest,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, box) {
                  final width = box.maxWidth < 650
                      ? box.maxWidth
                      : (box.maxWidth - 34) / 3;
                  return Wrap(
                    spacing: 17,
                    runSpacing: 20,
                    children: [
                      _SettingValue(
                        width: width,
                        label: 'Estate code',
                        value: settings.code ?? 'Not configured',
                        icon: Icons.tag_rounded,
                      ),
                      _SettingValue(
                        width: width,
                        label: 'Estate type',
                        value: _label(settings.type),
                        icon: Icons.domain_outlined,
                      ),
                      _SettingValue(
                        width: width,
                        label: 'Operational status',
                        value: _label(settings.status),
                        icon: Icons.check_circle_outline,
                      ),
                      _SettingValue(
                        width: width,
                        label: 'Address',
                        value: settings.address ?? 'Not configured',
                        icon: Icons.location_on_outlined,
                      ),
                      _SettingValue(
                        width: width,
                        label: 'Local government',
                        value: settings.lga ?? 'Not configured',
                        icon: Icons.map_outlined,
                      ),
                      _SettingValue(
                        width: width,
                        label: 'State',
                        value: settings.state ?? 'Not configured',
                        icon: Icons.location_city_outlined,
                      ),
                      _SettingValue(
                        width: width,
                        label: 'Timezone',
                        value: settings.timezone ?? 'Not configured',
                        icon: Icons.schedule_outlined,
                      ),
                      _SettingValue(
                        width: width,
                        label: 'Currency',
                        value: settings.currency ?? 'Not configured',
                        icon: Icons.currency_exchange_outlined,
                      ),
                      _SettingValue(
                        width: width,
                        label: 'Estate reference',
                        value: settings.id,
                        icon: Icons.fingerprint_outlined,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text(
        'Documents and files',
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.folder_open_outlined, color: EstateColors.muted),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estate document library is not connected',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Estate-level files will use permission-scoped private storage. Application review documents are private onboarding records and are not shown here.',
                      style: TextStyle(
                        color: EstateColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text(
        'Connected configuration',
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      const Card(
        child: Column(
          children: [
            _ConfigRow(
              icon: Icons.wallet_outlined,
              title: 'Platform subscription',
              detail: 'Managed by platform operations',
              status: 'Separate area',
            ),
            Divider(height: 1, indent: 16, endIndent: 16),
            _ConfigRow(
              icon: Icons.notifications_active_outlined,
              title: 'Resident notifications',
              detail: 'Uses the estate notification service',
              status: 'Host integration',
            ),
            Divider(height: 1, indent: 16, endIndent: 16),
            _ConfigRow(
              icon: Icons.payments_outlined,
              title: 'Estate payment destination',
              detail: 'Managed in authorized billing policy',
              status: 'Host integration',
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'The settings view follows the allowlisted estate summary. Configuration changes require the estate settings command, permission checks and audit history.',
        style: TextStyle(color: EstateColors.muted, fontSize: 12),
      ),
    ],
  );

  String _label(String value) => value
      .split('_')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

class _SettingsPreviewNotice extends StatelessWidget {
  const _SettingsPreviewNotice();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F7F5),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFDDE8E0)),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, color: EstateColors.forest),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Preview settings are illustrative. The active estate context and all editable capabilities must come from the authenticated estate service.',
            style: TextStyle(color: EstateColors.ink),
          ),
        ),
      ],
    ),
  );
}

class _SettingValue extends StatelessWidget {
  const _SettingValue({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });
  final double width;
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: EstateColors.muted),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: EstateColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.status,
  });
  final IconData icon;
  final String title;
  final String detail;
  final String status;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: EstateColors.forest),
    title: Text(
      title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(detail, style: const TextStyle(fontSize: 11)),
    trailing: Text(
      status,
      style: const TextStyle(color: EstateColors.muted, fontSize: 10),
    ),
  );
}
