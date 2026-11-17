import 'package:flutter/material.dart';

import '../core/theme/estate_theme.dart';
import '../features/onboarding/data/estate_application_repository.dart';
import '../features/resident/presentation/resident_home_api_page.dart';

class EstateManagementApp extends StatelessWidget {
  const EstateManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Estate Management',
      debugShowCheckedModeBanner: false,
      theme: EstateTheme.light(),
      home: ResidentHomeApiPage(repository: EstateApplicationApiClient()),
    );
  }
}
