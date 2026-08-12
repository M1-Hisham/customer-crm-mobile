import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import '../utils/date_helper.dart';
import '../core/widgets/staggered_list_item.dart';
import '../core/widgets/luxury_header.dart';

class AppointmentsView extends StatefulWidget {
  final List<Appointment> appointments;
  final List<Case> cases;
  final List<SystemUser> staff;
  final VoidCallback onAppointmentsUpdated;

  const AppointmentsView({
    super.key,
    required this.appointments,
    required this.cases,
    required this.staff,
    required this.onAppointmentsUpdated,
  });

  @override
  State<AppointmentsView> createState() => _AppointmentsViewState();
}

class _AppointmentsViewState extends State<AppointmentsView> {
  String _activeFilter = 'scheduled';
  bool _loading = false;

  // New Appointment Form States
  final _titleController = TextEditingController();
  final _courtController = TextEditingController(text: 'المحكمة العامة');
  final _notesController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _opposingNameController = TextEditingController();
  final _caseSubjectController = TextEditingController();
  String _clientRole = 'مدعي';
  String _opposingRole = 'مدعى عليه';
  String _caseId = '';
  DateTime? _selectedDateTime;
  String _assignedLawyerId = '';
  bool _requiresReply = false;

  final Color royalGreen = const Color(0xFF1E3D30);
  final Color goldColor = const Color(0xFFB8963A);

