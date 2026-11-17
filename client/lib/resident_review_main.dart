import 'package:flutter/material.dart';

import 'core/theme/estate_theme.dart';
import 'features/onboarding/data/estate_application_repository.dart';
import 'features/resident_access/presentation/resident_access_review_page.dart';

void main() => runApp(const ResidentReviewApp());

class ResidentReviewApp extends StatelessWidget {
  const ResidentReviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Resident access review',
    debugShowCheckedModeBanner: false,
    theme: EstateTheme.light(),
    home: ResidentAccessReviewPage(repository: EstateApplicationApiClient()),
  );
}
