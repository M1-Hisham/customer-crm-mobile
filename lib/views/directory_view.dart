import 'dart:convert';
import 'package:flutter/material.dart';
import '../main.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class DirectoryView extends StatefulWidget {
  final List<Customer> customers;
  final List<SystemUser> staff;
  final VoidCallback onCustomerUpdated;

  const DirectoryView({
    super.key,
    required this.customers,
    required this.staff,
    required this.onCustomerUpdated,
  });

  @override
  State<DirectoryView> createState() => _DirectoryViewState();
}

class _DirectoryViewState extends State<DirectoryView> {
  String _searchQuery = '';
  String _selectedStatus = 'الكل';

  final Color royalGreen = const Color(0xFF1E3D30);
  final Color goldColor = const Color(0xFFB8963A);

  Map<String, dynamic> _parseNotes(String? notesStr) {
    if (notesStr == null || notesStr.trim().isEmpty) {
      return {'clientType': 'individual', 'nationalId': '', 'crNumber': '', 'representativeName': '', 'actualNotes': ''};
    }
    try {
      final trimmed = notesStr.trim();
      if (trimmed.startsWith('{')) {
        final parsed = jsonDecode(trimmed);
        if (parsed is Map) {
          return {
            'clientType': parsed['clientType'] ?? 'individual',
            'nationalId': parsed['nationalId'] ?? '',
            'crNumber': parsed['crNumber'] ?? '',
            'representativeName': parsed['representativeName'] ?? '',
            'actualNotes': parsed['actualNotes'] ?? ''
          };
        }
      }
    } catch (_) {}
    return {'clientType': 'individual', 'nationalId': '', 'crNumber': '', 'representativeName': '', 'actualNotes': notesStr};
  }

  bool _checkCanEdit(Customer cust) {
    final user = ApiService().currentUser;
    if (user == null) return false;
    if (user.role == 'admin' || user.role == 'super_admin' || user.role == 'manager' || user.role == 'reception' || user.role == 'receptionist') return true;
    return cust.receptionistId == user.uid;
  }

