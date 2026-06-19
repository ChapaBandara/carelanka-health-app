import 'dart:io';
import 'dart:typed_data';

import 'package:carelanka_app/services/user_service.dart';
import 'package:flutter/material.dart';

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    required this.initials,
    this.radius = 44,
    this.pendingFile,
  });

  final String? imageUrl;
  final String initials;
  final double radius;
  final File? pendingFile;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Uint8List? _cachedBytes;

  @override
  void initState() {
    super.initState();
    _loadCached();
  }

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadCached();
    }
  }

  Future<void> _loadCached() async {
    final url = widget.imageUrl;
    if (url == null || !url.startsWith('local:')) {
      if (mounted) setState(() => _cachedBytes = null);
      return;
    }
    final uid = url.substring('local:'.length);
    final bytes = await UserService().getCachedProfileImageBytes(uid);
    if (mounted) setState(() => _cachedBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pendingFile != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage: FileImage(widget.pendingFile!),
      );
    }

    final url = widget.imageUrl;
    if (url != null && url.startsWith('local:') && _cachedBytes != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage: MemoryImage(_cachedBytes!),
      );
    }

    if (url != null && url.isNotEmpty && !url.startsWith('local:')) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, _) {},
      );
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: const Color(0x33000000),
      child: Text(
        widget.initials,
        style: TextStyle(
          fontSize: widget.radius * 0.62,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
