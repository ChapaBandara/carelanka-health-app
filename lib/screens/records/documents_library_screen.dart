import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/core/utils/active_uid.dart';
import 'package:carelanka_app/providers/family_provider.dart';
import 'package:carelanka_app/services/health_record_service.dart';
import 'package:carelanka_app/widgets/carelanka/carelanka_bottom_nav.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// CareLanka UI #34 — Documents Library with search and category filters.
class DocumentsLibraryScreen extends StatefulWidget {
  const DocumentsLibraryScreen({super.key});

  @override
  State<DocumentsLibraryScreen> createState() => _DocumentsLibraryScreenState();
}

class _DocumentsLibraryScreenState extends State<DocumentsLibraryScreen> {
  int _chip = 0;
  final _chips = ['All', 'Prescriptions', 'Lab Reports', 'Scans', 'Summary Reports'];
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map<String, String>> _filter(List<Map<String, String>> records) {
    var list = HealthRecordService().searchRecords(records, _search.text);
    if (_chip == 0) return list;
    final chip = _chips[_chip].toLowerCase();
    return list.where((r) {
      final type = (r['documentType'] ?? '').toLowerCase();
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
    return Consumer<FamilyProvider>(
      builder: (context, _, _) {
        final userId = context.activeUid;

    return StreamBuilder<List<Map<String, String>>>(
      stream: HealthRecordService().watchRecordMaps(userId),
      builder: (context, snapshot) {
        final records = _filter(snapshot.data ?? []);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: const Text('My Documents'),
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.healthRecordSearch),
                icon: const Icon(Icons.search),
              ),
              IconButton(onPressed: () {}, icon: const Icon(Icons.grid_view_rounded)),
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
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search prescriptions, lab reports...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFDEE2E6)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Newest first', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (records.isEmpty)
                  const EmptyListPlaceholder(
                    icon: Icons.folder_open_outlined,
                    title: 'No documents found',
                    subtitle: 'Try a different search or add a new health record.',
                  )
                else
                  for (final r in records) _docCard(context, r),
              ],
            ),
          ),
        );
      },
    );
      },
    );
  }

  Widget _docCard(BuildContext context, Map<String, String> record) {
    final type = record['documentType'] ?? record['tag'] ?? '';
    final style = _styleFor(type);
    final recordId = record['recordId'] ?? '';
    final title = record['title'] ?? record['doctor'] ?? 'Document';

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
        confirmDismiss: (_) => _confirmDelete(context, title),
        onDismissed: (_) => _deleteRecord(recordId),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          elevation: 0.5,
          shadowColor: Colors.black12,
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
                          child: Icon(style.icon, color: style.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(
                                '${record['doctor']} • ${record['monthDay'] ?? record['date']}',
                                style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(12)),
                                child: Text(
                                  type.toUpperCase(),
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

  Future<bool> _confirmDelete(BuildContext context, String title) async {
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

  ({IconData icon, Color bg, Color color}) _styleFor(String type) {
    final t = type.toLowerCase();
    if (t.contains('summary') || t.contains('annual') || t.contains('checkup')) {
      return (icon: Icons.summarize_outlined, bg: const Color(0xFFE8EAF6), color: const Color(0xFF3949AB));
    }
    if (t.contains('lab')) return (icon: Icons.science_outlined, bg: const Color(0xFFE3F2FD), color: const Color(0xFF1565C0));
    if (t.contains('scan') || t.contains('x-ray')) {
      return (icon: Icons.crop_free, bg: const Color(0xFFF3E5F5), color: const Color(0xFF7B1FA2));
    }
    if (t.contains('prescription')) {
      return (icon: Icons.medication_outlined, bg: const Color(0xFFE0F7F7), color: AppColors.primaryTeal);
    }
    return (icon: Icons.description_outlined, bg: const Color(0xFFE8F5E9), color: const Color(0xFF388E3C));
  }
}
