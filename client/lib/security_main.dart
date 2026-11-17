import 'package:flutter/material.dart';

import 'core/theme/estate_theme.dart';
import 'features/onboarding/data/estate_application_repository.dart';
import 'features/security/data/security_repository.dart';
import 'features/security/presentation/security_gate_shell.dart';

void main() {
  runApp(const ZvendEstateSecurityApp());
}

class ZvendEstateSecurityApp extends StatelessWidget {
  const ZvendEstateSecurityApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Estate Gate',
    debugShowCheckedModeBanner: false,
    theme: EstateTheme.light(),
    home: SecurityGateShell(
      repository: ApiSecurityRepository(EstateApplicationApiClient()),
    ),
  );
}
