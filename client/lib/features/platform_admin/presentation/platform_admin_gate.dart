import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../../core/navigation/auth_redirect.dart';
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
    return singleSignInRedirect();
  }
}
