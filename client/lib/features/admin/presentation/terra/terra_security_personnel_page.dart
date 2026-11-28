import 'package:flutter/material.dart';

import '../../../../core/design/terra_theme.dart';
import '../../../../data/api.dart';

/// Security personnel assigned to the estate, with their gate assignments.
class TerraSecurityPersonnelPage extends StatefulWidget {
  const TerraSecurityPersonnelPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;

  @override
  State<TerraSecurityPersonnelPage> createState() =>
      _TerraSecurityPersonnelPageState();
}

class _TerraSecurityPersonnelPageState extends State<TerraSecurityPersonnelPage> {
  List<EstateStaffChoice> _officers = const [];
  List<EstateGateRecord> _gates = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _officers = await widget.repository.loadSecurityOfficers(widget.estateId);
    } catch (_) {
      _officers = const [];
    }
    try {
      _gates = await widget.repository.loadEstateGates(widget.estateId);
    } catch (_) {
      _gates = const [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        appBar: AppBar(
          title: const Text('Security personnel'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
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
                  TerraSectionTitle(
                    title: 'Security personnel',
                    trailing: TerraBadge(label: '${_officers.length} officers'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.estateName,
                    style: const TextStyle(
                        color: TerraColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  TerraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TerraSectionTitle(title: 'Estate gates'),
                        const SizedBox(height: 8),
                        if (_gates.isEmpty)
                          const TerraEmpty(message: 'No gates have been configured.')
                        else
                          ..._gates.map(
                            (gate) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.sensor_door_outlined,
                                  color: TerraColors.forest),
                              title: Text(gate.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text('Gate code ${gate.code}',
                                  style: const TextStyle(fontSize: 11)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TerraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TerraSectionTitle(title: 'Officers'),
                        const SizedBox(height: 8),
                        if (_loading)
                          const Center(
                              child:
                                  CircularProgressIndicator(color: TerraColors.forest))
                        else if (_officers.isEmpty)
                          const TerraEmpty(
                              message: 'No security officers are linked to this estate.')
                        else
                          ..._officers.map(
                            (officer) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: TerraColors.sage,
                                child: Text(
                                  officer.displayName
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
                              title: Text(officer.displayName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: const Text('Security officer'),
                            ),
                          ),
                      ],
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
