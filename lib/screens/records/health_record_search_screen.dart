import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// CareLanka UI #36 — Health Record Search with highlighted matches.
class HealthRecordSearchScreen extends StatefulWidget {
  const HealthRecordSearchScreen({super.key});

  @override
  State<HealthRecordSearchScreen> createState() => _HealthRecordSearchScreenState();
}

class _HealthRecordSearchScreenState extends State<HealthRecordSearchScreen> {
  final _search = TextEditingController();
  int _chip = 0;
  final _chips = ['All', 'Prescriptions', 'Lab Reports', 'Doctors'];
  late final Future<List<Map<String, String>>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = _fetchRecords();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Map<String, String>>> _fetchRecords() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await FirebaseFirestore.instance.collection('health_records').where('userId', isEqualTo: userId).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final visitDate = (data['visitDate'] as Timestamp?)?.toDate();
      return <String, String>{
        'recordId': doc.id,
        'doctor': data['doctorName']?.toString() ?? '',
        'hospital': data['hospital']?.toString() ?? '',
        'diagnosis': data['diagnosis']?.toString() ?? '',
        'notes': data['notes']?.toString() ?? '',
        'documentType': data['documentType']?.toString() ?? '',
        'title': data['diagnosis']?.toString() ?? data['doctorName']?.toString() ?? 'Record',
        'date': visitDate != null ? '${visitDate.day}/${visitDate.month}/${visitDate.year}' : '',
      };
    }).toList();
  }

  List<Map<String, String>> _filter(List<Map<String, String>> records) {
    final q = _search.text.trim().toLowerCase();
    var list = q.isEmpty
        ? records
        : records.where((r) {
            final doctor = (r['doctor'] ?? '').toLowerCase();
            final hospital = (r['hospital'] ?? '').toLowerCase();
            final diagnosis = (r['diagnosis'] ?? '').toLowerCase();
            final notes = (r['notes'] ?? '').toLowerCase();
            final documentType = (r['documentType'] ?? '').toLowerCase();
            return doctor.contains(q) ||
                hospital.contains(q) ||
                diagnosis.contains(q) ||
                notes.contains(q) ||
                documentType.contains(q);
          }).toList();

    if (_chip == 0) return list;
    final chip = _chips[_chip].toLowerCase();
    return list.where((r) {
      final type = (r['documentType'] ?? '').toLowerCase();
      if (chip.contains('prescription')) return type.contains('prescription');
      if (chip.contains('lab')) return type.contains('lab');
      if (chip.contains('doctor')) return (r['doctor'] ?? '').isNotEmpty;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();

    return FutureBuilder<List<Map<String, String>>>(
      future: _recordsFuture,
      builder: (context, snapshot) {
        final results = query.isEmpty ? <Map<String, String>>[] : _filter(snapshot.data ?? []);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search records...',
                border: InputBorder.none,
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => _search.clear(),
                      )
                    : null,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
              if (query.isEmpty)
                const EmptyListPlaceholder(
                  icon: Icons.search,
                  title: 'Search your records',
                  subtitle: 'Find prescriptions, lab reports, and doctor visits.',
                )
              else ...[
                Text(
                  '${results.length} RESULT${results.length == 1 ? '' : 'S'} FOUND',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                if (results.isEmpty)
                  const EmptyListPlaceholder(
                    icon: Icons.search_off,
                    title: 'No results',
                    subtitle: 'Try a different search term or filter.',
                  )
                else
                  for (final r in results) _resultCard(context, r, query),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _resultCard(BuildContext context, Map<String, String> record, String query) {
    final title = record['title'] ?? record['diagnosis'] ?? record['doctor'] ?? 'Record';
    final type = record['documentType'] ?? record['tag'] ?? 'Record';
    final style = _docStyle(type);

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
                  decoration: BoxDecoration(
                    color: style.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(style.icon, color: style.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _highlightedText(title, query),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textGrey),
                          const SizedBox(width: 4),
                          Text(record['date'] ?? '', style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                          const Text(' • ', style: TextStyle(color: AppColors.textGrey)),
                          Text(type, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textGrey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Identical to the _docStyle in health_records_screen.dart — kept in sync.
  _DocStyle _docStyle(String type) {
    final t = type.toLowerCase();
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

  Widget _highlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15));
    }
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final index = lower.indexOf(q);
    if (index < 0) {
      return Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15));
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.w700),
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: const TextStyle(backgroundColor: Color(0xFFFFF59D)),
          ),
          TextSpan(text: text.substring(index + query.length)),
        ],
      ),
    );
  }
}

class _DocStyle {
  const _DocStyle(this.icon, this.bg, this.color);
  final IconData icon;
  final Color bg;
  final Color color;
}
