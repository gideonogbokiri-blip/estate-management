import 'package:flutter/material.dart';

import 'core/theme/estate_theme.dart';
import 'features/platform_admin/data/platform_application_api_repository.dart';
import 'features/platform_admin/presentation/platform_admin_gate.dart';

void main() {
  runApp(const ZvendPlatformAdminApp());
}

class ZvendPlatformAdminApp extends StatelessWidget {
  const ZvendPlatformAdminApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Estate Management | Platform Operations',
    debugShowCheckedModeBanner: false,
    theme: EstateTheme.light(),
    home: PlatformAdminGate(repository: PlatformApplicationApiClient()),
  );
}
