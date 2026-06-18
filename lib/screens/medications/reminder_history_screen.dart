import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/models/daily_dose_item.dart';
import 'package:carelanka_app/services/reminder_service.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// CareLanka UI #27–#33 — Reminder History with status-specific tab layouts.
class ReminderHistoryScreen extends StatefulWidget {
  const ReminderHistoryScreen({super.key});

  @override
  State<ReminderHistoryScreen> createState() => _ReminderHistoryScreenState();
}

class _ReminderHistoryScreenState extends State<ReminderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);
  late final Stream<List<Map<String, dynamic>>> _doseHistoryStream;
  bool _searchOpen = false;
  List<Map<String, dynamic>> _allLogs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  List<Map<String, dynamic>>? _lastStreamSnapshot;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
    _doseHistoryStream = ReminderService().watchAllDoseHistory(
      FirebaseAuth.instance.currentUser!.uid,
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _tab.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredLogs = _allLogs;
      } else {
        _filteredLogs = _allLogs.where((log) {
          final name = (log['medicationName'] ?? '').toString().toLowerCase();
          final condition = (log['condition'] ?? '').toString().toLowerCase();
          final status = (log['status'] ?? '').toString().toLowerCase();
          return name.contains(query) ||
              condition.contains(query) ||
              status.contains(query);
        }).toList();
      }
    });
  }

  DateTime? _scheduledAt(Map<String, dynamic> entry) {
    final scheduled = entry['scheduledTime'];
    if (scheduled is DateTime) return scheduled;
    return null;
  }

  String _dateGroupFor(DateTime scheduledAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yday = today.subtract(const Duration(days: 1));
    final day = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);

    if (day == today) {
      return 'Today';
    } else if (day == yday) {
      return 'Yesterday';
    } else {
      return DateFormat.yMMMMd().format(day);
    }
  }

  Map<String, String> _entryToUiMap(Map<String, dynamic> data) {
    final scheduledAt = _scheduledAt(data);
    final action = data['actualResponseTime'];
    final status = (data['status'] as String? ?? 'confirmed').toLowerCase();
    final latency = (data['responseLatencyMinutes'] as int?) ?? 0;

    String actionTime = '—';
    if (action is DateTime) {
      actionTime = DateFormat.jm().format(action);
    }

    return {
      'medication': data['medicationName']?.toString() ?? '',
      'condition': data['condition']?.toString() ?? '',
      'scheduled': scheduledAt != null ? DateFormat.jm().format(scheduledAt) : '—',
      'actionTime': actionTime,
      'status': status,
      'dateGroup': scheduledAt != null ? _dateGroupFor(scheduledAt) : 'Earlier',
      'timing': latency > 0 ? 'late' : 'on_time',
      'lateBy': latency > 0 ? '+$latency min' : 'On time',
    };
  }

  DailyDoseItem _entryToDailyDose(Map<String, dynamic> data) {
    final scheduledAt = _scheduledAt(data) ?? DateTime.now();
    final status = (data['status'] as String? ?? 'pending').toLowerCase();
    final actual = data['actualResponseTime'];
    String? actionLabel;
    if (actual is DateTime) {
      actionLabel = DateFormat.jm().format(actual);
    }

    DateTime? snoozeUntil;
    final snooze = data['snoozeUntil'];
    if (snooze is DateTime) {
      snoozeUntil = snooze;
    }

    return DailyDoseItem(
      medicationId: data['medicationId']?.toString() ?? '',
      medicationName: data['medicationName']?.toString() ?? 'Medication',
      dosage: data['dosage']?.toString() ?? '',
      condition: data['condition']?.toString() ?? '',
      scheduledLabel: data['scheduledLabel']?.toString() ?? DateFormat.jm().format(scheduledAt),
      scheduledAt: scheduledAt,
      status: status == 'pending' && scheduledAt.isAfter(DateTime.now()) ? 'upcoming' : status,
      actionLabel: actionLabel,
      mealTiming: data['mealTiming']?.toString() ?? '',
      latencyMinutes: data['responseLatencyMinutes'] as int?,
      logId: data['logId']?.toString(),
      snoozeUntil: snoozeUntil,
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _doseHistoryStream,
      builder: (context, snapshot) {
        if (snapshot.hasData && !identical(snapshot.data, _lastStreamSnapshot)) {
          _lastStreamSnapshot = snapshot.data;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _allLogs = snapshot.data!;
            _applyFilter();
          });
        }

        final reminders = _filteredLogs.map(_entryToUiMap).toList();
        final todayDoses = _filteredLogs
            .where((e) {
              final scheduledAt = _scheduledAt(e);
              return scheduledAt != null && _isToday(scheduledAt);
            })
            .map(_entryToDailyDose)
            .toList();

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
                  _AllTab(reminders: reminders),
                  _ConfirmedTab(doses: todayDoses),
                  _MissedTab(doses: todayDoses.where((d) => d.status == 'missed').toList()),
                  _SnoozedTab(doses: todayDoses.where((d) => d.status == 'snoozed').toList()),
                ],
              ),
            );
      },
    );
  }
}

