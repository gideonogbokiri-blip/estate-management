import 'package:flutter/material.dart';

import 'core/theme/estate_theme.dart';
import 'features/landlord/data/landlord_repository.dart';
import 'features/landlord/presentation/landlord_shell.dart';

void main() {
  runApp(const LandlordPreviewApp());
}

class LandlordPreviewApp extends StatelessWidget {
  const LandlordPreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Estate Management | Landlord',
    debugShowCheckedModeBanner: false,
    theme: EstateTheme.light(),
    home: LandlordShell(repository: PreviewLandlordRepository()),
  );
}
