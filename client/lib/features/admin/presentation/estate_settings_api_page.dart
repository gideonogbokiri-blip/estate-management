import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class EstateSettingsApiPage extends StatefulWidget {
  const EstateSettingsApiPage({
    super.key,
    required this.repository,
    required this.estateId,
  });
  final EstateApplicationApiRepository repository;
  final String estateId;

  @override
  State<EstateSettingsApiPage> createState() => _EstateSettingsApiPageState();
}

class _EstateSettingsApiPageState extends State<EstateSettingsApiPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _type = TextEditingController();
  final _address = TextEditingController();
  final _state = TextEditingController();
  final _lga = TextEditingController();
  String? _estateCode;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _type.dispose();
    _address.dispose();
    _state.dispose();
    _lga.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.loadEstateSettings(widget.estateId);
      _name.text = data['name'] as String? ?? '';
      _type.text = data['estateType'] as String? ?? '';
      _address.text = data['address'] as String? ?? '';
      _state.text = data['state'] as String? ?? '';
      _lga.text = data['lga'] as String? ?? '';
      _estateCode = data['estateCode'] as String?;
    } catch (error) {
      _error = error is EstateApiException
          ? error.message
          : 'Estate settings could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.updateEstateSettings(
        estateId: widget.estateId,
        fields: {
          'name': _name.text.trim(),
          'estateType': _type.text.trim(),
          'address': _address.text.trim(),
          'state': _state.text.trim(),
          'lga': _lga.text.trim(),
        },
      );
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Estate settings saved.')));
    } catch (error) {
      _error = error is EstateApiException
          ? error.message
          : 'Estate settings could not be saved.';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value) =>
      (value?.trim().length ?? 0) < 2 ? 'Enter at least 2 characters.' : null;

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      validator: _required,
      maxLength: label == 'Estate name'
          ? 200
          : label == 'Address'
          ? 300
          : 100,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: EstateColors.canvas,
    appBar: AppBar(title: const Text('Estate settings')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Operating profile',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Keep the estate identity and location current for residents and staff.',
                    style: TextStyle(color: EstateColors.muted),
                  ),
                  const SizedBox(height: 18),
                  if (_estateCode != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.tag_outlined,
                          color: EstateColors.forest,
                        ),
                        title: const Text('Estate reference'),
                        subtitle: Text(_estateCode!),
                        trailing: const Text(
                          'Managed by the platform',
                          style: TextStyle(
                            color: EstateColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _field(_name, 'Estate name'),
                            _field(
                              _type,
                              'Estate type',
                              hint: 'Residential community',
                            ),
                            _field(_address, 'Street address'),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _field(_state, 'State')),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _field(_lga, 'Local government area'),
                                ),
                              ],
                            ),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: EstateColors.red,
                                  ),
                                ),
                              ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  _saving ? 'Saving…' : 'Save changes',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Changes are saved to the estate record and included in its audit history. Only estate administrators can save profile changes.',
                    style: TextStyle(
                      color: EstateColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
  );
}
