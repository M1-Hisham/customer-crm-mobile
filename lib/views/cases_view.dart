import 'package:flutter/material.dart';
import '../main.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'documents_view.dart';
import '../utils/date_helper.dart';
import '../core/widgets/staggered_list_item.dart';
import '../core/widgets/luxury_header.dart';

class CasesView extends StatefulWidget {
  final List<Case> cases;
  final List<Appointment> appointments;
  final List<SystemUser> staff;
  final VoidCallback onCaseUpdated;
  final bool initialIsArchivedView;

  const CasesView({
    super.key,
    required this.cases,
    required this.appointments,
    required this.staff,
    required this.onCaseUpdated,
    this.initialIsArchivedView = false,
  });

  @override
  State<CasesView> createState() => _CasesViewState();
}

class _CasesViewState extends State<CasesView> {
  String _searchQuery = '';
  Case? _selectedCase;
  bool _isDetailsOpen = false;
  late bool _isArchivedView;

  @override
  void initState() {
    super.initState();
    _isArchivedView = widget.initialIsArchivedView;
  }

  // Form controllers
  final _actionController = TextEditingController();
  final _noteController = TextEditingController();
  bool _addingAction = false;
  bool _addingNote = false;

  final Color royalGreen = const Color(0xFF1E3D30);
  final Color goldColor = const Color(0xFFB8963A);

  Color _getStatusColor(String status) {
    switch (status) {
      case 'مفتوح': return Colors.green;
      case 'قيد النظر': return Colors.orange;
      case 'تحت المراجعة': return Colors.blue;
      case 'مغلق': return Colors.grey;
      default: return Colors.grey;
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'low': return Colors.grey;
      case 'medium': return Colors.blue;
      case 'high': return Colors.orange;
      case 'urgent': return Colors.red;
      default: return Colors.blue;
    }
  }

  String _getPriorityLabel(String? priority) {
    switch (priority) {
      case 'low': return 'أولوية منخفضة';
      case 'medium': return 'أولوية متوسطة';
      case 'high': return 'أولوية مرتفعة';
      case 'urgent': return 'أولوية عاجلة';
      default: return 'أولوية متوسطة';
    }
  }

