import 'package:flutter/material.dart';

import 'terra_theme.dart';

/// Common shell for every dedicated service page, in the Terra Crest visual
/// language so each service feels like part of one calm, trustworthy product.
class ServicePageScaffold extends StatelessWidget {
  const ServicePageScaffold({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.child,
    this.actions = const [],
    this.onRefresh,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget child;
  final List<Widget> actions;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        appBar: AppBar(
          title: Row(
            children: [
              Icon(icon, color: TerraColors.forest, size: 20),
              const SizedBox(width: 10),
              Text(title),
            ],
          ),
          actions: [
            if (onRefresh != null)
              IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ...actions,
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  TerraSectionTitle(title: title),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      color: TerraColors.muted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ServiceStateMessage extends StatelessWidget {
  const ServiceStateMessage({
    super.key,
    required this.message,
    this.error = false,
    this.onRetry,
  });

  final String message;
  final bool error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => TerraCard(
        child: Column(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.inbox_outlined,
              color: error ? TerraColors.amber : TerraColors.forest,
              size: 26,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: TerraColors.muted, fontSize: 13),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      );
}
