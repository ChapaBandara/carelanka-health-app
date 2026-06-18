import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class FamilyDetailScreen extends StatelessWidget {
  const FamilyDetailScreen({super.key});

  Map<String, String>? _member(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, String>) return args;
    if (args is Map) {
      return args.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final member = _member(context);
    final name = member?['name'] ?? 'Family member';
    final linked = member?['type'] == 'linked';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(name),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Relationship'),
              trailing: Text(member?['meta'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Account type'),
              trailing: Text(
                linked ? 'Linked Account' : 'Dependent Profile',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if ((member?['tag1'] ?? '').isNotEmpty)
            Card(
              child: ListTile(
                title: const Text('Gender'),
                trailing: Text(member!['tag1']!, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          if ((member?['tag2'] ?? '').isNotEmpty)
            Card(
              child: ListTile(
                title: const Text('Blood type'),
                trailing: Text(member!['tag2']!, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}
