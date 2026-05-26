import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/services/health_record_service.dart';
import 'package:carelanka_app/widgets/carelanka/carelanka_bottom_nav.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
                          onChanged: (v) => setModalState(() => attachOnly = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    GradientPrimaryButton(label: 'Apply Filters', onPressed: () => Navigator.pop(ctx)),
                    TextButton(onPressed: () {}, child: const Text('Clear Filters', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700))),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<List<Map<String, String>>>(
      stream: HealthRecordService().watchRecordMaps(userId),
      builder: (context, snapshot) {
        final records = snapshot.data ?? [];
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
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          IconButton(onPressed: _openFilter, icon: const Icon(Icons.filter_list)),
        ],
      ),
      bottomNavigationBar: const CareLankaBottomNav(currentIndex: 0),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.addRecord),
        backgroundColor: AppColors.navy,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!hasRecords)
              const EmptyListPlaceholder(
                icon: Icons.folder_open_outlined,
                title: 'No health records yet',
                subtitle: 'Upload prescriptions, lab reports, and scans to keep everything in one place.',
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('My Documents', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  TextButton(onPressed: () {}, child: const Text('View All', style: TextStyle(fontWeight: FontWeight.w600))),
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
                      labelStyle: TextStyle(color: sel ? Colors.white : AppColors.textGrey, fontWeight: FontWeight.w600, fontSize: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: sel ? AppColors.navy : const Color(0xFFDEE2E6))),
                      backgroundColor: Colors.white,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              for (final r in records)
                _recordTile(
                  r['date'] ?? '',
                  r['doctor'] ?? '',
                  r['place'] ?? '',
                  r['tag'] ?? '',
                ),
            ],
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _recordTile(String date, String doctor, String place, String tag) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        title: Text('$date — $doctor', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(place, style: const TextStyle(color: AppColors.textGrey)),
              const SizedBox(height: 6),
              Chip(label: Text(tag, style: const TextStyle(fontSize: 11)), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
            ],
          ),
        ),
        trailing: TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.documentViewer), child: const Text('View')),
      ),
    );
  }
}
