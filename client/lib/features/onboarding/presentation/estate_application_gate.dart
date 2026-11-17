import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/estate_application_repository.dart';
import 'estate_application_shell.dart';

class EstateApplicationGate extends StatefulWidget {
  const EstateApplicationGate({super.key, required this.repository});
  final EstateApplicationApiRepository repository;

  @override
  State<EstateApplicationGate> createState() => _EstateApplicationGateState();
}

class _EstateApplicationGateState extends State<EstateApplicationGate> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  EstateAccount? _account;
  bool _restoring = true;
  bool _busy = false;
  bool _registering = false;
  bool _obscurePassword = true;
  String? _startupMessage;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    try {
      final account = await widget.repository.restoreSession();
      if (!mounted) return;
      setState(() {
        _account = account;
        _restoring = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _startupMessage = error.toString();
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_registering) {
        await widget.repository.register(
          email: _email.text,
          displayName: _name.text,
          password: _password.text,
        );
      }
      final account = await widget.repository.signIn(
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      setState(() => _account = account);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await widget.repository.signOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _account = null;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final account = _account;
    if (account != null) {
      return EstateApplicationShell(
        key: ValueKey(account.id),
        repository: widget.repository,
        onSignOut: _signOut,
      );
    }
    return Scaffold(
      backgroundColor: EstateColors.forest,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/onboarding_background.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xA607150F),
                  Color(0x54101A15),
                  Color(0xB306110B),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: EstateColors.forest,
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: const Icon(
                            Icons.domain_rounded,
                            color: Colors.white,
                            size: 29,
                          ),
                        ),
                      ),
                      const SizedBox(height: 17),
                      Text(
                        'Estate Management',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Estate registration and community management',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xD1FFFFFF)),
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
                                  _registering
                                      ? 'Create your account'
                                      : 'Welcome back',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  _registering
                                      ? 'Use your account to save and manage estate applications.'
                                      : 'Sign in to continue your estate application.',
                                  style: const TextStyle(
                                    color: EstateColors.muted,
                                    height: 1.45,
                                  ),
                                ),
                                if (_startupMessage != null) ...[
                                  const SizedBox(height: 15),
                                  _ApiStatusNote(message: _startupMessage!),
                                ],
                                if (_registering) ...[
                                  const SizedBox(height: 18),
                                  TextFormField(
                                    controller: _name,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'Full name',
                                      prefixIcon: Icon(
                                        Icons.person_outline_rounded,
                                      ),
                                    ),
                                    validator: (value) =>
                                        _registering &&
                                            (value == null ||
                                                value.trim().length < 2)
                                        ? 'Enter your full name.'
                                        : null,
                                  ),
                                ],
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  textCapitalization: TextCapitalization.none,
                                  decoration: const InputDecoration(
                                    labelText: 'Email address',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  validator: (value) {
                                    final email = value?.trim() ?? '';
                                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                        .hasMatch(email)) {
                                      return 'Enter a valid email address.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword
                                          ? 'Show password'
                                          : 'Hide password',
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Enter your password.';
                                    }
                                    if (_registering && value.length < 12) {
                                      return 'Use at least 12 characters.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                FilledButton(
                                  onPressed: _busy ? null : _submit,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    child: Text(
                                      _busy
                                          ? 'Please wait…'
                                          : _registering
                                          ? 'Create account'
                                          : 'Sign in',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() {
                                          _registering = !_registering;
                                          _startupMessage = null;
                                        }),
                                  child: Text(
                                    _registering
                                        ? 'I already have an account'
                                        : 'Create an account',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Your application details are saved to your account and can be updated before submission.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xD1FFFFFF),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiStatusNote extends StatelessWidget {
  const _ApiStatusNote({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5E5),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Text(message, style: const TextStyle(fontSize: 12, height: 1.4)),
  );
}

String _friendlyError(Object error) {
  if (error is EstateApiException) return error.message;
  return 'The estate service could not be reached. Check your connection and try again.';
}
