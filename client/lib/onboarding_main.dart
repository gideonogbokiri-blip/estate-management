import 'package:flutter/material.dart';

import 'core/theme/estate_theme.dart';
import 'features/onboarding/data/estate_application_repository.dart';
import 'features/onboarding/presentation/estate_application_gate.dart';

void main() {
  runApp(const ZvendEstateOnboardingApp());
}

class ZvendEstateOnboardingApp extends StatelessWidget {
  const ZvendEstateOnboardingApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Estate Applications',
    debugShowCheckedModeBanner: false,
    theme: EstateTheme.light(),
    home: EstateApplicationGate(repository: EstateApplicationApiClient()),
  );
}
