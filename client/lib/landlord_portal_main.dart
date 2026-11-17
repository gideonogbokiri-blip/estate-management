import 'package:flutter/material.dart';

import 'core/theme/estate_theme.dart';
import 'features/onboarding/data/estate_application_repository.dart';
import 'features/landlord/presentation/landlord_portfolio_api_page.dart';

void main() => runApp(const LandlordPortfolioApp());

class LandlordPortfolioApp extends StatelessWidget {
  const LandlordPortfolioApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Landlord portfolio',
    debugShowCheckedModeBanner: false,
    theme: EstateTheme.light(),
    home: LandlordPortfolioApiPage(repository: EstateApplicationApiClient()),
  );
}
