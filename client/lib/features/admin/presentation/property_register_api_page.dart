import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_base_url.dart';

const _green = Color(0xFF176B4B);
String get _apiBase => runtimeApiBaseUrl() ?? const String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:4100/api/v1',
);
const _statuses = <String, String>{
  'active': 'Active',
  'under_development': 'Under development',
  'reserved': 'Reserved',
  'under_maintenance': 'Under maintenance',
  'inactive': 'Inactive',
};

class _EstateChoice {
  const _EstateChoice(this.id, this.code, this.name, this.location, this.roles);
  final String id;
  final String code;
  final String name;
  final String location;
  final List<String> roles;

  factory _EstateChoice.fromJson(Map<String, dynamic> json) => _EstateChoice(
    json['id'] as String,
    json['estateCode'] as String,
    json['name'] as String,
    [
      json['state'],
      json['lga'],
    ].whereType<String>().where((part) => part.isNotEmpty).join(', '),
    (json['roles'] as List<dynamic>).cast<String>(),
  );
}

class _PropertyRecord {
  const _PropertyRecord({
    required this.id,
    required this.code,
    required this.type,
    required this.status,
    this.unitNumber,
    this.address,
    this.description,
    this.structureNodes = const [],
  });
  final String id;
  final String code;
  final String type;
  final String status;
  final String? unitNumber;
  final String? address;
  final String? description;
  final List<_StructureOption> structureNodes;

  factory _PropertyRecord.fromJson(Map<String, dynamic> json) =>
      _PropertyRecord(
        id: json['id'] as String,
        code: json['code'] as String,
        type: json['propertyType'] as String,
        status: json['status'] as String,
        unitNumber: json['unitNumber'] as String?,
        address: json['address'] as String?,
        description: json['description'] as String?,
        structureNodes: (json['structureNodes'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_StructureOption.fromJson)
            .toList(growable: false),
      );
}

class _StructureOption {
  const _StructureOption({
    required this.id,
    required this.type,
    required this.name,
    this.code,
  });
  final String id;
  final String type;
  final String name;
  final String? code;
  String get label =>
      '${type[0].toUpperCase()}${type.substring(1)} · $name${code == null ? '' : ' ($code)'}';
  factory _StructureOption.fromJson(Map<String, dynamic> json) =>
      _StructureOption(
        id: json['id'] as String,
        type: json['type'] as String,
        name: json['name'] as String,
        code: json['code'] as String?,
      );
}

class PropertyRegisterApiPage extends StatefulWidget {
  const PropertyRegisterApiPage({super.key});

