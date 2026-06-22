import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyService {
  FamilyService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirebaseCollections.familyProfiles);

  Stream<List<Map<String, String>>> watchFamilyMaps(String ownerId) {
    return _col.where('ownerId', isEqualTo: ownerId).snapshots().map(
          (snap) => snap.docs.map(_toUiMap).toList(),
        );
  }

  Map<String, String> _toUiMap(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final name = d['fullName'] as String? ?? '';
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
            ? parts.first[0].toUpperCase()
            : '${parts.first[0]}${parts.last[0]}'.toUpperCase();

    final hasOwn = d['hasOwnAccount'] == true;
    final relationship = d['relationship'] as String? ?? '';
    final gender = d['gender'] as String? ?? '';
    final bloodType = d['bloodType'] as String? ?? '';
    final linkedUserId = d['linkedUserId'] as String? ?? '';

    return {
      'profileId': doc.id,
      'name': name,
      'meta': relationship.isNotEmpty ? relationship : (hasOwn ? 'Linked account' : 'Dependent profile'),
      'initials': initials,
      'type': hasOwn ? 'linked' : 'dependent',
      'tag1': gender.isNotEmpty ? gender : '',
      'tag2': bloodType.isNotEmpty ? bloodType : '',
      'linkedUserId': linkedUserId,
      'hasOwnAccount': hasOwn.toString(),
    };
  }

  Future<void> addDependentProfile({
    required String ownerId,
    required String fullName,
    required String relationship,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodType,
    List<String> allergies = const [],
  }) async {
    final ref = _col.doc();
    await ref.set({
      'profileId': ref.id,
      'ownerId': ownerId,
      'hasOwnAccount': false,
      'linkedUserId': null,
      'fullName': fullName,
      'relationship': relationship,
      if (dateOfBirth != null) 'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'gender': ?gender,
      'bloodType': ?bloodType,
      'allergies': allergies,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteFamilyMember(String profileId) async {
    await _col.doc(profileId).delete();
  }
}
