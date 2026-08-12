import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../services/api_service.dart';
import '../models/models.dart';
import '../core/widgets/luxury_header.dart';
import '../main.dart';

class AttendanceView extends StatefulWidget {
  const AttendanceView({Key? key}) : super(key: key);

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView>
    with SingleTickerProviderStateMixin {
  bool _checkedIn = false;
  bool _checkedOut = false;
  String? _checkInTime;
  String? _checkOutTime;
  bool _loading = false;
  String _statusMessage = 'لم تسجل بعد';
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    _loadTodayStatus();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatTime(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('hh:mm a', 'ar').format(dt);
  }

  Future<void> _loadTodayStatus() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getTodayAttendance();
      if (res['success'] == true) {
        final data = res['data'];
        setState(() {
          _checkedIn = data['checkIn'] != null;
          _checkedOut = data['checkOut'] != null;
          _checkInTime = data['checkIn']?['recorded_at'];
          _checkOutTime = data['checkOut']?['recorded_at'];
          if (_checkedOut) {
            _statusMessage = 'تم تسجيل الانصراف ✅';
          } else if (_checkedIn) {
            _statusMessage = 'أنت حاضر منذ ${_formatTime(_checkInTime)}';
          } else {
            _statusMessage = 'لم تسجل حضورك بعد';
          }
        });
      }
    } catch (_) {
      setState(() {
        _statusMessage = 'فشل تحديث الحالة اليومية';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<Position?> _getLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('يجب السماح بالوصول للموقع لتسجيل الحضور');
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showError('الوصول للموقع محظور — يرجى تفعيله من إعدادات الجهاز');
      return null;
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _register(String type) async {
    setState(() => _loading = true);
    try {
      final position = await _getLocation();
      if (position == null) return;

      Map<String, dynamic> res;
      if (type == 'check-in') {
        res = await ApiService().checkIn(position.latitude, position.longitude);
      } else {
        res = await ApiService().checkOut(position.latitude, position.longitude);
      }

      if (res['success'] == true) {
        _animController.forward(from: 0);
        await _loadTodayStatus();
        _showSuccess(res['message'] ?? 'تمت العملية بنجاح');
      } else {
        _showError(res['error'] ?? 'حدث خطأ غير متوقع');
      }
    } catch (e) {
      _showError('تعذر الاتصال بالخادم');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService().currentUser;
    final role = user?.role ?? '';
    final bool isAdmin = ['admin', 'super_admin', 'manager'].contains(role);

    final now = DateTime.now();
    final timeStr = DateFormat('hh:mm:ss a', 'ar').format(now);
    final dateStr = DateFormat('EEEE، d MMMM yyyy', 'ar').format(now);

    final Color royalGreen = const Color(0xFF1E3D30);
    final Color goldColor = const Color(0xFFB8963A);

    if (isAdmin) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Column(
            children: [
              LuxuryHeader(
                title: 'حضور وانصراف الموظفين',
                subtitle: 'إثبات الحضور بالبصمة الجغرافية والتقارير',
              ),
              Container(
                color: Colors.white,
                child: TabBar(
                  labelColor: royalGreen,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: goldColor,
                  labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(text: 'سجلي الشخصي'),
                    Tab(text: 'لوحة التحكم والتقارير'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Personal Attendance
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildPersonalAttendanceBody(context, royalGreen, goldColor, timeStr, dateStr),
                    ),
                    // Tab 2: Admin Reports
                    const AttendanceAdminReportView(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // For normal employees
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          LuxuryHeader(
            title: 'تسجيل الحضور الشخصي',
            subtitle: 'إثبات الحضور بالبصمة الجغرافية',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildPersonalAttendanceBody(context, royalGreen, goldColor, timeStr, dateStr),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalAttendanceBody(BuildContext context, Color royalGreen, Color goldColor, String timeStr, String dateStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),

        // Logo & Title
        const Text('⚖️', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(
          'تسجيل الحضور والانصراف',
          style: TextStyle(
            color: royalGreen,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        const Text(
          'مكتب حجاج عبدالرحمن الضويحي للمحاماة',
          style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Cairo'),
        ),

        const SizedBox(height: 24),

        // Live Clock
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: royalGreen,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: goldColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: Column(
            children: [
              Text(
                timeStr,
                style: TextStyle(
                  color: goldColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                dateStr,
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Cairo'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Status Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _checkedOut
                ? Colors.grey.shade200
                : _checkedIn
                    ? Colors.green.shade50
                    : Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _checkedOut
                  ? Colors.grey.shade400
                  : _checkedIn
                      ? Colors.green.shade300
                      : Colors.red.shade300,
            ),
          ),
          child: Row(
            children: [
              ScaleTransition(
                scale: _scaleAnim,
                child: Text(
                  _checkedOut ? '🚪' : _checkedIn ? '✅' : '🕐',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _checkedOut
                        ? Colors.grey.shade700
                        : _checkedIn
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Check-in Button
        _AttendanceButton(
          label: 'تسجيل الحضور',
          icon: Icons.login_rounded,
          color: Colors.green.shade600,
          disabledColor: Colors.grey.shade300,
          disabled: _checkedIn || _loading,
          time: _checkInTime != null ? 'تم الحضور: ${_formatTime(_checkInTime)}' : null,
          onPressed: () => _register('check-in'),
        ),

        const SizedBox(height: 16),

        // Check-out Button
        _AttendanceButton(
          label: 'تسجيل الانصراف',
          icon: Icons.logout_rounded,
          color: Colors.red.shade600,
          disabledColor: Colors.grey.shade300,
          disabled: !_checkedIn || _checkedOut || _loading,
          time: _checkOutTime != null ? 'تم الانصراف: ${_formatTime(_checkOutTime)}' : null,
          onPressed: () => _register('check-out'),
        ),

        if (_loading) ...[
          const SizedBox(height: 24),
          CircularProgressIndicator(color: goldColor),
          const SizedBox(height: 12),
          const Text(
            'جاري الاتصال والتحقق من الموقع (GPS)...',
            style: TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'Cairo'),
          ),
        ],

        const SizedBox(height: 24),

        // Info Note
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, color: goldColor, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'ملاحظة: يجب أن تكون متواجداً داخل حدود المكتب الجغرافية (50 متر كحد أقصى) لتتمكن من إتمام الحضور أو الانصراف بنجاح.',
                  style: TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'Cairo', height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttendanceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color disabledColor;
  final bool disabled;
  final String? time;
  final VoidCallback onPressed;

  const _AttendanceButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.disabledColor,
    required this.disabled,
    required this.onPressed,
    this.time,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: disabled ? disabledColor : color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: disabled ? Colors.grey.shade500 : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: disabled ? Colors.grey.shade600 : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                if (time != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    time!,
                    style: TextStyle(
                      color: disabled ? Colors.grey.shade500 : Colors.white70,
                      fontSize: 11,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── لوحة تحكم وتقارير المدير والمطور ──
class AttendanceAdminReportView extends StatefulWidget {
  const AttendanceAdminReportView({Key? key}) : super(key: key);

  @override
  State<AttendanceAdminReportView> createState() => _AttendanceAdminReportViewState();
}

class _AttendanceAdminReportViewState extends State<AttendanceAdminReportView> {
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;
  List<dynamic> _records = [];
  int _totalEmployees = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final res = await ApiService().getAttendanceReport(dateStr);
      if (res['success'] == true) {
        setState(() {
          _records = res['data'] ?? [];
          _totalEmployees = res['totalEmployees'] ?? 0;
        });
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('فشل تحميل تقارير الحضور', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadReport();
  }

  String _formatTime(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('hh:mm a', 'ar').format(dt);
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'super_admin': return 'مدير عام النظام';
      case 'admin': return 'مدير النظام';
      case 'manager': return 'مدير مكتب';
      case 'lawyer': return 'محامي مستشار';
      case 'trainee_lawyer': return 'محامي متدرب';
      case 'secretary': return 'سكرتير';
      case 'archive': return 'مسؤول الأرشيف';
      case 'reception':
      case 'receptionist': return 'موظف استقبال';
      default: return 'موظف';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color goldColor = const Color(0xFFB8963A);

    final presentCount = _records.where((r) => r['check_in_time'] != null).length;
    final absentCount = _totalEmployees > 0 ? (_totalEmployees - presentCount).clamp(0, 999) : 0;
    final checkedOutCount = _records.where((r) => r['check_out_time'] != null).length;

    return Column(
      children: [
        // Date Selector Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeDate(-1),
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy-MM-dd').format(_selectedDate),
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _selectedDate.day == DateTime.now().day && _selectedDate.month == DateTime.now().month && _selectedDate.year == DateTime.now().year
                    ? null
                    : () => _changeDate(1),
              ),
            ],
          ),
        ),

        // Summary Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard('حاضر', presentCount.toString(), Colors.green.shade50, Colors.green.shade700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard('غائب', absentCount.toString(), Colors.red.shade50, Colors.red.shade700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard('منصرف', checkedOutCount.toString(), Colors.blue.shade50, Colors.blue.shade700),
              ),
            ],
          ),
        ),

        // Records List
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: goldColor))
              : _records.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد سجلات حضور لهذا اليوم.',
                        style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReport,
                      color: goldColor,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _records.length,
                        itemBuilder: (context, idx) {
                          final r = _records[idx];
                          final name = r['user_name'] ?? 'موظف';
                          final role = r['user_role'] ?? '';
                          final shift = r['shift'] ?? 'morning';
                          final checkIn = r['check_in_time'];
                          final checkOut = r['check_out_time'];
                          final distance = r['check_in_distance'];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: checkIn == null
                                              ? Colors.red.shade50
                                              : checkOut != null
                                                  ? Colors.grey.shade100
                                                  : Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          checkIn == null
                                              ? 'غائب'
                                              : checkOut != null
                                                  ? 'منصرف'
                                                  : 'حاضر',
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: checkIn == null
                                                ? Colors.red.shade700
                                                : checkOut != null
                                                    ? Colors.grey.shade700
                                                    : Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        _getRoleLabel(role),
                                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: shift == 'evening' ? Colors.purple.shade50 : Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          shift == 'evening' ? 'مسائية' : 'صباحية',
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: shift == 'evening' ? Colors.purple.shade700 : Colors.amber.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('الحضور', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                                          Text(
                                            _formatTime(checkIn),
                                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('الانصراف', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                                          Text(
                                            _formatTime(checkOut),
                                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('GPS (المسافة)', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                                          Text(
                                            distance != null ? '${distance}م' : '—',
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: distance != null && distance > 50 ? Colors.red : Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textCol.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.bold, color: textCol),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: textCol.withOpacity(0.8), fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
