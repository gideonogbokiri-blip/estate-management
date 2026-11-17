import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/estate_admin_repository.dart';

class LandlordPortfolioPage extends StatefulWidget {
  const LandlordPortfolioPage({super.key, required this.properties});
  final List<LandlordPortfolioItem> properties;

  @override
  State<LandlordPortfolioPage> createState() => _LandlordPortfolioPageState();
}

class _LandlordPortfolioPageState extends State<LandlordPortfolioPage> {
  final _search = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final occupied = widget.properties
        .where((p) => p.occupancyStatus == 'rented')
        .length;
    final available = widget.properties.length - occupied;
    final leased = widget.properties
        .where((p) => p.tenancyStatus == 'active')
        .length;
    final query = _search.text.trim().toLowerCase();
    final visible = widget.properties.where((p) {
      final matches =
          query.isEmpty ||
          '${p.propertyLabel} ${p.propertyAddress ?? ''} ${p.tenantDisplayName ?? ''} ${p.propertyType ?? ''}'
              .toLowerCase()
              .contains(query);
      final statusMatches = switch (_filter) {
        'rented' => p.occupancyStatus == 'rented',
        'available' => p.occupancyStatus != 'rented',
        _ => true,
      };
      return matches && statusMatches;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 40),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 14,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Landlord portfolio',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Verified ownership and property occupancy in this estate.',
                  style: TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export portfolio'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _PortfolioNotice(),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth < 560
                ? box.maxWidth
                : (box.maxWidth - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _PortfolioMetric(
                  width: width,
                  label: 'Verified properties',
                  value: '${widget.properties.length}',
                  icon: Icons.apartment_outlined,
                  color: EstateColors.forest,
                ),
                _PortfolioMetric(
                  width: width,
                  label: 'Currently rented',
                  value: '$occupied',
                  icon: Icons.key_outlined,
                  color: const Color(0xFF476B91),
                ),
                _PortfolioMetric(
                  width: width,
                  label: 'Not currently rented',
                  value: '$available',
                  icon: Icons.home_work_outlined,
                  color: const Color(0xFF8A6731),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          '$leased active tenancies shown. Contract rent is not a payment or collection balance.',
          style: const TextStyle(color: EstateColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 15),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 310,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search property or tenant',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: _filter,
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('All properties'),
                    ),
                    DropdownMenuItem(
                      value: 'rented',
                      child: Text('Currently rented'),
                    ),
                    DropdownMenuItem(
                      value: 'available',
                      child: Text('Not currently rented'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _filter = value ?? 'all'),
                ),
                Text(
                  '${visible.length} properties',
                  style: const TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: Text('No properties match these filters.')),
            ),
          )
        else
          ...visible.map(
            (p) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF1EC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: EstateColors.forest,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                p.propertyLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              _OccupancyBadge(
                                rented: p.occupancyStatus == 'rented',
                              ),
                              _PropertyState(text: p.operationalStatus),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            [
                              p.estateName,
                              if (p.estateLocation != null) p.estateLocation!,
                              if (p.propertyAddress != null) p.propertyAddress!,
                            ].join(' · '),
                            style: const TextStyle(
                              color: EstateColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          if (p.tenantDisplayName != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 16,
                                  color: EstateColors.muted,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Tenant: ${p.tenantDisplayName}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _label(p.tenancyStatus),
                                  style: const TextStyle(
                                    color: EstateColors.forest,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 10),
                            const Text(
                              'No current rental shown',
                              style: TextStyle(
                                color: EstateColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (p.rentAmount != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${p.currency} ${_money(p.rentAmount!)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'contract rent / ${p.rentFrequency}',
                              style: const TextStyle(
                                color: EstateColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _money(String value) =>
      value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  String _label(String? value) => value == null
      ? ''
      : value
            .split('_')
            .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
}

class _PortfolioNotice extends StatelessWidget {
  const _PortfolioNotice();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F7F5),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFDDE8E0)),
    ),
    child: const Row(
      children: [
        Icon(Icons.verified_user_outlined, color: EstateColors.forest),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Preview portfolio. The connected read service must verify ownership, estate scope and actor access before returning these records.',
            style: TextStyle(color: EstateColors.ink),
          ),
        ),
      ],
    ),
  );
}

class _PortfolioMetric extends StatelessWidget {
  const _PortfolioMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(label, style: const TextStyle(color: EstateColors.muted)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _OccupancyBadge extends StatelessWidget {
  const _OccupancyBadge({required this.rented});
  final bool rented;
  @override
  Widget build(BuildContext context) {
    final color = rented ? EstateColors.forest : const Color(0xFF8A6731);
    final label = rented ? 'Rented' : 'Not rented';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PropertyState extends StatelessWidget {
  const _PropertyState({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final label = text
        .split('_')
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
    return Text(
      '· $label',
      style: const TextStyle(color: EstateColors.muted, fontSize: 11),
    );
  }
}
