import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../services/ai_assistant.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/medicine_card.dart';
import '../widgets/stats_card.dart';
import 'add_edit_medicine_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final AIAssistant _aiAssistant = AIAssistant();
  final NotificationService _notificationService = NotificationService();
  final DatabaseService _db = DatabaseService();
  final AuthService _auth = AuthService();

  int _currentTabIndex = 0; // 0 = Jadwal, 1 = Kalender, 2 = Grafik, 3 = Profil
  List<Medicine> _medicines = [];
  List<MedicineLog> _logs = [];
  DateTime _selectedDate = DateTime.now();
  int _selectedFilter = 0; // 0 = Semua, 1 = Belum, 2 = Selesai

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    AppTheme.themeNotifier.addListener(_onThemeChanged);
    _initHome();
  }

  Future<void> _initHome() async {
    await _db.recordAppOpen();
    _loadData();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppTheme.themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _loadData() async {
    _medicines = _db.getAllMedicines();
    await _ensureLogsForDate(_selectedDate);
    if (!mounted) return;
    setState(() {
      _logs = _db.getLogsForDate(_selectedDate);
    });
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
      _logs = _db.getLogsForDate(normalized);
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi 🌤️';
    if (hour < 15) return 'Selamat Siang ☀️';
    if (hour < 18) return 'Selamat Sore 🌇';
    return 'Selamat Malam 🌙';
  }

  Future<void> _openAddMedicine([Medicine? medicine]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditMedicineScreen(medicine: medicine),
      ),
    );
    if (result == true) _loadData();
  }

  void _markAsTaken(MedicineLog log, {bool showDialogPraise = true}) async {
    final medicine = _medicines.where((m) => m.id == log.medicineId).firstOrNull;
    if (medicine == null) return;

    log.isTaken = true;
    log.takenTime = DateTime.now();
    await _db.updateLog(log);

    setState(() {
      _logs = _db.getLogsForDate(_selectedDate);
    });

    if (mounted && showDialogPraise) {
      _showAIResponse(
        context,
        _aiAssistant.generatePraiseMessage(medicine.name),
        isPositive: true,
      );
    }
  }

  void _unmarkAsTaken(MedicineLog log) async {
    log.isTaken = false;
    log.takenTime = null;
    await _db.updateLog(log);

    setState(() {
      _logs = _db.getLogsForDate(_selectedDate);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Status obat diubah menjadi Belum Diminum'),
          backgroundColor: AppColors.textSecondary,
        ),
      );
    }
  }

  /// Menghitung jumlah notifikasi jadwal obat hari ini yang sudah waktunya tapi belum diminum
  int _getPendingDueNotificationsCount() {
    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);
    final validIds = _medicines.map((m) => m.id).toSet();
    final todayLogs = _db
        .getLogsForDate(todayNorm)
        .where((l) => validIds.contains(l.medicineId))
        .toList();

    return todayLogs.where((log) {
      return !log.isTaken &&
          (log.scheduledTime.isBefore(now) ||
              log.scheduledTime.isAtSameMomentAs(now));
    }).length;
  }

  /// Menampilkan Bottom Sheet Notifikasi & Riwayat Aktivitas Buka Aplikasi
  Future<void> _showNotificationHistorySheet() async {
    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);
    await _ensureLogsForDate(todayNorm);
    await _db.markNotificationsRead();
    if (!mounted) return;
    setState(() {});

    final appOpenHistory = _db.getAppOpenHistory();
    final todayOpens = appOpenHistory
        .where((dt) => _isSameDay(dt, todayNorm))
        .toList();

    final validIds = _medicines.map((m) => m.id).toSet();
    final timeFormat = DateFormat('HH:mm');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final currentTodayLogs = _db
                .getLogsForDate(todayNorm)
                .where((l) => validIds.contains(l.medicineId))
                .toList()
              ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.84,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1.2),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header Sheet
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifikasi & Riwayat Aplikasi',
                              style: TextStyle(
                                fontSize: 17.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pantau apakah aplikasi sudah dibuka & status obat',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. KARTU STATUS BUKA APLIKASI HARI INI
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.successSoft.withValues(
                                alpha: AppColors.isDark ? 0.6 : 0.75,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(
                                          alpha: 0.18,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.verified_user_rounded,
                                        color: AppColors.success,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            todayOpens.isNotEmpty
                                                ? 'Aplikasi Sudah Dibuka Hari Ini'
                                                : 'Aplikasi Belum Dibuka Hari Ini',
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            todayOpens.isNotEmpty
                                                ? 'Dibuka ${todayOpens.length}x hari ini • Terakhir pukul ${timeFormat.format(todayOpens.first)}'
                                                : 'Belum ada aktivitas tercatat hari ini',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Aktif',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (appOpenHistory.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Divider(
                                    color: AppColors.success.withValues(
                                      alpha: 0.2,
                                    ),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Riwayat Waktu Aplikasi Dibuka:',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: appOpenHistory.take(6).map((dt) {
                                      final isToday = _isSameDay(dt, todayNorm);
                                      final label = isToday
                                          ? 'Hari ini • ${timeFormat.format(dt)}'
                                          : '${DateFormat('d MMM', 'id_ID').format(dt)} • ${timeFormat.format(dt)}';
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.access_time_filled_rounded,
                                              size: 12,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
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
                          ),

                          const SizedBox(height: 20),

                          // 2. RIWAYAT NOTIFIKASI PENGINGAT OBAT HARI INI
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Notifikasi Jadwal Hari Ini',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'EEEE, d MMM',
                                  'id_ID',
                                ).format(todayNorm),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (currentTodayLogs.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.notifications_off_outlined,
                                    size: 32,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Belum ada jadwal pengingat obat untuk hari ini.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...currentTodayLogs.map((log) {
                              final med = _medicines
                                  .where((m) => m.id == log.medicineId)
                                  .firstOrNull;
                              if (med == null) return const SizedBox.shrink();

                              final isTaken = log.isTaken;
                              final isPastDue =
                                  !isTaken && log.scheduledTime.isBefore(now);

                              final Color statusColor = isTaken
                                  ? AppColors.success
                                  : isPastDue
                                  ? AppColors.danger
                                  : AppColors.warning;

                              final String statusText = isTaken
                                  ? (log.takenTime != null
                                        ? 'Sudah Diminum • ${timeFormat.format(log.takenTime!)}'
                                        : 'Sudah Diminum ✓')
                                  : isPastDue
                                  ? 'Waktunya Minum / Belum Diminum!'
                                  : 'Menunggu Jadwal';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isPastDue
                                        ? AppColors.danger.withValues(
                                            alpha: 0.45,
                                          )
                                        : AppColors.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: med.color.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: Icon(
                                        med.icon,
                                        color: med.color,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  med.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                timeFormat.format(
                                                  log.scheduledTime,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            statusText,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: statusColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (!isTaken)
                                      GestureDetector(
                                        onTap: () {
                                          _markAsTaken(
                                            log,
                                            showDialogPraise: false,
                                          );
                                          setSheetState(() {});
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius:
                                                BorderRadius.circular(11),
                                          ),
                                          child: const Text(
                                            'Minum',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.success,
                                        size: 22,
                                      ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showReminder(MedicineLog log) {
    final medicine = _medicines.firstWhere((m) => m.id == log.medicineId);
    final timeFormat = DateFormat('HH:mm');

    _notificationService.playNotificationSound();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: medicine.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(medicine.icon, size: 44, color: medicine.color),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: medicine.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${DateFormat('d MMM yyyy', 'id_ID').format(log.scheduledTime)} • Pukul ${timeFormat.format(log.scheduledTime)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: medicine.color,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Waktunya Minum Obat ✨',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildSheetDetailRow(
                      icon: Icons.medication_rounded,
                      label: 'Nama Obat',
                      value: medicine.name,
                      color: medicine.color,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: AppColors.border, height: 1),
                    ),
                    _buildSheetDetailRow(
                      icon: Icons.science_rounded,
                      label: 'Dosis & Aturan',
                      value: medicine.dosage,
                      color: medicine.color,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.spa_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _aiAssistant.generateHealthTip(),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.isDark
                              ? AppColors.primaryLight
                              : AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showMotivation(log);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: AppColors.textSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        side: BorderSide(
                          color: AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: const Text(
                        'Belum',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _markAsTaken(log);
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text(
                        'Sudah Diminum',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: medicine.color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  void _showMotivation(MedicineLog log) {
    final medicine = _medicines.firstWhere((m) => m.id == log.medicineId);

    _showAIResponse(
      context,
      _aiAssistant.generateMotivationMessage(medicine.name),
      isPositive: false,
    );
  }

  void _showAIResponse(
    BuildContext context,
    String message, {
    required bool isPositive,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isPositive
                      ? AppColors.successSoft
                      : AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPositive
                      ? Icons.celebration_rounded
                      : Icons.favorite_rounded,
                  size: 44,
                  color: isPositive ? AppColors.success : AppColors.primary,
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 18),
              Text(
                isPositive ? 'Hebat Sekali! 🎉' : 'Pengingat Hangat 💚',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: isPositive
                        ? AppColors.success
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Mengerti',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteMedicine(Medicine medicine) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Hapus Pengingat Obat?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Apakah kamu yakin ingin menghapus jadwal "${medicine.name}"?',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Ya, Hapus',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (int i = 0; i < medicine.scheduleTimes.length; i++) {
        await _notificationService.cancelNotification(medicine.id.hashCode + i);
      }

      await _db.deleteMedicine(medicine.id);
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jadwal obat berhasil dihapus'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Soft ambient pastel blobs
          Positioned(
            top: -80,
            right: -50,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryLight.withValues(
                  alpha: AppColors.isDark ? 0.08 : 0.16,
                ),
              ),
            ),
          ),
          Positioned(
            top: 90,
            left: -70,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentLavender.withValues(
                  alpha: AppColors.isDark ? 0.06 : 0.10,
                ),
              ),
            ),
          ),

          SafeArea(
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                // TAB 0: BERANDA & JADWAL OBAT
                _buildScheduleTab(todayNorm),

                // TAB 1: KALENDER BULANAN & RIWAYAT PER HARI
                CalendarScreen(
                  key: ValueKey(
                    'cal_${AppColors.isDark}_${_selectedDate.millisecondsSinceEpoch}_${_logs.length}_${_logs.where((l) => l.isTaken).length}',
                  ),
                  initialDate: _selectedDate,
                  onDataChanged: _loadData,
                ),

                // TAB 2: GRAFIK & STATISTIK KEPATUHAN
                StatisticsScreen(
                  key: ValueKey(
                    'stats_${AppColors.isDark}_${_selectedDate.millisecondsSinceEpoch}_${_logs.length}_${_logs.where((l) => l.isTaken).length}',
                  ),
                  initialDate: _selectedDate,
                  onDataChanged: _loadData,
                ),

                // TAB 3: PROFIL SAYA
                ProfileScreen(
                  key: ValueKey('profile_${AppColors.isDark}'),
                  isEmbedded: true,
                ),
              ],
            ),
          ),
        ],
      ),

      // Tombol Tambah Obat (Tampil di Tab Jadwal)
      floatingActionButton: _currentTabIndex == 0
          ? Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.36),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openAddMedicine(),
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          'Tambah Obat',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,

      // Aesthetic Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.85)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: AppColors.isDark ? 0.22 : 0.04,
              ),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _buildBottomNavItem(
                  index: 0,
                  icon: Icons.medication_liquid_outlined,
                  activeIcon: Icons.medication_liquid_rounded,
                  label: 'Jadwal',
                ),
                _buildBottomNavItem(
                  index: 1,
                  icon: Icons.calendar_month_outlined,
                  activeIcon: Icons.calendar_month_rounded,
                  label: 'Kalender',
                ),
                _buildBottomNavItem(
                  index: 2,
                  icon: Icons.insert_chart_outlined_rounded,
                  activeIcon: Icons.bar_chart_rounded,
                  label: 'Grafik',
                ),
                _buildBottomNavItem(
                  index: 3,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentTabIndex == index;
    final activeColor = AppColors.isDark
        ? AppColors.primaryLight
        : AppColors.primaryDark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTabIndex = index;
          });
          if (index == 0 || index == 1 || index == 2) {
            _loadData();
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 22,
                color: isSelected ? activeColor : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? activeColor : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Konten Tab 0: Jadwal Obat Harian
  Widget _buildScheduleTab(DateTime todayNorm) {
    final isSelectedToday = _isSameDay(_selectedDate, todayNorm);
    final user = _auth.currentUser;
    final firstName = (user?.name != null && user!.name.trim().isNotEmpty)
        ? user.name.trim().split(' ').first
        : 'Sahabat Sehat';

    final validMedicineIds = _medicines.map((m) => m.id).toSet();
    final allSelectedDateLogs = _logs
        .where((l) => validMedicineIds.contains(l.medicineId))
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    final takenCount = allSelectedDateLogs.where((log) => log.isTaken).length;
    final totalCount = allSelectedDateLogs.length;
    final progress = totalCount > 0 ? takenCount / totalCount : 0.0;

    final filteredLogs = allSelectedDateLogs.where((log) {
      if (_selectedFilter == 1) return !log.isTaken;
      if (_selectedFilter == 2) return log.isTaken;
      return true;
    }).toList();

    final pendingDueCount = _getPendingDueNotificationsCount();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting + Tombol Mode Gelap + Tombol Notifikasi & Riwayat Aplikasi
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Halo, $firstName!',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tombol Cepat Mode Gelap / Terang (Ramah Mata)
                    GestureDetector(
                      onTap: () => AppTheme.toggleTheme(),
                      child: Tooltip(
                        message: AppColors.isDark
                            ? 'Ubah ke Mode Terang'
                            : 'Ubah ke Mode Gelap',
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            AppColors.isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            color: AppColors.isDark
                                ? AppColors.warning
                                : AppColors.textSecondary,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Tombol Notifikasi & Riwayat Buka Aplikasi
                    GestureDetector(
                      onTap: _showNotificationHistorySheet,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1.2,
                              ),
                            ),
                            child: Icon(
                              pendingDueCount > 0
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_none_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          if (pendingDueCount > 0)
                            Positioned(
                              top: -3,
                              right: -3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5.5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.surface,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  '$pendingDueCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            )
                          else
                            Positioned(
                              top: 9,
                              right: 10,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Compact Interactive 7-Day Strip (100% Overflow-Free)
                _buildInteractiveCalendarCard(todayNorm),

                const SizedBox(height: 16),

                // Stats Card
                StatsCard(
                      takenCount: takenCount,
                      totalCount: totalCount,
                      progress: progress,
                    )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0),

                const SizedBox(height: 22),

                // Section Header + Selected Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isSelectedToday
                            ? 'Jadwal Obat Hari Ini'
                            : 'Jadwal ${DateFormat('d MMM yyyy', 'id_ID').format(_selectedDate)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isSelectedToday)
                      GestureDetector(
                        onTap: () => _selectDate(todayNorm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'Hari Ini',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.isDark
                                  ? AppColors.primaryLight
                                  : AppColors.primaryDark,
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        DateFormat('EEEE, d MMM', 'id_ID').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        index: 0,
                        label: 'Semua (${allSelectedDateLogs.length})',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        index: 1,
                        label:
                            'Belum (${allSelectedDateLogs.length - takenCount})',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        index: 2,
                        label: 'Selesai ($takenCount)',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),

        // Medicine Schedule List or Aesthetic Empty State
        filteredLogs.isEmpty
            ? SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                  child: _buildEmptyState(
                    isFiltered: allSelectedDateLogs.isNotEmpty,
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final log = filteredLogs[index];
                    final medicine = _medicines.firstWhere(
                      (m) => m.id == log.medicineId,
                    );

                    return MedicineCard(
                          medicine: medicine,
                          log: log,
                          onTap: () => _showReminder(log),
                          onMarkAsTaken: () => _markAsTaken(log),
                          onUnmarkTaken: () => _unmarkAsTaken(log),
                          onEdit: () => _openAddMedicine(medicine),
                          onDelete: () => _deleteMedicine(medicine),
                        )
                        .animate()
                        .fadeIn(duration: 350.ms, delay: (60 * index).ms)
                        .slideY(begin: 0.1, end: 0);
                  }, childCount: filteredLogs.length),
                ),
              ),
      ],
    );
  }

  /// Kartu Kalender Mingguan Interaktif (Bebas Overflow)
  Widget _buildInteractiveCalendarCard(DateTime todayNorm) {
    final startOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppColors.isDark ? 0.18 : 0.025,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Bulan & Navigasi Minggu (Menggunakan Expanded agar tidak pernah overflow)
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentTabIndex = 1),
                  child: Text(
                    DateFormat('MMMM yyyy', 'id_ID').format(_selectedDate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _selectDate(
                  _selectedDate.subtract(const Duration(days: 7)),
                ),
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
                onTap: () => _selectDate(
                  _selectedDate.add(const Duration(days: 7)),
                ),
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
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _currentTabIndex = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 13,
                        color: AppColors.isDark
                            ? AppColors.primaryLight
                            : AppColors.primaryDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Bulanan',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.isDark
                              ? AppColors.primaryLight
                              : AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Baris 7 Hari yang Bisa Diklik
          Row(
            children: List.generate(7, (index) {
              final date = startOfWeek.add(Duration(days: index));
              final isSelected = _isSameDay(date, _selectedDate);
              final isToday = _isSameDay(date, todayNorm);
              final isPast = date.isBefore(todayNorm);
              final dayLabel = DateFormat('E', 'id_ID').format(date);
              final stats = _getDayStats(date);

              Color statusColor = AppColors.textMuted;
              IconData? statusIcon;
              if (stats.total > 0) {
                if (stats.taken >= stats.total) {
                  statusColor = AppColors.success;
                  statusIcon = Icons.check_circle_rounded;
                } else if (stats.taken > 0) {
                  statusColor = AppColors.warning;
                  statusIcon = Icons.timelapse_rounded;
                } else if (isPast) {
                  statusColor = AppColors.danger;
                  statusIcon = Icons.cancel_rounded;
                }
              }

              return Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppColors.primaryGradient : null,
                      color: isSelected
                          ? null
                          : isToday
                          ? AppColors.primarySoft.withValues(alpha: 0.6)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : isToday
                            ? AppColors.primary
                            : AppColors.border,
                        width: isToday && !isSelected ? 1.3 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.28,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          dayLabel,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.9)
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        if (stats.total == 0)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : AppColors.border,
                            ),
                          )
                        else if (statusIcon != null)
                          Icon(
                            statusIcon,
                            size: 13,
                            color: isSelected ? Colors.white : statusColor,
                          )
                        else
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? Colors.white : statusColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 10),
          // Info Bar Kecil Keterangan Status Kalender (Wrap agar bebas overflow)
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              _buildLegendItem(color: AppColors.success, label: 'Sudah Minum'),
              _buildLegendItem(color: AppColors.warning, label: 'Sebagian'),
              _buildLegendItem(color: AppColors.danger, label: 'Belum Minum'),
            ],
          ),
        ],
      ),
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

  Widget _buildFilterChip({required int index, required String label}) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool isFiltered}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFiltered
                  ? Icons.check_circle_outline_rounded
                  : Icons.medication_liquid_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isFiltered
                ? 'Tidak Ada Jadwal di Kategori Ini'
                : 'Belum Ada Jadwal Obat',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isFiltered
                ? 'Coba pilih kategori filter lain di atas untuk melihat jadwalmu.'
                : 'Yuk tambahkan pengingat obat atau vitamin pertamamu agar jadwal minum obat selalu teratur.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          if (!isFiltered) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => _openAddMedicine(),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text(
                'Buat Jadwal Obat Pertama',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}
