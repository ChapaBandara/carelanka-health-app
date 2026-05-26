import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/services/reminder_service.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// CareLanka UI #27 — Reminder History with All / Confirmed / Missed / Snoozed tabs.
class ReminderHistoryScreen extends StatefulWidget {
  const ReminderHistoryScreen({super.key});

  @override
  State<ReminderHistoryScreen> createState() => _ReminderHistoryScreenState();
}

class _ReminderHistoryScreenState extends State<ReminderHistoryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<List<Map<String, String>>>(
      stream: ReminderService().watchReminderMaps(userId),
      builder: (context, snapshot) {
        final reminders = snapshot.data ?? [];

        return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Reminder History'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.navy,
          unselectedLabelColor: AppColors.textGrey,
          indicatorColor: AppColors.navy,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Confirmed'),
            Tab(text: 'Missed'),
            Tab(text: 'Snoozed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ReminderList(reminders: reminders, filter: null),
          _ReminderList(reminders: reminders, filter: 'confirmed'),
          _ReminderList(reminders: reminders, filter: 'missed'),
          _ReminderList(reminders: reminders, filter: 'snoozed'),
        ],
      ),
    );
      },
    );
  }
}

class _ReminderList extends StatelessWidget {
  const _ReminderList({required this.reminders, required this.filter});

  final List<Map<String, String>> reminders;
  final String? filter;

  @override
  Widget build(BuildContext context) {
    final filtered = filter == null
        ? reminders
        : reminders.where((r) => r['status'] == filter).toList();

    if (filtered.isEmpty) {
      return const EmptyListPlaceholder(
        icon: Icons.history,
        title: 'No reminder history yet',
        subtitle: 'When you take, miss, or snooze doses, they will appear here.',
      );
    }

    final groups = <String, List<Map<String, String>>>{};
    for (final r in filtered) {
      final key = r['dateGroup'] ?? 'Earlier';
      groups.putIfAbsent(key, () => []).add(r);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final groupTitle = groups.keys.elementAt(index);
        final items = groups[groupTitle]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: Text(
                groupTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textGrey,
                ),
              ),
            ),
            ...items.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReminderCard(data: r),
                )),
          ],
        );
      },
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.data});

  final Map<String, String> data;

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'confirmed';
    final style = _statusStyle(status);
    final badge = _badgeText(status, data);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: style.iconBg, shape: BoxShape.circle),
            child: Icon(style.icon, color: style.iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        data['medication'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: style.badgeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: style.badgeText,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((data['condition'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    data['condition']!,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: AppColors.textGrey,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Scheduled: ${data['scheduled'] ?? '—'}',
                  style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  _actionLine(status, data),
                  style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _actionLine(String status, Map<String, String> data) {
    switch (status) {
      case 'missed':
        return 'No response recorded';
      case 'snoozed':
        return 'Snoozed at: ${data['actionTime'] ?? '—'}';
      default:
        return 'Taken: ${data['actionTime'] ?? '—'}';
    }
  }

  String _badgeText(String status, Map<String, String> data) {
    switch (status) {
      case 'missed':
        return 'No response';
      case 'snoozed':
        return 'Snoozed';
      case 'confirmed':
        final timing = data['timing'];
        if (timing == 'on_time') return 'On time';
        if (timing == 'late') return data['lateBy'] ?? '+10 min';
        return 'On time';
      default:
        return '';
    }
  }

  _StatusStyle _statusStyle(String status) {
    switch (status) {
      case 'missed':
        return const _StatusStyle(
          icon: Icons.close,
          iconBg: Color(0xFFFFEBEE),
          iconColor: AppColors.errorRed,
          badgeBg: Color(0xFFFFEBEE),
          badgeText: AppColors.errorRed,
        );
      case 'snoozed':
        return const _StatusStyle(
          icon: Icons.schedule,
          iconBg: Color(0xFFFFF9C4),
          iconColor: Color(0xFF8D6E63),
          badgeBg: Color(0xFFFFF9C4),
          badgeText: Color(0xFF8D6E63),
        );
      default:
        return const _StatusStyle(
          icon: Icons.check,
          iconBg: Color(0xFFE0F2F1),
          iconColor: Color(0xFF00897B),
          badgeBg: Color(0xFFE0F2F1),
          badgeText: Color(0xFF00897B),
        );
    }
  }
}

class _StatusStyle {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color badgeBg;
  final Color badgeText;

  const _StatusStyle({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.badgeBg,
    required this.badgeText,
  });
}
