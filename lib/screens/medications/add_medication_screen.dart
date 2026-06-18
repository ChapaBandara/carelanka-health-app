import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/drug_interaction_service.dart';
import 'package:carelanka_app/services/medication_service.dart';
import 'package:carelanka_app/services/notification_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/labeled_text_field.dart';
import 'package:carelanka_app/widgets/carelanka/profile_dropdown_field.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _dose = TextEditingController();
  final _lowStockDays = TextEditingController(text: '3');
  final _prescribedDays = TextEditingController();
  final _totalStock = TextEditingController();

  String? _illnessId;
  String _illnessName = '';
  String? _medicationId;
  bool _isEdit = false;
  bool _prescriptionReady = false;
  bool _saving = false;

  String _category = 'Tablet';
  String _frequency = 'Twice daily';
  String _mealTiming = 'After meals';
  bool _fixedDuration = true;
  bool _stockReminderOn = true;
  List<TimeOfDay> _doseTimes = [
    const TimeOfDay(hour: 8, minute: 0),
    const TimeOfDay(hour: 20, minute: 0),
  ];

  String? _conflictMessage;
  String? _allergyMessage;
  List<String> _userAllergies = [];

  static const _categories = ['Tablet', 'Capsule', 'Syrup', 'Injection', 'Cream', 'Drops'];
  static const _frequencies = ['Once daily', 'Twice daily', 'Three times daily', 'Four times daily'];
  static const _mealTimings = ['Before meals', 'After meals', 'With meals', 'Anytime'];

  @override
  void initState() {
    super.initState();
    _name.addListener(_checkConflicts);
    _loadAllergies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromArgs());
  }

  void _initFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;

    final illnessId = args['illnessId'] as String?;
    final illnessName = args['illnessName'] as String? ?? '';
    final medication = args['medication'];

    setState(() {
      _illnessId = illnessId;
      _illnessName = illnessName;
    });

    if (medication is Map) {
      _loadMedicationForEdit(Map<String, dynamic>.from(medication));
      return;
    }

    if (illnessId != null && illnessId.isNotEmpty) {
      _showPrescriptionDetailsSheet();
    } else {
      setState(() => _prescriptionReady = true);
    }
  }

  void _loadMedicationForEdit(Map<String, dynamic> med) {
    _isEdit = true;
    _medicationId = med['medicationId'] as String?;
    _name.text = med['name'] as String? ?? '';
    _dose.text = med['dosage'] as String? ?? '';
    _category = med['category'] as String? ?? 'Tablet';
    _frequency = med['frequency'] as String? ?? 'Twice daily';
    _mealTiming = _mealTimingLabel(med['mealTiming'] as String? ?? 'after_meals');
    _prescribedDays.text = '${med['prescribedDays'] ?? 14}';
    _totalStock.text = '${med['stockCount'] ?? 28}';
    _lowStockDays.text = '${med['lowStockThreshold'] ?? 3}';
    _stockReminderOn = true;
    _fixedDuration = (med['prescribedDays'] as num?) != null;

    final times = (med['scheduledTimes'] as List?)?.map((e) => e.toString()).toList() ?? [];
    _doseTimes = times.isNotEmpty
        ? times.map(_parseTimeString).whereType<TimeOfDay>().toList()
        : [const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 20, minute: 0)];
    _syncDoseCountToFrequency();
    _prescriptionReady = true;
    _checkConflicts();
  }

  TimeOfDay? _parseTimeString(String value) {
    final match = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)?', caseSensitive: false).firstMatch(value.trim());
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final ampm = match.group(3)?.toUpperCase();
    if (ampm == 'PM' && hour < 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _mealTimingLabel(String stored) {
    switch (stored.toLowerCase()) {
      case 'before_meals':
        return 'Before meals';
      case 'with_meals':
        return 'With meals';
      case 'anytime':
        return 'Anytime';
      default:
        return 'After meals';
    }
  }

  String _mealTimingValue(String label) {
    switch (label) {
      case 'Before meals':
        return 'before_meals';
      case 'With meals':
        return 'with_meals';
      case 'Anytime':
        return 'anytime';
      default:
        return 'after_meals';
    }
  }

  int _doseCountForFrequency(String frequency) {
    switch (frequency) {
      case 'Once daily':
        return 1;
      case 'Three times daily':
        return 3;
      case 'Four times daily':
        return 4;
      default:
        return 2;
    }
  }

  void _syncDoseCountToFrequency() {
    final count = _doseCountForFrequency(_frequency);
    final defaults = [
      const TimeOfDay(hour: 8, minute: 0),
      const TimeOfDay(hour: 14, minute: 0),
      const TimeOfDay(hour: 20, minute: 0),
      const TimeOfDay(hour: 22, minute: 0),
    ];
    while (_doseTimes.length < count) {
      _doseTimes.add(defaults[_doseTimes.length]);
    }
    if (_doseTimes.length > count) {
      _doseTimes = _doseTimes.sublist(0, count);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _showPrescriptionDetailsSheet() async {
    final daysController = TextEditingController(text: '7');
    final stockController = TextEditingController(text: '14');
    final alertDaysController = TextEditingController(text: '3');
    final sheetFormKey = GlobalKey<FormState>();
    var fixed = true;
    var stockOn = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: SingleChildScrollView(
                  child: Form(
                    key: sheetFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Prescription Details',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                      Text(
                        'How long is this medication prescribed?',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _sheetDurationChip(
                              label: 'Fixed Duration',
                              selected: fixed,
                              onTap: () => setSheetState(() => fixed = true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _sheetDurationChip(
                              label: 'Until Further Notice',
                              selected: !fixed,
                              onTap: () => setSheetState(() => fixed = false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text('Prescribed for how many days?', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: daysController,
                        keyboardType: TextInputType.number,
                        decoration: _sheetFieldDecoration(
                          fixed ? 'Enter number of days' : 'Optional',
                        ),
                        validator: (v) {
                          if (fixed && (v == null || v.trim().isEmpty)) {
                            return 'Required for fixed duration';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Total tablets/doses prescribed', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: stockController,
                        keyboardType: TextInputType.number,
                        decoration: _sheetFieldDecoration(
                          fixed ? 'Enter total tablets/doses' : 'Optional',
                        ),
                        validator: (v) {
                          if (fixed && (v == null || v.trim().isEmpty)) {
                            return 'Required for fixed duration';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Remind me when stock is running low',
                              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                            ),
                          ),
                          Switch(
                            value: stockOn,
                            activeTrackColor: AppColors.primaryTeal.withValues(alpha: 0.45),
                            thumbColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.selected)
                                  ? AppColors.primaryTeal
                                  : Colors.grey,
                            ),
                            onChanged: (v) => setSheetState(() => stockOn = v),
                          ),
                        ],
                      ),
                      if (stockOn) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Alert when'),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 48,
                              child: TextField(
                                controller: alertDaysController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: _sheetFieldDecoration('3'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('days of stock remain'),
                          ],
                        ),
                      ],
                      const SizedBox(height: 22),
                      GradientPrimaryButton(
                        label: 'Continue',
                        onPressed: () {
                          if (!(sheetFormKey.currentState?.validate() ?? false)) return;
                          setState(() {
                            _fixedDuration = fixed;
                            _prescribedDays.text = daysController.text.trim().isEmpty ? '30' : daysController.text;
                            _totalStock.text = stockController.text.trim().isEmpty ? '30' : stockController.text;
                            _lowStockDays.text = alertDaysController.text;
                            _stockReminderOn = stockOn;
                            _prescriptionReady = true;
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!_prescriptionReady && mounted) {
      Navigator.maybePop(context);
    }
  }

  InputDecoration _sheetFieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
        ),
      );

  Widget _sheetDurationChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFE0F7F7) : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primaryTeal : const Color(0xFFE0E0E0)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: selected ? AppColors.primaryTeal : AppColors.textGrey,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadAllergies() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('allergies')
          .where('userId', isEqualTo: userId)
          .get();
      if (!mounted) return;
      setState(() {
        _userAllergies = snap.docs
            .map((d) => d.data()['allergyName'] as String? ?? '')
            .where((n) => n.isNotEmpty)
            .toList();
      });
    } catch (_) {}
  }

  void _showConflictOverlay(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.errorRed, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Drug Conflict Detected',
                        style: TextStyle(
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 4), () {
      try {
        entry.remove();
      } catch (_) {}
    });
  }

  Future<void> _checkConflicts() async {
    final medName = _name.text.trim();
    if (medName.isEmpty) {
      setState(() {
        _conflictMessage = null;
        _allergyMessage = null;
      });
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final result = await DrugInteractionService().checkAll(medName, userId);

      if (!mounted) return;
      setState(() {
        _conflictMessage = result.conflictMessage;
        _allergyMessage = result.allergyMessage;
      });
      if (result.hasWarning) {
        _showConflictOverlay(
          context,
          result.conflictMessage ?? result.allergyMessage ?? '',
        );
      }
    } catch (_) {
      // Never surface a crash to the user — conflicts are advisory only.
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;

    final userId = FirebaseAuth.instance.currentUser!.uid;
    final medService = MedicationService();
    setState(() => _saving = true);

    try {
      var illnessId = _illnessId;
      if (illnessId == null || illnessId.isEmpty) {
        illnessId = await medService.findIllnessIdByName(userId, _illnessName);
      }
      if (illnessId == null) {
        throw Exception('No illness found. Add the illness first.');
      }

      final times = _doseTimes.map(_formatTime).toList();
      final prescribedDays = int.tryParse(_prescribedDays.text) ?? 14;
      final stockCount = int.tryParse(_totalStock.text) ?? 28;
      final lowStock = int.tryParse(_lowStockDays.text) ?? 3;

      if (_isEdit && _medicationId != null) {
        await medService.updateMedication(
          medicationId: _medicationId!,
          name: _name.text.trim(),
          dosage: _dose.text.trim(),
          category: _category,
          frequency: _frequency,
          scheduledTimes: times,
          mealTiming: _mealTimingValue(_mealTiming),
          prescribedDays: prescribedDays,
          stockCount: stockCount,
          lowStockThreshold: _stockReminderOn ? lowStock : 0,
          hasConflictWarning: _conflictMessage != null || _allergyMessage != null,
        );
        if (_conflictMessage != null || _allergyMessage != null) {
          try {
            final message = [
              if (_conflictMessage != null) _conflictMessage!,
              if (_allergyMessage != null) _allergyMessage!,
            ].join('\n');
            await FirebaseFirestore.instance.collection('alerts').add({
              'userId': userId,
              'type': 'drug',
              'message': message,
              'read': false,
              'createdAt': Timestamp.fromDate(DateTime.now()),
            });
          } catch (_) {}
        }
      } else {
        final medicationId = await medService.addMedication(
          userId: userId,
          illnessId: illnessId,
          name: _name.text.trim(),
          dosage: _dose.text.trim(),
          frequency: _frequency,
          scheduledTimes: times,
          category: _category,
          mealTiming: _mealTimingValue(_mealTiming),
          prescribedDays: prescribedDays,
          stockCount: stockCount,
          lowStockThreshold: _stockReminderOn ? lowStock : 0,
          hasConflictWarning: _conflictMessage != null || _allergyMessage != null,
        );
        if (_conflictMessage != null || _allergyMessage != null) {
          try {
            final message = [
              if (_conflictMessage != null) _conflictMessage!,
              if (_allergyMessage != null) _allergyMessage!,
            ].join('\n');
            await FirebaseFirestore.instance.collection('alerts').add({
              'userId': userId,
              'type': 'drug',
              'message': message,
              'read': false,
              'createdAt': Timestamp.fromDate(DateTime.now()),
            });
          } catch (_) {}
        }
        try {
          await NotificationService.instance.scheduleMedicationReminders(
            medicationId: medicationId,
            title: '${_name.text.trim()} ${_dose.text.trim()}',
            timeStrings: times,
          );
        } catch (_) {}
      }

      if (!mounted) return;
      await showCareLankaSuccessNotification(
        context,
        title: 'Medication saved',
        subtitle: '${_name.text.trim()} has been added to your list. Reminders will follow your schedule.',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(context: context, initialTime: _doseTimes[index]);
    if (picked != null) {
      setState(() => _doseTimes[index] = picked);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _lowStockDays.dispose();
    _prescribedDays.dispose();
    _totalStock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_prescriptionReady) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(
            _illnessName.isNotEmpty ? _illnessName : 'Add Medication',
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy),
          ),
          centerTitle: false,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final hasWarning = _conflictMessage != null || _allergyMessage != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.navy),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          _isEdit ? 'Edit Medication' : 'Add Medication',
          style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: AppColors.navy),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_illnessName.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    color: const Color(0xFFE0F7F7),
                    child: Row(
                      children: [
                        const Icon(Icons.monitor_heart_outlined, color: AppColors.primaryTeal, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: AppColors.navy, fontSize: 14),
                              children: [
                                const TextSpan(text: 'Adding medication for: '),
                                TextSpan(
                                  text: _illnessName,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionTitle('Medication Details'),
                      const SizedBox(height: 12),
                      LabeledIconField(
                        label: 'Medication Name',
                        hint: 'Aspirin',
                        controller: _name,
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      if (_userAllergies.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9C4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFF176)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Color(0xFFF9A825), size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Your Allergies',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF6D4C00),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _userAllergies
                                    .map(
                                      (a) => Chip(
                                        label: Text(
                                          a,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF6D4C00)),
                                        ),
                                        backgroundColor: const Color(0xFFFFF9C4),
                                        side: const BorderSide(color: Color(0xFFF9A825)),
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      LabeledIconField(
                        label: 'Dosage',
                        hint: 'e.g. 500mg',
                        controller: _dose,
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      ProfileDropdownField(
                        label: 'Category',
                        hint: 'Tablet',
                        value: _category,
                        items: _categories,
                        onChanged: (v) => setState(() => _category = v ?? _category),
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle('Schedule'),
                      const SizedBox(height: 12),
                      ProfileDropdownField(
                        label: 'Frequency',
                        hint: 'Twice daily',
                        value: _frequency,
                        items: _frequencies,
                        onChanged: (v) {
                          setState(() {
                            _frequency = v ?? _frequency;
                            _syncDoseCountToFrequency();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: List.generate(_doseTimes.length, (index) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: index < _doseTimes.length - 1 ? 10 : 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dose ${index + 1} Time',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => _pickTime(index),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFDEE2E6)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 18, color: AppColors.textGrey),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _formatTime(_doseTimes[index]),
                                              style: const TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      ProfileDropdownField(
                        label: 'Meal Timing',
                        hint: 'After meals',
                        value: _mealTiming,
                        items: _mealTimings,
                        onChanged: (v) => setState(() => _mealTiming = v ?? _mealTiming),
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle('Duration & Stock'),
                      const SizedBox(height: 12),
                      _readOnlyField(
                        label: 'Duration',
                        value: _fixedDuration
                            ? 'Prescribed for: ${_prescribedDays.text.isEmpty ? '—' : '${_prescribedDays.text} days'}'
                            : 'Until further notice',
                      ),
                      const SizedBox(height: 14),
                      _readOnlyField(
                        label: 'Total stock count',
                        value: _totalStock.text.isEmpty ? '—' : _totalStock.text,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Low stock reminder threshold',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: TextFormField(
                              controller: _lowStockDays,
                              enabled: _stockReminderOn,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('days'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle('Conflict Check'),
                      const SizedBox(height: 12),
                      if (_conflictMessage != null)
                        _alertBox(
                          title: 'Drug Conflict',
                          message: _conflictMessage!,
                          background: const Color(0xFFFFEBEE),
                          border: const Color(0xFFE57373),
                          icon: Icons.warning_amber_rounded,
                          iconColor: AppColors.errorRed,
                          titleColor: AppColors.errorRed,
                        ),
                      if (_allergyMessage != null) ...[
                        if (_conflictMessage != null) const SizedBox(height: 10),
                        _alertBox(
                          title: 'Allergy Alert',
                          message: _allergyMessage!,
                          background: const Color(0xFFFFF8E1),
                          border: const Color(0xFFFFD54F),
                          icon: Icons.health_and_safety_outlined,
                          iconColor: const Color(0xFFF9A825),
                          titleColor: const Color(0xFFF57F17),
                        ),
                      ],
                      if (_conflictMessage == null && _allergyMessage == null)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                          ),
                          child: Text(
                            'Enter a medication name to check for conflicts and allergies.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ),
                      const SizedBox(height: 28),
                      GradientPrimaryButton(
                        label: _saving
                            ? 'Saving...'
                            : hasWarning
                                ? 'Save with Warning'
                                : 'Save Medication',
                        onPressed: _saving ? null : _save,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy),
    );
  }

  Widget _readOnlyField({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Text(value, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _alertBox({
    required String title,
    required String message,
    required Color background,
    required Color border,
    required IconData icon,
    required Color iconColor,
    required Color titleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: titleColor)),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: titleColor.withValues(alpha: 0.85), fontSize: 13, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
