import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/health_record_service.dart';
import 'package:carelanka_app/widgets/carelanka/carelanka_bottom_nav.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// CareLanka UI #35 — Health Records with document list.
class HealthRecordsScreen extends StatefulWidget {
  const HealthRecordsScreen({super.key});

  @override
  State<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends State<HealthRecordsScreen> {
  int _chip = 0;
  final _chips = ['All', 'Prescriptions', 'Lab Reports', 'Scans', 'Summary Reports'];
  DateTime? _filterFrom;
  DateTime? _filterTo;
  String _filterDoctor = '';
  String _filterDiagnosis = 'all';
  bool _filterAttachOnly = false;
  final _filterDoctorCtrl = TextEditingController();

  @override
  void dispose() {
    _filterDoctorCtrl.dispose();
    super.dispose();
  }

  void _openFilter(List<Map<String, String>> allRecords) {
    var attachOnly = _filterAttachOnly;
    final doctorCtrl = TextEditingController(text: _filterDoctor);
    var from = _filterFrom;
    var to = _filterTo;
    var diagnosis = _filterDiagnosis;

    final diagnoses = <String>{'all'};
    for (final r in allRecords) {
      final diagnosis = (r['diagnosis'] ?? '').trim();
      final condition = (r['condition'] ?? r['linkedIllness'] ?? '').trim();
      if (diagnosis.isNotEmpty) diagnoses.add(diagnosis);
      if (condition.isNotEmpty) diagnoses.add(condition);
    }

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
                            controller: TextEditingController(
                              text: from != null ? DateFormat('MMM d, yyyy').format(from!) : '',
                            ),
                            decoration: InputDecoration(
                              hintText: 'From',
                              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                                initialDate: from ?? DateTime.now(),
                              );
                              if (picked != null) setModalState(() => from = picked);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            readOnly: true,
                            controller: TextEditingController(
                              text: to != null ? DateFormat('MMM d, yyyy').format(to!) : '',
                            ),
                            decoration: InputDecoration(
                              hintText: 'To',
                              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                                initialDate: to ?? DateTime.now(),
                              );
                              if (picked != null) setModalState(() => to = picked);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('Doctor Name', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: doctorCtrl,
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
                      initialValue: diagnosis,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: diagnoses
                          .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text(d == 'all' ? 'All conditions' : d),
                              ))
                          .toList(),
                      onChanged: (v) => setModalState(() => diagnosis = v ?? 'all'),
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
                    GradientPrimaryButton(
                      label: 'Apply Filters',
                      onPressed: () {
                        setState(() {
                          _filterFrom = from;
                          _filterTo = to;
                          _filterDoctor = doctorCtrl.text.trim();
                          _filterDiagnosis = diagnosis;
                          _filterAttachOnly = attachOnly;
                          _filterDoctorCtrl.text = doctorCtrl.text.trim();
                        });
                        doctorCtrl.dispose();
                        Navigator.pop(ctx);
                      },
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filterFrom = null;
                          _filterTo = null;
                          _filterDoctor = '';
                          _filterDiagnosis = 'all';
                          _filterAttachOnly = false;
                          _filterDoctorCtrl.clear();
                        });
                        doctorCtrl.dispose();
                        Navigator.pop(ctx);
                      },
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
    var filtered = HealthRecordService().filterRecords(
      records,
      from: _filterFrom,
      to: _filterTo,
      doctorQuery: _filterDoctor,
      diagnosisQuery: _filterDiagnosis,
      attachOnly: _filterAttachOnly,
    );

    if (_chip == 0) return filtered;
    final chip = _chips[_chip].toLowerCase();
    return filtered.where((r) {
      final type = (r['documentType'] ?? r['tag'] ?? '').toLowerCase();
      if (chip.contains('prescription')) return type.contains('prescription');
      if (chip.contains('lab')) return type.contains('lab');
      if (chip.contains('scan')) return type.contains('scan') || type.contains('x-ray');
      if (chip.contains('summary')) {
        return type.contains('summary') || type.contains('annual') || type.contains('checkup');
      }
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
              IconButton(onPressed: () => _openFilter(snapshot.data ?? []), icon: const Icon(Icons.filter_list)),
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
                  for (final r in records) _recordTile(context, r, userId),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _recordTile(BuildContext context, Map<String, String> record, String userId) {
    // Use documentType first for icon logic, fall back to tag
    final docType = record['documentType'] ?? record['tag'] ?? '';
    final style = _docStyle(docType);
    final recordId = record['recordId'] ?? '';
    final title = record['title'] ?? '${record['doctor']} — ${record['shortDate']}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(recordId),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppColors.errorRed,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
        ),
        confirmDismiss: (_) => _confirmDeleteRecord(context, title),
        onDismissed: (_) => _deleteRecord(recordId),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.documentViewer, arguments: record),
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
                                title,
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
                                  (record['documentType'] ?? record['tag'] ?? 'RECORD').toUpperCase(),
                                  style: TextStyle(color: style.color, fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textGrey, size: 20),
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.pushNamed(context, AppRoutes.addRecord, arguments: record);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: AppColors.navy),
                          SizedBox(width: 10),
                          Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteRecord(BuildContext context, String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteRecord(String recordId) async {
    if (recordId.isEmpty) return;
    try {
      await HealthRecordService().deleteRecord(recordId);
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    }
  }

  _DocStyle _docStyle(String type) {
    final t = type.toLowerCase();
    if (t.contains('summary') || t.contains('annual') || t.contains('checkup')) {
      return const _DocStyle(Icons.summarize_outlined, Color(0xFFE8EAF6), Color(0xFF3949AB));
    }
    if (t.contains('lab') || t.contains('test') || t.contains('blood')) {
      return const _DocStyle(Icons.science_outlined, Color(0xFFE3F2FD), Color(0xFF1565C0));
    }
    if (t.contains('scan') || t.contains('mri') || t.contains('ct') || t.contains('x-ray') || t.contains('xray')) {
      return const _DocStyle(Icons.crop_free, Color(0xFFF3E5F5), Color(0xFF7B1FA2));
    }
    if (t.contains('prescription') || t.contains('rx')) {
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
