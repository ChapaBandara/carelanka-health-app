import 'package:firebase_auth/firebase_auth.dart';

extension FirebaseAuthX on FirebaseAuth {
  String requireUid() {
    final uid = currentUser?.uid;
    if (uid == null) {
      throw Exception('You must be signed in to continue.');
    }
    return uid;
  }
}
