import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../../core/navigation/auth_redirect.dart';
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
    return singleSignInRedirect();
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
