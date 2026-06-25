import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/utils/active_uid.dart';
import 'package:carelanka_app/providers/family_provider.dart';
import 'package:carelanka_app/services/health_record_service.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// CareLanka UI #36 — Health Record Search with highlighted matches.
class HealthRecordSearchScreen extends StatefulWidget {
  const HealthRecordSearchScreen({super.key});

  @override
  State<HealthRecordSearchScreen> createState() => _HealthRecordSearchScreenState();
}

class _HealthRecordSearchScreenState extends State<HealthRecordSearchScreen> {
  final _search = TextEditingController();
  int _chip = 0;
  final _chips = ['All', 'Prescriptions', 'Lab Reports', 'Doctors', 'Summary Reports'];

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
      if (chip.contains('summary')) {
        return type.contains('summary') || type.contains('annual') || type.contains('checkup');
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final isFiltering = query.isNotEmpty;

    return Consumer<FamilyProvider>(
      builder: (context, _, _) {
        final userId = context.activeUid;

    return StreamBuilder<List<Map<String, String>>>(
      stream: HealthRecordService().watchRecordMaps(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: const Text('Search records'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final results = _filter(snapshot.data ?? []);

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
              Text(
                isFiltering
                    ? '${results.length} RESULT${results.length == 1 ? '' : 'S'} FOUND'
                    : '${results.length} RECORD${results.length == 1 ? '' : 'S'}',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              if (results.isEmpty)
                EmptyListPlaceholder(
                  icon: isFiltering ? Icons.search_off : Icons.folder_open_outlined,
                  title: isFiltering ? 'No results' : 'No health records yet',
                  subtitle: isFiltering
                      ? 'Try a different search term or filter.'
                      : 'Add a health record to start building your library.',
                )
              else
                for (final r in results) _resultCard(context, r, query),
            ],
          ),
        );
      },
    );
      },
    );
  }

  Widget _resultCard(BuildContext context, Map<String, String> record, String query) {
    final title = record['title'] ?? record['diagnosis'] ?? record['doctor'] ?? 'Record';
    final doctor = record['doctor'] ?? '';
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
                      if (doctor.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _highlightedText(doctor, query, fontSize: 13, color: AppColors.textGrey),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textGrey),
                          const SizedBox(width: 4),
                          Text(record['date'] ?? '', style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                          const Text(' • ', style: TextStyle(color: AppColors.textGrey)),
                          Flexible(child: _highlightedText(type, query, fontSize: 12, color: AppColors.textGrey)),
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

  Widget _highlightedText(
    String text,
    String query, {
    double fontSize = 15,
    Color color = AppColors.textDark,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    if (query.isEmpty) {
      return Text(text, style: TextStyle(fontWeight: fontWeight, fontSize: fontSize, color: color));
    }
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final index = lower.indexOf(q);
    if (index < 0) {
      return Text(text, style: TextStyle(fontWeight: fontWeight, fontSize: fontSize, color: color));
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight),
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
