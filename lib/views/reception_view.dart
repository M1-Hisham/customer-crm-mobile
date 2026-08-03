import 'dart:convert';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ReceptionView extends StatefulWidget {
  final List<SystemUser> staff;
  final VoidCallback onCustomerRegistered;

  const ReceptionView({
    super.key,
    required this.staff,
    required this.onCustomerRegistered,
  });

  @override
  State<ReceptionView> createState() => _ReceptionViewState();
}

class _ReceptionViewState extends State<ReceptionView> {
  String _clientType = 'individual';
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _serviceController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _crNumberController = TextEditingController();
  final _representativeController = TextEditingController();
  final _feeController = TextEditingController();
  final _notesController = TextEditingController();

  String _caseType = 'جنائية';
  String _assignedLawyerId = '';
  String _priority = 'medium';
  String _referralSource = 'اتصال مباشر';

  bool _loading = false;
  String? _success;
  String? _error;

  final Color royalGreen = const Color(0xFF1E3D30);
  final Color goldColor = const Color(0xFFB8963A);

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final service = _serviceController.text.trim();

    if (name.isEmpty || phone.isEmpty || service.isEmpty) {
      setState(() => _error = 'الاسم ورقم الجوال والخدمة حقول مطلوبة.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    final packedNotes = jsonEncode({
      'clientType': _clientType,
      'nationalId': _clientType == 'individual' ? _nationalIdController.text.trim() : null,
      'crNumber': _clientType == 'corporate' ? _crNumberController.text.trim() : null,
      'representativeName': _clientType == 'corporate' ? _representativeController.text.trim() : null,
      'actualNotes': _notesController.text.trim()
    });

    try {
      await ApiService().createCustomer({
        'name': name,
        'phone': phone,
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'service': service,
        'status': 'قيد الانتظار',
        'notes': packedNotes,
        'caseType': _caseType,
        'assignedLawyerId': _assignedLawyerId.isEmpty ? null : _assignedLawyerId,
        'priority': _priority,
        'estimatedFee': _feeController.text.trim().isEmpty ? null : double.tryParse(_feeController.text.trim()),
        'referralSource': _referralSource,
      });

      setState(() => _success = 'تم تسجيل الموكل بنجاح في النظام القضائي.');
      widget.onCustomerRegistered();

      // Reset fields
      _nameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _serviceController.clear();
      _nationalIdController.clear();
      _crNumberController.clear();
      _representativeController.clear();
      _feeController.clear();
      _notesController.clear();
      _assignedLawyerId = '';
    } catch (err) {
      setState(() => _error = err.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lawyers = widget.staff.where((u) => u.role == 'lawyer' || u.role == 'admin' || u.role == 'super_admin').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => MainAppController.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('تسجيل موكل جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_success != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_success!, style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),

            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),

            // Client Type Selector
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _clientType = 'individual'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _clientType == 'individual' ? royalGreen : Colors.white,
                      foregroundColor: _clientType == 'individual' ? Colors.white : Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: _clientType == 'individual' ? goldColor : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: const Text('فرد (مواطن / مقيم)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _clientType = 'corporate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _clientType == 'corporate' ? royalGreen : Colors.white,
                      foregroundColor: _clientType == 'corporate' ? Colors.white : Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: _clientType == 'corporate' ? goldColor : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: const Text('منشأة / شركة / جهة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Form Inputs
            _buildTextField(_nameController, _clientType == 'individual' ? 'الاسم الكامل للموكل *' : 'اسم المنشأة / الشركة *', Icons.person_outline),
            const SizedBox(height: 12),

            if (_clientType == 'individual')
              _buildTextField(_nationalIdController, 'رقم الهوية الوطنية / الإقامة', Icons.fingerprint)
            else ...[
              _buildTextField(_crNumberController, 'رقم السجل التجاري', Icons.business),
              const SizedBox(height: 12),
              _buildTextField(_representativeController, 'اسم المفوض / الممثل القانوني', Icons.assignment_ind_outlined),
            ],
            const SizedBox(height: 12),

            _buildTextField(_phoneController, 'رقم الجوال *', Icons.phone_android, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),

            _buildTextField(_emailController, 'البريد الإلكتروني (اختياري)', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),

            _buildTextField(_serviceController, 'نوع الاستشارة / الخدمة المطلوبة *', Icons.work_outline),
            const SizedBox(height: 16),

            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),

            // Dropdowns
            _buildDropdown('التصنيف القضائي المبدئي', _caseType, ['جنائية', 'مدنية', 'تجارية', 'عمالية', 'أحوال شخصية', 'إدارية', 'عقارية', 'أخرى'], (v) => setState(() => _caseType = v!)),
            const SizedBox(height: 12),

            _buildLawyerDropdown(lawyers),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildDropdown('الأولوية', _priority, ['low', 'medium', 'high', 'urgent'], (v) => setState(() => _priority = v!), labels: {'low': 'أولوية منخفضة', 'medium': 'أولوية متوسطة', 'high': 'أولوية مرتفعة', 'urgent': 'أولوية عاجلة'}),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(_feeController, 'الأتعاب المقدرة (SAR)', Icons.money, keyboardType: TextInputType.number),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildDropdown('مصدر التعرف', _referralSource, ['اتصال مباشر', 'توصية شخصية', 'موقع إلكتروني', 'وسائل التواصل الاجتماعي', 'إعلان', 'أخرى'], (v) => setState(() => _referralSource = v!)),
            const SizedBox(height: 12),

            _buildTextField(_notesController, 'ملاحظات إضافية وتفاصيل الطلب', Icons.note_alt_outlined, maxLines: 3),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: royalGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(color: goldColor),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_task, size: 16),
                          SizedBox(width: 8),
                          Text('إدراج الموكل وتوثيق السجل', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11),
        prefixIcon: Icon(icon, size: 18),
        fillColor: Colors.white,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: goldColor),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    Map<String, String>? labels,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
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
              value: value,
              isExpanded: true,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              onChanged: onChanged,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(labels != null ? (labels[item] ?? item) : item),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLawyerDropdown(List<SystemUser> lawyers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              value: _assignedLawyerId,
              isExpanded: true,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              onChanged: (v) => setState(() => _assignedLawyerId = v!),
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
      ],
    );
  }
}
