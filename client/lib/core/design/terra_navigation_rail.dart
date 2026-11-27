import 'package:flutter/material.dart';

import 'terra_theme.dart';

/// A section in the persistent left-hand navigation.
class TerraNavItem {
  const TerraNavItem({
    required this.id,
    required this.icon,
    required this.label,
    this.section = 'WORKSPACE',
    this.badge,
    this.danger = false,
  });

  final String id;
  final IconData icon;
  final String label;
  final String section;
  final String? badge;
  final bool danger;
}

/// Permanent left navigation, matching the Zvend admin shell pattern.
/// On narrow screens it collapses to a 64px icon rail.
class TerraNavigationRail extends StatelessWidget {
  const TerraNavigationRail({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    this.width = 244,
    this.header,
    this.footer,
  });

  final List<TerraNavItem> items;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final double width;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: TerraColors.surface,
        border: Border(right: BorderSide(color: TerraColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) header!,
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                for (final entry in _grouped().entries) ...[
                  if (width > 100)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                      child: TerraLabel(entry.key),
                    )
                  else
                    const SizedBox(height: 10),
                  ...entry.value.map(_item),
                ],
              ],
            ),
          ),
          if (footer != null) footer!,
        ],
      ),
    );
  }

  Map<String, List<TerraNavItem>> _grouped() {
    final groups = <String, List<TerraNavItem>>{};
    for (final item in items) {
      groups.putIfAbsent(item.section, () => []).add(item);
    }
    return groups;
  }

  Widget _item(TerraNavItem item) {
    final selected = item.id == selectedId;
    final color = item.danger
        ? TerraColors.danger
        : selected
            ? TerraColors.forest
            : TerraColors.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? TerraColors.sage : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onSelect(item.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(item.icon, size: 19, color: color),
                if (width > 100) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        color: item.danger ? TerraColors.danger : TerraColors.ink,
                      ),
                    ),
                  ),
                  if (item.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: selected
                            ? TerraColors.forest
                            : TerraColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.badge!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : TerraColors.muted,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact header shown at the top of the rail.
class TerraRailHeader extends StatelessWidget {
  const TerraRailHeader({
    super.key,
    required this.estateName,
    required this.subtitle,
    this.extended = true,
  });

  final String estateName;
  final String subtitle;
  final bool extended;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: const BoxDecoration(color: TerraColors.forest),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.eco_outlined,
                  color: Colors.white, size: 19),
            ),
            if (extended) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      estateName.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: Color(0xFFCFE0D2), fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
}
