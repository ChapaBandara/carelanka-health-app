import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// CareLanka UI #37 — Health record summary with optional attachment viewer.
class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({super.key});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  double _zoom = 1.0;
  bool _showAttachment = false;

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.gif') ||
        lower.contains('.webp') ||
        lower.contains('image');
  }

  String _fileNameFromUrl(String url) {
    if (url.isEmpty) return 'Attachment';
    final uri = Uri.tryParse(url);
    if (uri == null) return 'Attachment';
    final segments = uri.pathSegments;
    if (segments.isEmpty) return 'Attachment';
    return Uri.decodeComponent(segments.last);
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final record = args is Map<String, String> ? args : <String, String>{};
    final diagnosis = record['diagnosis'] ?? '';
    final title = diagnosis.isNotEmpty ? diagnosis : record['title'] ?? 'Health Record';
    final visitDate = record['monthDay'] ?? record['date'] ?? '';
    final doctor = record['doctor'] ?? '';
    final hospital = record['place'] ?? '';
    final notes = record['notes'] ?? '';
    final docType = record['documentType'] ?? record['tag'] ?? '';
    final linked = record['linkedIllness'] ?? '';
    final documentUrl = record['documentUrl'] ?? '';
    final hasAttachment = documentUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _summaryCard(
            visitDate: visitDate,
            doctor: doctor,
            hospital: hospital,
            diagnosis: diagnosis,
            notes: notes,
            docType: docType,
            linked: linked,
          ),
          if (hasAttachment) ...[
            const SizedBox(height: 20),
            const Text(
              'Attachments',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.navy),
            ),
            const SizedBox(height: 10),
            _attachmentTile(
              fileName: _fileNameFromUrl(documentUrl),
              docType: docType,
              selected: _showAttachment,
              onTap: () => setState(() => _showAttachment = !_showAttachment),
            ),
            if (_showAttachment) ...[
              const SizedBox(height: 12),
              _attachmentPreview(documentUrl),
            ],
          ],
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String visitDate,
    required String doctor,
    required String hospital,
    required String diagnosis,
    required String notes,
    required String docType,
    required String linked,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.summarize_outlined, color: AppColors.primaryTeal, size: 22),
              SizedBox(width: 8),
              Text(
                'Summary Report',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (visitDate.isNotEmpty) _summaryRow('Visit Date', visitDate),
          if (doctor.isNotEmpty) _summaryRow('Doctor', doctor),
          if (hospital.isNotEmpty) _summaryRow('Hospital', hospital),
          if (diagnosis.isNotEmpty) _summaryRow('Diagnosis', diagnosis),
          if (docType.isNotEmpty) _summaryRow('Record Type', docType),
          if (notes.isNotEmpty) _summaryRow('Notes', notes, multiline: true),
          if (linked.isNotEmpty) _summaryRow('Linked Illness', linked),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool multiline = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: multiline ? 1.45 : 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentTile({
    required String fileName,
    required String docType,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primaryTeal : const Color(0xFFDEE2E6),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.attach_file, color: AppColors.primaryTeal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fileName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    if (docType.isNotEmpty)
                      Text(docType, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: AppColors.textGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentPreview(String url) {
    if (_isImageUrl(url)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 200,
                alignment: Alignment.center,
                color: Colors.white,
                child: const CircularProgressIndicator(color: AppColors.primaryTeal),
              );
            },
            errorBuilder: (context, error, stackTrace) => _documentPlaceholder(url),
          ),
        ),
      );
    }
    return _documentPlaceholder(url);
  }

  Widget _documentPlaceholder(String url) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Center(
            child: Transform.scale(
              scale: _zoom,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: SizedBox(
                  width: 260,
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
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _zoomButton(Icons.zoom_in, () => setState(() => _zoom = (_zoom + 0.1).clamp(0.8, 2.0))),
              const SizedBox(height: 8),
              _zoomButton(Icons.zoom_out, () => setState(() => _zoom = (_zoom - 0.1).clamp(0.8, 2.0))),
            ],
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
