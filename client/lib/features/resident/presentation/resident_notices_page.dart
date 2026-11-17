import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/resident_estate_repository.dart';

class ResidentNoticesPage extends StatefulWidget {
  const ResidentNoticesPage({
    super.key,
    required this.announcements,
    required this.onBack,
    required this.onAnnouncementOpened,
  });

  final List<ResidentAnnouncement> announcements;
  final VoidCallback onBack;
  final ValueChanged<String> onAnnouncementOpened;

  @override
  State<ResidentNoticesPage> createState() => _ResidentNoticesPageState();
}

class _ResidentNoticesPageState extends State<ResidentNoticesPage> {
  final _searchController = TextEditingController();
  String _readFilter = 'all';
  String _categoryFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final categories =
        widget.announcements
            .map((announcement) => announcement.category)
            .toSet()
            .toList()
          ..sort();
    final unreadCount = widget.announcements
        .where((announcement) => !announcement.read)
        .length;
    final visible = widget.announcements.where((announcement) {
      final matchesRead =
          _readFilter == 'all' ||
          (_readFilter == 'unread' && !announcement.read) ||
          (_readFilter == 'read' && announcement.read);
      final matchesCategory =
          _categoryFilter == 'all' || announcement.category == _categoryFilter;
      final matchesSearch =
          query.isEmpty ||
          '${announcement.title} ${announcement.body} ${announcement.category} ${announcement.audienceLabel}'
              .toLowerCase()
              .contains(query);
      return matchesRead && matchesCategory && matchesSearch;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Community services'),
          ),
        ),
        Text(
          'Community notices',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 5),
        const Text('Updates shared with your estate and resident group.'),
        const SizedBox(height: 16),
        const _NoticeSource(),
        const SizedBox(height: 14),
        _NoticeSummary(total: widget.announcements.length, unread: unreadCount),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search notices',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 6,
          children: [
            _NoticeFilterChip(
              label: 'All',
              selected: _readFilter == 'all',
              onSelected: () => setState(() => _readFilter = 'all'),
            ),
            _NoticeFilterChip(
              label: 'Unread${unreadCount == 0 ? '' : ' $unreadCount'}',
              selected: _readFilter == 'unread',
              onSelected: () => setState(() => _readFilter = 'unread'),
            ),
            _NoticeFilterChip(
              label: 'Read',
              selected: _readFilter == 'read',
              onSelected: () => setState(() => _readFilter = 'read'),
            ),
          ],
        ),
        if (categories.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              _NoticeFilterChip(
                label: 'Every category',
                selected: _categoryFilter == 'all',
                onSelected: () => setState(() => _categoryFilter = 'all'),
              ),
              for (final category in categories)
                _NoticeFilterChip(
                  label: category,
                  selected: _categoryFilter == category,
                  onSelected: () => setState(() => _categoryFilter = category),
                ),
            ],
          ),
        ],
        const SizedBox(height: 13),
        if (widget.announcements.isEmpty)
          const _NoNotices()
        else if (visible.isEmpty)
          _FilteredNoticesEmpty(
            onClear: () {
              _searchController.clear();
              setState(() {
                _readFilter = 'all';
                _categoryFilter = 'all';
              });
            },
          )
        else ...[
          Text(
            '${visible.length} ${visible.length == 1 ? 'notice' : 'notices'}',
            style: const TextStyle(
              color: EstateColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final announcement in visible)
            _NoticeCard(
              key: ValueKey(announcement.id),
              announcement: announcement,
              onOpened: widget.onAnnouncementOpened,
            ),
        ],
      ],
    );
  }
}

class _NoticeSummary extends StatelessWidget {
  const _NoticeSummary({required this.total, required this.unread});
  final int total;
  final int unread;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5EAE6)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.mark_email_unread_outlined,
          color: EstateColors.forest,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$total ${total == 1 ? 'notice' : 'notices'}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '$unread unread',
          style: TextStyle(
            color: unread > 0 ? EstateColors.forest : EstateColors.muted,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _NoticeFilterChip extends StatelessWidget {
  const _NoticeFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    onSelected: (_) => onSelected(),
  );
}

class _NoticeSource extends StatelessWidget {
  const _NoticeSource();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F6F3),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD7E5DC)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.campaign_outlined, color: EstateColors.forest, size: 19),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Sample notice feed. In the connected app, audience and delivery are resolved by the estate notification service.',
            style: TextStyle(
              color: EstateColors.forest,
              height: 1.4,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    super.key,
    required this.announcement,
    required this.onOpened,
  });
  final ResidentAnnouncement announcement;
  final ValueChanged<String> onOpened;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 11),
    child: ExpansionTile(
      onExpansionChanged: (expanded) {
        if (expanded && !announcement.read) onOpened(announcement.id);
      },
      leading: CircleAvatar(
        backgroundColor: announcement.emergency
            ? const Color(0xFFFFF1DC)
            : const Color(0xFFEAF3EE),
        child: Icon(
          announcement.emergency
              ? Icons.priority_high_rounded
              : Icons.campaign_outlined,
          color: announcement.emergency
              ? const Color(0xFF9D5A12)
              : EstateColors.forest,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              announcement.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          if (!announcement.read)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: EstateColors.forest,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          '${announcement.category} · ${announcement.audienceLabel} · ${_date(announcement.publishedAt)}',
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(announcement.body, style: const TextStyle(height: 1.55)),
        ),
        if (announcement.emergency) ...[
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: Color(0xFF9D5A12),
                size: 17,
              ),
              SizedBox(width: 6),
              Text(
                'Important estate update',
                style: TextStyle(
                  color: Color(0xFF9D5A12),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _NoNotices extends StatelessWidget {
  const _NoNotices();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 45),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            size: 36,
            color: EstateColors.muted,
          ),
          SizedBox(height: 10),
          Text('There are no notices for your account.'),
        ],
      ),
    ),
  );
}

class _FilteredNoticesEmpty extends StatelessWidget {
  const _FilteredNoticesEmpty({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      child: Column(
        children: [
          const Icon(
            Icons.filter_alt_off_outlined,
            size: 32,
            color: EstateColors.muted,
          ),
          const SizedBox(height: 8),
          const Text('No notices match these filters.'),
          const SizedBox(height: 6),
          TextButton(onPressed: onClear, child: const Text('Clear filters')),
        ],
      ),
    ),
  );
}

String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
