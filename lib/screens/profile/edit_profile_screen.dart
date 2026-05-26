import 'dart:io';

import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/health_profile_options.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/core/utils/date_helpers.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:carelanka_app/services/user_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/labeled_text_field.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _dobDisplay;
  late final TextEditingController _emergencyName;
  late final TextEditingController _emergencyPhone;
  DateTime? _dob;
  String? _gender;
  String? _bloodType;
  String? _profileImageUrl;
  File? _pendingImageFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AuthProvider>().profile;
    _name = TextEditingController(text: p?.fullName ?? '');
    _email = TextEditingController(text: p?.email ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _dob = p?.dateOfBirth;
    _dobDisplay = TextEditingController(text: _dob == null ? '' : DateHelpers.formatDmySlashes(_dob!));
    _emergencyName = TextEditingController(text: p?.emergencyContactName ?? '');
    _emergencyPhone = TextEditingController(text: p?.emergencyContactPhone ?? '');
    _gender = p?.gender;
    _bloodType = p?.bloodType;
    _profileImageUrl = p?.profileImageUrl;
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final loaded = await UserService().getUserProfile(uid);
      if (loaded == null || !mounted) return;
      setState(() {
        _name.text = loaded.fullName;
        _email.text = loaded.email;
        _phone.text = loaded.phone;
        _dob = loaded.dateOfBirth;
        _dobDisplay.text = _dob == null ? '' : DateHelpers.formatDmySlashes(_dob!);
        _emergencyName.text = loaded.emergencyContactName ?? '';
        _emergencyPhone.text = loaded.emergencyContactPhone ?? '';
        _gender = loaded.gender;
        _bloodType = loaded.bloodType;
        _profileImageUrl = loaded.profileImageUrl;
      });
    } catch (_) {}
  }

  Future<void> _pickProfileImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() {
      _pendingImageFile = File(picked.path);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _dobDisplay.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthProvider>();
    final current = auth.profile;
    if (current == null) return;

    setState(() => _saving = true);
    try {
      var imageUrl = _profileImageUrl;
      final uid = FirebaseAuth.instance.currentUser!.uid;
      if (_pendingImageFile != null) {
        imageUrl = await UserService().uploadProfileImage(uid, _pendingImageFile!);
      }

      await auth.updateProfile(
        current.copyWith(
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          dateOfBirth: _dob,
          gender: _gender,
          bloodType: _bloodType,
          profileImageUrl: imageUrl,
          emergencyContactName: _emergencyName.text.trim(),
          emergencyContactPhone: _emergencyPhone.text.trim(),
        ),
      );
      if (!mounted) return;
      await showCareLankaSuccessNotification(
        context,
        title: 'Profile Updated',
        subtitle: 'Your profile changes have been saved successfully.',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _profileAvatar(String initials) {
    if (_pendingImageFile != null) {
      return CircleAvatar(radius: 48, backgroundImage: FileImage(_pendingImageFile!));
    }
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: NetworkImage(_profileImageUrl!),
        onBackgroundImageError: (_, _) {},
        child: _profileImageUrl!.isEmpty ? Text(initials) : null,
      );
    }
    return CircleAvatar(
      radius: 48,
      child: Text(initials, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AuthProvider>().profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Edit Profile'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    children: [
                      _profileAvatar(p?.initials ?? '?'),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: AppColors.primaryTeal,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _pickProfileImage,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _pickProfileImage,
                    child: const Text('Change profile photo', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 16),
                LabeledIconField(
                  label: 'Full name',
                  controller: _name,
                  prefixIcon: Icons.person_outline,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Email',
                  controller: _email,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Phone',
                  controller: _phone,
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 18),
                const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  hint: const Text('Select gender'),
                  items: HealthProfileOptions.genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() => _gender = v),
                ),
                const SizedBox(height: 18),
                const Text('Blood Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _bloodType,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  hint: const Text('Select blood type'),
                  items: HealthProfileOptions.bloodTypes.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                  onChanged: (v) => setState(() => _bloodType = v),
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Date of birth',
                  readOnly: true,
                  controller: _dobDisplay,
                  prefixIcon: Icons.calendar_today_outlined,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dob ?? DateTime(1990),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _dob = picked;
                        _dobDisplay.text = DateHelpers.formatDmySlashes(picked);
                      });
                    }
                  },
                ),
                const SizedBox(height: 18),
                const Text('Emergency contact', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 12),
                LabeledIconField(
                  label: 'Contact name',
                  controller: _emergencyName,
                  prefixIcon: Icons.contact_emergency_outlined,
                  hint: 'e.g. Spouse or parent',
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Contact phone',
                  controller: _emergencyPhone,
                  prefixIcon: Icons.phone_in_talk_outlined,
                  keyboardType: TextInputType.phone,
                  hint: '+94 77 123 4567',
                ),
                const SizedBox(height: 28),
                GradientPrimaryButton(
                  label: _saving ? 'Saving...' : 'Save changes',
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
