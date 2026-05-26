import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/appointment_service.dart';
import 'package:carelanka_app/services/notification_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/labeled_text_field.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _doctor.dispose();
    _place.dispose();
    _reason.dispose();
    _dateDisplay.dispose();
    _timeDisplay.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_date == null || _time == null) return;
    final dt = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      await AppointmentService().addAppointment(
        userId: userId,
        doctorName: _doctor.text.trim(),
        hospital: _place.text.trim(),
        dateTime: dt,
        notes: _reason.text.trim(),
        reminderSettings: const ['2 hours before', '1 day before'],
      );
      await NotificationService.instance.scheduleAppointmentReminders(
        appointmentId: '${userId}_${dt.millisecondsSinceEpoch}',
        title: 'Appointment with ${_doctor.text.trim()}',
        appointmentTime: dt,
      );
      if (!mounted) return;
      showFirebaseSuccessSnackBar(context, 'Appointment saved successfully');
      await showCareLankaSuccessNotification(
        context,
        title: 'Appointment saved',
        subtitle: 'Your appointment has been added. Reminders will notify you before the visit.',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    }
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
        title: const Text('Add / Edit Appointment'),
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
                LabeledIconField(
                  label: 'Doctor',
                  hint: 'Dr. Amila Silva',
                  controller: _doctor,
                  prefixIcon: Icons.person_outline,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Hospital / Clinic',
                  hint: 'Asiri Medical Hospital',
                  controller: _place,
                  prefixIcon: Icons.local_hospital_outlined,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Date',
                  hint: 'Tap to choose date',
                  readOnly: true,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (d != null) {
                      setState(() {
                        _date = d;
                        _dateDisplay.text = '${d.day}/${d.month}/${d.year}';
                      });
                    }
                  },
                  controller: _dateDisplay,
                  prefixIcon: Icons.calendar_today_outlined,
                  validator: (_) => _date == null ? 'Pick a date' : null,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Time',
                  hint: 'Tap to choose time',
                  readOnly: true,
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (t != null) {
                      setState(() {
                        _time = t;
                        _timeDisplay.text = t.format(context);
                      });
                    }
                  },
                  controller: _timeDisplay,
                  prefixIcon: Icons.access_time,
                  validator: (_) => _time == null ? 'Pick a time' : null,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Reason / Notes',
                  hint: 'Optional',
                  controller: _reason,
                  prefixIcon: Icons.notes_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: 28),
                GradientPrimaryButton(label: 'Save Appointment', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
