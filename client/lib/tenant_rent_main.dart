import 'package:flutter/material.dart';

import 'core/theme/estate_theme.dart';
import 'features/onboarding/data/estate_application_repository.dart';
import 'features/resident/presentation/tenant_rent_api_page.dart';

void main() => runApp(const TenantRentApp());

class TenantRentApp extends StatelessWidget {
  const TenantRentApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'My tenancy',
    debugShowCheckedModeBanner: false,
    theme: EstateTheme.light(),
    home: TenantRentApiPage(repository: EstateApplicationApiClient()),
  );
}
