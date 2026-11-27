import 'package:flutter/material.dart';
import '../../../core/navigation/auth_redirect.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class TenantRentApiPage extends StatefulWidget {
  const TenantRentApiPage({super.key, required this.repository});
  final EstateApplicationApiRepository repository;
  @override
  State<TenantRentApiPage> createState() => _TenantRentApiPageState();
}

class _TenantRentApiPageState extends State<TenantRentApiPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  EstateAccount? _account;
  List<TenantTenancyRecord> _tenancies = const [];
  bool _restoring = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() { super.initState(); _restore(); }
  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _restore() async {
    try { _account = await widget.repository.restoreSession(); if (_account != null) await _load(); }
    catch (error) { _error = _message(error); }
    finally { if (mounted) setState(() => _restoring = false); }
  }

  Future<void> _signIn() async {
    setState(() { _busy = true; _error = null; });
    try { _account = await widget.repository.signIn(email: _email.text.trim(), password: _password.text); await _load(); }
    catch (error) { _error = _message(error); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _load() async => _tenancies = await widget.repository.loadMyTenancies();
  String _message(Object error) => error is EstateApiException ? error.message : 'Your tenancy details could not be loaded.';

  @override
  Widget build(BuildContext context) {
    if (_restoring) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_account == null) return singleSignInRedirect();
    return Scaffold(
      appBar: AppBar(
        title: const Text('My tenancy'),
        actions: [
          IconButton(tooltip: 'Refresh tenancy', onPressed: _busy ? null : () async { setState(() { _busy = true; _error = null; }); try { await _load(); } catch (error) { _error = _message(error); } finally { if (mounted) setState(() => _busy = false); } }, icon: const Icon(Icons.refresh_rounded)),
          PopupMenuButton<String>(onSelected: (_) async { await widget.repository.signOut(); if (mounted) setState(() { _account = null; _tenancies = const []; }); }, itemBuilder: (_) => const [PopupMenuItem(value: 'signout', child: Text('Sign out'))]),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Hello, ${_account!.displayName}', style: const TextStyle(color: EstateColors.muted)),
              const SizedBox(height: 7),
              const Text('Your active tenancy', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w700, color: EstateColors.ink)),
              const SizedBox(height: 8),
              const Text('These terms come from your approved estate tenancy record. Payment history and outstanding balances are shown separately when billing is connected.', style: TextStyle(color: EstateColors.muted, height: 1.5)),
              if (_error != null) ...[const SizedBox(height: 16), _InfoCard(message: _error!, error: true)],
              if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
              const SizedBox(height: 20),
              if (_tenancies.isEmpty)
                const _InfoCard(message: 'No active tenancy is linked to this account. Contact your estate manager if this looks incorrect.')
              else
                ..._tenancies.map((record) => _TenancyCard(record: record)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _signInView() => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/onboarding_background.jpg', fit: BoxFit.cover),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x85111F18), Color(0xD509140F)]))),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Card(
                  color: Colors.white.withValues(alpha: .97),
                  child: Padding(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.key_outlined, color: EstateColors.forest, size: 36),
                        const SizedBox(height: 12),
                        const Text('Tenant sign in', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 18),
                        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address')),
                        const SizedBox(height: 12),
                        TextField(controller: _password, obscureText: true, onSubmitted: (_) => _signIn(), decoration: const InputDecoration(labelText: 'Password')),
                        if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: EstateColors.red))],
                        const SizedBox(height: 18),
                        FilledButton(onPressed: _busy ? null : _signIn, child: Text(_busy ? 'Signing in…' : 'Sign in')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _TenancyCard extends StatelessWidget {
  const _TenancyCard({required this.record});
  final TenantTenancyRecord record;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(record.estateName, style: const TextStyle(color: EstateColors.muted)),
          const SizedBox(height: 4),
          Text('${record.propertyCode} · ${record.propertyType}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Text('${record.currency} ${record.amount}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: EstateColors.forest)),
          Text('${record.frequency[0].toUpperCase()}${record.frequency.substring(1)} rent · due on day ${record.dueDay}'),
          const Divider(height: 28),
          Text('Landlord: ${record.landlordName}'),
          Text('Term: ${record.effectiveFrom}${record.effectiveTo == null ? ' · ongoing' : ' to ${record.effectiveTo}'}'),
          const SizedBox(height: 12),
          const Text('This is the agreed rent term. It does not show payments received or an outstanding balance.', style: TextStyle(fontSize: 12, color: EstateColors.muted, height: 1.45)),
        ],
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.message, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Card(
    color: error ? const Color(0xFFFFF0EE) : null,
    child: Padding(padding: const EdgeInsets.all(18), child: Text(message, style: TextStyle(color: error ? EstateColors.red : EstateColors.muted, height: 1.45))),
  );
}

