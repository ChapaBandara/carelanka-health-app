import 'dart:io';

import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/core/utils/date_helpers.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:carelanka_app/services/user_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:carelanka_app/widgets/carelanka/profile_avatar.dart';
import 'package:provider/provider.dart';

/// CareLanka UI #51 — Edit My Profile screen.
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
    _gender = p?.gender ?? 'Male';
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
        _gender = loaded.gender ?? _gender;
        _profileImageUrl = loaded.profileImageUrl;
      });
    } catch (_) {}
  }

  Future<void> _pickProfileImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _pendingImageFile = File(picked.path));
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

  InputDecoration _decoration({Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      prefixIcon: prefix,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryTeal, width: 1.5)),
    );
  }

  Widget _label(String text, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (hint != null) ...[
            const SizedBox(width: 6),
            Text(hint, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
          ],
        ],
      ),
    );
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
          phone: _phone.text.trim(),
          dateOfBirth: _dob,
          gender: _gender,
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
    return ProfileAvatar(
      radius: 48,
      imageUrl: _profileImageUrl,
      initials: initials,
      pendingFile: _pendingImageFile,
    );
  }

  Widget _genderOption(String value) {
    final selected = _gender == value;
    return Expanded(
      child: Material(
        color: selected ? const Color(0xFFE3F2FD) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _gender = value),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? const Color(0xFF42A5F5) : const Color(0xFFDEE2E6), width: selected ? 1.5 : 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? const Color(0xFF1565C0) : AppColors.textGrey,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(value, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? const Color(0xFF1565C0) : AppColors.textDark)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AuthProvider>().profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.maybePop(context)),
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: const Color(0xFFEEEEEE))),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
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
                            onTap: _pickProfileImage,
                            customBorder: const CircleBorder(),
                            child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.camera_alt, color: Colors.white, size: 20)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(onPressed: _pickProfileImage, child: const Text('Change Picture', style: TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.w600))),
                ),
                const SizedBox(height: 16),
                _label('Full Name'),
                TextFormField(controller: _name, decoration: _decoration(prefix: const Icon(Icons.person_outline, color: AppColors.textGrey)), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                const SizedBox(height: 18),
                _label('Phone Number'),
                TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: _decoration(prefix: const Icon(Icons.phone_outlined, color: AppColors.textGrey))),
                const SizedBox(height: 18),
                _label('Email Address', hint: '(Cannot be changed)'),
                TextFormField(controller: _email, readOnly: true, style: const TextStyle(color: AppColors.textGrey), decoration: _decoration(prefix: const Icon(Icons.email_outlined, color: AppColors.textGrey)).copyWith(fillColor: const Color(0xFFF5F5F5))),
                const SizedBox(height: 18),
                _label('Date of Birth'),
                TextFormField(
                  readOnly: true,
                  controller: _dobDisplay,
                  decoration: _decoration(prefix: const Icon(Icons.calendar_today_outlined, color: AppColors.textGrey), suffix: const Icon(Icons.keyboard_arrow_down, color: AppColors.textGrey)),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _dob ?? DateTime(1990), firstDate: DateTime(1900), lastDate: DateTime.now());
                    if (picked != null) {
                      setState(() {
                        _dob = picked;
                        _dobDisplay.text = DateHelpers.formatDmySlashes(picked);
                      });
                    }
                  },
                ),
                const SizedBox(height: 18),
                _label('Gender'),
                Row(children: [_genderOption('Male'), const SizedBox(width: 10), _genderOption('Female')]),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Emergency Contact', style: TextStyle(fontWeight: FontWeight.w700)),
                    TextButton(onPressed: () {}, child: const Text('Select from Contacts', style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.w600))),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDEE2E6))),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite_border, color: AppColors.errorRed),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_emergencyName.text.isEmpty ? 'Add emergency contact' : '${_emergencyName.text} (${_emergencyPhone.text.isNotEmpty ? _emergencyPhone.text : 'Son'})', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined, color: AppColors.textGrey, size: 20)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(controller: _emergencyName, decoration: _decoration(prefix: const Icon(Icons.contact_emergency_outlined, color: AppColors.textGrey)).copyWith(hintText: 'Contact name')),
                const SizedBox(height: 12),
                TextFormField(controller: _emergencyPhone, keyboardType: TextInputType.phone, decoration: _decoration(prefix: const Icon(Icons.phone_in_talk_outlined, color: AppColors.textGrey)).copyWith(hintText: 'Contact phone')),
                const SizedBox(height: 28),
                GradientPrimaryButton(
                  label: _saving ? 'Saving...' : 'Save Changes',
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
