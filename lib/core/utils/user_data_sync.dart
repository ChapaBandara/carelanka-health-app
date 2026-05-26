import 'package:carelanka_app/models/user_profile.dart';
import 'package:carelanka_app/providers/user_data_provider.dart';

/// Aligns in-memory health data with the signed-in profile.
void syncUserDataForProfile(UserDataProvider data, UserProfile? profile) {
  if (profile == null) {
    data.resetForOwner();
    return;
  }
  if (profile.isDependent) {
    data.resetForDependent(
      guardianName: profile.guardianName ?? 'Family account',
      dependentName: profile.fullName,
    );
  } else {
    data.resetForOwner();
  }
}
