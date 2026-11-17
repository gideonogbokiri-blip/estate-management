import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class ResidentJoinPage extends StatefulWidget {
  const ResidentJoinPage({super.key, required this.repository});
  final EstateApplicationApiRepository repository;
  @override
  State<ResidentJoinPage> createState() => _ResidentJoinPageState();
}

class _ResidentJoinPageState extends State<ResidentJoinPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _note = TextEditingController();
  EstateAccount? _account;
  List<ManagedEstateChoice> _estates = const [];
  List<JoinRequestPropertyChoice> _properties = const [];
  List<ResidentJoinRequestStatusEntry> _history = const [];
  ManagedEstateChoice? _estate;
  String? _propertyId;
  String _relationship = 'tenant';
  bool _registering = false;
  bool _busy = false;
  bool _restoring = true;
  String? _error;

  @override
  void initState() { super.initState(); _restore(); }
  @override
  void dispose() { _name.dispose(); _email.dispose(); _password.dispose(); _note.dispose(); super.dispose(); }

  Future<void> _restore() async {
    try {
      _account = await widget.repository.restoreSession();
      if (_account != null) await _loadWorkspace();
    } catch (error) { _error = _text(error); }
    finally { if (mounted) setState(() => _restoring = false); }
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (_registering) {
        await widget.repository.register(email: _email.text, displayName: _name.text, password: _password.text);
      }
      _account = await widget.repository.signIn(email: _email.text, password: _password.text);
      await _loadWorkspace();
    } catch (error) { _error = _text(error); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _loadWorkspace() async {
    final results = await Future.wait([
      widget.repository.loadAvailableEstates(),
      widget.repository.loadMyJoinRequestHistory(),
    ]);
    _estates = results[0] as List<ManagedEstateChoice>;
    _history = results[1] as List<ResidentJoinRequestStatusEntry>;
    _estate = _estates.where((estate) => estate.id == _estate?.id).firstOrNull ?? (_estates.isEmpty ? null : _estates.first);
    await _loadProperties();
  }

  Future<void> _loadProperties() async {
    final estate = _estate;
    if (estate == null) { _properties = const []; _propertyId = null; return; }
    _properties = await widget.repository.loadJoinRequestProperties(estate.id);
    if (!_properties.any((property) => property.id == _propertyId)) _propertyId = null;
  }

  Future<void> _selectEstate(ManagedEstateChoice? estate) async {
    setState(() { _estate = estate; _busy = true; _error = null; });
    try { await _loadProperties(); }
    catch (error) { _error = _text(error); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _submitRequest() async {
    final estate = _estate;
    if (estate == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.repository.submitResidentJoinRequest(
        estateId: estate.id,
        propertyId: _propertyId,
        relationship: _propertyId == null ? null : _relationship,
        note: _note.text,
      );
      _note.clear();
      _history = await widget.repository.loadMyJoinRequestHistory();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your request was sent to the estate team.')));
    } catch (error) { _error = _text(error); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _signOut() async {
    await widget.repository.signOut();
    if (!mounted) return;
    setState(() { _account = null; _estates = const []; _properties = const []; _history = const []; _estate = null; });
  }

  String _text(Object error) => error is EstateApiException ? error.message : 'The estate service could not complete this request.';

  @override
  Widget build(BuildContext context) {
    if (_restoring) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_account == null) return _signInView();
    final currentEstatePending = _history.any((entry) => entry.estateId == _estate?.id && entry.status == 'pending');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Row(children: [Icon(Icons.domain_rounded, color: EstateColors.forest), SizedBox(width: 10), Text('Estate Management', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))]),
        actions: [Text(_account!.displayName, style: const TextStyle(color: EstateColors.muted)), const SizedBox(width: 8), IconButton(tooltip: 'Sign out', onPressed: _signOut, icon: const Icon(Icons.logout_rounded)), const SizedBox(width: 10)],
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Request resident access', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w700, color: EstateColors.ink, letterSpacing: -.5)),
        const SizedBox(height: 7),
        const Text('Choose your estate and, if applicable, the home or unit connected to your request.', style: TextStyle(color: EstateColors.muted)),
        const SizedBox(height: 22),
        if (_error != null) _ErrorCard(message: _error!),
        if (_estates.isEmpty)
          const _EmptyCard(title: 'No estates are available yet', detail: 'Estate applications appear here after they are approved and activated.')
        else ...[
          Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Access request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            DropdownButtonFormField<ManagedEstateChoice>(
              initialValue: _estate,
              decoration: const InputDecoration(labelText: 'Estate', prefixIcon: Icon(Icons.apartment_rounded)),
              items: _estates.map((item) => DropdownMenuItem(value: item, child: Text(item.name))).toList(),
              onChanged: _busy ? null : _selectEstate,
            ),
            if (_properties.isNotEmpty) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: _propertyId,
                decoration: const InputDecoration(labelText: 'Home or unit (optional)', prefixIcon: Icon(Icons.home_work_outlined)),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Request estate access only')),
                  ..._properties.map((property) => DropdownMenuItem<String?>(value: property.id, child: Text('${property.code} · ${property.type}${property.structureLabels.isEmpty ? '' : ' · ${property.structureLabels.join(' / ')}'}', overflow: TextOverflow.ellipsis))),
                ],
                onChanged: _busy ? null : (value) => setState(() => _propertyId = value),
              ),
            ],
            if (_propertyId != null) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _relationship,
                decoration: const InputDecoration(labelText: 'Your relationship to this property'),
                items: const [
                  DropdownMenuItem(value: 'owner', child: Text('Owner')),
                  DropdownMenuItem(value: 'tenant', child: Text('Tenant')),
                  DropdownMenuItem(value: 'household_member', child: Text('Household member')),
                  DropdownMenuItem(value: 'authorized_occupant', child: Text('Authorized occupant')),
                ],
                onChanged: _busy ? null : (value) => setState(() => _relationship = value ?? _relationship),
              ),
            ],
            const SizedBox(height: 14),
            TextField(controller: _note, maxLength: 1000, maxLines: 3, decoration: const InputDecoration(labelText: 'Note for the estate team (optional)', alignLabelWithHint: true)),
            Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _busy || currentEstatePending ? null : _submitRequest, icon: _busy ? const SizedBox.square(dimension: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded), label: Text(currentEstatePending ? 'Request pending' : 'Send request'))),
            if (currentEstatePending) const Text('You already have a pending request for this estate.', style: TextStyle(color: EstateColors.amber, fontSize: 12)),
          ]))),
        ],
        const SizedBox(height: 24),
        const Text('Your requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: EstateColors.ink)),
        const SizedBox(height: 10),
        if (_history.isEmpty) const _EmptyCard(title: 'No requests yet', detail: 'Requests you send will appear here with their current review status.')
        else ..._history.map((entry) => _HistoryCard(entry: entry)),
      ]))),
    );
  }

  Widget _signInView() => Scaffold(body: Stack(fit: StackFit.expand, children: [
    Image.asset('assets/images/onboarding_background.jpg', fit: BoxFit.cover),
    const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x85111F18), Color(0xD509140F)]))),
    SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Card(color: Colors.white.withValues(alpha: .97), child: Padding(padding: const EdgeInsets.all(28), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.holiday_village_outlined, size: 36, color: EstateColors.forest),
      const SizedBox(height: 14),
      Text(_registering ? 'Create your resident account' : 'Sign in to find your estate', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, color: EstateColors.ink, fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      const Text('Request access to your home and estate services.', textAlign: TextAlign.center, style: TextStyle(color: EstateColors.muted)),
      if (_registering) ...[const SizedBox(height: 20), TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded)), validator: (value) => value == null || value.trim().length < 2 ? 'Enter your name.' : null)],
      const SizedBox(height: 18),
      TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded)), validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email address.' : null),
      const SizedBox(height: 13),
      TextFormField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline_rounded)), validator: (value) => value == null || value.length < 10 ? 'Use at least 10 characters.' : null),
      if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: EstateColors.red))],
      const SizedBox(height: 20),
      FilledButton(onPressed: _busy ? null : _authenticate, child: Text(_busy ? 'Please wait…' : _registering ? 'Create account' : 'Sign in')),
      TextButton(onPressed: _busy ? null : () => setState(() { _registering = !_registering; _error = null; }), child: Text(_registering ? 'Already have an account? Sign in' : 'New here? Create an account')),
    ])))))))),
  ]));
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});
  final ResidentJoinRequestStatusEntry entry;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
    leading: const CircleAvatar(backgroundColor: Color(0xFFE9F2ED), child: Icon(Icons.apartment_rounded, color: EstateColors.forest)),
    title: Text(entry.estateName, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text([if (entry.propertyCode != null) 'Property ${entry.propertyCode}', if (entry.relationship != null) _label(entry.relationship!), _date(entry.submittedAt), if (entry.decisionReason != null) entry.decisionReason!].join(' · ')),
    trailing: _StatusLabel(status: entry.status),
  ));
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = status == 'approved' ? EstateColors.forest : status == 'pending' ? EstateColors.amber : EstateColors.red;
    final fill = status == 'approved' ? const Color(0xFFE9F2ED) : status == 'pending' ? const Color(0xFFFFF5E5) : const Color(0xFFFFECEA);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(18)), child: Text(_label(status), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)));
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.detail});
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [const Icon(Icons.inbox_outlined, color: EstateColors.forest, size: 28), const SizedBox(height: 9), Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: EstateColors.muted))])));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(color: const Color(0xFFFFF0EE), child: Padding(padding: const EdgeInsets.all(14), child: Text(message, style: const TextStyle(color: EstateColors.red))));
}

String _label(String value) => value.split('_').map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}').join(' ');
String _date(String value) { final date = DateTime.tryParse(value)?.toLocal(); return date == null ? 'Submitted' : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'; }
