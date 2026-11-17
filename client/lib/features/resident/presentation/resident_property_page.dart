import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/resident_estate_repository.dart';

class ResidentPropertyPage extends StatefulWidget {
  const ResidentPropertyPage({
    super.key,
    required this.properties,
    required this.onBack,
  });
  final List<ResidentPropertyDetail> properties;
  final VoidCallback onBack;

  @override
  State<ResidentPropertyPage> createState() => _ResidentPropertyPageState();
}

class _ResidentPropertyPageState extends State<ResidentPropertyPage> {
  String? _selectedPropertyId;

  @override
  Widget build(BuildContext context) {
    if (widget.properties.isEmpty) {
      return const Center(
        child: Text('No property relationships are available.'),
      );
    }
    final property = widget.properties.firstWhere(
      (item) => item.propertyId == _selectedPropertyId,
      orElse: () => widget.properties.first,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Community'),
          ),
        ),
        const SizedBox(height: 7),
        Text('My property', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 5),
        const Text(
          'Your property and approved household relationships.',
          style: TextStyle(color: EstateColors.muted),
        ),
        const SizedBox(height: 17),
        const _PropertyNotice(),
        const SizedBox(height: 14),
        if (widget.properties.length > 1) ...[
          DropdownButtonFormField<String>(
            initialValue: property.propertyId,
            decoration: const InputDecoration(
              labelText: 'Property and estate',
              prefixIcon: Icon(Icons.swap_horiz_rounded),
            ),
            items: widget.properties
                .map(
                  (item) => DropdownMenuItem(
                    value: item.propertyId,
                    child: Text(
                      '${item.propertyLabel} · ${item.estateName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedPropertyId = value),
          ),
          const SizedBox(height: 14),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF1EC),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.home_work_outlined,
                        color: EstateColors.forest,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            property.propertyLabel,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${property.propertyType} · ${_label(property.status)}',
                            style: const TextStyle(
                              color: EstateColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _PropertyDetailLine(
                  icon: Icons.location_on_outlined,
                  label: 'Address',
                  value: property.address,
                ),
                const SizedBox(height: 10),
                _PropertyDetailLine(
                  icon: Icons.apartment_outlined,
                  label: 'Estate',
                  value: '${property.estateName} · ${property.estateLocation}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        _RelationshipSection(
          title: 'Ownership',
          icon: Icons.verified_user_outlined,
          relationships: property.ownershipRecords,
          ownership: true,
        ),
        const SizedBox(height: 14),
        _RelationshipSection(
          title: 'Household and occupancy',
          icon: Icons.people_outline_rounded,
          relationships: property.occupancyRecords,
          ownership: false,
        ),
        const SizedBox(height: 12),
        const Text(
          'Relationship details are shown only when returned by the authorized estate property service.',
          style: TextStyle(color: EstateColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  String _label(String value) => value
      .split('_')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

class _PropertyNotice extends StatelessWidget {
  const _PropertyNotice();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F7F5),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFDDE8E0)),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, color: EstateColors.forest),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Preview property information. Your connected account controls which ownership and household details are visible.',
            style: TextStyle(fontSize: 12, color: EstateColors.ink),
          ),
        ),
      ],
    ),
  );
}

class _PropertyDetailLine extends StatelessWidget {
  const _PropertyDetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: EstateColors.muted),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: EstateColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    ],
  );
}

class _RelationshipSection extends StatelessWidget {
  const _RelationshipSection({
    required this.title,
    required this.icon,
    required this.relationships,
    required this.ownership,
  });
  final String title;
  final IconData icon;
  final List<ResidentPropertyRelationship> relationships;
  final bool ownership;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: EstateColors.forest),
              const SizedBox(width: 9),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 9),
          if (relationships.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No relationship details are available.',
                style: TextStyle(color: EstateColors.muted, fontSize: 12),
              ),
            ),
          ...relationships.map(
            (relationship) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFEAF1EC),
                    child: Text(
                      relationship.displayName.isNotEmpty
                          ? relationship.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: EstateColors.forest,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          relationship.displayName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_label(relationship.relationship)} · ${_label(relationship.status)}',
                          style: const TextStyle(
                            color: EstateColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ownership && relationship.share != null)
                    Text(
                      relationship.share!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  String _label(String value) => value
      .split('_')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
