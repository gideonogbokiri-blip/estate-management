import 'package:flutter/material.dart';

import 'core/theme/estate_theme.dart';
import 'features/resident/data/resident_estate_repository.dart';
import 'features/resident/presentation/resident_map_page.dart';

void main() => runApp(const EstateMapPreviewApp());

class EstateMapPreviewApp extends StatelessWidget {
  const EstateMapPreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Estate Management | Estate map',
    debugShowCheckedModeBanner: false,
    theme: EstateTheme.light(),
    home: FutureBuilder<ResidentEstateMap>(
      future: PreviewResidentEstateRepository().loadMyEstateMap(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('The estate map preview is unavailable.')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ResidentMapPage(
                  map: snapshot.requireData,
                  onBack: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Open the resident app to return to Community.',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
