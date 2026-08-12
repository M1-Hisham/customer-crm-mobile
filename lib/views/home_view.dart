import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import '../utils/date_helper.dart';
import '../core/widgets/case_summary_card.dart';
import '../core/theme/app_theme.dart';
import '../main.dart';

class HomeView extends StatelessWidget {
  final List<Customer> customers;
  final List<Case> cases;
  final List<Appointment> appointments;
  final Function(String) onTabChange;

  const HomeView({
    super.key,
    required this.customers,
    required this.cases,
    required this.appointments,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    final user = ApiService().currentUser;
    final String name = user?.name ?? 'المستخدم';
    final String role = user?.role ?? '';
    
    // Stats
    final totalCustomers = customers.length;
    final totalCases = cases.length;
    final activeCases = cases.where((c) => c.status != 'مغلق').length;
    final scheduledAppts = appointments.where((a) => a.status == 'scheduled').length;

    // Filter upcoming appointments
    final now = DateTime.now();
    final upcoming = appointments
        .where((a) {
          try {
            final date = DateTime.parse(a.date);
            return date.isAfter(now) && a.status != 'cancelled';
          } catch (_) {
            return false;
          }
        })
        .toList();
    upcoming.sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));
    final displayAppts = upcoming.take(3).toList();

    const Color primaryEmerald = AppTheme.primaryNavy; // Color(0xFF0F172A)
    const Color goldAccent = AppTheme.secondaryGold; // Color(0xFFC5A880)

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header Widget (Najiz / Absher Style)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            decoration: const BoxDecoration(
              color: primaryEmerald,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => MainAppController.scaffoldKey.currentState?.openDrawer(),
                      icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        padding: const EdgeInsets.all(10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: goldAccent, width: 1.2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'شركة حجاج الضويحي للمحاماة',
                            style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Cairo'),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'مرحباً، $name',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: goldAccent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: goldAccent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _getRoleLabel(role),
                        style: const TextStyle(color: goldAccent, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary Card with Formatted Date
                CaseSummaryCard(
                  activeCases: activeCases,
                  nextSessionDate: displayAppts.isNotEmpty ? displayAppts.first.date : 'لا يوجد',
                ),
                const SizedBox(height: 18),

                // Featured Nearest Session Card
                Builder(
                  builder: (context) {
                    final myAppts = upcoming.where((a) => a.lawyerId == user?.uid || role == 'admin' || role == 'super_admin' || role == 'manager').toList();
                    if (myAppts.isEmpty) return const SizedBox.shrink();
                    final nearest = myAppts.first;

                    String dStr = nearest.date;
                    try {
                      dStr = DateHelper.formatDualDateTime(DateTime.parse(nearest.date));
                    } catch (_) {}

                    return Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3D30), Color(0xFF12251D)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: goldAccent, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E3D30).withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.push_pin_outlined, color: goldAccent, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    '📌 أقرب جلسة قضائية لك',
                                    style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  nearest.court,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            nearest.title,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                          ),
                          if (nearest.clientName != null && nearest.clientName!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'الموكل: ${nearest.clientName} (${nearest.clientRole ?? "مدعي"})',
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Cairo'),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.only(top: 8),
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: Colors.white12)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_filled, color: goldAccent, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      dStr,
                                      style: const TextStyle(color: goldAccent, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () => onTabChange('appointments'),
                                  style: TextButton.styleFrom(
                                    backgroundColor: goldAccent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('تفاصيل الجلسة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),


                // Section Title: Stats
                Row(
                  children: [
                    Container(width: 4, height: 16, decoration: BoxDecoration(color: primaryEmerald, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    const Text(
                      'إحصائيات النظام',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stats Grid (Unified clean white cards with gold numbers)
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    _buildStatCard('إجمالي الموكلين', totalCustomers.toString(), Icons.people_outline, () => onTabChange('directory')),
                    _buildStatCard('إجمالي القضايا', totalCases.toString(), Icons.folder_open, () => onTabChange('cases')),
                    _buildStatCard('القضايا النشطة', activeCases.toString(), Icons.gavel_outlined, () => onTabChange('cases')),
                    _buildStatCard('الجلسات المجدولة', scheduledAppts.toString(), Icons.calendar_month_outlined, () => onTabChange('appointments')),
                  ],
                ),
                const SizedBox(height: 22),

                // Section Title: Quick Actions
                Row(
                  children: [
                    Container(width: 4, height: 16, decoration: BoxDecoration(color: primaryEmerald, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    const Text(
                      'إجراءات سريعة',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Quick Action Buttons (UNIFIED elegant Emerald palette!)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton(Icons.person_add_alt_1_outlined, 'تسجيل موكل', () => onTabChange('reception')),
                      _buildActionButton(Icons.folder_shared_outlined, 'الموكلين', () => onTabChange('directory')),
                      _buildActionButton(Icons.gavel_outlined, 'القضايا', () => onTabChange('cases')),
                      _buildActionButton(Icons.chat_bubble_outline, 'المحادثة', () => onTabChange('chat')),
                      if (role != 'client')
                        _buildActionButton(Icons.location_on_outlined, 'تسجيل حضور', () => onTabChange('attendance')),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Upcoming Appointments Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 4, height: 16, decoration: BoxDecoration(color: primaryEmerald, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        const Text(
                          'مواعيد الجلسات القادمة',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => onTabChange('appointments'),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Text('عرض الكل', style: TextStyle(color: primaryEmerald, fontSize: 12, fontWeight: FontWeight.bold)),
                            Icon(Icons.chevron_left, color: primaryEmerald, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (displayAppts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.calendar_today_outlined, color: Colors.black26, size: 32),
                        SizedBox(height: 8),
                        Text(
                          'لا توجد جلسات مجدولة قادمة',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                else
                  ...displayAppts.map((appt) => _buildAppointmentCard(appt)),

                const SizedBox(height: 20),

                // Law Firm Security Notice Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryEmerald,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified_user_outlined, color: goldAccent, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'ميثاق العمل القانوني الآمن',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: goldAccent),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'يلتزم المكتب بأعلى معايير السرية والأمان في تداول بيانات الموكلين والقضايا. يرجى التصل التام بحدود الصلاحيات الممنوحة.',
                        style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primaryNavy, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.goldText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, color: AppTheme.primaryNavy, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          )
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment appt) {
    String formattedTime = '';
    String formattedDate = '';
    try {
      final date = DateTime.parse(appt.date);
      formattedDate = DateHelper.formatDualDate(date);
      formattedTime = DateFormat('hh:mm a', 'ar_SA').format(date);
    } catch (_) {
      formattedDate = appt.date;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  appt.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (appt.court.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    appt.court,
                    style: const TextStyle(color: AppTheme.primaryNavy, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.goldText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$formattedDate | $formattedTime',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          if (appt.caseTitle != null && appt.caseTitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'القضية: ${appt.caseTitle}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'رقم: ${appt.caseNumber}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'super_admin': return 'مشرف عام أول';
      case 'admin': return 'مشرف عام';
      case 'manager': return 'مدير إداري';
      case 'lawyer': return 'محامي مستشار';
      case 'trainee_lawyer': return 'محامي متدرب';
      case 'secretary': return 'سكرتير / موظف';
      case 'accountant': return 'محاسب';
      case 'receptionist':
      case 'reception': return 'موظف استقبال';
      case 'archive': return 'أخصائي أرشفة';
      default: return 'موظف';
    }
  }
}
