import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import '../utils/date_helper.dart';
import '../core/widgets/luxury_header.dart';

class AlertsView extends StatefulWidget {
  final List<Appointment> appointments;
  final VoidCallback onRefresh;

  const AlertsView({
    super.key,
    required this.appointments,
    required this.onRefresh,
  });

  @override
  State<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<AlertsView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, pending, completed, postponed, cancelled
  String? _updatingId;

  final Color royalGreen = const Color(0xFF1E3D30);
  final Color goldColor = const Color(0xFFB8963A);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getRemainingDaysInfo(String createdAtStr) {
    try {
      final created = DateTime.parse(createdAtStr);
      final today = DateTime.now();

      final createdDate = DateTime(created.year, created.month, created.day);
      final todayDate = DateTime(today.year, today.month, today.day);

      final diffDays = todayDate.difference(createdDate).inDays;
      final remaining = 30 - diffDays;

      return {
        'remaining': remaining,
        'elapsed': diffDays,
        'isOverdue': remaining < 0,
        'daysAbs': remaining.abs(),
      };
    } catch (_) {
      return {
        'remaining': 30,
        'elapsed': 0,
        'isOverdue': false,
        'daysAbs': 30,
      };
    }
  }

  Future<void> _handleStatusUpdate(String id, String newStatus) async {
    setState(() => _updatingId = id);
    try {
      await ApiService().updateAppointment(id, {'status': newStatus});
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث حالة الجلسة بنجاح', style: TextStyle()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('خطأ', style: TextStyle()),
            content: Text(err.toString(), style: const TextStyle()),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingId = null);
      }
    }
  }

  Future<void> _handleDismissAlert(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء التنبيه', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من إلغاء تنبيه هذه الجلسة؟ لن تظهر في قائمة التنبيهات مجدداً.', style: TextStyle(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع', style: TextStyle())),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، إلغاء التنبيه', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _updatingId = id);
    try {
      await ApiService().updateAppointment(id, {'requiresReply': false});
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء التنبيه للجلسة بنجاح', style: TextStyle()),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('خطأ', style: TextStyle()),
            content: Text(err.toString(), style: const TextStyle()),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingId = null);
      }
    }
  }

  Future<void> _handleDeleteAppointment(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الجلسة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من حذف هذه الجلسة نهائياً من النظام؟', style: TextStyle(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع', style: TextStyle())),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، احذف الجلسة', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _updatingId = id);
    try {
      await ApiService().deleteAppointment(id);
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الجلسة بنجاح', style: TextStyle()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('خطأ', style: TextStyle()),
            content: Text(err.toString(), style: const TextStyle()),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingId = null);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'postponed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'scheduled':
        return 'معلقة';
      case 'completed':
        return 'تم الرد';
      case 'postponed':
        return 'مؤجلة';
      case 'cancelled':
        return 'ملغاة';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ApiService().currentUser?.role ?? '';
    final canManage = role != 'accountant' && role != 'reception' && role != 'receptionist';

    // 1. Get all reply required hearings
    final allAlerts = widget.appointments.where((a) => a.requiresReply == true).toList();

    // 2. Filter search and status
    final filteredAlerts = allAlerts.where((a) {
      final matchesSearch = (a.title).toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (a.caseNumber ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (a.clientName ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (a.caseTitle ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (a.court).toLowerCase().contains(_searchQuery.toLowerCase());

      if (_statusFilter == 'all') return matchesSearch;
      if (_statusFilter == 'pending') return matchesSearch && a.status == 'scheduled';
      return matchesSearch && a.status == _statusFilter;
    }).toList();

    // 3. Stats calculations
    final totalCount = allAlerts.length;
    final pendingCount = allAlerts.where((a) => a.status == 'scheduled').length;
    final completedCount = allAlerts.where((a) => a.status == 'completed').length;
    final postponedCount = allAlerts.where((a) => a.status == 'postponed').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          LuxuryHeader(
            title: 'تنبيهات الرد على الجلسات',
            subtitle: 'المتابعة الدقيقة لردود الجلسات المحددة بزمن',
          ),
          // Visual Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatCard('إجمالي الجلسات للرد', totalCount.toString(), Icons.notifications_none, Colors.amber.shade800),
                  _buildStatCard('معلّقة (تحتاج رد)', pendingCount.toString(), Icons.hourglass_empty, Colors.red.shade700),
                  _buildStatCard('تم الرد عليها', completedCount.toString(), Icons.check_circle_outline, Colors.green.shade700),
                  _buildStatCard('جلسات مؤجلة', postponedCount.toString(), Icons.alarm_on, Colors.blue.shade700),
                ],
              ),
            ),
          ),

          // Search and Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'البحث برقم القضية، الموكل، المحكمة...',
                    hintStyle: const TextStyle(fontSize: 11),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                    fillColor: const Color(0xFFF8FAFC),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: goldColor),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Status Chips
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      {'id': 'all', 'label': 'الكل'},
                      {'id': 'pending', 'label': 'المعلّقة'},
                      {'id': 'completed', 'label': 'تم الرد'},
                      {'id': 'postponed', 'label': 'مؤجلة'},
                      {'id': 'cancelled', 'label': 'ملغاة'},
                    ].map((item) {
                      final active = _statusFilter == item['id'];
                      return Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: ChoiceChip(
                          label: Text(
                            item['label']!,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          selected: active,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _statusFilter = item['id']!);
                            }
                          },
                          selectedColor: royalGreen,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(color: active ? Colors.white : Colors.black87),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Alerts List
          Expanded(
            child: filteredAlerts.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 48, color: Colors.black26),
                        SizedBox(height: 12),
                        Text(
                          'لا توجد تنبيهات تطابق خياراتك حالياً',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
                        SizedBox(height: 4),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32.0),
                          child: Text(
                            'تنبيهات الرد على الجلسات تظهر وتعد تصاعدياً بمجرد تحديد خيار "مطلوب الرد" للجلسة.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredAlerts.length,
                    itemBuilder: (context, index) {
                      final appt = filteredAlerts[index];
                      final isPending = appt.status == 'scheduled';
                      final daysInfo = _getRemainingDaysInfo(appt.createdAt);
                      final remaining = daysInfo['remaining'] as int;
                      final isOverdue = daysInfo['isOverdue'] as bool;
                      final daysAbs = daysInfo['daysAbs'] as int;

                      // Urgency Styling
                      Color badgeBg = Colors.grey.shade100;
                      Color badgeText = Colors.grey.shade700;
                      Color cardBorder = const Color(0xFFE2E8F0);
                      Color cardBg = Colors.white;

                      if (isPending) {
                        if (isOverdue) {
                          badgeBg = Colors.red.shade50;
                          badgeText = Colors.red.shade800;
                          cardBorder = Colors.red.shade200;
                          cardBg = const Color(0xFFFFF5F5);
                        } else if (remaining <= 5) {
                          badgeBg = Colors.orange.shade50;
                          badgeText = Colors.orange.shade800;
                          cardBorder = Colors.orange.shade200;
                          cardBg = const Color(0xFFFFF9F2);
                        } else if (remaining <= 15) {
                          badgeBg = Colors.amber.shade50;
                          badgeText = Colors.amber.shade800;
                          cardBorder = Colors.amber.shade100;
                        } else {
                          badgeBg = Colors.green.shade50;
                          badgeText = Colors.green.shade800;
                        }
                      }

                      String alertLabel = '';
                      if (appt.status == 'completed') {
                        alertLabel = '✓ تم الرد بنجاح';
                        badgeBg = Colors.green.shade50;
                        badgeText = Colors.green.shade800;
                      } else if (appt.status == 'postponed') {
                        alertLabel = '⏱ تم التأجيل';
                        badgeBg = Colors.blue.shade50;
                        badgeText = Colors.blue.shade800;
                      } else if (appt.status == 'cancelled') {
                        alertLabel = '✕ ملغية';
                        badgeBg = Colors.red.shade50;
                        badgeText = Colors.red.shade800;
                      } else if (isOverdue) {
                        alertLabel = 'متأخرة! (منذ $daysAbs يوم)';
                      } else {
                        alertLabel = 'متبقي للرد: $remaining يوم';
                      }

                      // Date formatting
                      String dateStr = '';
                      try {
                        final parsed = DateTime.parse(appt.date);
                        dateStr = DateHelper.formatDualDateTime(parsed);
                      } catch (_) {
                        dateStr = appt.date;
                      }

                      String addedDateStr = '';
                      try {
                        final parsed = DateTime.parse(appt.createdAt);
                        addedDateStr = DateHelper.formatDualDate(parsed);
                      } catch (_) {
                        addedDateStr = appt.createdAt;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Urgency Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: badgeText.withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    alertLabel,
                                    style: TextStyle(
                                      color: badgeText,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      ),
                                  ),
                                ),
                                // Case number if available
                                if (appt.caseNumber != null && appt.caseNumber!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'قضية #${appt.caseNumber}',
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Title
                            Text(
                              appt.title,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 4),

                            // Case Title
                            if (appt.caseTitle != null && appt.caseTitle!.isNotEmpty)
                              Row(
                                children: [
                                  Icon(Icons.assignment_outlined, size: 14, color: goldColor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      appt.caseTitle!,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ),
                                ],
                              ),
                            const Divider(height: 16),

                            // Details block
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('الموكل: ${appt.clientName ?? "غير متوفر"}', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.account_balance_outlined, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('المحكمة: ${appt.court}', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.calendar_month_outlined, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text('تاريخ الجلسة: $dateStr', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('أضيفت بتاريخ: $addedDateStr', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                if (appt.lawyerName != null)
                                  Text('المحامي الممثل: ${appt.lawyerName}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                              ],
                            ),

                            // Notes block if present
                            if (appt.notes != null && appt.notes!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Text(
                                  'الملاحظات المطلوبة للرد:\n${appt.notes}',
                                  style: const TextStyle(fontSize: 9, color: Colors.black87, height: 1.4),
                                ),
                              ),
                            ],

                            // Action buttons row
                            const SizedBox(height: 12),
                            if (_updatingId == appt.id)
                              const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            else
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (isPending) ...[
                                    ElevatedButton.icon(
                                      onPressed: () => _handleStatusUpdate(appt.id, 'completed'),
                                      icon: const Icon(Icons.check, size: 12),
                                      label: const Text('تم الرد', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    ElevatedButton.icon(
                                      onPressed: () => _handleStatusUpdate(appt.id, 'postponed'),
                                      icon: const Icon(Icons.schedule, size: 12),
                                      label: const Text('تأجيل الجلسة', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber.shade700,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ] else ...[
                                    OutlinedButton(
                                      onPressed: () => _handleStatusUpdate(appt.id, 'scheduled'),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: royalGreen),
                                        foregroundColor: royalGreen,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('إرجاع للمعلّقة', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                  const SizedBox(width: 6),
                                  OutlinedButton.icon(
                                    onPressed: () => _handleDismissAlert(appt.id),
                                    icon: const Icon(Icons.notifications_off_outlined, size: 12, color: Colors.red),
                                    label: const Text('إلغاء التنبيه', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                  if (canManage) ...[
                                    const SizedBox(width: 6),
                                    OutlinedButton.icon(
                                      onPressed: () => _handleDeleteAppointment(appt.id),
                                      icon: const Icon(Icons.delete_forever_outlined, size: 12, color: Colors.red),
                                      label: const Text('حذف نهائي', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.red),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.all(12),
      width: 130,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 16, color: color),
              Text(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
