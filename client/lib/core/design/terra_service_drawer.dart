import 'package:flutter/material.dart';

import 'terra_theme.dart';

/// One service entry in the navigation drawer.
class TerraMenuService {
  const TerraMenuService({
    required this.label,
    required this.icon,
    required this.onTap,
    this.section = 'Services',
    this.danger = false,
    this.badge,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String section;
  final bool danger;
  final String? badge;
}

/// The app's single navigation surface: every service, grouped by section,
/// reachable from the menu button instead of cluttering the dashboard body.
class TerraServiceDrawer extends StatelessWidget {
  const TerraServiceDrawer({
    super.key,
    required this.estateName,
    required this.userName,
    required this.services,
    this.onProfile,
    this.onSignOut,
  });

  final String estateName;
  final String userName;
  final List<TerraMenuService> services;
  final VoidCallback? onProfile;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final sections = <String, List<TerraMenuService>>{};
    for (final service in services) {
      sections.putIfAbsent(service.section, () => []).add(service);
    }
    return Drawer(
      backgroundColor: TerraColors.surface,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: const BoxDecoration(
                color: TerraColors.forest,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.eco_outlined,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'TERRA CREST',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    estateName,
                    style: const TextStyle(
                        color: Color(0xFFD8E7DC), fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (onProfile != null)
              ListTile(
                leading: const Icon(Icons.person_outline,
                    color: TerraColors.forest, size: 20),
                title: const Text('My profile'),
                onTap: () {
                  Navigator.of(context).pop();
                  onProfile!();
                },
              ),
            const Divider(height: 1, color: TerraColors.line),
            for (final section in sections.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: TerraLabel(section.key),
              ),
              ...section.value.map(
                (service) => ListTile(
                  leading: Icon(
                    service.icon,
                    color: service.danger ? TerraColors.danger : TerraColors.forest,
                    size: 20,
                  ),
                  title: Text(
                    service.label,
                    style: TextStyle(
                      color: service.danger
                          ? TerraColors.danger
                          : TerraColors.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  trailing: service.badge != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: TerraColors.sage,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            service.badge!,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: TerraColors.forest,
                            ),
                          ),
                        )
                      : const Icon(Icons.chevron_right,
                          size: 16, color: TerraColors.muted),
                  onTap: () {
                    Navigator.of(context).pop();
                    service.onTap();
                  },
                ),
              ),
            ],
            const Divider(height: 1, color: TerraColors.line),
            if (onSignOut != null)
              ListTile(
                leading: const Icon(Icons.logout_outlined,
                    color: TerraColors.danger, size: 20),
                title: const Text('Sign out',
                    style: TextStyle(color: TerraColors.danger)),
                onTap: () {
                  Navigator.of(context).pop();
                  onSignOut!();
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
