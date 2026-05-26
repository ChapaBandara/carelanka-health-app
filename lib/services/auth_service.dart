import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:carelanka_app/core/firebase/firebase_collections.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    return _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> reauthenticateWithPassword(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to continue.');
    }
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> deleteAuthUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to continue.');
    }
    await user.delete();
  }

  /// Resolves login identifier to email (supports phone lookup in users collection).
  Future<String> resolveEmailForLogin(String emailOrPhone) async {
    final input = emailOrPhone.trim();
    if (input.contains('@')) return input;

    final digits = input.replaceAll(RegExp(r'\D'), '');
    final normalized = digits.length == 9 ? digits : digits;

    final snap = await _firestore
        .collection(FirebaseCollections.users)
        .where('phone', isEqualTo: normalized)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw Exception('No account found with this phone number. Create an account first.');
    }

    final email = snap.docs.first.data()['email'] as String?;
    if (email == null || email.isEmpty) {
      throw Exception('Account email not found. Contact support.');
    }
    return email;
  }
}