class _AllTab extends StatelessWidget {
  const _AllTab({required this.reminders});

  final List<Map<String, String>> reminders;

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) {
      return const EmptyListPlaceholder(
        icon: Icons.history,
        title: 'No reminder history yet',
        subtitle: 'When you take, miss, or snooze doses, they will appear here.',
      );
    }

    final groups = <String, List<Map<String, String>>>{};
    for (final r in reminders) {
      groups.putIfAbsent(r['dateGroup'] ?? 'Earlier', () => []).add(r);
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
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textGrey),
              ),
            ),
            ...items.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HistoryCard(data: r),
                )),
          ],
        );
      },
    );
  }
}

/// CareLanka UI #29 — Confirmed daily medication list tab.
class _ConfirmedTab extends StatelessWidget {
  const _ConfirmedTab({required this.doses});

  final List<DailyDoseItem> doses;

  @override
  Widget build(BuildContext context) {
    final confirmed = doses.where((d) => d.status == 'confirmed').toList();
    final upcoming = doses.where((d) => d.status == 'upcoming').toList();
    final total = doses.length;
    final taken = confirmed.length;

    if (total == 0) {
      return const EmptyListPlaceholder(
        icon: Icons.check_circle_outline,
        title: 'No doses scheduled today',
        subtitle: 'Add medications to track your daily schedule.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F7F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryTeal, width: 3),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$taken/$total',
                  style: const TextStyle(
                    color: AppColors.primaryTeal,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Great progress!',
                      style: TextStyle(
                        color: AppColors.primaryTeal,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You have taken $taken out of $total scheduled doses today.',
                      style: const TextStyle(color: AppColors.textGrey, fontSize: 13, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (confirmed.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionHeader('CONFIRMED'),
          const SizedBox(height: 10),
          ...confirmed.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DoseStatusCard(
                  dose: d,
                  accent: AppColors.primaryTeal,
                  icon: Icons.check,
                  iconBg: const Color(0xFFE0F7F7),
                  statusLabel: 'Taken at ${d.actionLabel ?? DateFormat.jm().format(d.scheduledAt)}',
                  statusColor: AppColors.primaryTeal,
                ),
              )),
        ],
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionHeader('UPCOMING'),
          const SizedBox(height: 10),
          ...upcoming.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DoseStatusCard(
                  dose: d,
                  accent: const Color(0xFFFFF9C4),
                  icon: Icons.schedule,
                  iconBg: const Color(0xFFFFF9C4),
                  statusLabel: 'Scheduled for ${d.scheduledLabel}',
                  statusColor: const Color(0xFF8D6E63),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.takingMedication, arguments: d),
                ),
              )),
        ],
      ],
    );
  }
}

/// CareLanka UI #31 — Missed daily medication list tab.
class _MissedTab extends StatelessWidget {
  const _MissedTab({required this.doses});

  final List<DailyDoseItem> doses;

