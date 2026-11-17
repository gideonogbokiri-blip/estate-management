import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/platform_application_repository.dart';
import 'platform_admin_shell.dart';

class PlatformAdminGate extends StatefulWidget {
  const PlatformAdminGate({super.key, required this.repository});
  final PlatformApplicationApiRepository repository;

  @override
  State<PlatformAdminGate> createState() => _PlatformAdminGateState();
}

class _PlatformAdminGateState extends State<PlatformAdminGate> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  bool _signedIn = false;
  bool _hidePassword = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final signedIn = await widget.repository.restoreSession();
      if (!mounted) return;
      setState(() {
        _signedIn = signedIn;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = error.toString();
      });
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.repository.signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      setState(() => _signedIn = true);
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await widget.repository.signOut();
    if (mounted) setState(() => _signedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_signedIn) {
      return PlatformAdminShell(
        repository: widget.repository,
        onSignOut: _signOut,
      );
    }
    return Scaffold(
      backgroundColor: EstateColors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: EstateColors.forest,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  Text(
                    'Estate Management',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Platform operations',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: EstateColors.muted),
                  ),
                  const SizedBox(height: 25),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign in',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Use an account with platform review access.',
                              style: TextStyle(color: EstateColors.muted),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.username],
                              decoration: const InputDecoration(
                                labelText: 'Work email',
                                prefixIcon: Icon(Icons.alternate_email_rounded),
                              ),
                              validator: (value) =>
                                  value == null || !value.contains('@')
                                  ? 'Enter a valid email address.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _password,
                              obscureText: _hidePassword,
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _hidePassword = !_hidePassword,
                                  ),
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Enter your password.'
                                  : null,
                              onFieldSubmitted: (_) => _signIn(),
                            ),
                            if (_message != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                _message!,
                                style: const TextStyle(color: EstateColors.red),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _busy ? null : _signIn,
                              child: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Continue to platform'),
                            ),
                          ],
                        ),
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
