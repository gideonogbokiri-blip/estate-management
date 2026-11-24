import 'package:flutter/material.dart';

import 'dashboard_design.dart';

/// Common shell for every dedicated service page. Keeps the dark LANCON visual
/// language consistent and gives each service a real route/page of its own.
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
      data: DashboardTokens.darkShell,
      child: Scaffold(
        backgroundColor: DashboardTokens.background,
        appBar: AppBar(
          title: Row(
            children: [
              Icon(icon, color: DashboardTokens.greenLeaf, size: 20),
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
                  DashboardGreeting(
                    period: 'LANCON SERVICE',
                    title: title,
                    subtitle: description,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: DashboardTokens.surfaceRaised,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              color: DashboardTokens.greenLeaf, size: 19),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'In plain English',
                                  style: TextStyle(
                                    color: DashboardTokens.text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  description,
                                  style: const TextStyle(
                                    color: DashboardTokens.mutedStrong,
                                    fontSize: 13,
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
  const ServiceStateMessage({super.key, required this.message, this.error = false, this.onRetry});

  final String message;
  final bool error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Icon(
                error ? Icons.error_outline : Icons.inbox_outlined,
                color: error ? DashboardTokens.amber : DashboardTokens.muted,
                size: 28,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: DashboardTokens.mutedStrong, fontSize: 13),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                FilledButton(onPressed: onRetry, child: const Text('Try again')),
              ],
            ],
          ),
        ),
      );
}
