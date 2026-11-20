import 'package:flutter/material.dart';

/// Visual language shared by the resident, estate-management and landlord
/// dashboards. Based on the LANCON expansion reference screen: dark canvas,
/// deep-green account card with three prominent actions, and a four-column
/// quick-services grid.
class DashboardTokens {
  static const background = Color(0xFF080A09);
  static const surface = Color(0xFF111715);
  static const surfaceRaised = Color(0xFF161E1A);
  static const line = Color(0xFF25332C);
  static const text = Color(0xFFFFFFFF);
  static const muted = Color(0xFF9BB2A5);
  static const mutedStrong = Color(0xFFC7D8CE);
  static const greenDeep = Color(0xFF0A2F27);
  static const greenMid = Color(0xFF0D3B30);
  static const green = Color(0xFF176B4B);
  static const greenLeaf = Color(0xFF258565);
  static const actionSurface = Color(0xFFFFFFFF);
  static const actionInk = Color(0xFF0E503D);
  static const amber = Color(0xFFD8A24A);

  static const heroGradient = LinearGradient(
    colors: [greenDeep, greenMid, green],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkShell => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: greenLeaf,
          surface: surface,
          onSurface: text,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
          foregroundColor: text,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            side: BorderSide(color: line),
          ),
        ),
      );
}

/// Greeting block at the top of every role dashboard.
class DashboardGreeting extends StatelessWidget {
  const DashboardGreeting({
    super.key,
    required this.period,
    required this.title,
    required this.subtitle,
    this.trailing = const [],
  });

  final String period;
  final String title;
  final String subtitle;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                period.toUpperCase(),
                style: const TextStyle(
                  color: DashboardTokens.muted,
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: const TextStyle(
                  color: DashboardTokens.text,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: DashboardTokens.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        ...trailing,
      ],
    );
  }
}

class DashboardHeroAction {
  const DashboardHeroAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Deep-green account card with balance and three white actions.
class DashboardHero extends StatelessWidget {
  const DashboardHero({
    super.key,
    required this.label,
    required this.amount,
    required this.actions,
    this.caption,
    this.badge,
    this.onSettings,
    this.cardIcon = Icons.account_balance_wallet_outlined,
  });

  final String label;
  final String amount;
  final List<DashboardHeroAction> actions;
  final String? caption;
  final String? badge;
  final VoidCallback? onSettings;
  final IconData cardIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: DashboardTokens.heroGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(cardIcon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: DashboardTokens.mutedStrong,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onSettings != null)
                IconButton(
                  onPressed: onSettings,
                  tooltip: 'Card settings',
                  icon: const Icon(Icons.settings_outlined,
                      color: Colors.white, size: 19),
                ),
            ],
          ),
          if (badge != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: DashboardTokens.mutedStrong,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(
              caption!,
              style: const TextStyle(
                color: DashboardTokens.mutedStrong,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              for (final action in actions) ...[
                Expanded(
                  child: _HeroButton(action: action),
                ),
                if (action != actions.last) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({required this.action});

  final DashboardHeroAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DashboardTokens.actionSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, color: DashboardTokens.actionInk, size: 20),
              const SizedBox(height: 7),
              Text(
                action.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: DashboardTokens.actionInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardService {
  const DashboardService({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Four-column quick-services grid matching the reference screen.
class DashboardQuickServices extends StatelessWidget {
  const DashboardQuickServices({
    super.key,
    required this.services,
    this.title = 'Quick Services',
  });

  final List<DashboardService> services;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: DashboardTokens.text,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 18,
          crossAxisSpacing: 8,
          childAspectRatio: 0.82,
          children: [
            for (final service in services)
              _QuickServiceTile(service: service),
          ],
        ),
      ],
    );
  }
}

class _QuickServiceTile extends StatelessWidget {
  const _QuickServiceTile({required this.service});

  final DashboardService service;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: service.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(service.icon, color: Colors.white, size: 23),
            const SizedBox(height: 10),
            Text(
              service.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section title with an optional trailing action, e.g. "View all".
class DashboardSectionTitle extends StatelessWidget {
  const DashboardSectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: DashboardTokens.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                color: DashboardTokens.mutedStrong,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

/// A dark list row used for outstanding items, activity and quick summaries.
class DashboardListRow extends StatelessWidget {
  const DashboardListRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.icon = Icons.receipt_long_outlined,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: DashboardTokens.surface,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: DashboardTokens.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: DashboardTokens.greenLeaf, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: DashboardTokens.text,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: DashboardTokens.muted, fontSize: 11),
        ),
        trailing: Text(
          trailing,
          style: const TextStyle(
            color: DashboardTokens.text,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
