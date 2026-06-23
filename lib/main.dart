import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/navigation/app_route_observer.dart';
import 'package:carelanka_app/core/theme/app_theme.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:carelanka_app/providers/family_provider.dart';
import 'package:carelanka_app/providers/medication_provider.dart';
import 'package:carelanka_app/providers/reminder_provider.dart';
import 'package:carelanka_app/providers/user_data_provider.dart';
import 'package:carelanka_app/screens/auth/verify_reset_code_screen.dart';
import 'package:carelanka_app/screens/alerts/drug_conflict_detail_screen.dart';
import 'package:carelanka_app/screens/alerts/alerts_screen.dart';
import 'package:carelanka_app/screens/appointments/add_appointment_screen.dart';
import 'package:carelanka_app/screens/appointments/appointments_screen.dart';
import 'package:carelanka_app/screens/auth/forgot_password_screen.dart';
import 'package:carelanka_app/screens/auth/login_screen.dart';
import 'package:carelanka_app/screens/auth/register_screen.dart';
import 'package:carelanka_app/screens/auth/splash_screen.dart';
import 'package:carelanka_app/screens/auth/welcome_screen.dart';
import 'package:carelanka_app/screens/allergies/allergy_screen.dart';
import 'package:carelanka_app/screens/family/add_dependent_screen.dart';
import 'package:carelanka_app/screens/family/family_detail_screen.dart';
import 'package:carelanka_app/screens/family/link_confirmation_screen.dart';
import 'package:carelanka_app/screens/family/my_qr_screen.dart';
import 'package:carelanka_app/screens/family/qr_scanner_screen.dart';
import 'package:carelanka_app/screens/illnesses/add_illness_screen.dart';
import 'package:carelanka_app/screens/illnesses/illness_detail_screen.dart';
import 'package:carelanka_app/screens/illnesses/illness_list_screen.dart';
import 'package:carelanka_app/screens/main_shell.dart';
import 'package:carelanka_app/screens/medications/medication_search_screen.dart';
import 'package:carelanka_app/screens/medications/medication_list_screen.dart';
import 'package:carelanka_app/screens/medications/add_medication_screen.dart';
import 'package:carelanka_app/screens/medications/confirmed_medication_screen.dart';
import 'package:carelanka_app/screens/medications/reminder_history_screen.dart';
import 'package:carelanka_app/screens/medications/snoozed_medication_screen.dart';
import 'package:carelanka_app/screens/medications/taking_medication_screen.dart';
import 'package:carelanka_app/screens/profile/about_screen.dart';
import 'package:carelanka_app/screens/profile/change_password_screen.dart';
import 'package:carelanka_app/screens/profile/edit_profile_screen.dart';
import 'package:carelanka_app/screens/profile/help_screen.dart';
import 'package:carelanka_app/screens/profile/notification_settings_screen.dart';
import 'package:carelanka_app/screens/profile/privacy_screen.dart';
import 'package:carelanka_app/screens/profile/report_problem_screen.dart';
import 'package:carelanka_app/screens/records/documents_library_screen.dart';
import 'package:carelanka_app/screens/records/health_record_search_screen.dart';
import 'package:carelanka_app/screens/records/health_records_screen.dart';
import 'package:carelanka_app/screens/records/add_health_record_screen.dart';
import 'package:carelanka_app/screens/records/document_viewer_screen.dart';
import 'package:carelanka_app/screens/reports/reports_screen.dart';
import 'package:carelanka_app/firebase_options.dart';
import 'package:carelanka_app/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.initialize();
  runApp(const CareLankaApp());
}

class CareLankaApp extends StatelessWidget {
  const CareLankaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MedicationProvider()),
        ChangeNotifierProvider(create: (_) => ReminderProvider()),
        ChangeNotifierProvider(create: (_) => FamilyProvider()),
        ChangeNotifierProvider(create: (_) => UserDataProvider()),
      ],
      child: _AuthBootstrap(
        child: MaterialApp(
        title: 'CareLanka',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorKey: notificationNavigatorKey,
        navigatorObservers: [authRouteObserver],
        initialRoute: AppRoutes.splash,
        routes: {
          AppRoutes.splash: (_) => const SplashScreen(),
          AppRoutes.welcome: (_) => const WelcomeScreen(),
          AppRoutes.login: (_) => const LoginScreen(),
          AppRoutes.register: (_) => const RegisterScreen(),
          AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
          AppRoutes.verifyResetCode: (_) => const VerifyResetCodeScreen(),
          AppRoutes.dashboard: (_) => const MainShell(initialIndex: 0),
          AppRoutes.medicationList: (_) => const MedicationListScreen(),
          AppRoutes.medicationSearch: (_) => const MedicationSearchScreen(),
          AppRoutes.healthRecords: (_) => const HealthRecordsScreen(),
          AppRoutes.family: (_) => const MainShell(initialIndex: 1),
          AppRoutes.profile: (_) => const MainShell(initialIndex: 2),
          AppRoutes.illnessList: (_) => const IllnessListScreen(),
          AppRoutes.addIllness: (_) => const AddIllnessScreen(),
          AppRoutes.illnessDetail: (_) => const IllnessDetailScreen(),
          AppRoutes.addMedication: (_) => const AddMedicationScreen(),
          AppRoutes.reminderHistory: (_) => const ReminderHistoryScreen(),
          AppRoutes.takingMedication: (_) => const TakingMedicationScreen(),
          AppRoutes.confirmedMedication: (_) => const ConfirmedMedicationScreen(),
          AppRoutes.snoozedMedication: (_) => const SnoozedMedicationScreen(),
          AppRoutes.addRecord: (_) => const AddHealthRecordScreen(),
          AppRoutes.documentsLibrary: (_) => const DocumentsLibraryScreen(),
          AppRoutes.healthRecordSearch: (_) => const HealthRecordSearchScreen(),
          AppRoutes.documentViewer: (_) => const DocumentViewerScreen(),
          AppRoutes.appointments: (_) => const AppointmentsScreen(),
          AppRoutes.addAppointment: (_) => const AddAppointmentScreen(),
          AppRoutes.reports: (_) => const ReportsScreen(),
          AppRoutes.qrScanner: (_) => const QrScannerScreen(),
          AppRoutes.myQr: (_) => const MyQrScreen(),
          AppRoutes.linkConfirmation: (_) => const LinkConfirmationScreen(),
          AppRoutes.addDependent: (_) => const AddDependentScreen(),
          AppRoutes.familyDetail: (_) => const FamilyDetailScreen(),
          AppRoutes.allergies: (_) => const AllergyScreen(),
          AppRoutes.alerts: (_) => const AlertsScreen(),
          '/drug-conflict-detail': (_) => const DrugConflictDetailScreen(),
          AppRoutes.editProfile: (_) => const EditProfileScreen(),
          AppRoutes.notificationSettings: (_) => const NotificationSettingsScreen(),
          AppRoutes.privacy: (_) => const PrivacyScreen(),
          AppRoutes.help: (_) => const HelpScreen(),
          AppRoutes.reportProblem: (_) => const ReportProblemScreen(),
          AppRoutes.about: (_) => const AboutScreen(),
          AppRoutes.changePassword: (_) => const ChangePasswordScreen(),
        },
        ),
      ),
    );
  }
}

/// Loads persisted session as early as possible so auth screens stay in sync.
class _AuthBootstrap extends StatefulWidget {
  const _AuthBootstrap({required this.child});

  final Widget child;

  @override
  State<_AuthBootstrap> createState() => _AuthBootstrapState();
}

class _AuthBootstrapState extends State<_AuthBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
