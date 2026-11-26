import 'package:flutter/material.dart';

import 'core/design/terra_theme.dart';
import 'features/landlord/presentation/terra/terra_landlord_page.dart';
import 'features/onboarding/data/estate_application_repository.dart';

void main() => runApp(const LandlordPortfolioApp());

class LandlordPortfolioApp extends StatelessWidget {
  const LandlordPortfolioApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Landlord portfolio',
    debugShowCheckedModeBanner: false,
    theme: TerraTheme.light(),
    home: TerraLandlordPage(repository: EstateApplicationApiClient()),
  );
}
