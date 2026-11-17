import 'package:flutter/material.dart';

import 'features/admin/presentation/property_register_api_page.dart';

void main() => runApp(const PropertyRegisterApp());

class PropertyRegisterApp extends StatelessWidget {
  const PropertyRegisterApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Estate property register',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B4B)),
      scaffoldBackgroundColor: const Color(0xFFF6F8F6),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    ),
    home: const PropertyRegisterApiPage(),
  );
}
