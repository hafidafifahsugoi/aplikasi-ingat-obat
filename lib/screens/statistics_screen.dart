import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class StatisticsScreen extends StatefulWidget {
  final DateTime initialDate;
  final VoidCallback? onDataChanged;

  const StatisticsScreen({
    super.key,
    required this.initialDate,
    this.onDataChanged,
  });

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final DatabaseService _db = DatabaseService();

  late DateTime _selectedDate;
  List<Medicine> _medicines = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _loadData();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _loadData() async {
    _medicines = _db.getAllMedicines();
    if (mounted) setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);

    final daysInMonth = DateUtils.getDaysInMonth(
      _selectedDate.year,
      _selectedDate.month,
    );

    int fullCompletedDays = 0;
    int totalTakenInMonth = 0;
    double monthRatioSum = 0;
    int activeDaysInMonth = 0;

    for (int d = 1; d <= daysInMonth; d++) {
      final dt = DateTime(_selectedDate.year, _selectedDate.month, d);
      final st = _getDayStats(dt);
      totalTakenInMonth += st.taken;
      if (st.total > 0 && st.taken >= st.total) {
        fullCompletedDays++;
      }
      if (st.total > 0 && !dt.isAfter(todayNorm)) {
        monthRatioSum += st.ratio;
        activeDaysInMonth++;
      }
    }

    final monthAdherencePercent = activeDaysInMonth > 0
        ? ((monthRatioSum / activeDaysInMonth) * 100).round()
        : 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        // Header Title
        Text(
          'Grafik & Statistik',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Analisis kepatuhan & perkembangan minum obat pasien',
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 18),

        // 3 KPI Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                icon: Icons.verified_rounded,
                iconColor: AppColors.success,
                iconBg: AppColors.successSoft,
                value: '$fullCompletedDays Hari',
                label: 'Tuntas 100%',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniStatCard(
                icon: Icons.medication_rounded,
                iconColor: AppColors.primary,
                iconBg: AppColors.primarySoft,
                value: '$totalTakenInMonth',
                label: 'Dosis Diminum',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniStatCard(
                icon: Icons.insights_rounded,
                iconColor: AppColors.accentLavender,
                iconBg: AppColors.accentLavenderSoft,
                value: '$monthAdherencePercent%',
                label: 'Kepatuhan',
              ),
            ),
          ],
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),

        const SizedBox(height: 18),

        // Weekly Adherence Bar Chart Card
        _buildWeeklyChartCard(todayNorm)
            .animate()
            .fadeIn(delay: 80.ms, duration: 350.ms)
            .slideY(begin: 0.08, end: 0),

        const SizedBox(height: 18),

        // Per-Medicine Adherence Breakdown Card
        _buildMedicineBreakdownCard(todayNorm)
            .animate()
            .fadeIn(delay: 140.ms, duration: 350.ms)
            .slideY(begin: 0.08, end: 0),
      ],
    );
  }

  Widget _buildMiniStatCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChartCard(DateTime todayNorm) {
    final startOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    double totalRatioSum = 0;
    int activeDaysCount = 0;

    final weekDays = List.generate(7, (i) {
      final dt = startOfWeek.add(Duration(days: i));
      final st = _getDayStats(dt);
      if (st.total > 0 && !dt.isAfter(todayNorm)) {
        totalRatioSum += st.ratio;
        activeDaysCount++;
      }
      return (date: dt, stats: st);
    });

    final avgPercent = activeDaysCount > 0
        ? ((totalRatioSum / activeDaysCount) * 100).round()
        : 0;

    final rangeLabel =
        '${DateFormat('d MMM', 'id_ID').format(startOfWeek)} - ${DateFormat('d MMM', 'id_ID').format(endOfWeek)}';

    return Container(
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
                  Icons.bar_chart_rounded,
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
                      'Grafik Mingguan (7 Hari)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      rangeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(
                      const Duration(days: 7),
                    );
                  });
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 7));
                  });
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weekDays.map((item) {
                final dt = item.date;
                final st = item.stats;
                final isSelected = _isSameDay(dt, _selectedDate);
                final isPast = dt.isBefore(todayNorm);
                final dayLabel = DateFormat('E', 'id_ID').format(dt);

                Color barColor = AppColors.primary;
                if (st.total > 0) {
                  if (st.taken >= st.total) {
                    barColor = AppColors.success;
                  } else if (st.taken > 0) {
                    barColor = AppColors.warning;
                  } else if (isPast) {
                    barColor = AppColors.danger.withValues(alpha: 0.45);
                  } else {
                    barColor = AppColors.border;
                  }
                } else {
                  barColor = AppColors.border;
                }

                final fillFactor = st.total > 0
                    ? (st.ratio > 0 ? st.ratio : (isPast ? 0.12 : 0.06))
                    : 0.06;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDate = dt),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          st.total > 0 ? '${st.taken}/${st.total}' : '-',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Container(
                            width: 24,
                            alignment: Alignment.bottomCenter,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: AnimatedFractionallySizedBox(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                              heightFactor: fillFactor.clamp(0.06, 1.0),
                              widthFactor: 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primarySoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                dayLabel,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                '${dt.day}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rata-rata Kepatuhan Minggu Ini',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$avgPercent% Tuntas',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineBreakdownCard(DateTime todayNorm) {
    final startOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );

    return Container(
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
                  color: AppColors.accentLavenderSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pie_chart_outline_rounded,
                  color: AppColors.accentLavender,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Capaian per Obat (Hari Ini)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Rincian dosis yang sudah diminum untuk setiap obat',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_medicines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Belum ada daftar obat yang ditambahkan.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ..._medicines.map((med) {
              final dayLogs = _db
                  .getLogsForDate(_selectedDate)
                  .where((l) => l.medicineId == med.id)
                  .toList();
              final total = med.scheduleTimes.length;
              final taken = dayLogs.where((l) => l.isTaken).length;
              final ratio = total > 0 ? (taken / total).clamp(0.0, 1.0) : 0.0;

              int weekTaken = 0;
              for (int i = 0; i < 7; i++) {
                final dt = startOfWeek.add(Duration(days: i));
                weekTaken += _db
                    .getLogsForDate(dt)
                    .where((l) => l.medicineId == med.id && l.isTaken)
                    .length;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: med.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(med.icon, size: 17, color: med.color),
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${med.dosage} • $weekTaken dosis diminum minggu ini',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$taken/$total Hari Ini',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: med.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 7,
                        backgroundColor: AppColors.background,
                        valueColor: AlwaysStoppedAnimation<Color>(med.color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
