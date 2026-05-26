import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AppointmentService {
  AppointmentService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirebaseCollections.appointments);

  Stream<List<Map<String, String>>> watchAppointmentMaps(String userId) {
    return _col.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final list = snap.docs.map(_toUiMap).toList();
      list.sort((a, b) {
        final ap = a['period'] == 'past' ? 1 : 0;
        final bp = b['period'] == 'past' ? 1 : 0;
        return ap.compareTo(bp);
      });
      return list;
    });
  }

  Map<String, String> _toUiMap(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final dtField = d['dateTime'];
    DateTime dt = DateTime.now();
    if (dtField is Timestamp) dt = dtField.toDate();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final apptDay = DateTime(dt.year, dt.month, dt.day);
    final diff = apptDay.difference(today).inDays;

    String badge;
    if (diff == 0) {
      badge = 'TODAY';
    } else if (diff == 1) {
      badge = 'TOMORROW';
    } else if (diff > 1) {
      badge = 'IN $diff DAYS';
    } else {
      badge = '';
    }

    return {
      'appointmentId': doc.id,
      'day': DateFormat('d').format(dt),
      'month': DateFormat('MMM').format(dt).toUpperCase(),
      'year': DateFormat('yyyy').format(dt),
      'doctor': d['doctorName'] as String? ?? '',
      'badge': badge,
      'hospital': d['hospital'] as String? ?? '',
      'time': DateFormat.jm().format(dt),
      'note': d['notes'] as String? ?? '',
      'reminders': (d['reminderSettings'] as List?)?.join('|') ?? '',
      'period': dt.isBefore(DateTime.now()) ? 'past' : 'upcoming',
    };
  }

  Future<void> addAppointment({
    required String userId,
    required String doctorName,
    required String hospital,
    required DateTime dateTime,
    required String notes,
    List<String> reminderSettings = const [],
  }) async {
    final ref = _col.doc();
    await ref.set({
      'appointmentId': ref.id,
      'userId': userId,
      'doctorName': doctorName,
      'hospital': hospital,
      'dateTime': Timestamp.fromDate(dateTime),
      'notes': notes,
      'reminderSettings': reminderSettings,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