  @override
  Widget build(BuildContext context) {
    if (doses.isEmpty) {
      return const EmptyListPlaceholder(
        icon: Icons.check_circle_outline,
        title: 'No missed doses today',
        subtitle: 'You are on track with your medication schedule.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Action Required',
                      style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You have ${doses.length} missed medication${doses.length == 1 ? '' : 's'} today. Please take them as soon as possible or mark them as skipped.',
                      style: TextStyle(color: AppColors.errorRed.withValues(alpha: 0.85), fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _SectionHeader('MISSED TODAY'),
        const SizedBox(height: 10),
        ...doses.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ActionDoseCard(dose: d, accent: AppColors.errorRed),
            )),
      ],
    );
  }
}

/// CareLanka UI #33 — Snoozed daily medication list tab.
class _SnoozedTab extends StatelessWidget {
  const _SnoozedTab({required this.doses});

  final List<DailyDoseItem> doses;

  @override
  Widget build(BuildContext context) {
    if (doses.isEmpty) {
      return const EmptyListPlaceholder(
        icon: Icons.schedule,
        title: 'No snoozed reminders',
        subtitle: 'Snoozed medications will appear here until you take them.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9C4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.schedule, color: Color(0xFF8D6E63), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Snoozed Reminders',
                      style: TextStyle(color: Color(0xFF8D6E63), fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You have ${doses.length} medication${doses.length == 1 ? '' : 's'} currently snoozed. We will remind you again when the time comes.',
                      style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _SectionHeader('CURRENTLY SNOOZED'),
        const SizedBox(height: 10),
        ...doses.map((d) {
          final remindAt = d.snoozeUntil != null ? DateFormat.jm().format(d.snoozeUntil!) : d.scheduledLabel;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ActionDoseCard(
              dose: d,
              accent: const Color(0xFF8D6E63),
              statusLabel: 'Reminding again at $remindAt',
            ),
          );
        }),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 13,
        color: AppColors.navy,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _DoseStatusCard extends StatelessWidget {
  const _DoseStatusCard({
    required this.dose,
    required this.accent,
    required this.icon,
    required this.iconBg,
    required this.statusLabel,
    required this.statusColor,
    this.onTap,
  });

  final DailyDoseItem dose;
  final Color accent;
  final IconData icon;
  final Color iconBg;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                          child: Icon(icon, color: statusColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dose.medicationName,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy),
                              ),
                              if (dose.dosage.isNotEmpty)
                                Text(dose.dosage, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                              const SizedBox(height: 6),
                              Text(
                                statusLabel,
                                style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
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
      ),
    );
  }
}

class _ActionDoseCard extends StatelessWidget {
  const _ActionDoseCard({
    required this.dose,
    required this.accent,
    this.statusLabel,
  });

  final DailyDoseItem dose;
  final Color accent;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final label = statusLabel ?? 'Missed at ${dose.scheduledLabel}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(color: Color(0xFFFFEBEE), shape: BoxShape.circle),
                          child: Icon(Icons.schedule, color: accent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dose.medicationName,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy),
                              ),
                              if (dose.dosage.isNotEmpty)
                                Text(dose.dosage, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(label, style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pushNamed(context, AppRoutes.takingMedication, arguments: dose),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryTeal,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Take Now', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              await ReminderService().logDose(
                                userId: userId,
                                medicationId: dose.medicationId,
                                medicationName: dose.medicationName,
                                condition: dose.condition,
                                scheduledTime: dose.scheduledAt,
                                status: 'missed',
                                existingLogId: dose.logId,
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF42A5F5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Skip Dose', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.data});

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
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
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
                        style: TextStyle(color: style.badgeText, fontWeight: FontWeight.w700, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                if ((data['condition'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    data['condition']!,
                    style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.textGrey, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 8),
                Text('Scheduled: ${data['scheduled'] ?? '—'}', style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                const SizedBox(height: 2),
                Text(_actionLine(status, data), style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
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
      case 'skipped':
        return 'Skipped at: ${data['actionTime'] ?? '—'}';
      case 'pending':
        return 'Awaiting response';
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
      case 'skipped':
        return 'Skipped';
      case 'pending':
        return 'Pending';
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
