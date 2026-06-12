import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// CareLanka UI #37 — Document view with zoom controls and metadata footer.
class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({super.key});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  double _zoom = 1.0;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final record = args is Map<String, String> ? args : <String, String>{};
    final title = record['diagnosis']?.isNotEmpty == true
        ? record['diagnosis']!
        : record['title'] ?? 'Document';
    final uploaded = record['monthDay'] ?? record['date'] ?? '';
    final doctor = record['doctor'] ?? '';
    final linked = record['linkedIllness'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFECEFF1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.download_outlined)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                Center(
                  child: Transform.scale(
                    scale: _zoom,
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: SizedBox(
                        width: 280,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(height: 12, width: 120, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Container(height: 8, width: double.infinity, color: Colors.grey.shade200),
                            const SizedBox(height: 8),
                            Container(height: 8, width: double.infinity, color: Colors.grey.shade200),
                            const SizedBox(height: 8),
                            Container(height: 8, width: 200, color: Colors.grey.shade200),
                            const SizedBox(height: 24),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFE91E63), width: 3),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'VERIFIED',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFE91E63),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _zoomButton(Icons.zoom_in, () => setState(() => _zoom = (_zoom + 0.1).clamp(0.8, 2.0))),
                      const SizedBox(height: 8),
                      _zoomButton(Icons.zoom_out, () => setState(() => _zoom = (_zoom - 0.1).clamp(0.8, 2.0))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Uploaded $uploaded${doctor.isNotEmpty ? ' • $doctor' : ''}',
                  style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
                if (linked.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'From: $linked',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.open_in_new, size: 16, color: AppColors.navy),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22, color: AppColors.navy),
        ),
      ),
    );
  }
}
