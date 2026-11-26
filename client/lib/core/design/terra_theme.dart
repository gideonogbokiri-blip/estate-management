import 'package:flutter/material.dart';

/// Terra Crest visual language — warm cream surfaces, deep forest green,
/// serif display headings and generous, calm spacing. Used by every role
/// dashboard and service page.
abstract final class TerraColors {
  static const canvas = Color(0xFFF6F3ED);
  static const surface = Color(0xFFFDFBF7);
  static const surfaceMuted = Color(0xFFF1EDE4);
  static const sage = Color(0xFFE9F0E5);
  static const sageDeep = Color(0xFFDCE9D6);
  static const forest = Color(0xFF1F5C3A);
  static const forestDeep = Color(0xFF17472E);
  static const forestSoft = Color(0xFF2E6C49);
  static const ink = Color(0xFF1E2A22);
  static const muted = Color(0xFF7C857A);
  static const line = Color(0xFFE6E0D4);
  static const amber = Color(0xFFB8873B);
  static const amberWash = Color(0xFFF7EEDC);
  static const danger = Color(0xFFB44A3E);
  static const white = Color(0xFFFFFFFF);
}

class TerraTheme {
  static ThemeData light() {
    const forest = TerraColors.forest;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Helvetica',
      colorScheme: ColorScheme.fromSeed(
        seedColor: forest,
        brightness: Brightness.light,
        surface: TerraColors.surface,
      ).copyWith(primary: forest, onPrimary: TerraColors.white),
      scaffoldBackgroundColor: TerraColors.canvas,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: TerraColors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: TerraColors.ink,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 18,
          color: TerraColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: TerraColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: TerraColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TerraColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TerraColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TerraColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: forest, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: forest,
          foregroundColor: TerraColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: forest,
          side: const BorderSide(color: TerraColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: TerraColors.surface,
        selectedItemColor: forest,
        unselectedItemColor: TerraColors.muted,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

/// A soft card used throughout the dashboards.
class TerraCard extends StatelessWidget {
  const TerraCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Card(
        color: color ?? TerraColors.surface,
        child: Padding(padding: padding, child: child),
      );
}

/// Small uppercase pill used for statuses and tags.
class TerraBadge extends StatelessWidget {
  const TerraBadge({
    super.key,
    required this.label,
    this.tone = TerraBadgeTone.sage,
    this.icon,
  });

  final String label;
  final TerraBadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      TerraBadgeTone.sage => (bg: TerraColors.sage, fg: TerraColors.forest),
      TerraBadgeTone.amber => (bg: TerraColors.amberWash, fg: TerraColors.amber),
      TerraBadgeTone.danger => (bg: const Color(0xFFF8E9E6), fg: TerraColors.danger),
      TerraBadgeTone.outline => (bg: Colors.transparent, fg: TerraColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
        border: tone == TerraBadgeTone.outline
            ? Border.all(color: TerraColors.line)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: colors.fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: colors.fg,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .4,
            ),
          ),
        ],
      ),
    );
  }
}

enum TerraBadgeTone { sage, amber, danger, outline }

/// Small uppercase label above a value.
class TerraLabel extends StatelessWidget {
  const TerraLabel(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color ?? TerraColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      );
}

/// Section title in the serif voice used by the mockups.
class TerraSectionTitle extends StatelessWidget {
  const TerraSectionTitle({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: TerraColors.ink,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

/// A service definition for a Terra quick-services grid.
class TerraServiceAction {
  const TerraServiceAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
}

/// Four-column quick-services grid in the Terra language.
class TerraQuickServicesGrid extends StatelessWidget {
  const TerraQuickServicesGrid({super.key, required this.services});
  final List<TerraServiceAction> services;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
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
            for (final service in services)
              Material(
                color: TerraColors.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: service.onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          service.icon,
                          color: service.danger ? TerraColors.danger : TerraColors.forest,
                          size: 20,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          service.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: TerraColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A metric tile used in telemetry-style cards.
class TerraMetric extends StatelessWidget {
  const TerraMetric({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TerraColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TerraLabel(label),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: TerraColors.ink,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(height: 4),
              Icon(icon, size: 14, color: TerraColors.forest),
            ],
          ],
        ),
      );
}

/// An empty state that reads as calm guidance, not an error.
class TerraEmpty extends StatelessWidget {
  const TerraEmpty({super.key, required this.message, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Icon(icon, color: TerraColors.forest, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: TerraColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      );
}