  void _showEditRulingDialog(Case currentCase, Function setSheetState) {
    final textCtrl = TextEditingController(text: currentCase.ruling ?? '');
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('تعديل حكم القضية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: textCtrl,
            maxLines: 5,
            textDirection: ui.TextDirection.rtl,
            decoration: const InputDecoration(
              hintText: 'سجل منطوق الحكم القضائي هنا...',
              hintStyle: TextStyle(fontSize: 11),
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء', style: TextStyle()),
            ),
            TextButton(
              onPressed: () async {
                final newRuling = textCtrl.text.trim();
                Navigator.pop(dialogCtx);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('جاري حفظ الحكم...', style: TextStyle()), duration: Duration(seconds: 1)),
                );

                try {
                  final updatedCase = await ApiService().updateCase(currentCase.id, {'ruling': newRuling});
                  
                  setSheetState(() {
                    _selectedCase = updatedCase;
                  });
                  
                  widget.onCaseUpdated();
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حفظ الحكم بنجاح', style: TextStyle()), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل حفظ الحكم: $e', style: TextStyle()), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showDetailsSheet(Case c, {int initialTabIndex = 0}) {
    _selectedCase = c;
    _isDetailsOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        List<Appointment>? sheetAppointments;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (sheetAppointments == null) {
              sheetAppointments = widget.appointments.where((a) => a.caseId == c.id).toList();
            }

            Future<void> refreshSheetAppointments() async {
              try {
                final allAppts = await ApiService().getAppointments();
                setSheetState(() {
                  sheetAppointments = allAppts.where((a) => a.caseId == c.id).toList();
                });
              } catch (_) {}
            }

            Future<void> deleteHearingLocal(Appointment appt) async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  title: const Text('إلغاء موعد الجلسة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  content: const Text('هل أنت متأكد من إلغاء موعد هذه الجلسة نهائياً؟', style: TextStyle()),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('رجوع', style: TextStyle())),
                    TextButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('نعم، إلغاء الموعد', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  await ApiService().deleteAppointment(appt.id);
                  widget.onCaseUpdated();
                  await refreshSheetAppointments();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إلغاء الجلسة بنجاح', style: TextStyle()), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل الإلغاء: $e', style: TextStyle()), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            }

            void _showAddHearingDialogLocal() {
              final formKey = GlobalKey<FormState>();
              final titleCtrl = TextEditingController(text: 'جلسة: ${c.title}');
              final courtCtrl = TextEditingController(text: c.court);
              final notesCtrl = TextEditingController();
              final clientNameCtrl = TextEditingController(text: c.customerName);
              final opposingNameCtrl = TextEditingController();
              final caseSubjectCtrl = TextEditingController(text: c.title);
              
              String clientRole = 'مدعي';
              String opposingRole = 'مدعى عليه';
              DateTime? selectedDateTime;
              String assignedLawyerId = c.lawyerId ?? '';
              bool dialogLoading = false;
              bool requiresReply = false;

              final lawyers = widget.staff.where((u) => u.role == 'lawyer' || u.role == 'admin' || u.role == 'super_admin').toList();
              if (assignedLawyerId.isEmpty && lawyers.isNotEmpty) {
                assignedLawyerId = lawyers.first.uid;
              } else if (assignedLawyerId.isNotEmpty && !lawyers.any((l) => l.uid == assignedLawyerId)) {
                if (lawyers.isNotEmpty) {
                  assignedLawyerId = lawyers.first.uid;
                }
              }

              showDialog(
                context: context,
                builder: (dialogContext) {
                  return StatefulBuilder(
                    builder: (dialogContext, setDialogState) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Row(
                          children: [
                            Icon(Icons.calendar_month, color: goldColor),
                            const SizedBox(width: 8),
                            const Text(
                              'جدولة جلسة قضائية جديدة',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        content: SizedBox(
                          width: MediaQuery.of(dialogContext).size.width * 0.9,
                          child: Form(
                            key: formKey,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('موضوع الجلسة (العنوان) *'),
                                  TextFormField(
                                    controller: titleCtrl,
                                    validator: (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
                                    decoration: _getInputDecoration('مثال: جلسة المرافعة الأولى'),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  _buildLabel('مقر المحكمة / الدائرة *'),
                                  TextFormField(
                                    controller: courtCtrl,
                                    validator: (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
                                    decoration: _getInputDecoration('مثال: المحكمة التجارية بالرياض'),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  _buildLabel('اسم الموكل وصفته *'),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: TextFormField(
                                          controller: clientNameCtrl,
                                          validator: (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
                                          decoration: _getInputDecoration('اسم الموكل'),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: DropdownButtonFormField<String>(
                                          value: clientRole,
                                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                                          items: const [
                                            DropdownMenuItem(value: 'مدعي', child: Text('مدعي', style: TextStyle())),
                                            DropdownMenuItem(value: 'مدعى عليه', child: Text('مدعى عليه', style: TextStyle())),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setDialogState(() {
                                                clientRole = val;
                                                opposingRole = clientRole == 'مدعي' ? 'مدعى عليه' : 'مدعي';
                                              });
                                            }
                                          },
                                          decoration: _getInputDecoration(''),
                                        ),
                                      ),
                                    ],
                                  ),
                                  _buildLabel('اسم الطرف الآخر وصفته'),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: TextFormField(
                                          controller: opposingNameCtrl,
                                          decoration: _getInputDecoration('الخصم / الطرف الآخر'),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: DropdownButtonFormField<String>(
                                          value: opposingRole,
                                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                                          items: const [
                                            DropdownMenuItem(value: 'مدعي', child: Text('مدعي', style: TextStyle())),
                                            DropdownMenuItem(value: 'مدعى عليه', child: Text('مدعى عليه', style: TextStyle())),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setDialogState(() => opposingRole = val);
                                            }
                                          },
                                          decoration: _getInputDecoration(''),
                                        ),
                                      ),
                                    ],
                                  ),
                                  _buildLabel('موضوع الدعوى (السبب)'),
                                  TextFormField(
                                    controller: caseSubjectCtrl,
                                    decoration: _getInputDecoration('موضوع الدعوى بالتفصيل'),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  _buildLabel('تاريخ ووقت الجلسة *'),
                                  InkWell(
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: dialogContext,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                                      );
                                      if (date != null && dialogContext.mounted) {
                                        final time = await showTimePicker(
                                          context: dialogContext,
                                          initialTime: TimeOfDay.now(),
                                        );
                                        if (time != null) {
                                          setDialogState(() {
                                            selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                                          });
                                        }
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            selectedDateTime == null
                                                ? 'اختر التاريخ والوقت'
                                                : DateFormat('yyyy/MM/dd | hh:mm a', 'ar_SA').format(selectedDateTime!),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: selectedDateTime == null ? Colors.black38 : Colors.black87,
                                            ),
                                          ),
                                          Icon(Icons.calendar_today, size: 16, color: goldColor),
                                        ],
                                      ),
                                    ),
                                  ),
                                  _buildLabel('المحامي المسؤول الممثل بالجلسة'),
                                  DropdownButtonFormField<String>(
                                    value: assignedLawyerId.isEmpty ? null : assignedLawyerId,
                                    isExpanded: true,
                                    items: lawyers.map((l) => DropdownMenuItem<String>(
                                      value: l.uid,
                                      child: Text(l.name, style: const TextStyle(fontSize: 11)),
                                    )).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(() => assignedLawyerId = val);
                                      }
                                    },
                                    decoration: _getInputDecoration(''),
                                  ),
                                  _buildLabel('ملاحظات ودفوع الجلسة'),
                                  TextFormField(
                                    controller: notesCtrl,
                                    maxLines: 2,
                                    decoration: _getInputDecoration('ملاحظات ودفوع الجلسة...'),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: requiresReply,
                                        activeColor: royalGreen,
                                        onChanged: (val) {
                                          setDialogState(() {
                                            requiresReply = val ?? false;
                                          });
                                        },
                                      ),
                                      const Text(
                                        'مطلوب الرد عليها (تنبيه خاص)',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ),
                          ElevatedButton(
                            onPressed: dialogLoading ? null : () async {
                              if (formKey.currentState?.validate() ?? false) {
                                if (selectedDateTime == null) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    const SnackBar(content: Text('الرجاء اختيار تاريخ ووقت الجلسة', style: TextStyle()), backgroundColor: Colors.red),
                                  );
                                  return;
                                }
                                setDialogState(() => dialogLoading = true);
                                try {
                                  final selectedLawyer = widget.staff.firstWhere((u) => u.uid == assignedLawyerId, orElse: () => ApiService().currentUser!);
                                  await ApiService().createAppointment({
                                    'caseId': c.id,
                                    'caseNumber': c.caseNumber,
                                    'caseTitle': c.title,
                                    'title': titleCtrl.text.trim(),
                                    'court': courtCtrl.text.trim(),
                                    'date': selectedDateTime!.toIso8601String(),
                                    'lawyerId': assignedLawyerId,
                                    'lawyerName': selectedLawyer.name,
                                    'notes': notesCtrl.text.trim(),
                                    'status': 'scheduled',
                                    'requiresReply': requiresReply,
                                    'clientName': clientNameCtrl.text.trim(),
                                    'clientRole': clientRole,
                                    'opposingName': opposingNameCtrl.text.trim(),
                                    'opposingRole': opposingRole,
                                    'caseSubject': caseSubjectCtrl.text.trim(),
                                  });
                                  Navigator.pop(dialogContext); // close dialog
                                  widget.onCaseUpdated();
                                  await refreshSheetAppointments();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('تمت جدولة الجلسة بنجاح', style: TextStyle()), backgroundColor: Colors.green),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('فشل الجدولة: $e', style: TextStyle()), backgroundColor: Colors.red),
                                    );
                                  }
                                } finally {
                                  setDialogState(() => dialogLoading = false);
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: royalGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: dialogLoading
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white))
                                : const Text('جدولة الجلسة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            }

            final userRole = ApiService().currentUser?.role ?? '';
            final canManageAppts = userRole != 'accountant' && userRole != 'reception' && userRole != 'receptionist';
            final currentUid = ApiService().currentUser?.uid ?? '';
            final canEditRuling = (userRole == 'admin' || userRole == 'super_admin' || userRole == 'manager' || userRole == 'archive' || (userRole == 'lawyer' && _selectedCase!.lawyerId == currentUid));

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              minChildSize: 0.6,
              expand: false,
              builder: (context, scrollController) {
                return DefaultTabController(
                  length: 3,
                  initialIndex: initialTabIndex,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 12, top: 8),
                          decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedCase!.title,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: royalGreen),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Chip(
                              label: Text(_selectedCase!.status, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                              backgroundColor: _getStatusColor(_selectedCase!.status),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            )
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'رقم القضية: ${_selectedCase!.caseNumber} | المحكمة: ${_selectedCase!.court}',
                          style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TabBar(
                        indicatorColor: goldColor,
                        labelColor: royalGreen,
                        unselectedLabelColor: Colors.grey,
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        tabs: const [
                          Tab(text: 'تفاصيل القضية'),
                          Tab(text: 'الجلسات'),
                          Tab(text: 'المستندات'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Tab 1: Details
                            SingleChildScrollView(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow('الموكل:', _selectedCase!.customerName),
                                  _buildDetailRow('صفة الموكل:', _selectedCase!.clientType ?? 'موكّل'),
                                  _buildDetailRow('تصنيف الدعوى:', _selectedCase!.caseType),
                                  _buildDetailRow(
                                    'الأولوية القضائية:', 
                                    _getPriorityLabel(_selectedCase!.priority),
                                    customVal: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: _getPriorityColor(_selectedCase!.priority).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                      child: Text(_getPriorityLabel(_selectedCase!.priority), style: TextStyle(color: _getPriorityColor(_selectedCase!.priority), fontSize: 8, fontWeight: FontWeight.bold)),
                                    )
                                  ),
                                  _buildDetailRow('المستشار الموكل:', _selectedCase!.lawyerName ?? 'غير مسند', valColor: goldColor),
                                  _buildDetailRow(
                                    'رؤية المحامي المتدرب:',
                                    _selectedCase!.traineeAccess == 'all'
                                        ? 'يظهر للجميع'
                                        : _selectedCase!.traineeAccess == 'specific'
                                            ? 'متدرب محدد (${_selectedCase!.traineeName ?? 'غير محدد'})'
                                            : 'لا يظهر لأي متدرب',
                                    valColor: _selectedCase!.traineeAccess == 'all'
                                        ? royalGreen
                                        : _selectedCase!.traineeAccess == 'specific'
                                            ? royalGreen
                                            : Colors.red,
                                  ),
                                  if (_selectedCase!.estimatedFee != null)
                                    _buildDetailRow('الأتعاب المقدرة:', '${_selectedCase!.estimatedFee} ريال', valColor: royalGreen),
                                  if (_selectedCase!.hearingDate != null)
                                    _buildDetailRow('تاريخ الجلسة القادمة:', DateHelper.formatDualDate(_selectedCase!.hearingDate), valColor: Colors.red),
                                  
                                  if (_selectedCase!.description.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    const Text('موضوع الدعوى بالتفصيل:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(_selectedCase!.description, style: const TextStyle(fontSize: 11, height: 1.5)),
                                    ),
                                  ],
                                  const SizedBox(height: 10),

                                  // Ruling Section
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.gavel, size: 14, color: goldColor),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'حكم القضية (القرار النهائي):',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                      if (canEditRuling)
                                        TextButton.icon(
                                          onPressed: () => _showEditRulingDialog(_selectedCase!, setSheetState),
                                          icon: Icon(Icons.edit, size: 12, color: goldColor),
                                          label: Text(
                                            _selectedCase!.ruling == null || _selectedCase!.ruling!.isEmpty ? 'إضافة حكم' : 'تعديل الحكم',
                                            style: TextStyle(fontSize: 10, color: goldColor, fontWeight: FontWeight.bold),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB), // light amber background
                                      border: Border.all(color: const Color(0xFFFDE68A)), // amber border
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _selectedCase!.ruling != null && _selectedCase!.ruling!.isNotEmpty
                                          ? _selectedCase!.ruling!
                                          : 'لا يوجد حكم مسجل لهذه القضية بعد.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.5,
                                        color: _selectedCase!.ruling != null && _selectedCase!.ruling!.isNotEmpty
                                            ? Colors.black
                                            : Colors.grey,
                                        fontStyle: _selectedCase!.ruling != null && _selectedCase!.ruling!.isNotEmpty
                                            ? FontStyle.normal
                                            : FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Attachments List
                                  _buildHeaderSection(Icons.attach_file_outlined, 'المرفقات والمستندات القانونية (ملخص)'),
                                  const SizedBox(height: 10),
                                  _buildAttachmentsList(_selectedCase!.attachments),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),

                            // Tab 2: Hearings (الجلسات)
                            Column(
                              children: [
                                const SizedBox(height: 8),
                                if (canManageAppts)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _showAddHearingDialogLocal,
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('جدولة جلسة جديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: royalGreen,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          side: BorderSide(color: goldColor),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: sheetAppointments == null
                                      ? const Center(child: CircularProgressIndicator())
                                      : sheetAppointments!.isEmpty
                                          ? const Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.calendar_month_outlined, size: 36, color: Colors.black26),
                                                  SizedBox(height: 6),
                                                  Text('لا توجد جلسات مجدولة لهذه القضية.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                                ],
                                              ),
                                            )
                                          : ListView.builder(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              itemCount: sheetAppointments!.length,
                                              itemBuilder: (context, index) {
                                                final appt = sheetAppointments![index];
                                                String dateStr = '';
                                                String timeStr = '';
                                                try {
                                                  final parsed = DateTime.parse(appt.date);
                                                   dateStr = DateHelper.formatDualDate(parsed);
                                                  timeStr = DateFormat('hh:mm a').format(parsed);
                                                } catch (_) {
                                                  dateStr = appt.date;
                                                }

                                                return Container(
                                                  margin: const EdgeInsets.only(bottom: 10),
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                                    borderRadius: BorderRadius.circular(12),
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
                                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                            ),
                                                          ),
                                                          if (appt.requiresReply)
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                              margin: const EdgeInsets.only(left: 6),
                                                              decoration: BoxDecoration(
                                                                color: Colors.red.shade900.withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(12),
                                                              ),
                                                              child: Text('مطلب رد', style: TextStyle(color: Colors.red.shade900, fontSize: 8, fontWeight: FontWeight.bold)),
                                                            ),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                            decoration: BoxDecoration(
                                                              color: (appt.status == 'scheduled' ? Colors.orange : appt.status == 'completed' ? Colors.green : Colors.grey).withOpacity(0.1),
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Text(
                                                              appt.status == 'scheduled' ? 'مجدولة' : appt.status == 'completed' ? 'منتهية' : appt.status,
                                                              style: TextStyle(
                                                                color: appt.status == 'scheduled' ? Colors.orange : appt.status == 'completed' ? Colors.green : Colors.grey,
                                                                fontSize: 8,
                                                                fontWeight: FontWeight.bold,
                                                                ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text('المحكمة: ${appt.court}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                                          Text('$dateStr | $timeStr', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                                        ],
                                                      ),
                                                      if (appt.clientName != null && appt.clientName!.isNotEmpty) ...[
                                                        const SizedBox(height: 6),
                                                        Text('الموكل: ${appt.clientName} (${appt.clientRole ?? "مدعي"})', style: const TextStyle(fontSize: 9)),
                                                      ],
                                                      if (appt.opposingName != null && appt.opposingName!.isNotEmpty) ...[
                                                        const SizedBox(height: 4),
                                                        Text('الخصم: ${appt.opposingName} (${appt.opposingRole ?? "مدعى عليه"})', style: const TextStyle(fontSize: 9)),
                                                      ],
                                                      if (appt.caseSubject != null && appt.caseSubject!.isNotEmpty) ...[
                                                        const SizedBox(height: 4),
                                                        Text('موضوع الدعوى: ${appt.caseSubject}', style: const TextStyle(fontSize: 9, color: Colors.black54)),
                                                      ],
                                                      if (appt.notes != null && appt.notes!.isNotEmpty) ...[
                                                        const SizedBox(height: 6),
                                                        Container(
                                                          width: double.infinity,
                                                          padding: const EdgeInsets.all(6),
                                                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6)),
                                                          child: Text(appt.notes!, style: const TextStyle(fontSize: 8, color: Colors.black54)),
                                                        ),
                                                      ],
                                                      if (canManageAppts && appt.status == 'scheduled') ...[
                                                        const SizedBox(height: 4),
                                                        Align(
                                                          alignment: Alignment.centerLeft,
                                                          child: TextButton.icon(
                                                            onPressed: () => deleteHearingLocal(appt),
                                                            icon: const Icon(Icons.cancel_outlined, size: 12, color: Colors.red),
                                                            label: const Text('إلغاء الموعد', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                                                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                                          ),
                                                        )
                                                      ]
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                ),
                              ],
                            ),

                            // Tab 3: Documents (المستندات)
                            DocumentsView(
                              cases: widget.cases,
                              onDocumentsUpdated: widget.onCaseUpdated,
                              embedCaseId: _selectedCase!.id,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).then((_) {
      _isDetailsOpen = false;
      _selectedCase = null;
    });
  }

  Widget _buildDetailRow(String label, String val, {Color? valColor, Widget? customVal}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          customVal ?? Text(val, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: valColor ?? Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: goldColor, width: 1.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: goldColor),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTimelineList(List<String> actions) {
    if (actions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('لا توجد إجراءات مسجلة بعد.', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
      );
    }

    return Column(
      children: actions.map((act) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 6, left: 10),
                decoration: BoxDecoration(color: goldColor, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(act, style: const TextStyle(fontSize: 11, height: 1.4, color: Colors.black87)),
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNotesList(List<String> notes) {
    if (notes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('لا توجد ملاحظات قانونية سرية.', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
      );
    }

    return Column(
      children: notes.map((note) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: goldColor.withOpacity(0.05),
            border: Border.all(color: goldColor.withOpacity(0.15)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(note, style: const TextStyle(fontSize: 11, height: 1.4)),
        );
      }).toList(),
    );
  }

  Widget _buildAttachmentsList(List<Attachment> attachments) {
    if (attachments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('لا توجد مرفقات مرفوعة لهذه القضية.', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
      );
    }

    return Column(
      children: attachments.map((att) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6F8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.folder_shared_outlined, size: 16, color: royalGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        att.name,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('(${att.size})', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {},
                child: Row(
                  children: [
                    Text('فتح', style: TextStyle(color: goldColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    Icon(Icons.download, color: goldColor, size: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  bool _loadingFormLists = false;

  void _openCreateCaseDialog() async {
    if (_loadingFormLists) return;
    setState(() {
      _loadingFormLists = true;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFB8963A))),
    );

    try {
      final customersList = await ApiService().getCustomers();
      final usersList = await ApiService().getUsers();
      final lawyersList = usersList.where((u) => u.role == 'lawyer' || u.role == 'admin' || u.role == 'super_admin' || u.role == 'manager').toList();
      final traineeLawyersList = usersList.where((u) => u.role == 'trainee_lawyer').toList();
      
      if (mounted) Navigator.pop(context); // Close loading dialog
      
      _showFormDialog(customersList, lawyersList, traineeLawyersList);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل البيانات: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingFormLists = false;
        });
      }
    }
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0, top: 8.0),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
      ),
    );
  }

  InputDecoration _getInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11, color: Colors.black38),
      fillColor: const Color(0xFFF8FAFC),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: goldColor),
      ),
    );
  }

  void _showFormDialog(List<Customer> customersList, List<SystemUser> lawyersList, List<SystemUser> traineeLawyersList) {
    final formKey = GlobalKey<FormState>();
    
    final RegExp digitRegex = RegExp(r'\d+');
    final List<int> existingNums = widget.cases.map((c) {
      final match = digitRegex.firstMatch(c.caseNumber);
      if (match != null) {
        return int.tryParse(match.group(0)!) ?? 0;
      }
      return int.tryParse(c.caseNumber) ?? 0;
    }).where((n) => n > 0).toList();

    int nextNum = 1;
    while (existingNums.contains(nextNum)) {
      nextNum++;
    }

    final caseNumberCtrl = TextEditingController(text: nextNum.toString());
    final titleCtrl = TextEditingController();
    final customCustomerNameCtrl = TextEditingController();
    final courtCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    
    String? selectedCustomerId;
    String? selectedLawyerId;
    String? selectedTraineeId;
    String selectedCaseType = 'جنائي';
    String selectedStatus = 'مفتوح';
    String selectedPriority = 'medium';
    DateTime? selectedHearingDate;
    String selectedClientType = 'موكّل';
    String selectedTraineeAccess = 'none';
    
    final List<String> caseTypes = ['جنائي', 'حقوقي', 'تجاري', 'عمالي', 'أحوال شخصية', 'إداري', 'أخرى'];
    final List<Map<String, String>> priorityOptions = [
      {'val': 'low', 'label': 'أولوية منخفضة'},
      {'val': 'medium', 'label': 'أولوية متوسطة'},
      {'val': 'high', 'label': 'أولوية مرتفعة'},
      {'val': 'urgent', 'label': 'أولوية عاجلة'},
    ];
    final List<Map<String, String>> statusOptions = [
      {'val': 'مفتوح', 'label': 'مفتوح'},
      {'val': 'قيد النظر', 'label': 'قيد النظر'},
      {'val': 'تحت المراجعة', 'label': 'تحت المراجعة'},
      {'val': 'مغلق', 'label': 'مغلق'},
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.gavel, color: goldColor),
                  const SizedBox(width: 8),
                  Text(
                    'تأسيس ملف قضائي جديد',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: royalGreen),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('رقم القضية *'),
                        TextFormField(
                          controller: caseNumberCtrl,
                          validator: (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
                          decoration: _getInputDecoration('مثال: د/٤٣٢١'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        _buildLabel('عنوان القضية *'),
                        TextFormField(
                          controller: titleCtrl,
                          validator: (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
                          decoration: _getInputDecoration('مثال: دعوى تعويض تجاري'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        _buildLabel('ربط بموكل مسجل (اختياري)'),
                        DropdownButtonFormField<String>(
                          value: selectedCustomerId,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('-- اختيار موكل --', style: TextStyle(fontSize: 11))),
                            ...customersList.map((c) => DropdownMenuItem<String>(
                              value: c.id,
                              child: Text('( #${c.customerNumber} ) - ${c.name}', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                            )),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              selectedCustomerId = val;
                              if (val != null) {
                                final client = customersList.firstWhere((c) => c.id == val);
                                customCustomerNameCtrl.text = client.name;
                              } else {
                                customCustomerNameCtrl.text = '';
                              }
                            });
                          },
                          decoration: _getInputDecoration(''),
                        ),
                        _buildLabel('اسم الموكل *'),
                        TextFormField(
                          controller: customCustomerNameCtrl,
                          enabled: selectedCustomerId == null,
                          validator: (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
                          decoration: _getInputDecoration('اسم الموكل كاملاً'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        _buildLabel('صفة الموكل'),
                        DropdownButtonFormField<String>(
                          value: selectedClientType,
                          items: const [
                            DropdownMenuItem(value: 'موكّل', child: Text('موكّل', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'استشارة فقط', child: Text('استشارة فقط', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedClientType = val);
                            }
                          },
                          decoration: _getInputDecoration(''),
                        ),
                        _buildLabel('المحكمة *'),
                        TextFormField(
                          controller: courtCtrl,
                          validator: (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
                          decoration: _getInputDecoration('مثال: المحكمة العامة بالرياض'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        _buildLabel('نوع القضية *'),
                        DropdownButtonFormField<String>(
                          value: selectedCaseType,
                          items: caseTypes.map((t) => DropdownMenuItem<String>(
                            value: t,
                            child: Text(t, style: const TextStyle(fontSize: 12)),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedCaseType = val);
                            }
                          },
                          decoration: _getInputDecoration(''),
                        ),
                        _buildLabel('تاريخ الجلسة القادمة'),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedHearingDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: royalGreen,
                                      onPrimary: Colors.white,
                                      onSurface: royalGreen,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setDialogState(() => selectedHearingDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedHearingDate == null
                                      ? 'اختيار تاريخ الجلسة'
                                      : DateHelper.formatDualDate(selectedHearingDate),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: selectedHearingDate == null ? Colors.black38 : Colors.black87,
                                  ),
                                ),
                                Icon(Icons.calendar_today, size: 16, color: goldColor),
                              ],
                            ),
                          ),
                        ),
                        _buildLabel('المحامي المسؤول'),
                        DropdownButtonFormField<String>(
                          value: selectedLawyerId,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('-- اختر المحامي --', style: TextStyle(fontSize: 11))),
                            ...lawyersList.map((l) => DropdownMenuItem<String>(
                              value: l.uid,
                              child: Text(l.name, style: const TextStyle(fontSize: 11)),
                            )),
                          ],
                          onChanged: (val) {
                            setDialogState(() => selectedLawyerId = val);
                          },
                          decoration: _getInputDecoration(''),
                        ),
                        _buildLabel('إظهار للمحامين المتدربين'),
                        DropdownButtonFormField<String>(
                          value: selectedTraineeAccess,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem<String>(value: 'none', child: Text('لا يظهر لأي متدرب', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem<String>(value: 'all', child: Text('يظهر للجميع', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem<String>(value: 'specific', child: Text('محامي متدرب محدد', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedTraineeAccess = val;
                                if (val != 'specific') {
                                  selectedTraineeId = null;
                                }
                              });
                            }
                          },
                          decoration: _getInputDecoration(''),
                        ),
                        if (selectedTraineeAccess == 'specific') ...[
                          _buildLabel('المحامي المتدرب المساعد'),
                          DropdownButtonFormField<String>(
                            value: selectedTraineeId,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('-- اختر المتدرب --', style: TextStyle(fontSize: 11))),
                              ...traineeLawyersList.map((t) => DropdownMenuItem<String>(
                                value: t.uid,
                                child: Text(t.name, style: const TextStyle(fontSize: 11)),
                              )),
                            ],
                            onChanged: (val) {
                              setDialogState(() => selectedTraineeId = val);
                            },
                            decoration: _getInputDecoration(''),
                          ),
                        ],
                        _buildLabel('الحالة'),
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          items: statusOptions.map((opt) => DropdownMenuItem<String>(
                            value: opt['val'],
                            child: Text(opt['label']!, style: const TextStyle(fontSize: 12)),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedStatus = val);
                            }
                          },
                          decoration: _getInputDecoration(''),
                        ),
                        _buildLabel('الأولوية'),
                        DropdownButtonFormField<String>(
                          value: selectedPriority,
                          items: priorityOptions.map((opt) => DropdownMenuItem<String>(
                            value: opt['val'],
                            child: Text(opt['label']!, style: const TextStyle(fontSize: 12)),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedPriority = val);
                            }
                          },
                          decoration: _getInputDecoration(''),
                        ),
                        _buildLabel('شرح وتفاصيل القضية'),
                        TextFormField(
                          controller: descriptionCtrl,
                          maxLines: 3,
                          decoration: _getInputDecoration('تفاصيل أو موضوع الدعوى...'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final lawyer = selectedLawyerId != null
                          ? lawyersList.firstWhere((l) => l.uid == selectedLawyerId)
                          : null;
                      final trainee = selectedTraineeId != null
                          ? traineeLawyersList.firstWhere((t) => t.uid == selectedTraineeId)
                          : null;
                      
                      final Map<String, dynamic> payload = {
                        'caseNumber': caseNumberCtrl.text.trim(),
                        'title': titleCtrl.text.trim(),
                        'customerId': selectedCustomerId,
                        'customerName': customCustomerNameCtrl.text.trim(),
                        'description': descriptionCtrl.text.trim(),
                        'status': selectedStatus,
                        'priority': selectedPriority,
                        'court': courtCtrl.text.trim(),
                        'caseType': selectedCaseType,
                        'hearingDate': selectedHearingDate == null
                            ? null
                            : '${selectedHearingDate!.year}-${selectedHearingDate!.month.toString().padLeft(2, '0')}-${selectedHearingDate!.day.toString().padLeft(2, '0')}',
                        'lawyerId': selectedLawyerId,
                        'lawyerName': lawyer?.name,
                        'traineeId': selectedTraineeId ?? (selectedTraineeAccess == 'specific' ? selectedTraineeId : null),
                        'traineeName': (selectedTraineeId != null && trainee != null) ? trainee.name : (selectedTraineeAccess == 'specific' ? trainee?.name : null),
                        'traineeAccess': selectedTraineeId != null ? 'specific' : selectedTraineeAccess,
                        'clientType': selectedClientType,
                      };

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFB8963A))),
                      );

                      try {
                        await ApiService().createCase(payload);
                        if (context.mounted) {
                          Navigator.pop(context); // Close saving dialog
                          Navigator.pop(context); // Close form dialog
                        }
                        widget.onCaseUpdated();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تسجيل ملف القضية بنجاح'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context); // Close saving
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل الإضافة: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: royalGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('تسجيل القضية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInputFormField(TextEditingController controller, String hint) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 11),
          fillColor: Colors.white,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: goldColor),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService().currentUser;
    final canCreate = user != null && (
        user.role == 'admin' ||
        user.role == 'super_admin' ||
        user.role == 'manager' ||
        user.role == 'archive' ||
        user.role == 'lawyer');

    final filtered = widget.cases.where((c) {
      final isArchived = c.status == 'مغلق';
      if (_isArchivedView != isArchived) return false;

      return c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.caseNumber.contains(_searchQuery) ||
          c.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.court.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.caseType.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _openCreateCaseDialog,
              backgroundColor: royalGreen,
              icon: Icon(Icons.add, color: goldColor),
              label: const Text('قضية جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            )
          : null,
      body: Column(
        children: [
          LuxuryHeader(
            title: _isArchivedView ? 'أرشيف القضايا المغلقة' : 'إدارة ملفات القضايا',
            subtitle: _isArchivedView ? 'قائمة القضايا المحكومة والمغلقة' : 'القضايا المتداولة والمنظورة أمام المحاكم',
          ),
          // Search
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'ابحث برقم القضية، المحكمة، الموكل...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 20),
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
          ),

          // List
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cases_outlined, size: 40, color: Colors.black26),
                        SizedBox(height: 8),
                        Text('لا توجد قضايا مسجلة مطابقة للبحث', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final c = filtered[index];
                      return StaggeredListItem(
                        index: index,
                        child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.title,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(c.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  c.status,
                                  style: TextStyle(color: _getStatusColor(c.status), fontSize: 7, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('الموكل: ${c.customerName}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                              const SizedBox(height: 2),
                              Text('صفة الموكل: ${c.clientType ?? "موكّل"}', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(child: Text('رقم: ${c.caseNumber}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'المحكمة: ${c.court}',
                                      style: TextStyle(fontSize: 9, color: royalGreen, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => _showDetailsSheet(c, initialTabIndex: 2),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        border: Border.all(color: Colors.amber.shade200.withOpacity(0.5)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.folder_open_outlined, size: 11, color: Colors.amber.shade800),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${c.attachments.length} ملفات',
                                            style: TextStyle(fontSize: 8, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              )
                            ],
                          ),
                          onTap: () => _showDetailsSheet(c),
                        ),
                      ),
                    );
                  },
                ),
          )
        ],
      ),
    );
  }
}
