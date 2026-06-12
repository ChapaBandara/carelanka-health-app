import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:carelanka_app/services/health_record_service.dart';
import 'package:carelanka_app/widgets/carelanka/carelanka_bottom_nav.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// CareLanka UI #35 — Health Records with checkup banner and document list.
class HealthRecordsScreen extends StatefulWidget {
  const HealthRecordsScreen({super.key});

  @override
  State<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends State<HealthRecordsScreen> {
  int _chip = 0;
  final _chips = ['All', 'Prescriptions', 'Lab Reports', 'Scans'];

  void _openFilter() {
    var attachOnly = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, scroll) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filter Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Date Range', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            readOnly: true,
                            decoration: InputDecoration(
                              hintText: 'From',
                              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            readOnly: true,
                            decoration: InputDecoration(
                              hintText: 'To',
                              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('Doctor Name', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search doctor...',
                        prefixIcon: const Icon(Icons.search, size: 22),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Diagnosis / Condition', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: 'all',
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All conditions')),
                        DropdownMenuItem(value: 'dm', child: Text('Diabetes')),
                      ],
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Has attached document', style: TextStyle(fontWeight: FontWeight.w700)),
                        Switch(
                          value: attachOnly,
                          activeThumbColor: AppColors.primaryTeal,
                          onChanged: (v) => setModalState(() => attachOnly = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    GradientPrimaryButton(label: 'Apply Filters', onPressed: () => Navigator.pop(ctx)),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Clear Filters', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Map<String, String>> _filterRecords(List<Map<String, String>> records) {
    if (_chip == 0) return records;
    final chip = _chips[_chip].toLowerCase();
    return records.where((r) {
      final type = (r['documentType'] ?? r['tag'] ?? '').toLowerCase();
      if (chip.contains('prescription')) return type.contains('prescription');
      if (chip.contains('lab')) return type.contains('lab');
      if (chip.contains('scan')) return type.contains('scan') || type.contains('x-ray');
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<List<Map<String, String>>>(
      stream: HealthRecordService().watchRecordMaps(userId),
      builder: (context, snapshot) {
        final records = _filterRecords(snapshot.data ?? []);
        final hasRecords = records.isNotEmpty;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: const Text('Health Records'),
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.healthRecordSearch),
                icon: const Icon(Icons.search),
              ),
              IconButton(onPressed: _openFilter, icon: const Icon(Icons.filter_list)),
            ],
          ),
          bottomNavigationBar: const CareLankaBottomNav(currentIndex: 0),
          floatingActionButton: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: CareLankaGradients.fab),
            child: FloatingActionButton(
              elevation: 0,
              backgroundColor: Colors.transparent,
              onPressed: () => Navigator.pushNamed(context, AppRoutes.addRecord),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.oliveBannerBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.oliveBanner.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.oliveBanner, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "You haven't had a checkup in 180 days",
                          style: TextStyle(color: AppColors.oliveBanner, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.addAppointment),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.oliveBanner,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('Schedule Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('My Documents', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.documentsLibrary),
                      child: const Text('View All', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _chips.length,
                    separatorBuilder: (_, index) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final sel = _chip == i;
                      return FilterChip(
                        label: Text(_chips[i]),
                        selected: sel,
                        onSelected: (_) => setState(() => _chip = i),
                        selectedColor: AppColors.navy,
                        labelStyle: TextStyle(
                          color: sel ? Colors.white : AppColors.textGrey,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(color: sel ? AppColors.navy : const Color(0xFFDEE2E6)),
                        ),
                        backgroundColor: Colors.white,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (!hasRecords)
                  const EmptyListPlaceholder(
                    icon: Icons.folder_open_outlined,
                    title: 'No health records yet',
                    subtitle: 'Upload prescriptions, lab reports, and scans to keep everything in one place.',
                  )
                else
                  for (final r in records) _recordTile(context, r),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _recordTile(BuildContext context, Map<String, String> record) {
    final style = _docStyle(record['documentType'] ?? record['tag'] ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pushNamed(context, AppRoutes.documentViewer, arguments: record),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(style.icon, color: style.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record['title'] ?? '${record['doctor']} — ${record['shortDate']}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${record['doctor']} • ${record['monthDay'] ?? record['date']}',
                        style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: style.bg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (record['tag'] ?? 'RECORD').toUpperCase(),
                          style: TextStyle(color: style.color, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_vert, color: AppColors.textGrey, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _DocStyle _docStyle(String type) {
    final t = type.toLowerCase();
    if (t.contains('lab')) {
      return const _DocStyle(Icons.science_outlined, Color(0xFFE3F2FD), Color(0xFF1565C0));
    }
    if (t.contains('scan') || t.contains('x-ray')) {
      return const _DocStyle(Icons.crop_free, Color(0xFFF3E5F5), Color(0xFF7B1FA2));
    }
    if (t.contains('prescription')) {
      return const _DocStyle(Icons.medication_outlined, Color(0xFFE0F7F7), AppColors.primaryTeal);
    }
    return const _DocStyle(Icons.description_outlined, Color(0xFFE8F5E9), Color(0xFF388E3C));
  }
}

class _DocStyle {
  const _DocStyle(this.icon, this.bg, this.color);
  final IconData icon;
  final Color bg;
  final Color color;
}
