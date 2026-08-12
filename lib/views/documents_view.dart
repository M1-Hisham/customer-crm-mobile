import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class DocumentsView extends StatefulWidget {
  final List<Case> cases;
  final VoidCallback onDocumentsUpdated;
  final String? embedCaseId;

  const DocumentsView({
    super.key,
    required this.cases,
    required this.onDocumentsUpdated,
    this.embedCaseId,
  });

  @override
  State<DocumentsView> createState() => _DocumentsViewState();
}

class _DocumentsViewState extends State<DocumentsView> {
  String _selectedCaseId = '';
  List<Attachment> _documents = [];
  String _searchQuery = '';
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.embedCaseId != null) {
      _selectedCaseId = widget.embedCaseId!;
      _loadDocuments();
    }
  }

  final Color royalGreen = const Color(0xFF1E3D30);
  final Color goldColor = const Color(0xFFB8963A);

  @override
  void didUpdateWidget(covariant DocumentsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadDocuments();
  }

  void _loadDocuments() {
    if (_selectedCaseId.isEmpty) {
      setState(() => _documents = []);
      return;
    }
    final selectedCase = widget.cases.firstWhere((c) => c.id == _selectedCaseId, orElse: () => Case(id: '', caseNumber: '', title: '', customerId: '', customerName: '', description: '', status: '', court: '', caseType: '', actionHistory: [], notesHistory: [], attachments: [], createdAt: '', updatedAt: '', archivedById: '', archivedByName: ''));
    if (selectedCase.id.isNotEmpty) {
      setState(() => _documents = selectedCase.attachments);
    } else {
      setState(() => _documents = []);
    }
  }

  Future<void> _viewDocument(Attachment doc) async {
    final String urlStr = doc.url;
    if (urlStr.isEmpty) return;

    String fullUrl = urlStr;
    if (urlStr.startsWith('/')) {
      fullUrl = '${AppConfig.baseUrl}$urlStr';
    }

    final Uri uri = Uri.parse(fullUrl);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        alert(context, 'لا يمكن فتح المستند: $e');
      }
    }
  }

  String _getMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return 'application/msword';
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    return 'application/octet-stream';
  }

  Future<void> _showUploadDialog() async {
    if (_selectedCaseId.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(content: Text('الرجاء اختيار قضية أولاً.')),
      );
      return;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'gif', 'xls', 'xlsx'],
      );

      if (result == null || result.files.isEmpty) {
        return; // User canceled
      }

      final file = result.files.first;
      final fileName = file.name;
      final fileSize = file.size;

      // Check file size (10MB limit)
      if (fileSize > 10 * 1024 * 1024) {
        alert(context, 'الملف كبير جداً. الحد الأقصى هو 10 ميجابايت.');
        return;
      }

      setState(() => _uploading = true);

      // Read file bytes
      final bytes = file.bytes ?? await io.File(file.path!).readAsBytes();
      final base64Str = "data:${_getMimeType(fileName)};base64,${base64.encode(bytes)}";

      await ApiService().addCaseAttachment(
        _selectedCaseId,
        fileName,
        base64Str,
        "${(fileSize / 1024).toStringAsFixed(1)} KB",
      );

      if (mounted) {
        widget.onDocumentsUpdated();
        _loadDocuments();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفع المستند بنجاح.')),
        );
      }
    } catch (e) {
      alert(context, 'حدث خطأ أثناء رفع الملف: $e');
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _handleDelete(Attachment doc) async {
    if (!await showConfirmDialog(context, 'هل أنت متأكد من حذف المستند "${doc.name}" نهائياً؟')) return;
    try {
      await ApiService().deleteCaseAttachment(_selectedCaseId, doc.name);
      widget.onDocumentsUpdated();
      setState(() => _documents.removeWhere((d) => d.name == doc.name));
    } catch (e) {
      alert(context, e.toString());
    }
  }

  Future<bool> showConfirmDialog(BuildContext context, String msg) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }

  void alert(BuildContext context, String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _documents.where((doc) {
      return doc.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final userRole = ApiService().currentUser?.role ?? '';
    final canDelete = ['admin', 'super_admin', 'manager'].contains(userRole);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: widget.embedCaseId != null
          ? null
          : AppBar(
              title: const Text('مستندات القضايا والملفات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0.5,
              centerTitle: true,
            ),
      body: Column(
        children: [
          // Selector
          if (widget.embedCaseId == null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('اختر قضية نشطة لعرض مستنداتها', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCaseId.isEmpty ? null : _selectedCaseId,
                        hint: const Text('-- اختر ملف القضية --', style: TextStyle(fontSize: 12)),
                        isExpanded: true,
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                        onChanged: (v) {
                          setState(() => _selectedCaseId = v!);
                          _loadDocuments();
                        },
                        items: widget.cases.map((Case c) {
                          return DropdownMenuItem<String>(value: c.id, child: Text('#${c.caseNumber} — ${c.title}'));
                        }).toList(),
                      ),
                    ),
                  ),
                  if (_selectedCaseId.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'ابحث في المستندات المرفوعة...',
                        hintStyle: const TextStyle(fontSize: 11),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        fillColor: const Color(0xFFF8FAFC),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: goldColor)),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else if (_selectedCaseId.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'ابحث في المستندات المرفوعة...',
                  hintStyle: const TextStyle(fontSize: 11),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  fillColor: const Color(0xFFF8FAFC),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: goldColor)),
                ),
              ),
            ),

          // List & Upload button
          Expanded(
            child: _selectedCaseId.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_outlined, size: 40, color: Colors.black26),
                        SizedBox(height: 8),
                        Text('اختر قضية من القائمة لعرض مستنداتها', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // Upload Widget
                      InkWell(
                        onTap: _uploading ? null : _showUploadDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: goldColor, style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _uploading
                              ? Column(
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 8),
                                    Text('جاري معالجة ورفع الملف...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: royalGreen)),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Icon(Icons.upload_file, color: goldColor, size: 24),
                                    const SizedBox(height: 8),
                                    Text('اضغط لرفع مستند جديد', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: royalGreen)),
                                    const SizedBox(height: 4),
                                    const Text('PDF، Word، صور (حد أقصى 10MB)', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(child: Text('لا توجد مستندات مرفوعة بعد لهذه القضية.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                        )
                      else
                        ...filtered.map((doc) {
                          final isPdf = doc.name.endsWith('.pdf');
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              onTap: () => _viewDocument(doc),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFF4F6F8),
                                child: Icon(isPdf ? Icons.picture_as_pdf : Icons.image, color: isPdf ? Colors.red : Colors.blue, size: 18),
                              ),
                              title: Text(doc.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('الحجم: ${doc.size}', style: const TextStyle(fontSize: 9)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                                    onPressed: () => _viewDocument(doc),
                                    color: royalGreen,
                                    tooltip: 'عرض الملف',
                                  ),
                                  if (canDelete)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      onPressed: () => _handleDelete(doc),
                                      color: Colors.red,
                                      tooltip: 'حذف',
                                    ),
                                ],
                              ),
                            ),
                          );
                        })
                    ],
                  ),
          )
        ],
      ),
    );
  }
}
