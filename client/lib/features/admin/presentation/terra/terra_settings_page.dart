import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/design/terra_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../onboarding/data/estate_application_repository.dart';

/// Read-only Terra-styled view of the estate's operating settings.
class TerraSettingsPage extends StatefulWidget {
  const TerraSettingsPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;

  @override
  State<TerraSettingsPage> createState() => _TerraSettingsPageState();
}

class _TerraSettingsPageState extends State<TerraSettingsPage> {
  Map<String, dynamic> _settings = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _settings = await widget.repository.loadEstateSettings(widget.estateId);
    } catch (_) {
      _error = 'Estate settings could not be loaded.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Iterable<MapEntry<String, dynamic>> get _rows =>
      _settings.entries.where((entry) => entry.value != null);

  String _label(String key) {
    final spaced = key.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    if (spaced.isEmpty) return '';
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  String _value(dynamic value) {
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is Map || value is List) {
      try {
        return jsonEncode(value);
      } catch (_) {
        return value.toString();
      }
    }
    final text = value.toString();
    if (text.length >= 10 && text.contains('T')) {
      if (DateTime.tryParse(text) != null) return AppFormat.date(text);
    }
    return text.isEmpty ? '—' : text;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows.toList(growable: false);
    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        appBar: AppBar(
          title: const Text('Settings'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  TerraSectionTitle(title: 'Estate profile'),
                  const SizedBox(height: 8),
                  TerraCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: TerraColors.sage,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.domain_outlined,
                              color: TerraColors.forest),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const TerraLabel('Estate name'),
                              const SizedBox(height: 4),
                              Text(
                                widget.estateName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: TerraColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TerraSectionTitle(
                    title: 'Settings',
                    trailing: TerraBadge(label: '${rows.length}'),
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(color: TerraColors.forest),
                    )
                  else if (_error != null)
                    TerraCard(
                      child: TerraEmpty(
                        message: _error!,
                        icon: Icons.error_outline,
                      ),
                    )
                  else if (rows.isEmpty)
                    const TerraCard(
                      child: TerraEmpty(
                        message: 'No estate settings are available.',
                        icon: Icons.tune_outlined,
                      ),
                    )
                  else
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TerraCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: TerraLabel(_label(row.key))),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _value(row.value),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: TerraColors.ink,
                                  ),
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
        ),
      ),
    );
  }
}
