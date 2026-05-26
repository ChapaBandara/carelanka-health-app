import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:carelanka_app/services/illness_service.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Matches CareLanka UI "My Medications" — illness hub with Active / Completed tabs.
class MedicationListScreen extends StatefulWidget {
  const MedicationListScreen({super.key});

  @override
  State<MedicationListScreen> createState() => _MedicationListScreenState();
}

class _MedicationListScreenState extends State<MedicationListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('My Medications'),
        centerTitle: true,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.navy,
          unselectedLabelColor: AppColors.textGrey,
          indicatorColor: AppColors.navy,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Active Illnesses'),
            Tab(text: 'Completed Illnesses'),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: CareLankaGradients.fab, boxShadow: [
          BoxShadow(color: AppColors.navy.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 6)),
        ]),
        child: FloatingActionButton(
          elevation: 0,
          backgroundColor: Colors.transparent,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.addIllness),
          child: const Icon(Icons.add, color: Colors.white, size: 32),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _illnessList(active: true),
          _illnessList(active: false),
        ],
      ),
    );
  }

  Widget _illnessList({required bool active}) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<List<Map<String, String>>>(
      stream: IllnessService().watchIllnessMaps(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final illnesses = snapshot.data ?? [];
        final list = active
            ? illnesses.where((i) => i['status'] != 'completed').toList()
            : illnesses.where((i) => i['status'] == 'completed').toList();

        if (list.isEmpty) {
          return EmptyListPlaceholder(
            icon: Icons.healing_outlined,
            title: active ? 'No active illnesses' : 'No completed illnesses',
            subtitle: active ? 'Tap + to add an illness and track medications.' : null,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final item = list[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _illnessCard(
                item,
                item['initials'] ?? '?',
                const Color(0xFFB2DFDB),
                item['name'] ?? '',
                item['since'] ?? '',
                item['meds'] ?? '0 medications',
                item['chip2'] ?? 'Ongoing',
                const Color(0xFFBBDEFB),
              ),
            );
          },
        );
      },
    );
  }

  Widget _illnessCard(
    Map<String, String> item,
    String letter,
    Color avatarBg,
    String title,
    String since,
    String chip1,
    String chip2,
    Color chip2Bg,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0.5,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, AppRoutes.illnessDetail, arguments: item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: avatarBg,
                    child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                            ),
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primaryTeal, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            const Text('ACTIVE', style: TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.w800, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(since, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(chip1, style: const TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.w600, fontSize: 12)),
                    backgroundColor: const Color(0xFFE0F7F7),
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                    side: BorderSide.none,
                  ),
                  Chip(
                    label: Text(chip2, style: TextStyle(color: chip2Bg == const Color(0xFFFFF59D) ? const Color(0xFF5D4E00) : AppColors.navy, fontWeight: FontWeight.w600, fontSize: 12)),
                    backgroundColor: chip2Bg,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                    side: BorderSide.none,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