  bool _isAdmin() {
    final role = ApiService().currentUser?.role ?? '';
    return ['admin', 'super_admin', 'manager'].contains(role);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'نشط': return Colors.green;
      case 'قيد الانتظار': return Colors.orange;
      case 'مكتمل': return Colors.blue;
      case 'ملغي': return Colors.red;
      default: return Colors.grey;
    }
  }

  void _showDetailsSheet(Customer cust) {
    final parsed = _parseNotes(cust.notes);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            final bool isConsultation = cust.service.contains('استشارة') || cust.service.contains('استشاره');
            final bool canDelete = _isAdmin() || isConsultation;
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: royalGreen.withOpacity(0.1),
                        foregroundColor: goldColor,
                        child: Text(cust.name.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cust.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('ملف رقم: #${cust.customerNumber}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(cust.status, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                        backgroundColor: _getStatusColor(cust.status),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  _buildDetailRow('رقم الجوال:', cust.phone),
                  _buildDetailRow('البريد الإلكتروني:', cust.email ?? 'غير مسجل'),
                  _buildDetailRow('نوع الخدمة:', cust.service, valColor: royalGreen),
                  _buildDetailRow('التصنيف القضائي:', cust.caseType ?? 'غير محدد'),
                  _buildDetailRow('المستشار المسؤول:', cust.assignedLawyerName ?? 'غير مسند', valColor: goldColor),
                  _buildDetailRow('الأتعاب المقدرة:', cust.estimatedFee != null ? '${cust.estimatedFee} SAR' : 'غير محددة'),
                  _buildDetailRow('تاريخ التسجيل:', cust.createdAt.split('T')[0]),
                  
                  if (parsed['clientType'] == 'individual' && parsed['nationalId'].toString().isNotEmpty)
                    _buildDetailRow('الهوية الوطنية/الإقامة:', parsed['nationalId']),
                  if (parsed['clientType'] == 'corporate') ...[
                    if (parsed['crNumber'].toString().isNotEmpty) _buildDetailRow('السجل التجاري:', parsed['crNumber']),
                    if (parsed['representativeName'].toString().isNotEmpty) _buildDetailRow('الممثل القانوني:', parsed['representativeName']),
                  ],

                  if (parsed['actualNotes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('شرح الطلب والتفاصيل:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(parsed['actualNotes'], style: const TextStyle(fontSize: 11, height: 1.5)),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // WhatsApp & Call Quick Actions
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final phone = cust.phone.replaceFirst(RegExp(r'^0'), '966').replaceAll(RegExp(r'\D'), '');
                            final url = Uri.parse('https://wa.me/$phone');
                            launchUrl(url, mode: LaunchMode.externalApplication);
                          },
                          icon: const Icon(Icons.chat, size: 16),
                          label: const Text('واتساب', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final url = Uri.parse('tel:${cust.phone}');
                            launchUrl(url);
                          },
                          icon: const Icon(Icons.phone, size: 16),
                          label: const Text('اتصال', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3D30),
                            side: const BorderSide(color: Color(0xFF1E3D30)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      if (_checkCanEdit(cust))
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditDialog(cust);
                            },
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('تعديل السجل', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: royalGreen,
                              side: BorderSide(color: royalGreen),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      if (_checkCanEdit(cust) && canDelete) const SizedBox(width: 10),
                      if (canDelete)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('حذف ملف الموكل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  content: Text('هل أنت متأكد من حذف الموكل ${cust.name} نهائياً؟'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('نعم، حذف', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );

                              if (confirm == true && mounted) {
                                Navigator.pop(context);
                                try {
                                  await ApiService().deleteCustomer(cust.id);
                                  widget.onCustomerUpdated();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                }
                              }
                            },
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const Text('حذف السجل', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.1),
                              foregroundColor: Colors.red,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Colors.redAccent, width: 0.5),
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String val, {Color? valColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(val, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: valColor ?? Colors.black87)),
        ],
      ),
    );
  }

  // Edit Customer Dialog View
  void _showEditDialog(Customer cust) {
    final parsed = _parseNotes(cust.notes);
    final nameController = TextEditingController(text: cust.name);
    final phoneController = TextEditingController(text: cust.phone);
    final emailController = TextEditingController(text: cust.email ?? '');
    final serviceController = TextEditingController(text: cust.service);
    final nationalIdController = TextEditingController(text: parsed['nationalId']);
    final crNumberController = TextEditingController(text: parsed['crNumber']);
    final representativeController = TextEditingController(text: parsed['representativeName']);
    final notesController = TextEditingController(text: parsed['actualNotes']);
    String editClientType = parsed['clientType'] ?? 'individual';
    String editStatus = cust.status;
    String editCaseType = cust.caseType ?? '';
    String editAssignedLawyerId = cust.assignedLawyerId ?? '';
    String editPriority = cust.priority ?? 'medium';
    String editReferralSource = cust.referralSource ?? 'اتصال مباشر';
    final estimatedFeeController = TextEditingController(text: cust.estimatedFee != null ? cust.estimatedFee!.toInt().toString() : '');
    final lawyers = widget.staff.where((u) => u.role == 'lawyer' || u.role == 'admin' || u.role == 'super_admin' || u.role == 'manager').toList();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                          const Text('تعديل بيانات الموكل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Client Type Selector
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('فرد', style: TextStyle(fontSize: 11))),
                              selected: editClientType == 'individual',
                              onSelected: (selected) => setDialogState(() => editClientType = 'individual'),
                              selectedColor: royalGreen,
                              checkmarkColor: Colors.white,
                              labelStyle: TextStyle(color: editClientType == 'individual' ? Colors.white : Colors.black87),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('منشأة / جهة', style: TextStyle(fontSize: 11))),
                              selected: editClientType == 'corporate',
                              onSelected: (selected) => setDialogState(() => editClientType = 'corporate'),
                              selectedColor: royalGreen,
                              checkmarkColor: Colors.white,
                              labelStyle: TextStyle(color: editClientType == 'corporate' ? Colors.white : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _buildDialogField(nameController, 'الاسم الكامل / اسم الشركة *', Icons.person_outline),
                      const SizedBox(height: 10),

                      if (editClientType == 'individual')
                        _buildDialogField(nationalIdController, 'رقم الهوية الوطنية / الإقامة', Icons.fingerprint)
                      else ...[
                        _buildDialogField(crNumberController, 'رقم السجل التجاري', Icons.business),
                        const SizedBox(height: 10),
                        _buildDialogField(representativeController, 'اسم المفوض', Icons.assignment_ind),
                      ],
                      const SizedBox(height: 10),

                      _buildDialogField(phoneController, 'رقم الجوال *', Icons.phone_android),
                      const SizedBox(height: 10),

                      _buildDialogField(emailController, 'البريد الإلكتروني', Icons.email_outlined),
                      const SizedBox(height: 10),

                      _buildDialogField(serviceController, 'الخدمة المطلوبة *', Icons.work_outline),
                      const SizedBox(height: 12),

                      // Case Type Dropdown
                      const Text('التصنيف القضائي المبدئي', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: editCaseType.isEmpty ? null : editCaseType,
                            isExpanded: true,
                            hint: const Text('-- اختر التصنيف --', style: TextStyle(fontSize: 12)),
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                            onChanged: (v) => setDialogState(() => editCaseType = v!),
                            items: ['جنائية', 'مدنية', 'تجارية', 'عمالية', 'أحوال شخصية', 'إدارية', 'عقارية', 'أخرى'].map((String item) {
                              return DropdownMenuItem<String>(value: item, child: Text(item));
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Assigned Lawyer Dropdown
                      const Text('إسناد القضية إلى محامٍ مستشار', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: editAssignedLawyerId.isEmpty ? '' : editAssignedLawyerId,
                            isExpanded: true,
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                            onChanged: (v) => setDialogState(() => editAssignedLawyerId = v!),
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('-- اختر محامٍ لتفويضه --'),
                              ),
                              ...lawyers.map((SystemUser u) {
                                return DropdownMenuItem<String>(
                                  value: u.uid,
                                  child: Text(u.name),
                                );
                              })
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Priority Dropdown
                      const Text('مستوى الأهمية والأولوية', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: editPriority,
                            isExpanded: true,
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                            onChanged: (v) => setDialogState(() => editPriority = v!),
                            items: ['low', 'medium', 'high', 'urgent'].map((String item) {
                              final labels = {'low': 'منخفضة', 'medium': 'متوسطة', 'high': 'مرتفعة', 'urgent': 'عاجلة'};
                              return DropdownMenuItem<String>(value: item, child: Text(labels[item] ?? item));
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Estimated Fee TextField
                      _buildDialogField(estimatedFeeController, 'الأتعاب المقدرة (SAR)', Icons.attach_money, keyboardType: TextInputType.number),
                      const SizedBox(height: 10),

                      // Referral Source Dropdown
                      const Text('مصدر التعرف بالمنصة', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: editReferralSource,
                            isExpanded: true,
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                            onChanged: (v) => setDialogState(() => editReferralSource = v!),
                            items: ['اتصال مباشر', 'توصية شخصية', 'موقع إلكتروني', 'وسائل التواصل الاجتماعي', 'إعلان', 'أخرى'].map((String item) {
                              return DropdownMenuItem<String>(value: item, child: Text(item));
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Status Dropdown
                      const Text('الحالة الحالية للموكل', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: editStatus,
                            isExpanded: true,
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                            onChanged: (v) => setDialogState(() => editStatus = v!),
                            items: ['قيد الانتظار', 'نشط', 'مكتمل', 'ملغي'].map((String item) {
                              return DropdownMenuItem<String>(value: item, child: Text(item));
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildDialogField(notesController, 'ملاحظات وشرح الطلب', Icons.note_alt_outlined, maxLines: 3),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: saving ? null : () async {
                            final name = nameController.text.trim();
                            final phone = phoneController.text.trim();
                            final service = serviceController.text.trim();

                            if (name.isEmpty || phone.isEmpty || service.isEmpty) return;

                            setDialogState(() => saving = true);

                            final packedNotes = jsonEncode({
                              'clientType': editClientType,
                              'nationalId': editClientType == 'individual' ? nationalIdController.text.trim() : null,
                              'crNumber': editClientType == 'corporate' ? crNumberController.text.trim() : null,
                              'representativeName': editClientType == 'corporate' ? representativeController.text.trim() : null,
                              'actualNotes': notesController.text.trim()
                            });

                            try {
                              await ApiService().updateCustomer(cust.id, {
                                'name': name,
                                'phone': phone,
                                'email': emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                                'service': service,
                                'status': editStatus,
                                'notes': packedNotes,
                                'caseType': editCaseType.isEmpty ? null : editCaseType,
                                'assignedLawyerId': editAssignedLawyerId.isEmpty ? null : editAssignedLawyerId,
                                'priority': editPriority,
                                'estimatedFee': estimatedFeeController.text.trim().isEmpty ? null : double.tryParse(estimatedFeeController.text.trim()),
                                'referralSource': editReferralSource,
                              });

                              if (mounted) {
                                Navigator.pop(context);
                                widget.onCustomerUpdated();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعديل سجل الموكل بنجاح.')));
                              }
                            } catch (e) {
                              setDialogState(() => saving = false);
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(content: Text(e.toString())),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: royalGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: BorderSide(color: goldColor),
                          ),
                          child: saving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                              : const Text('حفظ التعديلات والتخزين', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildDialogField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
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
    // Search and Status filtering
    final filtered = widget.customers.where((cust) {
      final matchesSearch = cust.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          cust.phone.contains(_searchQuery) ||
          cust.customerNumber.toString().contains(_searchQuery) ||
          cust.service.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesStatus = _selectedStatus == 'الكل' || cust.status == _selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => MainAppController.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('الموكلين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar & Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم، الجوال، أو رقم الموكل...',
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
                const SizedBox(height: 12),
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: ['الكل', 'قيد الانتظار', 'نشط', 'مكتمل', 'ملغي'].map((status) {
                      final active = _selectedStatus == status;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: ChoiceChip(
                          label: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          selected: active,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedStatus = status);
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

          // List
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off_outlined, size: 40, color: Colors.black26),
                        SizedBox(height: 8),
                        Text('لا يوجد عملاء مطابقين للبحث', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final cust = filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cust.name,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('#${cust.customerNumber}', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(cust.service, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.phone_android, size: 12, color: goldColor),
                                      const SizedBox(width: 4),
                                      Text(cust.phone, style: const TextStyle(fontSize: 10)),
                                    ],
                                  ),
                                  Text(
                                    'المسؤول: ${cust.assignedLawyerName ?? "غير مسند"}',
                                    style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                                  )
                                ],
                              )
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(cust.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              cust.status,
                              style: TextStyle(color: _getStatusColor(cust.status), fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                          onTap: () => _showDetailsSheet(cust),
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
