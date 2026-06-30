import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/services/illness_service.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:carelanka_app/core/utils/active_uid.dart';
import 'package:flutter/material.dart';

/// Search illnesses — mirrors the health record search flow.
class MedicationSearchScreen extends StatefulWidget {
  const MedicationSearchScreen({super.key});

  @override
  State<MedicationSearchScreen> createState() => _MedicationSearchScreenState();
}

class _MedicationSearchScreenState extends State<MedicationSearchScreen> {
  final _search = TextEditingController();
  int _chip = 0;
  final _chips = ['All', 'Active', 'Completed'];
  Future<List<Map<String, String>>>? _illnessesFuture;
  bool _initialChipApplied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _illnessesFuture = _fetchIllnesses());
    });
    _search.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialChipApplied) return;
    _initialChipApplied = true;
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is Map) {
      final tab = routeArgs['tab'] as String?;
      if (tab == 'completed') {
        _chip = 2;
      } else if (tab == 'active') {
        _chip = 1;
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Map<String, String>>> _fetchIllnesses() async {
    final userId = context.activeScopeId;
    final illnesses = await IllnessService().watchIllnessMaps(userId).first;
    illnesses.sort((a, b) {
      final aMs = int.tryParse(a['diagnosedDateMillis'] ?? '0') ?? 0;
      final bMs = int.tryParse(b['diagnosedDateMillis'] ?? '0') ?? 0;
      return bMs.compareTo(aMs);
    });
    return illnesses;
  }

  List<Map<String, String>> _filter(List<Map<String, String>> illnesses) {
    final q = _search.text.trim().toLowerCase();
    var list = q.isEmpty
        ? illnesses
        : illnesses.where((i) {
            final name = (i['name'] ?? '').toLowerCase();
            final since = (i['since'] ?? '').toLowerCase();
            final meds = (i['meds'] ?? '').toLowerCase();
            final notes = (i['notes'] ?? '').toLowerCase();
            return name.contains(q) || since.contains(q) || meds.contains(q) || notes.contains(q);
          }).toList();

    if (_chip == 0) return list;
    final chip = _chips[_chip].toLowerCase();
    return list.where((i) {
      final status = (i['status'] ?? '').toLowerCase();
      if (chip.contains('active')) return status != 'completed';
      if (chip.contains('completed')) return status == 'completed';
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final isFiltering = query.isNotEmpty;

    return FutureBuilder<List<Map<String, String>>>(
      future: _illnessesFuture,
      builder: (context, snapshot) {
        if (_illnessesFuture == null ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
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
                hintText: 'Search illnesses...',
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
                    : '${results.length} ILLNESS${results.length == 1 ? '' : 'ES'}',
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
                  icon: isFiltering ? Icons.search_off : Icons.healing_outlined,
                  title: isFiltering ? 'No results' : 'No illnesses yet',
                  subtitle: isFiltering
                      ? 'Try a different search term or filter.'
                      : 'Add an illness from My Medications to get started.',
                )
              else
                for (final illness in results) _resultCard(context, illness, query),
            ],
          ),
        );
      },
    );
  }

  Widget _resultCard(BuildContext context, Map<String, String> illness, String query) {
    final name = illness['name'] ?? 'Illness';
    final since = illness['since'] ?? '';
    final meds = illness['meds'] ?? '';
    final isCompleted = illness['status'] == 'completed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pushNamed(context, AppRoutes.illnessDetail, arguments: illness),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFB2DFDB),
                  child: Text(
                    illness['initials'] ?? '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _highlightedText(name, query),
                      if (since.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _highlightedText(since, query, fontSize: 13, color: AppColors.textGrey),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (meds.isNotEmpty) ...[
                            Flexible(child: _highlightedText(meds, query, fontSize: 12, color: AppColors.textGrey)),
                            const Text(' • ', style: TextStyle(color: AppColors.textGrey)),
                          ],
                          Text(
                            isCompleted ? 'Completed' : 'Active',
                            style: TextStyle(
                              color: isCompleted ? AppColors.textGrey : AppColors.primaryTeal,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
