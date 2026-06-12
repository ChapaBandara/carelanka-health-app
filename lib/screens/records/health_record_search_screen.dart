import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/services/health_record_service.dart';
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
    var list = HealthRecordService().searchRecords(records, _search.text);
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
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final query = _search.text.trim();

    return StreamBuilder<List<Map<String, String>>>(
      stream: HealthRecordService().watchRecordMaps(userId),
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
                    color: const Color(0xFFE0F7F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    type.toLowerCase().contains('lab') ? Icons.biotech_outlined : Icons.description_outlined,
                    color: AppColors.primaryTeal,
                  ),
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
