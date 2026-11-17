import 'package:flutter/material.dart';

import 'core/theme/estate_theme.dart';
import 'features/onboarding/data/estate_application_repository.dart';
import 'features/resident_access/presentation/resident_join_page.dart';

void main() => runApp(const ResidentJoinApp());

class ResidentJoinApp extends StatelessWidget {
  const ResidentJoinApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Join an estate',
    debugShowCheckedModeBanner: false,
    theme: EstateTheme.light(),
    home: ResidentJoinPage(repository: EstateApplicationApiClient()),
  );
}