  @override
  void initState() {
    super.initState();
    final currentUser = ApiService().currentUser;
    if (currentUser != null) {
      _assignedLawyerId = currentUser.uid;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _courtController.dispose();
    _notesController.dispose();
    _clientNameController.dispose();
    _opposingNameController.dispose();
    _caseSubjectController.dispose();
    super.dispose();
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'scheduled': return 'مجدولة';
      case 'completed': return 'منتهية';
      case 'postponed': return 'مؤجلة';
      case 'cancelled': return 'ملغاة';
      default: return 'مجدولة';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled': return Colors.orange;
      case 'completed': return Colors.green;
      case 'postponed': return Colors.blue;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  Future<void> _handleCreateAppointment() async {
    final title = _titleController.text.trim();
    final court = _courtController.text.trim();
    
    if (title.isEmpty || _caseId.isEmpty || _selectedDateTime == null) {
      alert(context, 'الرجاء تعبئة حقول القضية وعنوان الجلسة وتاريخها.');
      return;
    }

    setState(() => _loading = true);
    
    try {
      final selectedCase = widget.cases.firstWhere((c) => c.id == _caseId);
      final selectedLawyer = widget.staff.firstWhere((u) => u.uid == _assignedLawyerId, orElse: () => ApiService().currentUser!);

      await ApiService().createAppointment({
        'caseId': _caseId,
        'caseNumber': selectedCase.caseNumber,
        'caseTitle': selectedCase.title,
        'title': title,
        'court': court,
        'date': _selectedDateTime!.toIso8601String(),
        'lawyerId': _assignedLawyerId,
        'lawyerName': selectedLawyer.name,
        'notes': _notesController.text.trim(),
        'status': 'scheduled',
        'requiresReply': _requiresReply,
        'clientName': _clientNameController.text.trim(),
        'clientRole': _clientRole,
        'opposingName': _opposingNameController.text.trim(),
        'opposingRole': _opposingRole,
        'caseSubject': _caseSubjectController.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onAppointmentsUpdated();
        _titleController.clear();
        _notesController.clear();
        _clientNameController.clear();
        _opposingNameController.clear();
        _caseSubjectController.clear();
        _caseId = '';
        _selectedDateTime = null;
      }
    } catch (err) {
      alert(context, err.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void alert(BuildContext context, String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(content: Text(msg)),
    );
  }

  void _showAddDialog() {
    _requiresReply = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final lawyers = widget.staff.where((u) => u.role == 'lawyer' || u.role == 'admin' || u.role == 'super_admin').toList();

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              minChildSize: 0.6,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('جدولة جلسة قضائية جديدة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Associated Case Dropdown
                      const Text('ربط الجلسة بملف قضية *', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _caseId.isEmpty ? null : _caseId,
                            hint: const Text('-- اختر ملف القضية القضائية --', style: TextStyle(fontSize: 12)),
                            isExpanded: true,
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                            onChanged: (v) {
                              setSheetState(() {
                                _caseId = v!;
                                final c = widget.cases.firstWhere((caseItem) => caseItem.id == _caseId);
                                _clientNameController.text = c.customerName;
                                _caseSubjectController.text = c.title;
                                _courtController.text = c.court;
                                if (_titleController.text.isEmpty) {
                                  _titleController.text = 'جلسة: ${c.title}';
                                }
                              });
                            },
                            items: widget.cases.map((Case c) {
                              return DropdownMenuItem<String>(
                                value: c.id,
                                child: Text('#${c.caseNumber} — ${c.title}'),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildDialogField(_titleController, 'موضوع الجلسة (العنوان) *', Icons.title),
                      const SizedBox(height: 10),

                      _buildDialogField(_courtController, 'مقر المحكمة / الدائرة', Icons.gavel),
                      const SizedBox(height: 12),

                      // New fields: clientName & clientRole
                      const Text('تفاصيل الموكل', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildDialogField(_clientNameController, 'اسم الموكل', Icons.person),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _clientRole,
                                  isExpanded: true,
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  onChanged: (v) {
                                    setSheetState(() {
                                      _clientRole = v!;
                                      _opposingRole = _clientRole == 'مدعي' ? 'مدعى عليه' : 'مدعي';
                                    });
                                  },
                                  items: const [
                                    DropdownMenuItem(value: 'مدعي', child: Text('مدعي')),
                                    DropdownMenuItem(value: 'مدعى عليه', child: Text('مدعى عليه')),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // New fields: opposingName & opposingRole
                      const Text('تفاصيل الطرف الآخر', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildDialogField(_opposingNameController, 'اسم الطرف الآخر', Icons.person_outline),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _opposingRole,
                                  isExpanded: true,
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  onChanged: (v) {
                                    setSheetState(() {
                                      _opposingRole = v!;
                                    });
                                  },
                                  items: const [
                                    DropdownMenuItem(value: 'مدعي', child: Text('مدعي')),
                                    DropdownMenuItem(value: 'مدعى عليه', child: Text('مدعى عليه')),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // New field: caseSubject
                      _buildDialogField(_caseSubjectController, 'موضوع الدعوى (السبب)', Icons.question_answer_outlined),
                      const SizedBox(height: 12),

                      // Date Time Picker
                      const Text('تاريخ ووقت الجلسة *', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null && mounted) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (time != null) {
                              setSheetState(() {
                                _selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                              });
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedDateTime == null
                                    ? 'اختر التاريخ والوقت'
                                    : DateHelper.formatDualDateTime(_selectedDateTime!),
                                style: const TextStyle(fontSize: 12),
                              ),
                              Icon(Icons.calendar_month, size: 18, color: goldColor),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Lawyer Dropdown
                      const Text('المحامي الممثل بالجلسة', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _assignedLawyerId,
                            isExpanded: true,
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                            onChanged: (v) => setSheetState(() => _assignedLawyerId = v!),
                            items: lawyers.map((SystemUser l) {
                              return DropdownMenuItem<String>(value: l.uid, child: Text(l.name));
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildDialogField(_notesController, 'ملاحظات ودفوع الجلسة', Icons.notes, maxLines: 3),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: _requiresReply,
                            activeColor: royalGreen,
                            onChanged: (val) {
                              setSheetState(() {
                                _requiresReply = val ?? false;
                              });
                            },
                          ),
                          const Text(
                            'مطلوب الرد عليها (تنبيه خاص للجلسة)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _handleCreateAppointment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: royalGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: BorderSide(color: goldColor),
                          ),
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                              : const Text('جدولة وتثبيت الموعد', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDialogField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11),
        prefixIcon: Icon(icon, size: 18),
        fillColor: Colors.white,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: goldColor)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.appointments.where((a) {
      if (_activeFilter == 'all') return true;
      if (_activeFilter == 'requires_reply') return a.requiresReply == true;
      return a.status == _activeFilter;
    }).toList();

    final userRole = ApiService().currentUser?.role ?? '';
    final canManage = userRole != 'accountant' && userRole != 'reception' && userRole != 'receptionist';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _showAddDialog,
              backgroundColor: royalGreen,
              icon: Icon(Icons.add, color: goldColor),
              label: const Text('جلسة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            )
          : null,
      body: Column(
        children: [
          LuxuryHeader(
            title: 'جدول الجلسات والمواعيد',
            subtitle: 'مواعيد الجلسات القضائية والتنبيهات المباشرة',
          ),
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  {'id': 'requires_reply', 'label': 'التنبيهات الخاصة'},
                  {'id': 'scheduled', 'label': 'المجدولة القريبة'},
                  {'id': 'completed', 'label': 'المنتهية سابقاً'},
                  {'id': 'postponed', 'label': 'المؤجلة'},
                  {'id': 'cancelled', 'label': 'الملغاة'},
                  {'id': 'all', 'label': 'كل التواريخ'},
                ].map((item) {
                  final active = _activeFilter == item['id'];
                  final isSpecial = item['id'] == 'requires_reply';
                  return Padding(
                    padding: const EdgeInsets.only(left: 6.0),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSpecial) ...[
                            const Icon(Icons.error_outline, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                          ],
                          Text(item['label']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      selected: active,
                      onSelected: (selected) {
                        if (selected) setState(() => _activeFilter = item['id']!);
                      },
                      selectedColor: isSpecial ? Colors.red.shade900 : royalGreen,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(color: active ? Colors.white : Colors.black87),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // List
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 40, color: Colors.black26),
                        SizedBox(height: 8),
                        Text('لا توجد جلسات في هذا التصنيف', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final appt = filtered[index];
                      
                      // Date parsing
                      String dateStr = '';
                      String timeStr = '';
                      bool isUpcomingSoon = false;
                      try {
                        final parsed = DateTime.parse(appt.date);
                        dateStr = DateHelper.formatDualDate(parsed);
                        timeStr = DateFormat('hh:mm a').format(parsed);
                        
                        final diff = parsed.difference(DateTime.now());
                        if (appt.status == 'scheduled' && !diff.isNegative && diff.inHours <= 24) {
                          isUpcomingSoon = true;
                        }
                      } catch (_) {
                        dateStr = appt.date;
                      }

                      return StaggeredListItem(
                        index: index,
                        child: Container(
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
                                  child: Text(appt.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                ),
                                Flexible(
                                  child: Row(
                                    children: [
                                      if (appt.requiresReply) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        margin: const EdgeInsets.only(left: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade900.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(99),
                                          border: Border.all(color: Colors.red.shade900.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.warning_amber_rounded, size: 8, color: Colors.red.shade900),
                                            const SizedBox(width: 2),
                                            Text(
                                              'مطلوب الرد',
                                              style: TextStyle(color: Colors.red.shade900, fontSize: 8, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (isUpcomingSoon) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        margin: const EdgeInsets.only(left: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(99),
                                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                                        ),
                                        child: const Text(
                                          'تبدأ خلال 24 ساعة',
                                          style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(appt.status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        _getStatusLabel(appt.status),
                                        style: TextStyle(color: _getStatusColor(appt.status), fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Row(
                                    children: [
                                      Icon(Icons.account_balance_outlined, size: 12, color: goldColor),
                                      const SizedBox(width: 4),
                                      Flexible(child: Text('المقر: ${appt.court}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis, maxLines: 1)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time, size: 12, color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 4),
                                      Flexible(child: Text('$dateStr | $timeStr', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis, maxLines: 1)),
                                    ],
                                  ),
                                )
                              ],
                            ),
                            if (appt.caseTitle != null) ...[
                              const SizedBox(height: 6),
                              Text('القضية المرتبطة: ${appt.caseTitle} (رقم: ${appt.caseNumber})', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                            if ((appt.clientName != null && appt.clientName!.isNotEmpty) || (appt.opposingName != null && appt.opposingName!.isNotEmpty) || (appt.caseSubject != null && appt.caseSubject!.isNotEmpty)) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (appt.clientName != null && appt.clientName!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('الموكل: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                            Expanded(child: Text('${appt.clientName} (${appt.clientRole ?? "مدعي"})', style: const TextStyle(fontSize: 10, color: Color(0xFF1E293B)))),
                                          ],
                                        ),
                                      ),
                                    if (appt.opposingName != null && appt.opposingName!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('الخصم: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                            Expanded(child: Text('${appt.opposingName} (${appt.opposingRole ?? "مدعى عليه"})', style: const TextStyle(fontSize: 10, color: Color(0xFF1E293B)))),
                                          ],
                                        ),
                                      ),
                                    if (appt.caseSubject != null && appt.caseSubject!.isNotEmpty)
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('موضوع الدعوى: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                          Expanded(child: Text(appt.caseSubject!, style: const TextStyle(fontSize: 10, color: Color(0xFF1E293B)))),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            if (appt.notes != null && appt.notes!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                                child: Text(appt.notes!, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), height: 1.4)),
                              )
                            ],
                             if (appt.postponeReason != null && appt.postponeReason!.isNotEmpty) ...[
                               const SizedBox(height: 8),
                               Container(
                                 width: double.infinity,
                                 padding: const EdgeInsets.all(8),
                                 decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                                 child: Text('📅 سبب التأجيل: ${appt.postponeReason!}', style: TextStyle(fontSize: 10, color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
                               )
                             ],
                             if (appt.sessionResult == 'judgment' && appt.deedNumber != null && appt.deedNumber!.isNotEmpty) ...[
                               const SizedBox(height: 8),
                               Container(
                                 width: double.infinity,
                                 padding: const EdgeInsets.all(8),
                                 decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade200)),
                                 child: Text('⚖️ حكم - صك رقم: ${appt.deedNumber!} ${appt.deedObjectionDeadline != null ? " | ⏰ آخر اعتراض: " + appt.deedObjectionDeadline! : ""}', style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                               )
                             ],
                             if (canManage) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('حذف الجلسة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                        content: const Text('هل أنت متأكد من حذف هذه الجلسة نهائياً من النظام؟', style: TextStyle()),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع', style: TextStyle())),
                                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('نعم، احذف الجلسة', style: TextStyle(color: Colors.red))),
                                        ],
                                      ),
                                    );

                                    if (confirm == true && mounted) {
                                      try {
                                        await ApiService().deleteAppointment(appt.id);
                                        widget.onAppointmentsUpdated();
                                      } catch (e) {
                                        alert(context, e.toString());
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                                  label: const Text('حذف الجلسة', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                ),
                              )
                            ]
                          ],
                        ),
                      ));
                    },
                  ),
          )
        ],
      ),
    );
  }
}
