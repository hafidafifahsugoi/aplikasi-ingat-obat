import 'package:hive_flutter/hive_flutter.dart';
import '../models/medicine.dart';
import '../models/user.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static const String medicineBoxName = 'medicines';
  static const String logBoxName = 'medicine_logs';
  static const String userBoxName = 'users';
  static const String sessionBoxName = 'session';

  Future<void> initialize() async {
    await Hive.initFlutter();
    Hive.registerAdapter(MedicineAdapter());
    Hive.registerAdapter(MedicineLogAdapter());
    Hive.registerAdapter(UserAdapter());
    await Hive.openBox<Medicine>(medicineBoxName);
    await Hive.openBox<MedicineLog>(logBoxName);
    await Hive.openBox<User>(userBoxName);
    await Hive.openBox(sessionBoxName);
  }

  Box<Medicine> get medicineBox => Hive.box<Medicine>(medicineBoxName);
  Box<MedicineLog> get logBox => Hive.box<MedicineLog>(logBoxName);
  Box<User> get userBox => Hive.box<User>(userBoxName);
  Box get sessionBox => Hive.box(sessionBoxName);

  // Medicine CRUD
  Future<void> addMedicine(Medicine medicine) async {
    await medicineBox.put(medicine.id, medicine);
  }

  Future<void> updateMedicine(Medicine medicine) async {
    await medicine.save();
  }

  Future<void> deleteMedicine(String id) async {
    await medicineBox.delete(id);
    final logsToDelete = logBox.values
        .where((log) => log.medicineId == id)
        .toList();
    for (var log in logsToDelete) {
      await log.delete();
    }
  }

  List<Medicine> getAllMedicines() {
    return medicineBox.values.toList();
  }

  Medicine? getMedicine(String id) {
    return medicineBox.get(id);
  }

  // Log CRUD
  Future<void> addLog(MedicineLog log) async {
    final key = '${log.medicineId}_${log.scheduledTime.millisecondsSinceEpoch}';
    await logBox.put(key, log);
  }

  Future<void> updateLog(MedicineLog log) async {
    await log.save();
  }

  List<MedicineLog> getLogsForDate(DateTime date) {
    return logBox.values.where((log) {
      return log.scheduledTime.year == date.year &&
          log.scheduledTime.month == date.month &&
          log.scheduledTime.day == date.day;
    }).toList();
  }

  List<MedicineLog> getAllLogs() {
    return logBox.values.toList();
  }

  Future<void> clearAllData() async {
    await medicineBox.clear();
    await logBox.clear();
  }

  // App Open & Notification History
  Future<void> recordAppOpen() async {
    final now = DateTime.now();
    final rawList =
        (sessionBox.get('appOpenHistory', defaultValue: <dynamic>[]) as List)
            .map((e) => e.toString())
            .toList();

    if (rawList.isNotEmpty) {
      final lastOpen = DateTime.tryParse(rawList.first);
      if (lastOpen != null && now.difference(lastOpen).inMinutes < 2) {
        return;
      }
    }

    rawList.insert(0, now.toIso8601String());
    if (rawList.length > 30) {
      rawList.removeRange(30, rawList.length);
    }
    await sessionBox.put('appOpenHistory', rawList);
  }

  List<DateTime> getAppOpenHistory() {
    final rawList =
        (sessionBox.get('appOpenHistory', defaultValue: <dynamic>[]) as List)
            .map((e) => DateTime.tryParse(e.toString()))
            .whereType<DateTime>()
            .toList();
    return rawList;
  }

  DateTime? getLastNotificationReadTime() {
    final str = sessionBox.get('lastNotifRead') as String?;
    return str != null ? DateTime.tryParse(str) : null;
  }

  Future<void> markNotificationsRead() async {
    await sessionBox.put('lastNotifRead', DateTime.now().toIso8601String());
  }
}
