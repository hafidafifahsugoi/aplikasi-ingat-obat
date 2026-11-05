import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class CalendarScreen extends StatefulWidget {
  final DateTime initialDate;
  final VoidCallback? onDataChanged;

  const CalendarScreen({
    super.key,
    required this.initialDate,
    this.onDataChanged,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final DatabaseService _db = DatabaseService();

  late DateTime _selectedDate;
  late DateTime _focusedMonth;
  List<Medicine> _medicines = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    _loadData();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _loadData() async {
    _medicines = _db.getAllMedicines();
    await _ensureLogsForDate(_selectedDate);
    if (mounted) setState(() {});
  }

  Future<void> _ensureLogsForDate(DateTime date) async {
    final existingDateLogs = _db.getLogsForDate(date);

    for (var medicine in _medicines) {
      for (var timeStr in medicine.scheduleTimes) {
        final parts = timeStr.split(':');
        final scheduledTime = DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );

        final existingLog = existingDateLogs
            .where(
              (log) =>
                  log.medicineId == medicine.id &&
                  log.scheduledTime.hour == scheduledTime.hour &&
                  log.scheduledTime.minute == scheduledTime.minute,
            )
            .firstOrNull;

        if (existingLog == null) {
          final log = MedicineLog(
            medicineId: medicine.id,
            scheduledTime: scheduledTime,
          );
          await _db.addLog(log);
        }
      }
    }
  }

  ({int taken, int total, double ratio}) _getDayStats(DateTime date) {
    final validMedicineIds = _medicines.map((m) => m.id).toSet();
    final dayLogs = _db
        .getLogsForDate(date)
        .where((l) => validMedicineIds.contains(l.medicineId))
        .toList();

    final expectedTotal = _medicines.fold<int>(
      0,
      (sum, m) => sum + m.scheduleTimes.length,
    );

    if (dayLogs.isEmpty) {
      return (taken: 0, total: expectedTotal, ratio: 0.0);
    }

    final taken = dayLogs.where((l) => l.isTaken).length;
    final total =
        dayLogs.length > expectedTotal ? dayLogs.length : expectedTotal;
    final ratio = total > 0 ? (taken / total).clamp(0.0, 1.0) : 0.0;
    return (taken: taken, total: total, ratio: ratio);
  }

  Future<void> _selectDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    await _ensureLogsForDate(normalized);
    if (!mounted) return;
    setState(() {
      _selectedDate = normalized;
      if (_focusedMonth.year != normalized.year ||
          _focusedMonth.month != normalized.month) {
        _focusedMonth = DateTime(normalized.year, normalized.month, 1);
      }
    });
  }

  Future<void> _toggleLogStatus(MedicineLog log) async {
    log.isTaken = !log.isTaken;
    log.takenTime = log.isTaken ? DateTime.now() : null;
    await _db.updateLog(log);
    widget.onDataChanged?.call();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);

    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );
    final firstDayWeekday = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
      1,
    ).weekday;
    final leadingEmptySlots = firstDayWeekday - 1;

    final validMedicineIds = _medicines.map((m) => m.id).toSet();
    final selectedDayLogs = _db
        .getLogsForDate(_selectedDate)
        .where((l) => validMedicineIds.contains(l.medicineId))
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    final selectedStats = _getDayStats(_selectedDate);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kalender Obat',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Ketuk tanggal untuk melihat jadwal hari tersebut',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isSameDay(_selectedDate, todayNorm))
              GestureDetector(
                onTap: () => _selectDate(todayNorm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Hari Ini',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // Monthly Interactive Calendar Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // Month Header Navigation
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _focusedMonth = DateTime(
                          _focusedMonth.year,
                          _focusedMonth.month - 1,
                          1,
                        );
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        DateFormat('MMMM yyyy', 'id_ID').format(_focusedMonth),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _focusedMonth = DateTime(
                          _focusedMonth.year,
                          _focusedMonth.month + 1,
                          1,
                        );
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Weekday Headers
              Row(
                children: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min']
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),

              // Calendar Days Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: leadingEmptySlots + daysInMonth,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.92,
                ),
                itemBuilder: (context, idx) {
                  if (idx < leadingEmptySlots) {
                    return const SizedBox.shrink();
                  }
                  final dayNum = idx - leadingEmptySlots + 1;
                  final cellDate = DateTime(
                    _focusedMonth.year,
                    _focusedMonth.month,
                    dayNum,
                  );
                  final isSelected = _isSameDay(cellDate, _selectedDate);
                  final isToday = _isSameDay(cellDate, todayNorm);
                  final isPast = cellDate.isBefore(todayNorm);
                  final st = _getDayStats(cellDate);

                  Color? statusColor;
                  IconData? statusIcon;
                  if (st.total > 0) {
                    if (st.taken >= st.total) {
                      statusColor = AppColors.success;
                      statusIcon = Icons.check_circle_rounded;
                    } else if (st.taken > 0) {
                      statusColor = AppColors.warning;
                      statusIcon = Icons.timelapse_rounded;
                    } else if (isPast) {
                      statusColor = AppColors.danger;
                      statusIcon = Icons.cancel_rounded;
                    } else {
                      statusColor = AppColors.textMuted;
                    }
                  }

                  return GestureDetector(
                    onTap: () => _selectDate(cellDate),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppColors.primaryGradient : null,
                        color: isSelected
                            ? null
                            : isToday
                            ? AppColors.primarySoft
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : isToday
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (statusColor != null)
                            statusIcon != null
                                ? Icon(
                                    statusIcon,
                                    size: 12,
                                    color: isSelected
                                        ? Colors.white
                                        : statusColor,
                                  )
                                : Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? Colors.white
                                          : statusColor,
                                    ),
                                  ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),
              Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 10),

              Wrap(
                spacing: 14,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _buildLegendItem(
                    color: AppColors.success,
                    label: 'Sudah Minum',
                  ),
                  _buildLegendItem(
                    color: AppColors.warning,
                    label: 'Sebagian',
                  ),
                  _buildLegendItem(
                    color: AppColors.danger,
                    label: 'Belum Minum',
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06, end: 0),

        const SizedBox(height: 16),

        // Single Selected-Day Detail Card
        Container(
          padding: const EdgeInsets.all(18),
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
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event_note_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat(
                            'EEEE, d MMMM yyyy',
                            'id_ID',
                          ).format(_selectedDate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedStats.total == 0
                              ? 'Tidak ada jadwal obat'
                              : '${selectedStats.taken} dari ${selectedStats.total} jadwal sudah diminum',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: selectedStats.ratio >= 1.0
                          ? AppColors.successSoft
                          : selectedStats.taken > 0
                          ? AppColors.warningSoft
                          : AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${(selectedStats.ratio * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: selectedStats.ratio >= 1.0
                            ? AppColors.success
                            : selectedStats.taken > 0
                            ? AppColors.warning
                            : AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (selectedDayLogs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Belum ada obat terjadwal pada tanggal ini.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                ...selectedDayLogs.map((log) {
                  final med = _medicines.firstWhere(
                    (m) => m.id == log.medicineId,
                  );
                  final timeStr = DateFormat('HH:mm').format(log.scheduledTime);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: log.isTaken
                            ? AppColors.success.withValues(alpha: 0.35)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: log.isTaken
                                ? AppColors.successSoft
                                : med.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            log.isTaken
                                ? Icons.check_circle_rounded
                                : med.icon,
                            size: 20,
                            color: log.isTaken ? AppColors.success : med.color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                med.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Jam $timeStr • ${med.dosage}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _toggleLogStatus(log),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: log.isTaken
                                  ? AppColors.successSoft
                                  : med.color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              log.isTaken ? 'Sudah ✓' : 'Minum',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: log.isTaken
                                    ? AppColors.success
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideY(begin: 0.06, end: 0),
      ],
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
