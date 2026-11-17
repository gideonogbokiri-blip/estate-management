import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/resident_estate_repository.dart';

class ResidentMapPage extends StatefulWidget {
  const ResidentMapPage({super.key, required this.map, required this.onBack});
  final ResidentEstateMap map;
  final VoidCallback onBack;

  @override
  State<ResidentMapPage> createState() => _ResidentMapPageState();
}

class _ResidentMapPageState extends State<ResidentMapPage> {
  String _filter = 'all';
  ResidentEstateMapAsset? _selected;

  @override
  Widget build(BuildContext context) {
    final visible = widget.map.assets.where(_matchesFilter).toList();
    final mapped = visible
        .where((asset) => asset.diagramX != null && asset.diagramY != null)
        .toList();
    final unmapped = widget.map.assets
        .where(
          (asset) =>
              (asset.diagramX == null || asset.diagramY == null) &&
              _matchesFilter(asset),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Community'),
          ),
        ),
        const SizedBox(height: 4),
        Text('Estate map', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          '${widget.map.estateName} · ${widget.map.location}',
          style: const TextStyle(color: EstateColors.muted),
        ),
        const SizedBox(height: 15),
        const _MapNotice(),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _MapFilter(
                label: 'All places',
                selected: _filter == 'all',
                onTap: () => _setFilter('all'),
              ),
              const SizedBox(width: 7),
              _MapFilter(
                label: 'Homes',
                selected: _filter == 'homes',
                onTap: () => _setFilter('homes'),
              ),
              const SizedBox(width: 7),
              _MapFilter(
                label: 'Shared spaces',
                selected: _filter == 'shared',
                onTap: () => _setFilter('shared'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, box) => Container(
            height: (box.maxWidth / 1.45).clamp(230, 430),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F0E9),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: EstateColors.line),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _EstateDiagramPainter()),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.layers_outlined,
                          size: 15,
                          color: EstateColors.forest,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.map.estateName,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ...mapped.map(
                  (asset) => _positionMarker(
                    asset,
                    box.maxWidth,
                    (box.maxWidth / 1.45).clamp(230, 430),
                  ),
                ),
                Positioned(
                  right: 11,
                  top: 11,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .92),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      '${mapped.length} places',
                      style: const TextStyle(
                        fontSize: 10,
                        color: EstateColors.muted,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 11,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: EstateColors.muted,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Illustrative layout · not to scale',
                          style: TextStyle(
                            fontSize: 10,
                            color: EstateColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 15,
          runSpacing: 6,
          children: [
            _LegendDot(color: EstateColors.forest, label: 'Your property'),
            _LegendDot(color: Color(0xFF47759A), label: 'Estate place'),
            _LegendDot(
              color: Color(0xFF8A6731),
              label: 'Approximate or unverified',
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Text(
            'Marker colour identifies your home versus estate places. Select a marker to see its location confidence; this diagram is illustrative and not to scale.',
            style: TextStyle(
              fontSize: 10,
              color: EstateColors.muted,
              height: 1.4,
            ),
          ),
        ),
        if (_selected != null) ...[
          const SizedBox(height: 12),
          _SelectedPlace(
            asset: _selected!,
            onClose: () => setState(() => _selected = null),
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Places in your estate',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${visible.length} places',
              style: const TextStyle(color: EstateColors.muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ...visible
            .where((asset) => asset.diagramX != null)
            .map(
              (asset) => _PlaceListTile(
                asset: asset,
                onTap: () => setState(() => _selected = asset),
              ),
            ),
        if (unmapped.isNotEmpty) ...[
          const SizedBox(height: 13),
          const Text(
            'Location not provided',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ...unmapped.map(
            (asset) => _PlaceListTile(
              asset: asset,
              onTap: () => setState(() => _selected = asset),
            ),
          ),
        ],
        const SizedBox(height: 13),
        Text(
          'Map data last updated ${_date(widget.map.asOf)}. Only estate assets returned by your authorized map view are shown; this app does not collect your device location.',
          style: const TextStyle(
            color: EstateColors.muted,
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  bool _matchesFilter(ResidentEstateMapAsset asset) => switch (_filter) {
    'homes' => asset.layer == 'home' || asset.layer == 'building',
    'shared' => asset.layer == 'gate' || asset.layer == 'facility',
    _ => true,
  };

  void _setFilter(String value) => setState(() {
    _filter = value;
    _selected = null;
  });

  Widget _positionMarker(
    ResidentEstateMapAsset asset,
    double width,
    double height,
  ) {
    final x = asset.diagramX!.clamp(.08, .92) * width;
    final y = asset.diagramY!.clamp(.13, .88) * height;
    return Positioned(
      left: (x - 43).clamp(4, width - 92),
      top: (y - 22).clamp(36, height - 51),
      child: _MapMarker(
        asset: asset,
        onTap: () => setState(() => _selected = asset),
      ),
    );
  }
}

class _MapNotice extends StatelessWidget {
  const _MapNotice();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEDF4EF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.privacy_tip_outlined, size: 17, color: EstateColors.forest),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Illustrative estate diagram only, not to scale or a survey. Place locations may be approximate. This map does not track residents or devices.',
            style: TextStyle(
              color: EstateColors.forestDeep,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EstateDiagramPainter extends CustomPainter {
  const _EstateDiagramPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grass = Paint()..color = const Color(0xFFDCEBDD);
    canvas.drawRect(Offset.zero & size, grass);

    final park = Paint()..color = const Color(0xFFC8DFC9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .38,
          size.height * .36,
          size.width * .27,
          size.height * .26,
        ),
        const Radius.circular(30),
      ),
      park,
    );

    final roadEdge = Paint()
      ..color = const Color(0xFFC6D1C9)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 31;
    final road = Paint()
      ..color = const Color(0xFFF8F8F3)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 26;
    final path = Path()
      ..moveTo(size.width * .02, size.height * .53)
      ..lineTo(size.width * .2, size.height * .53)
      ..cubicTo(
        size.width * .3,
        size.height * .53,
        size.width * .27,
        size.height * .22,
        size.width * .43,
        size.height * .22,
      )
      ..lineTo(size.width * .84, size.height * .22)
      ..moveTo(size.width * .3, size.height * .53)
      ..cubicTo(
        size.width * .43,
        size.height * .53,
        size.width * .4,
        size.height * .76,
        size.width * .5,
        size.height * .76,
      )
      ..lineTo(size.width * .84, size.height * .76)
      ..moveTo(size.width * .72, size.height * .22)
      ..lineTo(size.width * .72, size.height * .76);
    canvas.drawPath(path, roadEdge);
    canvas.drawPath(path, road);

    final smallRoad = Paint()
      ..color = const Color(0xFFF8F8F3)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 13;
    for (final y in [.34, .45, .62, .69]) {
      canvas.drawLine(
        Offset(size.width * .31, size.height * y),
        Offset(size.width * .44, size.height * y),
        smallRoad,
      );
      canvas.drawLine(
        Offset(size.width * .75, size.height * y),
        Offset(size.width * .86, size.height * y),
        smallRoad,
      );
    }

    final tree = Paint()..color = const Color(0xFF83B58E);
    for (final point in [
      Offset(size.width * .25, size.height * .3),
      Offset(size.width * .57, size.height * .3),
      Offset(size.width * .33, size.height * .81),
      Offset(size.width * .9, size.height * .4),
      Offset(size.width * .9, size.height * .65),
    ]) {
      canvas.drawCircle(point, 6, tree);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.asset, required this.onTap});
  final ResidentEstateMapAsset asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final confidenceLabel = _confidence(asset.locationConfidence);
    final color = asset.isHome
        ? EstateColors.forest
        : asset.locationConfidence == 'verified'
        ? const Color(0xFF47759A)
        : const Color(0xFF8A6731);
    final icon = asset.isHome
        ? Icons.home_rounded
        : asset.layer == 'building'
        ? Icons.apartment_rounded
        : asset.layer == 'gate'
        ? Icons.door_front_door_outlined
        : Icons.place_rounded;
    return Tooltip(
      message: '${asset.label} · $confidenceLabel',
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x25000000),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, size: 15, color: Colors.white),
            ),
            const SizedBox(height: 3),
            Container(
              constraints: const BoxConstraints(maxWidth: 96),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                asset.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapFilter extends StatelessWidget {
  const _MapFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: const Color(0xFFE3F0E7),
    showCheckmark: false,
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: EstateColors.muted),
      ),
    ],
  );
}

class _PlaceListTile extends StatelessWidget {
  const _PlaceListTile({required this.asset, required this.onTap});
  final ResidentEstateMapAsset asset;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 7),
    child: ListTile(
      dense: true,
      leading: Icon(
        asset.isHome ? Icons.home_work_outlined : Icons.place_outlined,
        color: asset.isHome ? EstateColors.forest : EstateColors.muted,
      ),
      title: Text(
        asset.label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${asset.detail ?? _layer(asset.layer)} · ${_confidence(asset.locationConfidence)}',
        style: const TextStyle(fontSize: 10),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    ),
  );
}

class _SelectedPlace extends StatelessWidget {
  const _SelectedPlace({required this.asset, required this.onClose});
  final ResidentEstateMapAsset asset;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final confidenceStyle = switch (asset.locationConfidence) {
      'verified' => (EstateColors.forest, const Color(0xFFE9F4ED)),
      'approximate' ||
      'unverified' => (const Color(0xFF795416), const Color(0xFFFFF2D8)),
      _ => (EstateColors.muted, const Color(0xFFF0F3F1)),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFEAF3EE),
              child: Icon(Icons.place_outlined, color: EstateColors.forest),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    asset.detail ?? _layer(asset.layer),
                    style: const TextStyle(
                      fontSize: 11,
                      color: EstateColors.muted,
                    ),
                  ),
                  if (asset.locationSource != null ||
                      asset.accuracyMeters != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      [
                        if (asset.locationSource != null)
                          'Source: ${asset.locationSource}',
                        if (asset.accuracyMeters != null)
                          'Known accuracy: about ${asset.accuracyMeters!.toStringAsFixed(0)} m',
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 10,
                        color: EstateColors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: confidenceStyle.$2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _confidence(asset.locationConfidence),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: confidenceStyle.$1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              tooltip: 'Close place details',
            ),
          ],
        ),
      ),
    );
  }
}

String _layer(String value) => switch (value) {
  'building' => 'Residential building',
  'gate' => 'Estate gate',
  'facility' => 'Shared place',
  'parking' => 'Parking area',
  'street' => 'Estate street',
  'zone' => 'Estate zone',
  _ => 'Estate place',
};

String _confidence(String value) => switch (value) {
  'verified' => 'Verified location',
  'approximate' => 'Approximate location',
  'unverified' => 'Unverified location',
  _ => 'Location not provided',
};

String _date(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
