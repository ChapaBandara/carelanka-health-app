import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/utils/active_uid.dart';
import 'package:carelanka_app/providers/family_provider.dart';
import 'package:carelanka_app/services/reminder_service.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// CareLanka UI #27–#33 — Reminder History with status-specific tab layouts.
class ReminderHistoryScreen extends StatefulWidget {
  const ReminderHistoryScreen({super.key});

  @override
  State<ReminderHistoryScreen> createState() => _ReminderHistoryScreenState();
}

class _ReminderHistoryScreenState extends State<ReminderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);
  bool _searchOpen = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
    });
    // FIX 2: Auto-log missed doses when the history screen opens.
    _autoLogMissedDoses();
  }

  /// Auto-logs any missed doses for the current user when the screen opens.
  Future<void> _autoLogMissedDoses() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return;
      await ReminderService().checkMissedReminders(uid);
    } catch (_) {
      // Silent — never surface to user.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tab.dispose();
    super.dispose();
  }

  /// Converts a Firestore doc snapshot to a display map.
  Map<String, dynamic> _docToDisplay(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final scheduledRaw = d['scheduledTime'];
    final actualRaw = d['actualResponseTime'];
    final DateTime? scheduledAt =
        scheduledRaw is Timestamp ? scheduledRaw.toDate() : null;
    final DateTime? actualAt =
        actualRaw is Timestamp ? actualRaw.toDate() : null;

    var status = (d['status'] as String? ?? 'confirmed').toLowerCase();
    if (status == 'taken') status = 'confirmed';

    return {
      'logId': doc.id,
      'medicationId': d['medicationId'] as String? ?? '',
      'medicationName': d['medicationName'] as String? ??
          d['name'] as String? ??
          'Medication',
      'medicationDosage': d['medicationDosage'] as String? ??
          d['dosage'] as String? ??
          '',
      'condition': d['condition'] as String? ?? '',
      'scheduledAt': scheduledAt,
      'actualAt': actualAt,
      'status': status,
      'responseLatencyMinutes': d['responseLatencyMinutes'] as int? ?? 0,
      'snoozeUntil': d['snoozeUntil'] is Timestamp
          ? (d['snoozeUntil'] as Timestamp).toDate()
          : null,
    };
  }

  bool _matchesSearch(Map<String, dynamic> item) {
    if (_searchQuery.isEmpty) return true;
    final name = (item['medicationName'] as String).toLowerCase();
    final condition = (item['condition'] as String).toLowerCase();
    return name.contains(_searchQuery) || condition.contains(_searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, _, _) {
        final userId = context.activeUid;
        final service = ReminderService();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: _searchOpen
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => _searchOpen = false);
                      _searchController.clear();
                    },
                  )
                : IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.maybePop(context),
                  ),
            title: _searchOpen
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search reminders...',
                      border: InputBorder.none,
                    ),
                  )
                : const Text('Reminder History'),
            centerTitle: !_searchOpen,
            actions: [
              if (!_searchOpen)
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() => _searchOpen = true),
                ),
            ],
            bottom: TabBar(
              controller: _tab,
              labelColor: AppColors.navy,
              unselectedLabelColor: AppColors.textGrey,
              indicatorColor: AppColors.navy,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
              // ── ALL TAB ───────────────────────────────────────────────────
              _FirestoreLogTab(
                stream: service.watchAllReminderLogs(userId),
                docToDisplay: _docToDisplay,
                matchesSearch: _matchesSearch,
                filterStatus: null,
                emptyIcon: Icons.history,
                emptyTitle: 'No reminder history yet',
                emptySubtitle:
                    'When you take, miss, or snooze doses, they will appear here.',
              ),
              // ── CONFIRMED TAB ─────────────────────────────────────────────
              _FirestoreLogTab(
                stream: service.watchReminderLogsByStatus(userId, 'confirmed'),
                docToDisplay: _docToDisplay,
                matchesSearch: _matchesSearch,
                filterStatus: 'confirmed',
                emptyIcon: Icons.check_circle_outline,
                emptyTitle: 'No confirmed doses yet',
                emptySubtitle:
                    'Confirmed doses will appear here after you mark them as taken.',
              ),
              // ── MISSED TAB ────────────────────────────────────────────────
              _FirestoreLogTab(
                stream: service.watchReminderLogsByStatus(userId, 'missed'),
                docToDisplay: _docToDisplay,
                matchesSearch: _matchesSearch,
                filterStatus: 'missed',
                emptyIcon: Icons.check_circle_outline,
                emptyTitle: 'No missed doses yet',
                emptySubtitle: 'You are on track! No missed medications found.',
              ),
              // ── SNOOZED TAB ───────────────────────────────────────────────
              _FirestoreLogTab(
                stream: service.watchReminderLogsByStatus(userId, 'snoozed'),
                docToDisplay: _docToDisplay,
                matchesSearch: _matchesSearch,
                filterStatus: 'snoozed',
                emptyIcon: Icons.schedule,
                emptyTitle: 'No snoozed doses yet',
                emptySubtitle:
                    'Snoozed medications will appear here until you take them.',
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic Firestore-backed tab widget
// ─────────────────────────────────────────────────────────────────────────────

class _FirestoreLogTab extends StatelessWidget {
  const _FirestoreLogTab({
    required this.stream,
    required this.docToDisplay,
    required this.matchesSearch,
    required this.filterStatus,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final Map<String, dynamic> Function(QueryDocumentSnapshot<Map<String, dynamic>>) docToDisplay;
  final bool Function(Map<String, dynamic>) matchesSearch;
  final String? filterStatus;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load history.',
              style: TextStyle(color: AppColors.textGrey),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final items = docs
            .map(docToDisplay)
            .where(matchesSearch)
            .toList();

        if (items.isEmpty) {
          return EmptyListPlaceholder(
            icon: emptyIcon,
            title: emptyTitle,
            subtitle: emptySubtitle,
          );
        }

        return _GroupedLogList(items: items);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grouped list by date
// ─────────────────────────────────────────────────────────────────────────────

class _GroupedLogList extends StatelessWidget {
  const _GroupedLogList({required this.items});

  final List<Map<String, dynamic>> items;

  String _dateGroupFor(DateTime scheduledAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yday = today.subtract(const Duration(days: 1));
    final day =
        DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);

    if (day == today) return 'Today';
    if (day == yday) return 'Yesterday';
    return DateFormat.yMMMMd().format(day);
  }

  @override
  Widget build(BuildContext context) {
    // Build ordered groups (preserves Firestore descending order).
    final groups = <String, List<Map<String, dynamic>>>{};
    final groupOrder = <String>[];

    for (final item in items) {
      final scheduled = item['scheduledAt'] as DateTime?;
      final group = scheduled != null ? _dateGroupFor(scheduled) : 'Earlier';
      if (!groups.containsKey(group)) {
        groups[group] = [];
        groupOrder.add(group);
      }
      groups[group]!.add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: groupOrder.length,
      itemBuilder: (context, index) {
        final groupTitle = groupOrder[index];
        final groupItems = groups[groupTitle]!;
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
            ...groupItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReminderLogCard(data: item),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reminder log card — shown in ALL tabs
// ─────────────────────────────────────────────────────────────────────────────

class _ReminderLogCard extends StatelessWidget {
  const _ReminderLogCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'confirmed';
    final style = _statusStyle(status);
    final medicationName = data['medicationName'] as String? ?? 'Medication';
    final medicationDosage = data['medicationDosage'] as String? ?? '';
    final scheduledAt = data['scheduledAt'] as DateTime?;
    final actualAt = data['actualAt'] as DateTime?;
    final latency = data['responseLatencyMinutes'] as int? ?? 0;

    final scheduledLabel =
        scheduledAt != null ? DateFormat.jm().format(scheduledAt) : '—';
    final actualLabel =
        actualAt != null ? DateFormat.jm().format(actualAt) : null;

    final badge = _badgeText(status, latency, actualLabel);

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
          // ── Left status circle ─────────────────────────────────────────
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: style.iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(style.icon, color: style.iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          // ── Center: name + times ───────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicationName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                if (medicationDosage.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    medicationDosage,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Scheduled: $scheduledLabel',
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 12,
                  ),
                ),
                if (actualLabel != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    'Response: $actualLabel',
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ── Right badge ────────────────────────────────────────────────
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
    );
  }

  String _badgeText(String status, int latency, String? actualLabel) {
    switch (status) {
      case 'missed':
        return 'No response';
      case 'snoozed':
        return 'Snoozed';
      case 'skipped':
        return 'Skipped';
      case 'pending':
        return 'Pending';
      case 'confirmed':
        if (latency > 0) return '+$latency min';
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
      case 'skipped':
        return const _StatusStyle(
          icon: Icons.fast_forward_rounded,
          iconBg: Color(0xFFEEEEEE),
          iconColor: Color(0xFF757575),
          badgeBg: Color(0xFFEEEEEE),
          badgeText: Color(0xFF757575),
        );
      case 'pending':
        return const _StatusStyle(
          icon: Icons.schedule,
          iconBg: Color(0xFFE3F2FD),
          iconColor: Color(0xFF1565C0),
          badgeBg: Color(0xFFE3F2FD),
          badgeText: Color(0xFF1565C0),
        );
      default: // confirmed
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

// ─────────────────────────────────────────────────────────────────────────────
// Status style data class
// ─────────────────────────────────────────────────────────────────────────────

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
