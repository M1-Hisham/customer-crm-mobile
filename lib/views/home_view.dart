import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import '../utils/date_helper.dart';
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

    final Color royalGreen = const Color(0xFF1E3D30);
    final Color goldColor = const Color(0xFFB8963A);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Column(
        children: [
          // Header Widget
          Container(
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
            decoration: BoxDecoration(
              color: royalGreen,
              border: Border(bottom: BorderSide(color: goldColor, width: 1.5)),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => MainAppController.scaffoldKey.currentState?.openDrawer(),
                  icon: const Icon(Icons.menu, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'منصة الهاتف الآمنة',
                        style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'مرحباً، $name',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getRoleLabel(role),
                          style: TextStyle(color: goldColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                  ),
                )
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Stats Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.5,
                  children: [
                    _buildStatCard('إجمالي الموكلين', totalCustomers.toString(), goldColor, () => onTabChange('directory')),
                    _buildStatCard('إجمالي القضايا', totalCases.toString(), goldColor, () => onTabChange('cases')),
                    _buildStatCard('القضايا النشطة', activeCases.toString(), goldColor, () => onTabChange('cases')),
                    _buildStatCard('الجلسات المجدولة', scheduledAppts.toString(), goldColor, () => onTabChange('appointments')),
                  ],
                ),
                const SizedBox(height: 20),

                // Quick Actions Title
                const Text(
                  'إجراءات سريعة',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 10),

                // Quick Action Buttons
                Wrap(
                  spacing: 15,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildActionButton(Icons.person_add_alt_1_outlined, 'تسجيل موكل', royalGreen, () => onTabChange('reception')),
                    _buildActionButton(Icons.folder_shared_outlined, 'الموكلين', goldColor, () => onTabChange('directory')),
                    _buildActionButton(Icons.gavel_outlined, 'القضايا', Colors.blue, () => onTabChange('cases')),
                    _buildActionButton(Icons.chat_bubble_outline, 'المحادثة', Colors.green, () => onTabChange('chat')),
                    if (role != 'client')
                      _buildActionButton(Icons.location_on_outlined, 'تسجيل حضور', Colors.orange, () => onTabChange('attendance')),
                  ],
                ),
                const SizedBox(height: 24),

                // Upcoming Appointments Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'مواعيد الجلسات القادمة',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    TextButton(
                      onPressed: () => onTabChange('appointments'),
                      child: Row(
                        children: [
                          Text('عرض الكل', style: TextStyle(color: goldColor, fontSize: 11, fontWeight: FontWeight.bold)),
                          Icon(Icons.chevron_left, color: goldColor, size: 14),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

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
                  ...displayAppts.map((appt) => _buildAppointmentCard(appt, royalGreen, goldColor)),

                const SizedBox(height: 20),

                // Law Firm Message Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [royalGreen, royalGreen.withOpacity(0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: goldColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ميثاق العمل القانوني الآمن',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: goldColor),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'يلتزم مكتب حجاج الضويحي للمحاماة بأعلى معايير السرية والأمان في تداول بيانات الموكلين والقضايا الجنائية والمدنية. يرجى التأكد دائماً من تسجيل الخروج عند تسليم الأجهزة.',
                        style: TextStyle(fontSize: 10, color: Colors.white70, height: 1.5),
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

  Widget _buildStatCard(String label, String value, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          )
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment appt, Color green, Color gold) {
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
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  appt.court,
                  style: const TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_month, size: 12, color: gold),
              const SizedBox(width: 4),
              Text(
                '$formattedDate | $formattedTime',
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
          if (appt.caseTitle != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('القضية: ${appt.caseTitle}', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                  Text('رقم: ${appt.caseNumber}', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
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

// Simple filter helper for List
extension ListFilter<T> on List<T> {
  List<T> filter(bool Function(T) test) {
    return where(test).toList();
  }
}
