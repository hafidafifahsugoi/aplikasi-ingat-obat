import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../models/medicine.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class AddEditMedicineScreen extends StatefulWidget {
  final Medicine? medicine; // null = add, not null = edit

  const AddEditMedicineScreen({super.key, this.medicine});

  @override
  State<AddEditMedicineScreen> createState() => _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends State<AddEditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final List<TimeOfDay> _scheduleTimes = [];

  Color _selectedColor = AppColors.medicinePalette[0];
  IconData _selectedIcon = Icons.medication_rounded;
  String _selectedMealRule = 'Sesudah makan';

  final List<String> _dosagePresets = [
    '1 Tablet',
    '2 Tablet',
    '1 Kapsul',
    '5 ml (1 Sdt)',
    '15 ml (1 Sdm)',
    '500 mg',
    '1 Sachet',
  ];

  final List<Map<String, dynamic>> _mealRules = [
    {'label': 'Sesudah makan', 'icon': Icons.restaurant_rounded},
    {'label': 'Sebelum makan', 'icon': Icons.no_meals_rounded},
    {'label': 'Saat makan', 'icon': Icons.soup_kitchen_rounded},
    {'label': 'Bebas', 'icon': Icons.check_circle_outline_rounded},
  ];

  final List<Map<String, dynamic>> _timePresets = [
    {
      'label': 'Pagi',
      'time': const TimeOfDay(hour: 7, minute: 0),
      'icon': Icons.wb_twilight_rounded,
    },
    {
      'label': 'Siang',
      'time': const TimeOfDay(hour: 12, minute: 30),
      'icon': Icons.wb_sunny_rounded,
    },
    {
      'label': 'Sore',
      'time': const TimeOfDay(hour: 17, minute: 0),
      'icon': Icons.wb_cloudy_rounded,
    },
    {
      'label': 'Malam',
      'time': const TimeOfDay(hour: 20, minute: 30),
      'icon': Icons.nights_stay_rounded,
    },
  ];

  final List<Map<String, dynamic>> _iconOptions = [
    {'icon': Icons.medication_rounded, 'label': 'Kapsul'},
    {'icon': Icons.medication_liquid_rounded, 'label': 'Sirup'},
    {'icon': Icons.vaccines_rounded, 'label': 'Suntik'},
    {'icon': Icons.healing_rounded, 'label': 'Tablet'},
    {'icon': Icons.water_drop_rounded, 'label': 'Tetes'},
    {'icon': Icons.health_and_safety_rounded, 'label': 'Vitamin'},
    {'icon': Icons.medical_services_rounded, 'label': 'Medis'},
    {'icon': Icons.local_hospital_rounded, 'label': 'Resep'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldChanged);
    _dosageController.addListener(_onFieldChanged);

    if (widget.medicine != null) {
      _nameController.text = widget.medicine!.name;
      final rawDosage = widget.medicine!.dosage;
      if (rawDosage.contains(' • ')) {
        final parts = rawDosage.split(' • ');
        _dosageController.text = parts[0].trim();
        final rule = parts.sublist(1).join(' • ').trim();
        if (_mealRules.any((r) => r['label'] == rule)) {
          _selectedMealRule = rule;
        } else {
          _selectedMealRule = '';
          _dosageController.text = rawDosage;
        }
      } else {
        _dosageController.text = rawDosage;
        _selectedMealRule = '';
      }

      _selectedColor = widget.medicine!.color;
      _selectedIcon = widget.medicine!.icon;

      for (var timeStr in widget.medicine!.scheduleTimes) {
        final parts = timeStr.split(':');
        _scheduleTimes.add(
          TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
        );
      }
    } else {
      _scheduleTimes.add(const TimeOfDay(hour: 8, minute: 0));
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _dosageController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  String _getCombinedDosage() {
    final base = _dosageController.text.trim();
    if (base.isEmpty) return '';
    if (_selectedMealRule.isNotEmpty) {
      return '$base • $_selectedMealRule';
    }
    return base;
  }

  void _sortTimes() {
    _scheduleTimes.sort((a, b) {
      final aMinutes = a.hour * 60 + a.minute;
      final bMinutes = b.hour * 60 + b.minute;
      return aMinutes.compareTo(bMinutes);
    });
  }

  bool _hasTime(TimeOfDay target) {
    return _scheduleTimes.any(
      (t) => t.hour == target.hour && t.minute == target.minute,
    );
  }

  void _togglePresetTime(TimeOfDay preset) {
    setState(() {
      final idx = _scheduleTimes.indexWhere(
        (t) => t.hour == preset.hour && t.minute == preset.minute,
      );
      if (idx >= 0) {
        _scheduleTimes.removeAt(idx);
      } else {
        _scheduleTimes.add(preset);
        _sortTimes();
      }
    });
  }

  Future<void> _addOrEditTime({int? editIndex}) async {
    final initial = editIndex != null
        ? _scheduleTimes[editIndex]
        : TimeOfDay.now();

    final time = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'PILIH WAKTU MINUM OBAT',
      cancelText: 'BATAL',
      confirmText: 'PILIH',
      builder: (context, child) {
        final isDark = AppColors.isDark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: _selectedColor,
                    onPrimary: Colors.white,
                    surface: AppColors.surface,
                    onSurface: AppColors.textPrimary,
                    secondary: _selectedColor.withValues(alpha: 0.25),
                  )
                : ColorScheme.light(
                    primary: _selectedColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppColors.textPrimary,
                    secondary: _selectedColor.withValues(alpha: 0.18),
                  ),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        if (editIndex != null) {
          _scheduleTimes[editIndex] = time;
        } else if (!_hasTime(time)) {
          _scheduleTimes.add(time);
        }
        _sortTimes();
      });
    }
  }

  void _removeTime(int index) {
    setState(() {
      _scheduleTimes.removeAt(index);
    });
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _getPeriodName(TimeOfDay time) {
    final h = time.hour;
    if (h >= 4 && h < 11) return 'Pagi';
    if (h >= 11 && h < 15) return 'Siang';
    if (h >= 15 && h < 18) return 'Sore';
    return 'Malam';
  }

  IconData _getPeriodIcon(TimeOfDay time) {
    final h = time.hour;
    if (h >= 4 && h < 11) return Icons.wb_twilight_rounded;
    if (h >= 11 && h < 15) return Icons.wb_sunny_rounded;
    if (h >= 15 && h < 18) return Icons.wb_cloudy_rounded;
    return Icons.nights_stay_rounded;
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    if (_scheduleTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text('Tambahkan minimal 1 jadwal waktu minum ya!')),
            ],
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final scheduleStrings = _scheduleTimes.map(_formatTime).toList();
    final combinedDosage = _getCombinedDosage();

    if (widget.medicine == null) {
      final medicine = Medicine(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        dosage: combinedDosage,
        scheduleTimes: scheduleStrings,
        colorValue: _selectedColor.toARGB32(),
        iconCodePoint: _selectedIcon.codePoint,
      );

      await DatabaseService().addMedicine(medicine);

      for (int i = 0; i < _scheduleTimes.length; i++) {
        final time = _scheduleTimes[i];
        final now = DateTime.now();
        final scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          time.hour,
          time.minute,
        );

        await NotificationService().scheduleNotification(
          id: medicine.id.hashCode + i,
          medicineName: medicine.name,
          dosage: medicine.dosage,
          scheduledTime: scheduledTime,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Jadwal obat berhasil ditambahkan!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      widget.medicine!.name = _nameController.text.trim();
      widget.medicine!.dosage = combinedDosage;
      widget.medicine!.scheduleTimes = scheduleStrings;
      widget.medicine!.setColor(_selectedColor);
      widget.medicine!.setIcon(_selectedIcon);

      await DatabaseService().updateMedicine(widget.medicine!);

      for (int i = 0; i < _scheduleTimes.length; i++) {
        await NotificationService().cancelNotification(
          widget.medicine!.id.hashCode + i,
        );

        final time = _scheduleTimes[i];
        final now = DateTime.now();
        final scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          time.hour,
          time.minute,
        );

        await NotificationService().scheduleNotification(
          id: widget.medicine!.id.hashCode + i,
          medicineName: widget.medicine!.name,
          dosage: widget.medicine!.dosage,
          scheduledTime: scheduledTime,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Jadwal obat berhasil diperbarui!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.medicine != null;
    final previewName = _nameController.text.trim().isEmpty
        ? 'Nama Obat Kamu'
        : _nameController.text.trim();
    final previewDosage = _getCombinedDosage().isEmpty
        ? '1 Tablet • Sesudah makan'
        : _getCombinedDosage();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -90,
            right: -60,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _selectedColor.withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: -70,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _selectedColor.withValues(alpha: 0.08),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom Aesthetic Top Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              isEdit ? 'Edit Pengingat Obat' : 'Tambah Obat Baru',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Atur jadwal & tampilan obatmu',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),

                // Main Scrollable Form Content
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                      children: [
                        _buildLivePreviewCard(
                          previewName: previewName,
                          previewDosage: previewDosage,
                        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 22),

                        // SECTION 1: DETAIL OBAT & DOSIS
                        _buildSectionContainer(
                          icon: Icons.edit_note_rounded,
                          title: 'Informasi Obat',
                          subtitle: 'Nama, takaran, dan aturan konsumsi',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Nama Obat / Vitamin'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Misal: Paracetamol, Vitamin C...',
                                  fillColor: AppColors.background,
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(10),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _selectedColor.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _selectedIcon,
                                      color: _selectedColor,
                                      size: 20,
                                    ),
                                  ),
                                  suffixIcon: _nameController.text.isNotEmpty
                                      ? IconButton(
                                          onPressed: () => _nameController.clear(),
                                          icon: Icon(
                                            Icons.cancel_rounded,
                                            color: AppColors.textMuted,
                                            size: 18,
                                          ),
                                        )
                                      : null,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Nama obat tidak boleh kosong ya';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),

                              _buildFieldLabel('Takaran / Dosis'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _dosageController,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Contoh: 1 Tablet, 500 mg, 5 ml...',
                                  fillColor: AppColors.background,
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(10),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _selectedColor.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.science_rounded,
                                      color: _selectedColor,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Takaran dosis harus diisi ya';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),

                              // Quick Dosage Presets
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _dosagePresets.map((preset) {
                                    final isMatched =
                                        _dosageController.text.trim().toLowerCase() ==
                                        preset.toLowerCase();
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _dosageController.text = preset;
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 13,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isMatched
                                                ? _selectedColor
                                                : AppColors.background,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isMatched
                                                  ? _selectedColor
                                                  : AppColors.border,
                                            ),
                                          ),
                                          child: Text(
                                            preset,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: isMatched
                                                  ? Colors.white
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),

                              const SizedBox(height: 18),
                              _buildFieldLabel('Waktu Konsumsi (Opsional)'),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _mealRules.map((rule) {
                                  final label = rule['label'] as String;
                                  final icon = rule['icon'] as IconData;
                                  final isSelected = _selectedMealRule == label;

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (_selectedMealRule == label) {
                                          _selectedMealRule = '';
                                        } else {
                                          _selectedMealRule = label;
                                        }
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 220),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _selectedColor.withValues(alpha: 0.14)
                                            : AppColors.background,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? _selectedColor
                                              : AppColors.border,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            icon,
                                            size: 16,
                                            color: isSelected
                                                ? _selectedColor
                                                : AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              color: isSelected
                                                  ? _selectedColor
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 80.ms, duration: 350.ms).slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 20),

                        // SECTION 2: JADWAL WAKTU MINUM
                        _buildSectionContainer(
                          icon: Icons.schedule_rounded,
                          title: 'Jadwal Minum Obat',
                          subtitle: 'Pilih rekomendasi waktu atau atur jam sendiri',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_scheduleTimes.length}x Sehari',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _selectedColor,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Pilih Cepat Waktu Umum'),
                              const SizedBox(height: 10),
                              Row(
                                children: _timePresets.map((preset) {
                                  final label = preset['label'] as String;
                                  final time = preset['time'] as TimeOfDay;
                                  final icon = preset['icon'] as IconData;
                                  final isAdded = _hasTime(time);

                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: GestureDetector(
                                        onTap: () => _togglePresetTime(time),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 220),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isAdded
                                                ? _selectedColor
                                                : AppColors.background,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: isAdded
                                                  ? _selectedColor
                                                  : AppColors.border,
                                            ),
                                            boxShadow: isAdded
                                                ? [
                                                    BoxShadow(
                                                      color: _selectedColor
                                                          .withValues(alpha: 0.25),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(
                                                icon,
                                                size: 20,
                                                color: isAdded
                                                    ? Colors.white
                                                    : AppColors.textSecondary,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                label,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: isAdded
                                                      ? Colors.white
                                                      : AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatTime(time),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: isAdded
                                                      ? Colors.white.withValues(
                                                          alpha: 0.9,
                                                        )
                                                      : AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: 18),
                              _buildFieldLabel('Daftar Jam Pengingat Aktif'),
                              const SizedBox(height: 10),

                              if (_scheduleTimes.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: AppColors.border,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.alarm_add_rounded,
                                        size: 36,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Belum ada jam yang dipilih.\nKetuk waktu di atas atau tambah jam kustom.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ...List.generate(_scheduleTimes.length, (index) {
                                  final time = _scheduleTimes[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: _selectedColor.withValues(alpha: 0.28),
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(18),
                                        onTap: () => _addOrEditTime(editIndex: index),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: _selectedColor.withValues(
                                                    alpha: 0.14,
                                                  ),
                                                  borderRadius: BorderRadius.circular(
                                                    13,
                                                  ),
                                                ),
                                                child: Icon(
                                                  _getPeriodIcon(time),
                                                  color: _selectedColor,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _formatTime(time),
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: AppColors
                                                            .textPrimary,
                                                        letterSpacing: 0.3,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Jadwal ${_getPeriodName(time)} • Ketuk untuk ubah',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors
                                                            .textSecondary,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () => _removeTime(index),
                                                child: Container(
                                                  width: 38,
                                                  height: 38,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.dangerSoft,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    color: AppColors.danger,
                                                    size: 19,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),

                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _addOrEditTime(),
                                  icon: Icon(
                                    Icons.more_time_rounded,
                                    color: _selectedColor,
                                    size: 20,
                                  ),
                                  label: Text(
                                    'Tambah Jam Kustom Lainnya',
                                    style: TextStyle(
                                      color: _selectedColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    side: BorderSide(
                                      color: _selectedColor.withValues(alpha: 0.5),
                                      width: 1.4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    backgroundColor: _selectedColor.withValues(
                                      alpha: 0.05,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 150.ms, duration: 350.ms).slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 20),

                        // SECTION 3: TEMA WARNA & IKON OBAT
                        _buildSectionContainer(
                          icon: Icons.palette_outlined,
                          title: 'Tampilan & Visual',
                          subtitle: 'Pilih warna pastel & ikon bentuk obatmu',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildFieldLabel('Warna Kartu Obat'),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _selectedColor.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      AppColors.getColorName(_selectedColor),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: _selectedColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: AppColors.medicinePalette.map((color) {
                                  final isSelected =
                                      color.toARGB32() == _selectedColor.toARGB32();
                                  return GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedColor = color),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 220),
                                      width: isSelected ? 38 : 32,
                                      height: isSelected ? 38 : 32,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.transparent,
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withValues(
                                              alpha: isSelected ? 0.45 : 0.2,
                                            ),
                                            blurRadius: isSelected ? 12 : 6,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            )
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: 22),
                              _buildFieldLabel('Pilih Bentuk / Ikon Obat'),
                              const SizedBox(height: 12),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _iconOptions.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      childAspectRatio: 1.05,
                                    ),
                                itemBuilder: (context, index) {
                                  final option = _iconOptions[index];
                                  final icon = option['icon'] as IconData;
                                  final label = option['label'] as String;
                                  final isSelected =
                                      icon.codePoint == _selectedIcon.codePoint;

                                  return GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedIcon = icon),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 220),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _selectedColor
                                            : AppColors.background,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? _selectedColor
                                              : AppColors.border,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: _selectedColor.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            icon,
                                            color: isSelected
                                                ? Colors.white
                                                : AppColors.textSecondary,
                                            size: 24,
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              color: isSelected
                                                  ? Colors.white
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 220.ms, duration: 350.ms).slideY(begin: 0.1, end: 0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sticky Floating Bottom Save Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.96),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
                ),
              ),
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveMedicine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        isEdit
                            ? 'Perbarui Pengingat Obat'
                            : 'Simpan Pengingat Obat',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreviewCard({
    required String previewName,
    required String previewDosage,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _selectedColor.withValues(alpha: 0.92),
            _selectedColor,
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _selectedColor.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Pratinjau Kartu Obat',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${_scheduleTimes.length} Jadwal/Hari',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(_selectedIcon, color: _selectedColor, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      previewName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      previewDosage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_scheduleTimes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _scheduleTimes.map((t) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time_filled_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatTime(t),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionContainer({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _selectedColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _selectedColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: AppColors.border, height: 1),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}
