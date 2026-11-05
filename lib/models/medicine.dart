import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'medicine.g.dart';

@HiveType(typeId: 0)
class Medicine extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String dosage;

  @HiveField(3)
  List<String> scheduleTimes;

  @HiveField(4)
  int colorValue;

  @HiveField(5)
  int iconCodePoint;

  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.scheduleTimes,
    this.colorValue = 0xFF5EB19E,
    this.iconCodePoint = 0xe3c9, // Icons.medication
  });

  Color get color => Color(colorValue);

  IconData get icon {
    if (iconCodePoint == Icons.medication_rounded.codePoint) {
      return Icons.medication_rounded;
    } else if (iconCodePoint == Icons.medication_liquid_rounded.codePoint ||
        iconCodePoint == Icons.medication_liquid.codePoint) {
      return Icons.medication_liquid_rounded;
    } else if (iconCodePoint == Icons.vaccines_rounded.codePoint ||
        iconCodePoint == Icons.vaccines.codePoint) {
      return Icons.vaccines_rounded;
    } else if (iconCodePoint == Icons.healing_rounded.codePoint ||
        iconCodePoint == Icons.healing.codePoint) {
      return Icons.healing_rounded;
    } else if (iconCodePoint == Icons.water_drop_rounded.codePoint) {
      return Icons.water_drop_rounded;
    } else if (iconCodePoint == Icons.health_and_safety_rounded.codePoint ||
        iconCodePoint == Icons.health_and_safety.codePoint) {
      return Icons.health_and_safety_rounded;
    } else if (iconCodePoint == Icons.medical_services_rounded.codePoint ||
        iconCodePoint == Icons.medical_services.codePoint) {
      return Icons.medical_services_rounded;
    } else if (iconCodePoint == Icons.local_hospital_rounded.codePoint ||
        iconCodePoint == Icons.local_hospital.codePoint) {
      return Icons.local_hospital_rounded;
    } else if (iconCodePoint == Icons.medical_information.codePoint) {
      return Icons.medical_information;
    }
    return Icons.medication_rounded;
  }

  void setColor(Color color) {
    colorValue = color.toARGB32();
  }

  void setIcon(IconData icon) {
    iconCodePoint = icon.codePoint;
  }
}

@HiveType(typeId: 1)
class MedicineLog extends HiveObject {
  @HiveField(0)
  String medicineId;

  @HiveField(1)
  DateTime scheduledTime;

  @HiveField(2)
  DateTime? takenTime;

  @HiveField(3)
  bool isTaken;

  MedicineLog({
    required this.medicineId,
    required this.scheduledTime,
    this.takenTime,
    this.isTaken = false,
  });
}
