import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:flutter/material.dart';

/// CareLanka UI #58 — Help and Support screen.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  int? _expanded;

  final _faqs = const [
    (
      'How does the adaptive reminder work?',
      'CareLanka tracks when you usually take your medication. After 7 days, if your adherence is below 70%, the system automatically adjusts your reminder time to better match your routine.',
    ),
    ('How do I add medications for a family member?', 'Open Family Health, select the member, then add medications from their illness detail screen.'),
    ('Is my health data secure?', 'Your data is encrypted in transit and at rest. Only you and linked family members can access shared records.'),
    ('How does drug conflict detection work?', 'CareLanka compares new medications against your allergy profile and existing medicines.'),
    ('What happens when stock runs low?', 'You receive a low-stock reminder so you can refill before doses are missed.'),
    ('How do I link my account to a family member?', 'Share your QR code or scan theirs from Family Health → Scan Family QR Code.'),
    ('Can I use CareLanka in Sinhala?', 'Sinhala language support is planned for a future release.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.maybePop(context)),
        title: const Text('Help and Support', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search help topics...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _quickCard(Icons.medication_outlined, const Color(0xFFE0F7F7), AppColors.primaryTeal, 'How to add medication'),
              _quickCard(Icons.people_outline, const Color(0xFFE0F7F7), AppColors.primaryTeal, 'How to add family member'),
              _quickCard(Icons.notifications_active_outlined, const Color(0xFFFFE0B2), const Color(0xFFF57C00), 'Understanding alerts'),
              _quickCard(Icons.schedule, const Color(0xFFF3E5F5), const Color(0xFF7B1FA2), 'How reminders work'),
            ],
          ),
          const SizedBox(height: 20),
          const Text('FREQUENTLY ASKED QUESTIONS', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          for (var i = 0; i < _faqs.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                initiallyExpanded: i == 0,
                onExpansionChanged: (open) => setState(() => _expanded = open ? i : null),
                title: Text(_faqs[i].$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: Icon(
                  _expanded == i || (i == 0 && _expanded == null) ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: _expanded == i || (i == 0 && _expanded == null) ? AppColors.primaryTeal : AppColors.textGrey,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_faqs[i].$2, style: const TextStyle(color: AppColors.textGrey, height: 1.45, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const Text('CONTACT SUPPORT', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, decoration: const BoxDecoration(color: AppColors.primaryTeal, borderRadius: BorderRadius.horizontal(left: Radius.circular(14)))),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _contactRow(Icons.email_outlined, const Color(0xFFE0F7F7), AppColors.primaryTeal, 'support@carelanka.lk'),
                          const Divider(height: 20),
                          _contactRow(Icons.phone_outlined, const Color(0xFFE3F2FD), const Color(0xFF1565C0), '+94 11 XXX XXXX'),
                          const Divider(height: 20),
                          const Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: AppColors.textGrey),
                              SizedBox(width: 6),
                              Text('Response time: Usually within 24 hours', style: TextStyle(color: AppColors.textGrey, fontSize: 12, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.reportProblem),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryTeal,
              side: const BorderSide(color: AppColors.primaryTeal),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.report_gmailerrorred_outlined),
            label: const Text('Report a Bug or Problem', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _quickCard(IconData icon, Color bg, Color color, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(backgroundColor: bg, radius: 22, child: Icon(icon, color: color, size: 22)),
          const Spacer(),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.3)),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, Color bg, Color color, String text) {
    return Row(
      children: [
        CircleAvatar(backgroundColor: bg, radius: 18, child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