  @override
  State<PropertyRegisterApiPage> createState() =>
      _PropertyRegisterApiPageState();
}

class _PropertyRegisterApiPageState extends State<PropertyRegisterApiPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _search = TextEditingController();
  String? _token;
  String? _error;
  String? _estateId;
  String? _statusFilter;
  List<_EstateChoice> _estates = const [];
  List<_StructureOption> _structureNodes = const [];
  List<_PropertyRecord> _properties = const [];
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _search.dispose();
    super.dispose();
  }

  Uri _uri(String path) => Uri.parse('$_apiBase$path');

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (_token != null) headers['Authorization'] = 'Bearer $_token';
    if (body != null) headers['Content-Type'] = 'application/json';
    final request = http.Request(method, _uri(path))..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(await request.send());
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message']
          : null;
      throw StateError(
        message is String
            ? message
            : 'The estate service returned ${response.statusCode}.',
      );
    }
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _request(
        'POST',
        '/auth/login',
        body: {'email': _email.text.trim(), 'password': _password.text},
      );
      _token = response['accessToken'] as String?;
      if (_token == null) {
        throw StateError('The service did not return a sign-in session.');
      }
      await _loadEstates();
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadEstates() async {
    final response = await _request('GET', '/estate/estates/mine');
    final list = (response['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_EstateChoice.fromJson)
        .where(
          (estate) => estate.roles.any(
            (role) =>
                const {'estate_administrator', 'estate_manager'}.contains(role),
          ),
        )
        .toList();
    if (!mounted) return;
    setState(() {
      _estates = list;
      _estateId = list.isEmpty ? null : list.first.id;
    });
    if (_estateId != null) {
      await _loadStructure();
      await _loadProperties();
    }
  }

  Future<void> _loadStructure() async {
    final estateId = _estateId;
    if (estateId == null) return;
    final response = await _request(
      'GET',
      '/estate/estates/$estateId/structure',
    );
    final nodes = (response['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_StructureOption.fromJson)
        .toList(growable: false);
    if (mounted) setState(() => _structureNodes = nodes);
  }

  Future<void> _loadProperties() async {
    final estateId = _estateId;
    if (estateId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final query = <String, String>{'page': '1', 'pageSize': '100'};
      final search = _search.text.trim();
      if (search.isNotEmpty) query['search'] = search;
      if (_statusFilter != null) query['status'] = _statusFilter!;
      final response = await _request(
        'GET',
        '/estate/estates/$estateId/properties?${Uri(queryParameters: query).query}',
      );
      final items = (response['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_PropertyRecord.fromJson)
          .toList();
      if (mounted) setState(() => _properties = items);
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditor([_PropertyRecord? current]) async {
    final formKey = GlobalKey<FormState>();
    final code = TextEditingController(text: current?.code ?? '');
    final type = TextEditingController(
      text: current?.type ?? 'Residential unit',
    );
    final unit = TextEditingController(text: current?.unitNumber ?? '');
    final address = TextEditingController(text: current?.address ?? '');
    final description = TextEditingController(text: current?.description ?? '');
    var status = current?.status ?? 'active';
    var structureNodeId = current?.structureNodes.firstOrNull?.id;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text(current == null ? 'Add property' : 'Edit property'),
          content: SizedBox(
            width: 470,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: code,
                      decoration: const InputDecoration(
                        labelText: 'Property code',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: type,
                      decoration: const InputDecoration(
                        labelText: 'Property type',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Operational status',
                      ),
                      items: _statuses.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          refresh(() => status = value ?? status),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: structureNodeId,
                      decoration: const InputDecoration(
                        labelText: 'Phase, street, building or floor',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No structure link'),
                        ),
                        ..._structureNodes.map(
                          (node) => DropdownMenuItem<String?>(
                            value: node.id,
                            child: Text(
                              node.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          refresh(() => structureNodeId = value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: unit,
                      decoration: const InputDecoration(
                        labelText: 'Unit or house number',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: address,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: description,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext, true);
              },
              child: Text(current == null ? 'Add property' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
    if (result == true && _estateId != null) {
      setState(() => _busy = true);
      try {
        final body = <String, dynamic>{
          'code': code.text.trim(),
          'propertyType': type.text.trim(),
          'status': status,
          'unitNumber': unit.text.trim().isEmpty ? null : unit.text.trim(),
          'address': address.text.trim().isEmpty ? null : address.text.trim(),
          'description': description.text.trim().isEmpty
              ? null
              : description.text.trim(),
          'structureNodeIds': structureNodeId == null
              ? <String>[]
              : <String>[structureNodeId!],
        };
        await _request(
          current == null ? 'POST' : 'PATCH',
          current == null
              ? '/estate/estates/$_estateId/properties'
              : '/estate/estates/$_estateId/properties/${current.id}',
          body: body,
        );
        await _loadProperties();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                current == null ? 'Property added.' : 'Property updated.',
              ),
            ),
          );
        }
      } catch (error) {
        if (mounted) setState(() => _error = _errorText(error));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    for (final controller in [code, type, unit, address, description]) {
      controller.dispose();
    }
  }

  Future<void> _archiveProperty(_PropertyRecord property) async {
    final estateId = _estateId;
    if (estateId == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive ${property.code}?'),
        content: const Text(
          'The property and its history will be kept. Archiving is blocked while it has active occupants or owners, a tenancy, an open maintenance request, a pending resident request, an active visitor pass or a visitor still inside.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive property'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _request(
        'POST',
        '/estate/estates/$estateId/properties/${property.id}/archive',
        body: const {},
      );
      await _loadProperties();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property archived. Its records have been retained.'),
          ),
        );
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manageOwnership(_PropertyRecord property) async {
    final estateId = _estateId;
    if (estateId == null) return;
    Future<List<Map<String, dynamic>>> load() async {
      final response = await _request(
        'GET',
        '/estate/estates/$estateId/properties/${property.id}/owners',
      );
      return (response['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }

    Future<void> decide(
      Map<String, dynamic> owner,
      String decision,
      String reason,
    ) async {
      await _request(
        'POST',
        '/estate/estates/$estateId/ownership/${owner['id']}/verify',
        body: {'decision': decision, 'reason': reason},
      );
    }

    try {
      var owners = await load();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, refresh) => AlertDialog(
            title: Text('Owners · ${property.code}'),
            content: SizedBox(
              width: 520,
              child: owners.isEmpty
                  ? const Text(
                      'No ownership records are linked to this property yet.',
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: owners.length,
                      separatorBuilder: (_, _) => const Divider(height: 18),
                      itemBuilder: (context, index) {
                        final record = owners[index];
                        final owner =
                            record['owner'] as Map<String, dynamic>? ??
                            const {};
                        final pending =
                            record['verificationStatus'] == 'pending';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              owner['displayName'] as String? ??
                                  'Account owner',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${owner['emailNormalized'] ?? ''} · ${record['share']}% · ${record['verificationStatus']}',
                            ),
                            if ((record['evidenceNote'] as String?)
                                    ?.isNotEmpty ==
                                true)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  'Evidence checked: ${record['evidenceNote']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            if (pending)
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () async {
                                      final reason = await _ownershipReason(
                                        'Reject ownership',
                                        'Reason for rejection',
                                      );
                                      if (reason == null) return;
                                      try {
                                        await decide(record, 'reject', reason);
                                        final updated = await load();
                                        if (dialogContext.mounted)
                                          refresh(() => owners = updated);
                                      } catch (error) {
                                        if (dialogContext.mounted)
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(_errorText(error)),
                                            ),
                                          );
                                      }
                                    },
                                    child: const Text('Reject'),
                                  ),
                                  FilledButton.tonal(
                                    onPressed: () async {
                                      final reason = await _ownershipReason(
                                        'Verify ownership',
                                        'Record what was checked',
                                      );
                                      if (reason == null) return;
                                      try {
                                        await decide(record, 'verify', reason);
                                        final updated = await load();
                                        if (dialogContext.mounted)
                                          refresh(() => owners = updated);
                                      } catch (error) {
                                        if (dialogContext.mounted)
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(_errorText(error)),
                                            ),
                                          );
                                      }
                                    },
                                    child: const Text('Verify'),
                                  ),
                                ],
                              ),
                          ],
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _addOwnership(property);
                },
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Add owner'),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_errorText(error))));
    }
  }

  Future<String?> _ownershipReason(String title, String label) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty)
                Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Save decision'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<void> _addOwnership(_PropertyRecord property) async {
    final formKey = GlobalKey<FormState>();
    final email = TextEditingController();
    final share = TextEditingController(text: '100');
    final effectiveFrom = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    final evidence = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add owner · ${property.code}'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Account email'),
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Enter the owner’s registered account email.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: share,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Ownership share (%)',
                  ),
                  validator: (value) =>
                      value == null ||
                          double.tryParse(value) == null ||
                          double.parse(value) <= 0 ||
                          double.parse(value) > 100
                      ? 'Enter a share from 0.01 to 100.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: effectiveFrom,
                  decoration: const InputDecoration(
                    labelText: 'Effective from (YYYY-MM-DD)',
                  ),
                  validator: (value) =>
                      value == null ||
                          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)
                      ? 'Use YYYY-MM-DD.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: evidence,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Evidence checked by estate team',
                    helperText: 'Record the offline source checked. This app does not upload title documents yet.',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Describe what the estate team checked.'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate())
                Navigator.pop(context, true);
            },
            child: const Text('Create pending record'),
          ),
        ],
      ),
    );
    if (saved == true && _estateId != null) {
      try {
        await _request(
          'POST',
          '/estate/estates/$_estateId/properties/${property.id}/owners',
          body: {
            'ownerEmail': email.text.trim(),
            'ownershipShare': share.text.trim(),
            'effectiveFrom': effectiveFrom.text.trim(),
            'evidenceNote': evidence.text.trim(),
          },
        );
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ownership record created for review.'),
            ),
          );
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }
    email.dispose();
    share.dispose();
    effectiveFrom.dispose();
    evidence.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchTenancies() async {
    final estateId = _estateId;
    if (estateId == null) return const [];
    final response = await _request(
      'GET',
      '/estate/estates/$estateId/tenancies?page=1&pageSize=100',
    );
    return (response['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<void> _openTenancies() async {
    if (_estateId == null) return;
    try {
      var records = await _fetchTenancies();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, refresh) => AlertDialog(
            title: const Text('Tenancies'),
            content: SizedBox(
              width: 650,
              child: records.isEmpty
                  ? const Text(
                      'No tenancy records have been created for this estate.',
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: records.length,
                      separatorBuilder: (_, _) => const Divider(height: 20),
                      itemBuilder: (context, index) {
                        final record = records[index];
                        final property =
                            record['property'] as Map<String, dynamic>? ??
                            const {};
                        final tenant =
                            record['tenant'] as Map<String, dynamic>? ??
                            const {};
                        final payee =
                            record['payee'] as Map<String, dynamic>? ??
                            const {};
                        final rent =
                            record['rent'] as Map<String, dynamic>? ?? const {};
                        final status = record['status'] as String? ?? 'unknown';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${property['code'] ?? 'Property'} · ${tenant['displayName'] ?? 'Tenant'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${rent['currency'] ?? ''} ${rent['amount'] ?? ''} / ${rent['frequency'] ?? ''} · due day ${rent['dueDay'] ?? ''}',
                            ),
                            Text(
                              'Payee: ${payee['displayName'] ?? '—'} · ${record['effectiveFrom'] ?? ''}${record['effectiveTo'] == null ? '' : ' to ${record['effectiveTo']}'}',
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Chip(label: Text(status.replaceAll('_', ' '))),
                                if (status == 'pending_approval')
                                  FilledButton.tonal(
                                    onPressed: () async {
                                      final reason = await _ownershipReason(
                                        'Approve tenancy',
                                        'Approval reason',
                                      );
                                      if (reason == null) return;
                                      try {
                                        await _request(
                                          'POST',
                                          '/estate/estates/$_estateId/tenancies/${record['id']}/approve',
                                          body: {'reason': reason},
                                        );
                                        final updated = await _fetchTenancies();
                                        if (dialogContext.mounted)
                                          refresh(() => records = updated);
                                      } catch (error) {
                                        if (dialogContext.mounted)
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(_errorText(error)),
                                            ),
                                          );
                                      }
                                    },
                                    child: const Text('Approve and activate'),
                                  ),
                                if (status == 'active')
                                  TextButton(
                                    onPressed: () async {
                                      final values =
                                          await _terminationDetails();
                                      if (values == null) return;
                                      try {
                                        await _request(
                                          'POST',
                                          '/estate/estates/$_estateId/tenancies/${record['id']}/terminate',
                                          body: {
                                            'effectiveTo': values.$1,
                                            'reason': values.$2,
                                          },
                                        );
                                        final updated = await _fetchTenancies();
                                        if (dialogContext.mounted)
                                          refresh(() => records = updated);
                                      } catch (error) {
                                        if (dialogContext.mounted)
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(_errorText(error)),
                                            ),
                                          );
                                      }
                                    },
                                    child: const Text('Terminate'),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  final created = await _openTenancyDraft();
                  if (created && mounted) await _openTenancies();
                },
                icon: const Icon(Icons.add),
                label: const Text('Create tenancy'),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_errorText(error))));
    }
  }

  Future<(String, String)?> _terminationDetails() async {
    final date = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    final reason = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminate tenancy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: date,
              decoration: const InputDecoration(
                labelText: 'Effective date (YYYY-MM-DD)',
              ),
            ),
            TextField(
              controller: reason,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date.text) &&
                  reason.text.trim().isNotEmpty)
                Navigator.pop(context, (date.text.trim(), reason.text.trim()));
            },
            child: const Text('Terminate'),
          ),
        ],
      ),
    );
    date.dispose();
    reason.dispose();
    return result;
  }

  Future<bool> _openTenancyDraft() async {
    final estateId = _estateId;
    final activeProperties = _properties
        .where((property) => property.status == 'active')
        .toList();
    if (estateId == null || activeProperties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an active property before creating a tenancy.'),
        ),
      );
      return false;
    }
    final formKey = GlobalKey<FormState>();
    final tenantEmail = TextEditingController();
    final rent = TextEditingController();
    final deposit = TextEditingController();
    final dueDay = TextEditingController(text: '1');
    final from = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    final to = TextEditingController();
    final note = TextEditingController();
    var propertyId = activeProperties.first.id;
    var frequency = 'monthly';
    var owners = <Map<String, dynamic>>[];
    var payeeId = '';
    Future<void> loadOwners(String selectedPropertyId) async {
      final response = await _request(
        'GET',
        '/estate/estates/$estateId/properties/$selectedPropertyId/owners',
      );
      final startDate = from.text.trim();
      final endDate = to.text.trim();
      owners = (response['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .where(
            (record) =>
                record['status'] == 'active' &&
                record['verificationStatus'] == 'verified' &&
                (record['effectiveFrom'] as String? ?? '').compareTo(
                      startDate,
                    ) <=
                    0 &&
                (record['effectiveTo'] == null ||
                    (record['effectiveTo'] as String).compareTo(
                          endDate.isEmpty ? startDate : endDate,
                        ) >=
                        0) &&
                (endDate.isNotEmpty || record['effectiveTo'] == null),
          )
          .toList();
      payeeId = owners.isEmpty
          ? ''
          : (owners.first['owner'] as Map<String, dynamic>)['id'] as String;
    }

    try {
      await loadOwners(propertyId);
      if (!mounted) return false;
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, refresh) => AlertDialog(
            title: const Text('Create tenancy'),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: propertyId,
                        decoration: const InputDecoration(
                          labelText: 'Property',
                        ),
                        items: activeProperties
                            .map(
                              (property) => DropdownMenuItem(
                                value: property.id,
                                child: Text(
                                  '${property.code} · ${property.type}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) async {
                          if (value == null) return;
                          propertyId = value;
                          try {
                            await loadOwners(value);
                            if (dialogContext.mounted) refresh(() {});
                          } catch (error) {
                            if (dialogContext.mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_errorText(error))),
                              );
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: payeeId.isEmpty ? null : payeeId,
                        decoration: const InputDecoration(
                          labelText: 'Verified landlord / rent payee',
                        ),
                        items: owners.map((record) {
                          final owner = record['owner'] as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: owner['id'] as String,
                            child: Text(
                              '${owner['displayName']} · ${record['share']}%',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            refresh(() => payeeId = value ?? ''),
                        validator: (_) => payeeId.isEmpty
                            ? 'This property needs a verified owner first.'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: tenantEmail,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Tenant account email',
                        ),
                        validator: (value) =>
                            value == null || !value.contains('@')
                            ? 'Enter the tenant’s registered account email.'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: rent,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Rent amount (NGN)',
                              ),
                              validator: _positiveAmount,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: frequency,
                              decoration: const InputDecoration(
                                labelText: 'Frequency',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'monthly',
                                  child: Text('Monthly'),
                                ),
                                DropdownMenuItem(
                                  value: 'quarterly',
                                  child: Text('Quarterly'),
                                ),
                                DropdownMenuItem(
                                  value: 'annually',
                                  child: Text('Annually'),
                                ),
                              ],
                              onChanged: (value) =>
                                  refresh(() => frequency = value ?? 'monthly'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: dueDay,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Due day (1–31)',
                              ),
                              validator: (value) =>
                                  int.tryParse(value ?? '') == null ||
                                      int.parse(value!) < 1 ||
                                      int.parse(value) > 31
                                  ? 'Use 1–31.'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: deposit,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Deposit (optional)',
                              ),
                              validator: _nonNegativeAmount,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: from,
                              decoration: const InputDecoration(
                                labelText: 'Start (YYYY-MM-DD)',
                              ),
                              onChanged: (_) async {
                                await loadOwners(propertyId);
                                if (dialogContext.mounted) refresh(() {});
                              },
                              validator: _calendarDateValidator,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: to,
                              decoration: const InputDecoration(
                                labelText: 'End (optional)',
                              ),
                              onChanged: (_) async {
                                await loadOwners(propertyId);
                                if (dialogContext.mounted) refresh(() {});
                              },
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? null
                                  : _calendarDateValidator(value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: note,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Terms note (optional)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Creating a tenancy does not record rent payments or upload an agreement. Approval activates tenant occupancy.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate())
                    Navigator.pop(dialogContext, true);
                },
                child: const Text('Save pending tenancy'),
              ),
            ],
          ),
        ),
      );
      if (saved != true) return false;
      await _request(
        'POST',
        '/estate/estates/$estateId/properties/$propertyId/tenancies',
        body: {
          'tenantEmail': tenantEmail.text.trim(),
          'payeeEmail':
              (owners.firstWhere(
                    (record) =>
                        (record['owner'] as Map<String, dynamic>)['id'] ==
                        payeeId,
                  )['owner']
                  as Map<String, dynamic>)['emailNormalized'],
          'rentAmount': rent.text.trim(),
          'currency': 'NGN',
          'rentFrequency': frequency,
          'rentDueDay': int.parse(dueDay.text.trim()),
          'depositAmount': deposit.text.trim().isEmpty
              ? null
              : deposit.text.trim(),
          'effectiveFrom': from.text.trim(),
          'effectiveTo': to.text.trim().isEmpty ? null : to.text.trim(),
          'termsNote': note.text.trim().isEmpty ? null : note.text.trim(),
        },
      );
      return true;
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_errorText(error))));
      return false;
    } finally {
      tenantEmail.dispose();
      rent.dispose();
      deposit.dispose();
      dueDay.dispose();
      from.dispose();
      to.dispose();
      note.dispose();
    }
  }

  String? _positiveAmount(String? value) =>
      value == null ||
          double.tryParse(value) == null ||
          double.parse(value) <= 0
      ? 'Enter an amount greater than zero.'
      : null;
  String? _nonNegativeAmount(String? value) =>
      value == null ||
          value.trim().isEmpty ||
          (double.tryParse(value) != null && double.parse(value) >= 0)
      ? null
      : 'Enter zero or a positive amount.';
  String? _calendarDateValidator(String? value) =>
      value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)
      ? 'Use YYYY-MM-DD.'
      : null;

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  String _errorText(Object error) => error is StateError
      ? error.message
      : 'Could not connect to the estate service.';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      backgroundColor: const Color(0xEFFFFFFF),
      surfaceTintColor: Colors.transparent,
      title: const Row(
        children: [
          Icon(Icons.home_work_outlined, color: _green),
          SizedBox(width: 10),
          Text(
            'Estate property register',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        if (_token != null)
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => setState(() {
              _token = null;
              _estates = const [];
              _properties = const [];
              _estateId = null;
            }),
            icon: const Icon(Icons.logout),
          ),
        const SizedBox(width: 12),
      ],
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/onboarding_background.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        const DecoratedBox(decoration: BoxDecoration(color: Color(0x68F6F8F6))),
        SafeArea(child: _token == null ? _signInView() : _registerView()),
      ],
    ),
  );

  Widget _signInView() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sign in to manage properties',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use your Estate Management account to open an estate register.',
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email address'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                obscureText: _obscure,
                onSubmitted: (_) => _signIn(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _signIn,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _registerView() {
    final estate = _estates.where((item) => item.id == _estateId).firstOrNull;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_estates.isEmpty) ...[
                const SizedBox(height: 60),
                const Center(
                  child: Text(
                    'No active estate management access is linked to this account.',
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Properties',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            estate == null
                                ? 'Estate register'
                                : '${estate.name}  ·  ${estate.location}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    if (_estates.length > 1)
                      DropdownButton<String>(
                        value: _estateId,
                        items: _estates
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) async {
                          setState(() => _estateId = value);
                          await _loadProperties();
                        },
                      ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _openTenancies,
                      icon: const Icon(Icons.key_outlined),
                      label: const Text('Tenancies'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _openEditor(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add property'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 290,
                          child: TextField(
                            controller: _search,
                            onSubmitted: (_) => _loadProperties(),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: 'Search code, type or address',
                              suffixIcon: IconButton(
                                onPressed: _loadProperties,
                                icon: const Icon(Icons.arrow_forward),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String?>(
                            initialValue: _statusFilter,
                            decoration: const InputDecoration(
                              labelText: 'Operational status',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All statuses'),
                              ),
                              ..._statuses.entries.map(
                                (entry) => DropdownMenuItem<String?>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _statusFilter = value);
                              _loadProperties();
                            },
                          ),
                        ),
                        Text(
                          '${_properties.length} properties',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: MaterialBanner(
                      content: Text(_error!),
                      leading: const Icon(Icons.cloud_off_outlined),
                      actions: [
                        TextButton(
                          onPressed: _loadProperties,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: _busy
                      ? const Center(child: CircularProgressIndicator())
                      : _properties.isEmpty
                      ? _emptyState()
                      : ListView.separated(
                          itemCount: _properties.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _propertyCard(_properties[index]),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.apartment_outlined, size: 48, color: _green),
          const SizedBox(height: 14),
          const Text(
            'No properties yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          const Text(
            'Add the first home, unit or commercial space to this estate register.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
            label: const Text('Add property'),
          ),
        ],
      ),
    ),
  );

  Widget _propertyCard(_PropertyRecord property) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE4EFE8),
        child: const Icon(Icons.home_work_outlined, color: _green),
      ),
      title: Text(
        '${property.code}  ·  ${property.type}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          [
            _statuses[property.status] ?? property.status,
            property.unitNumber,
            property.address,
            ...property.structureNodes.map((node) => node.label),
          ].whereType<String>().where((part) => part.isNotEmpty).join('  ·  '),
        ),
      ),
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            tooltip: 'Manage ownership',
            onPressed: () => _manageOwnership(property),
            icon: const Icon(Icons.people_alt_outlined),
          ),
          IconButton(
            tooltip: 'Edit property',
            onPressed: () => _openEditor(property),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Archive property',
            onPressed: _busy ? null : () => _archiveProperty(property),
            icon: const Icon(Icons.archive_outlined),
          ),
        ],
      ),
    ),
  );
}
