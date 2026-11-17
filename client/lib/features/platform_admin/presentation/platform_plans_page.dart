import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';

/// Platform plan catalog shell. Values are intentionally not seeded in the UI:
/// price and entitlements must come from the authorized platform catalog.
class PlatformPlansPage extends StatelessWidget {
  const PlatformPlansPage({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      return ListView(
        padding: EdgeInsets.all(compact ? 20 : 34),
        children: [
          Text('Plans', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text(
            'Manage versioned estate plans and commercial terms.',
            style: TextStyle(color: EstateColors.muted),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8),
              border: Border.all(color: const Color(0xFFF0DCA9)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF8A5B13)),
                SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'The platform plan catalog is not connected in this preview. Prices, limits and enabled modules must be loaded from authorized platform configuration; no example pricing or limits are hardcoded here.',
                    style: TextStyle(color: Color(0xFF795416), height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFE9F2ED),
                        foregroundColor: EstateColors.forest,
                        child: Icon(Icons.card_membership_outlined),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Plan catalog',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('New version'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cloud_off_outlined,
                            size: 38,
                            color: EstateColors.muted.withValues(alpha: .7),
                          ),
                          const SizedBox(height: 11),
                          const Text(
                            'No connected plan versions',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Connect the platform catalog to review current and historical terms.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: EstateColors.muted,
                              fontSize: 12,
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
          const SizedBox(height: 20),
          Text(
            'Plan version workflow',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _PlanStage(
                icon: Icons.edit_note_outlined,
                title: 'Draft',
                detail: 'Configure terms from platform policy.',
              ),
              _PlanStage(
                icon: Icons.publish_outlined,
                title: 'Published',
                detail: 'New subscriptions may use this version.',
              ),
              _PlanStage(
                icon: Icons.inventory_2_outlined,
                title: 'Retired',
                detail: 'Keep history; prevent new selection.',
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            'Each version captures its effective date, price and currency, billing interval, property and staff limits, enabled modules, storage, support and trial terms. Existing subscriptions retain their agreed version.',
            style: TextStyle(
              color: EstateColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      );
    },
  );
}

class _PlanStage extends StatelessWidget {
  const _PlanStage({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: EstateColors.forest),
            const SizedBox(height: 9),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(
                fontSize: 11,
                color: EstateColors.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
