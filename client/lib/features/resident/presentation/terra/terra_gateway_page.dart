import 'package:flutter/material.dart';

import '../../../../core/design/terra_theme.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../data/api.dart';
import '../../../services/presentation/resident_service_pages.dart';

/// Household gateway access.
///
/// Design note: the backend verifies VISITOR passes at the gate and those
/// check-in routes are restricted to assigned security officers. There is no
/// resident-callable PIN verification endpoint. This page therefore collects
/// the household passcode as a local unlock for the resident's own gate-pass
/// list; final validation still happens at the gate terminal.
class TerraGatewayPage extends StatefulWidget {
  const TerraGatewayPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.displayName,
    required this.propertyCode,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String displayName;
  final String propertyCode;

  @override
  State<TerraGatewayPage> createState() => _TerraGatewayPageState();
}

class _TerraGatewayPageState extends State<TerraGatewayPage> {
  final _pin = <String>[];
  List<ResidentVisitorPassRecord> _passes = const [];
  bool _unlocked = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _passes = await widget.repository.loadMyVisitorPasses(widget.estateId);
    } catch (_) {
      _passes = const [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _press(String key) {
    if (key == 'Del') {
      if (_pin.isNotEmpty) setState(() => _pin.removeLast());
      return;
    }
    if (key == 'OK') {
      if (_pin.length == 4) setState(() => _unlocked = true);
      return;
    }
    if (_pin.length >= 4) return;
    setState(() => _pin.add(key));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        appBar: AppBar(
          title: const Text('Sanctuary Gateway'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TerraCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lock_outline,
                                  color: TerraColors.forest, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'TERMINAL GATEWAY LOGIN',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: .6),
                                ),
                              ),
                              const TerraBadge(label: 'FPS 140-3'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Use your household passcode to open your gate-pass list. '
                            'The gate terminal performs the final validation.',
                            style: TextStyle(
                                fontSize: 12,
                                color: TerraColors.muted,
                                height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          TerraLabel('Authenticated resident'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: TerraColors.sage,
                                child: Text(
                                  widget.displayName
                                      .split(RegExp(r'\s+'))
                                      .take(2)
                                      .map((p) => p.isEmpty ? '' : p[0])
                                      .join()
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: TerraColors.forest),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.displayName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    Text('Head of Household • ${widget.propertyCode}',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: TerraColors.muted)),
                                  ],
                                ),
                              ),
                              const TerraBadge(label: '4 / 4 Verified'),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              4,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: index < _pin.length
                                      ? TerraColors.forest
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: TerraColors.forest),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.7,
                            children: [
                              for (final key in [
                                '1', '2', '3', '4', '5', '6', '7', '8', '9', 'Del', '0', 'OK'
                              ])
                                OutlinedButton(
                                  onPressed: () => _press(key),
                                  child: Text(key),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _pin.length == 4
                                ? () => setState(() => _unlocked = true)
                                : null,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Enter Sanctuary Gateway'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_unlocked) ...[
                      TerraSectionTitle(title: 'Your gate passes'),
                      const SizedBox(height: 10),
                      TerraCard(
                        child: _loading
                            ? const Center(
                                child: CircularProgressIndicator(color: TerraColors.forest))
                            : _passes.isEmpty
                                ? const TerraEmpty(
                                    message: 'No active visitor passes. Create one from Gate Pass.')
                                : Column(
                                    children: _passes.map(
                                      (pass) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(Icons.qr_code_2_outlined,
                                            color: TerraColors.forest),
                                        title: Text(pass.visitorName,
                                            style: const TextStyle(fontWeight: FontWeight.w700)),
                                        subtitle: Text(
                                          '${pass.propertyLabel} · ${pass.status}',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ).toList(),
                                  ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => AppNavigation.push(
                          context,
                          residentServices()
                              .firstWhere((item) => item.id == 'gate-pass')
                              .open(
                                ServicePageContext(
                                  repository: widget.repository,
                                  estateId: widget.estateId,
                                  estateName: 'Terra Crest',
                                ),
                              ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Manage gate passes'),
                      ),
                    ] else
                      const TerraCard(
                        child: TerraEmpty(
                          message: 'Enter your 4-digit household passcode to view your gate passes.',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
