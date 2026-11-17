import 'package:flutter/material.dart';

import 'core/theme/estate_theme.dart';
import 'features/onboarding/data/estate_application_repository.dart';
import 'features/admin/presentation/estate_manager_dashboard_api_page.dart';

void main() {
  runApp(const ZvendEstateAdminApp());
}

class ZvendEstateAdminApp extends StatelessWidget {
  const ZvendEstateAdminApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Estate Management Administration',
    debugShowCheckedModeBanner: false,
    theme: EstateTheme.light(),
    home: EstateManagerDashboardApiPage(repository: EstateApplicationApiClient()),
  );
}
