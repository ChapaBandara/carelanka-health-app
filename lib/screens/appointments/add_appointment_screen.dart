import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/appointment_service.dart';
import 'package:carelanka_app/services/checkup_service.dart';
import 'package:carelanka_app/services/notification_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:carelanka_app/core/utils/active_uid.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// CareLanka UI #41 — New / Edit Appointment form.
class AddAppointmentScreen extends StatefulWidget {
  const AddAppointmentScreen({super.key});

  @override
  State<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _doctor = TextEditingController();
  final _place = TextEditingController();
  final _reason = TextEditingController();
  final _dateDisplay = TextEditingController();
  final _timeDisplay = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  bool _remind3Days = true;
  bool _remind1Day = true;
  bool _remind2Hours = true;
  bool _remind1Hour = true;
  bool _saving = false;
  bool _isEdit = false;
  String? _editAppointmentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEditArgs());
  }

  void _loadEditArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map<String, String>) return;

    final millis = int.tryParse(args['dateTimeMillis'] ?? args['sortKey'] ?? '');
    if (millis == null) return;

    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final reminders = (args['reminders'] ?? '').split('|').where((s) => s.isNotEmpty).toSet();

    setState(() {
      _isEdit = true;
      _editAppointmentId = args['appointmentId'];
      _doctor.text = args['doctor'] ?? '';
      _place.text = args['hospital'] ?? '';
      _reason.text = args['note'] ?? '';
      _date = DateTime(dt.year, dt.month, dt.day);
      _time = TimeOfDay(hour: dt.hour, minute: dt.minute);
      _dateDisplay.text = DateFormat('MMM d, yyyy').format(_date!);
      _timeDisplay.text = _time!.format(context);
      _remind3Days = reminders.contains('3 days');
      _remind1Day = reminders.contains('1 day');
      _remind2Hours = reminders.contains('2 hours');
      _remind1Hour = reminders.contains('1 hour');
    });
  }

  @override
  void dispose() {
    _doctor.dispose();
    _place.dispose();
    _reason.dispose();
    _dateDisplay.dispose();
    _timeDisplay.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.85)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryTeal, width: 1.5)),
      suffixIcon: suffix,
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
      );

  List<String> get _selectedReminders {
    final list = <String>[];
    if (_remind3Days) list.add('3 days');
    if (_remind1Day) list.add('1 day');
    if (_remind2Hours) list.add('2 hours');
    if (_remind1Hour) list.add('1 hour');
    return list;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    if (_date == null || _time == null) return;
    setState(() => _saving = true);

    final dt = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
    try {
      final userId = context.activeScopeId;

      if (_isEdit && _editAppointmentId != null) {
        await AppointmentService().updateAppointment(
          appointmentId: _editAppointmentId!,
          doctorName: _doctor.text.trim(),
          hospital: _place.text.trim(),
          dateTime: dt,
          notes: _reason.text.trim(),
          reminderSettings: _selectedReminders,
        );
      } else {
        await AppointmentService().addAppointment(
          userId: userId,
          doctorName: _doctor.text.trim(),
          hospital: _place.text.trim(),
          dateTime: dt,
          notes: _reason.text.trim(),
          reminderSettings: _selectedReminders,
        );
      }

      if (!dt.isBefore(DateTime.now())) {
        try {
          await NotificationService.instance.scheduleAppointmentReminders(
            appointmentId: _editAppointmentId ?? '${userId}_${dt.millisecondsSinceEpoch}',
            title: 'Appointment with ${_doctor.text.trim()}',
            appointmentTime: dt,
            reminderSettings: _selectedReminders,
          );
        } catch (_) {}
      }

      await CheckupService().evaluateForUser(userId);

      if (!mounted) return;
      await showCareLankaSuccessNotification(
        context,
        title: _isEdit ? 'Appointment updated' : 'Appointment saved',
        subtitle: _isEdit
            ? 'Your appointment has been updated.'
            : 'Your appointment has been added. Reminders will notify you before the visit.',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          _isEdit ? 'Edit Appointment' : 'New Appointment',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEEE)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label('Doctor Name'),
                TextFormField(
                  controller: _doctor,
                  decoration: _decoration('e.g. Dr. K. Jayasuriya'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                _label('Hospital / Location'),
                TextFormField(
                  controller: _place,
                  decoration: _decoration('e.g. Lanka Hospitals'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                _label('Date'),
                TextFormField(
                  readOnly: true,
                  controller: _dateDisplay,
                  decoration: _decoration('Select a date', suffix: const Icon(Icons.calendar_today_outlined, color: AppColors.textGrey, size: 20)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      initialDate: _date ?? DateTime.now().add(const Duration(days: 1)),
                    );
                    if (d != null) {
                      setState(() {
                        _date = d;
                        _dateDisplay.text = DateFormat('MMM d, yyyy').format(d);
                      });
                    }
                  },
                  validator: (_) => _date == null ? 'Pick a date' : null,
                ),
                const SizedBox(height: 18),
                _label('Time'),
                TextFormField(
                  readOnly: true,
                  controller: _timeDisplay,
                  decoration: _decoration('Select time', suffix: const Icon(Icons.access_time, color: AppColors.textGrey, size: 20)),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
                    if (t != null) {
                      setState(() {
                        _time = t;
                        _timeDisplay.text = t.format(context);
                      });
                    }
                  },
                  validator: (_) => _time == null ? 'Pick a time' : null,
                ),
                const SizedBox(height: 18),
                _label('Notes (Optional)'),
                TextFormField(
                  controller: _reason,
                  maxLines: 3,
                  decoration: _decoration('Any specific details about this appointment...'),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDEE2E6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text('Send me reminders', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      SwitchListTile(
                        title: const Text('3 days before'),
                        value: _remind3Days,
                        activeThumbColor: AppColors.primaryTeal,
                        onChanged: (v) => setState(() => _remind3Days = v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('1 day before'),
                        value: _remind1Day,
                        activeThumbColor: AppColors.primaryTeal,
                        onChanged: (v) => setState(() => _remind1Day = v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('2 hours before'),
                        value: _remind2Hours,
                        activeThumbColor: AppColors.primaryTeal,
                        onChanged: (v) => setState(() => _remind2Hours = v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('1 hour before'),
                        value: _remind1Hour,
                        activeThumbColor: AppColors.primaryTeal,
                        onChanged: (v) => setState(() => _remind1Hour = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                GradientPrimaryButton(
                  label: _saving ? 'Saving...' : (_isEdit ? 'Update Appointment' : 'Save Appointment'),
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
