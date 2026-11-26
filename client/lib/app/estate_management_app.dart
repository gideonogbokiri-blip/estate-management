import 'package:flutter/material.dart';

import '../core/design/terra_theme.dart';
import '../features/onboarding/data/estate_application_repository.dart';
import '../features/resident/presentation/terra/terra_resident_page.dart';

class EstateManagementApp extends StatelessWidget {
  const EstateManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terra Crest Estate',
      debugShowCheckedModeBanner: false,
      theme: TerraTheme.light(),
      home: TerraResidentPage(repository: EstateApplicationApiClient()),
    );
  }
}
