import 'package:flutter/material.dart';

import 'core/design/terra_theme.dart';
import 'features/admin/presentation/terra/terra_manager_page.dart';
import 'features/onboarding/data/estate_application_repository.dart';

void main() {
  runApp(const ZvendEstateAdminApp());
}

class ZvendEstateAdminApp extends StatelessWidget {
  const ZvendEstateAdminApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Estate Management Administration',
    debugShowCheckedModeBanner: false,
    theme: TerraTheme.light(),
    home: TerraManagerPage(repository: EstateApplicationApiClient()),
  );
}
