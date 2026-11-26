import 'package:flutter/material.dart';

import 'terra_theme.dart';

/// Top navigation bar shared by the role dashboards.
class TerraTopBar extends StatelessWidget {
  const TerraTopBar({
    super.key,
    required this.estateName,
    required this.estateDescriptor,
    required this.userName,
    required this.userSubtitle,
    this.tier = 'Resident Tier 1',
    this.statuses = const [],
    this.onNotification,
    this.onProfile,
    this.onMenu,
  });

  final String estateName;
  final String estateDescriptor;
  final String userName;
  final String userSubtitle;
  final String tier;
  final List<TerraStatus> statuses;
  final VoidCallback? onNotification;
  final VoidCallback? onProfile;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TerraColors.surface,
        border: Border(bottom: BorderSide(color: TerraColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      child: Row(
        children: [
          const _Logo(),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                estateName.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .6,
                  color: TerraColors.ink,
                ),
              ),
              Text(
                estateDescriptor,
                style: const TextStyle(fontSize: 10, color: TerraColors.muted),
              ),
            ],
          ),
          const SizedBox(width: 10),
          TerraBadge(label: tier, tone: TerraBadgeTone.sage),
          const Spacer(),
          if (MediaQuery.sizeOf(context).width > 1100)
            ...statuses.map((status) => Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: Row(
                    children: [
                      Icon(status.icon, size: 15, color: TerraColors.forest),
                      const SizedBox(width: 7),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(status.label,
                              style: const TextStyle(
                                  fontSize: 9, color: TerraColors.muted)),
                          Text(status.value,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: TerraColors.ink)),
                        ],
                      ),
                    ],
                  ),
                )),
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotification,
            icon: const Icon(Icons.notifications_none_rounded,
                color: TerraColors.ink, size: 21),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(30),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: TerraColors.sage,
                  child: Text(
                    _initials(userName),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: TerraColors.forest,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: TerraColors.ink)),
                    Text(userSubtitle,
                        style: const TextStyle(
                            fontSize: 9, color: TerraColors.muted)),
                  ],
                ),
                const Icon(Icons.keyboard_arrow_down,
                    size: 16, color: TerraColors.muted),
              ],
            ),
          ),
          if (onMenu != null)
            IconButton(
              tooltip: 'Menu',
              onPressed: onMenu,
              icon: const Icon(Icons.menu, color: TerraColors.ink),
            ),
        ],
      ),
    );
  }

  static String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .take(2)
      .map((part) => part.isEmpty ? '' : part[0])
      .join()
      .toUpperCase();
}

class TerraStatus {
  const TerraStatus({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: TerraColors.forest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.eco_outlined,
            color: TerraColors.white, size: 22),
      );
}

/// The large deep-green account card with three white actions.
class TerraWalletCard extends StatelessWidget {
  const TerraWalletCard({
    super.key,
    required this.balance,
    required this.accountLabel,
    required this.accountDetail,
    required this.actions,
    this.badge,
  });

  final String balance;
  final String accountLabel;
  final String accountDetail;
  final List<TerraWalletAction> actions;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [TerraColors.forestDeep, TerraColors.forest, TerraColors.forestSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TerraLabel('My wallet balance', color: Color(0xFFCFE0D2)),
              const Spacer(),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.credit_card_outlined,
                  color: Colors.white70, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                balance,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -.8,
                ),
              ),
              if (accountLabel.isNotEmpty) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    accountLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            accountDetail,
            style: const TextStyle(color: Color(0xFFD8E7DC), fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (final action in actions) ...[
                Expanded(child: _WalletActionButton(action: action)),
                if (action != actions.last) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class TerraWalletAction {
  const TerraWalletAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _WalletActionButton extends StatelessWidget {
  const _WalletActionButton({required this.action});
  final TerraWalletAction action;

  @override
  Widget build(BuildContext context) => Material(
        color: TerraColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.icon, color: TerraColors.forest, size: 17),
                const SizedBox(width: 7),
                Text(
                  action.label,
                  style: const TextStyle(
                    color: TerraColors.forest,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// A single quick-service tile.
class TerraServiceTile extends StatelessWidget {
  const TerraServiceTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => Material(
        color: TerraColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: danger ? TerraColors.danger : TerraColors.forest,
                  size: 20,
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: TerraColors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
