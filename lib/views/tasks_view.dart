import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../utils/date_helper.dart';
import '../core/widgets/luxury_header.dart';

class TasksView extends StatefulWidget {
  final SystemUser currentUser;
  final List<SystemUser> staff;

  const TasksView({
    super.key,
    required this.currentUser,
    required this.staff,
  });

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> with SingleTickerProviderStateMixin {
  final Color royalGreen = const Color(0xFF1E3D30);
  final Color goldColor = const Color(0xFFB8963A);
  
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String? _error;
  
  // Date filter (defaults to today in YYYY-MM-DD format)
  DateTime _selectedDate = DateTime.now();

  // Sub-pages: 'active' (المهام الحالية), 'archived' (الأرشيف والمنجزة), 'all' (جميع المهام - للأدمن)
  String _activeTab = 'active';

  bool get isAdmin => ['admin', 'super_admin', 'manager'].contains(widget.currentUser.role);

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _fetchTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final formattedDate = _formatDate(_selectedDate);
      final tasks = await ApiService().getDailyTasks(date: formattedDate);
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _completeTask(String id, String note) async {
    try {
      await ApiService().completeDailyTask(id, note: note);
      _fetchTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('تم إنجاز المهمة ونقلها إلى الأرشيف بنجاح!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateNote(String id, String note) async {
    try {
      await ApiService().updateDailyTaskNote(id, note);
      _fetchTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الرد/الملاحظة بنجاح'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteTask(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المهمة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من حذف هذه المهمة نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().deleteDailyTask(id);
        _fetchTasks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف المهمة بنجاح'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showCreateTaskModal() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    List<String> selectedEmployeeIds = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 24,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.add_task, color: royalGreen),
                      const SizedBox(width: 8),
                      const Text(
                        'إضافة مهمة يومية جديدة',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'عنوان المهمة *',
                  hintText: 'مثلاً: مراجعة ملف القضية بالمحكمة',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'وصف المهمة والملاحظات',
                  hintText: 'اكتب تفاصيل وإرشادات المهمة...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'تعيين وتكليف الموظفين:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: widget.staff.map((staffUser) {
                      final isSelected = selectedEmployeeIds.contains(staffUser.uid);
                      return FilterChip(
                        label: Text(staffUser.name.isNotEmpty ? staffUser.name : staffUser.username),

                        selected: isSelected,
                        selectedColor: royalGreen.withValues(alpha: 0.2),
                        checkmarkColor: royalGreen,
                        labelStyle: TextStyle(
                          color: isSelected ? royalGreen : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          setModalState(() {
                            if (selected) {
                              selectedEmployeeIds.add(staffUser.uid);
                            } else {
                              selectedEmployeeIds.remove(staffUser.uid);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى إدخال عنوان المهمة')),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    try {
                      final formattedDate = _formatDate(_selectedDate);
                      await ApiService().createDailyTask({
                        'title': titleController.text.trim(),
                        'description': descController.text.trim(),
                        'task_date': formattedDate,
                        'employeeIds': selectedEmployeeIds,
                      });
                      _fetchTasks();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم إنشاء المهمة بنجاح'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  label: const Text('إرسال وتكليف المهمة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: royalGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNoteDialog(String taskId, bool isCompleteAction, {String initialNote = ''}) {
    final noteController = TextEditingController(text: initialNote);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(isCompleteAction ? Icons.task_alt : Icons.edit_note, color: isCompleteAction ? Colors.green : goldColor),
            const SizedBox(width: 8),
            Text(
              isCompleteAction ? 'إنجاز وترحيل المهمة' : 'إضافة رد / توضيح على المهمة',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCompleteAction ? 'يرجى إدخال الرد/التوضيح النهائي لما تم إنجازه في هذه المهمة:' : 'اكتب توضيحاً أو استفساراً بشأن المهمة:',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'اكتب تفاصيل الإنجاز والرد هنا...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: royalGreen, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              if (isCompleteAction) {
                _completeTask(taskId, noteController.text.trim());
              } else {
                _updateNote(taskId, noteController.text.trim());
              }
            },
            icon: Icon(isCompleteAction ? Icons.check : Icons.save, size: 16),
            label: Text(isCompleteAction ? 'إنجاز ونقل للأرشيف' : 'حفظ الرد', style: const TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCompleteAction ? Colors.green : royalGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get displayTasks {
    final uid = widget.currentUser.uid;

    List<Map<String, dynamic>> baseList = _tasks;

    // Filter by tab
    if (_activeTab == 'active') {
      baseList = _tasks.where((t) => t['status'] != 'done').toList();
    } else if (_activeTab == 'archived') {
      baseList = _tasks.where((t) => t['status'] == 'done').toList();
    }

    return baseList;
  }

  @override
  Widget build(BuildContext context) {
    final tasksList = displayTasks;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showCreateTaskModal,
              backgroundColor: royalGreen,
              icon: const Icon(Icons.add_task, color: Colors.white),
              label: const Text('مهمة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            )
          : null,
      body: Column(
        children: [
          LuxuryHeader(
            title: 'إدارة المهام اليومية',
            subtitle: 'متابعة شريط إنجاز المهام والردود والأرشيف',
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.white),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2023),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    _fetchTasks();
                  }
                },
                tooltip: 'اختيار التاريخ',
              ),
            ],
          ),
          
          // Date selector bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_note, size: 18, color: goldColor),
                    const SizedBox(width: 6),
                    Text(
                      'تاريخ المهام: ${_formatDate(_selectedDate)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: royalGreen),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _selectedDate = DateTime.now());
                    _fetchTasks();
                  },
                  child: const Text('اليوم', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Multi-tab Segmented Controller (المهام الحالية | المهام المنجزة والأرشيف | جميع المهام)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 'active'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _activeTab == 'active' ? royalGreen : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hourglass_top, size: 14, color: _activeTab == 'active' ? Colors.amber : Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'المهام الحالية',
                            style: TextStyle(
                              color: _activeTab == 'active' ? Colors.white : const Color(0xFF475569),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 'archived'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _activeTab == 'archived' ? Colors.green.shade800 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: _activeTab == 'archived' ? Colors.white : Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'المهام المؤرشفة',
                            style: TextStyle(
                              color: _activeTab == 'archived' ? Colors.white : const Color(0xFF475569),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeTab = 'all'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _activeTab == 'all' ? goldColor : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.list_alt, size: 14, color: _activeTab == 'all' ? Colors.white : Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'الكل',
                              style: TextStyle(
                                color: _activeTab == 'all' ? Colors.white : const Color(0xFF475569),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: royalGreen))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            const Text('حدث خطأ في تحميل المهام', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchTasks,
                              style: ElevatedButton.styleFrom(backgroundColor: royalGreen, foregroundColor: Colors.white),
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchTasks,
                        color: royalGreen,
                        child: tasksList.isEmpty
                            ? ListView(
                                children: [
                                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _activeTab == 'archived' ? Icons.folder_off_outlined : Icons.task_alt,
                                          size: 60,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _activeTab == 'archived' ? 'لا توجد مهام مؤرشفة لهذا اليوم' : 'لا توجد مهام حالية في هذا التاريخ',
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: tasksList.length,
                                itemBuilder: (context, index) {
                                  final task = tasksList[index];
                                  final isDone = task['status'] == 'done';
                                  final assignments = task['assignments'] as List?;
                                  final creatorName = task['creator_name'] ?? 'إدارة المكتب';
                                  
                                  String createdDate = '';
                                  if (task['created_at'] != null) {
                                    final raw = task['created_at'].toString();
                                    createdDate = raw.contains('T') ? raw.split('T')[0] : raw;
                                  }

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    elevation: 2,
                                    shadowColor: Colors.black12,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: isDone ? Colors.green.shade300 : const Color(0xFFE2E8F0),
                                        width: isDone ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Task Header Title & Badge
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: isDone ? Colors.green.shade50 : Colors.amber.shade50,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  isDone ? Icons.check_circle : Icons.hourglass_bottom,
                                                  color: isDone ? Colors.green.shade700 : Colors.amber.shade800,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      task['title'] ?? '',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.bold,
                                                        color: const Color(0xFF0F172A),
                                                        decoration: isDone ? TextDecoration.lineThrough : null,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.person_outline, size: 12, color: Colors.grey),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'بواسطة: $creatorName',
                                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                                        ),
                                                        if (createdDate.isNotEmpty) ...[
                                                          const SizedBox(width: 8),
                                                          const Icon(Icons.calendar_today, size: 11, color: Colors.grey),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            createdDate,
                                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (isAdmin) ...[
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                  onPressed: () => _deleteTask(task['id'].toString()),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                              ],
                                            ],
                                          ),

                                          const SizedBox(height: 12),

                                          // Task Progress Indicator Bar
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    isDone ? 'شريط الإنجاز: 100% (منتهية ومؤرشفة)' : 'شريط الإنجاز: 35% (جاري التنفيذ والمتابعة)',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDone ? Colors.green.shade800 : Colors.amber.shade900,
                                                    ),
                                                  ),
                                                  Icon(
                                                    isDone ? Icons.verified : Icons.pending_actions,
                                                    size: 14,
                                                    color: isDone ? Colors.green : Colors.amber.shade800,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(6),
                                                child: LinearProgressIndicator(
                                                  value: isDone ? 1.0 : 0.35,
                                                  minHeight: 7,
                                                  backgroundColor: const Color(0xFFE2E8F0),
                                                  color: isDone ? Colors.green : Colors.amber.shade700,
                                                ),
                                              ),
                                            ],
                                          ),

                                          if (task['description'] != null && task['description'].toString().isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                task['description'],
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                                              ),
                                            ),
                                          ],

                                          // Display assignments vertically stacked line by line
                                          if (assignments != null && assignments.isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'الموظفون المكلفون بالمهام:',
                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  ...assignments.map((a) {
                                                    final empName = a['employee_name'] ?? a['employee_id'] ?? 'موظف';
                                                    final aDone = a['status'] == 'done';
                                                    return Container(
                                                      margin: const EdgeInsets.only(bottom: 4),
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(empName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                          Row(
                                                            children: [
                                                              Icon(aDone ? Icons.check_circle : Icons.access_time, size: 12, color: aDone ? Colors.green : Colors.amber.shade800),
                                                              const SizedBox(width: 4),
                                                              Text(aDone ? 'منجزة' : 'معلقة', style: TextStyle(fontSize: 10, color: aDone ? Colors.green : Colors.amber.shade800, fontWeight: FontWeight.bold)),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              ),
                                            ),
                                          ],

                                          // Reply & Completion Note Section
                                          if (task['completion_note'] != null && task['completion_note'].toString().isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: Colors.blue.shade200),
                                              ),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(Icons.comment, size: 16, color: Colors.blue),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const Text('رد وتوضيح المهمة:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                                                        const SizedBox(height: 2),
                                                        Text(task['completion_note'], style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                                                    onPressed: () => _showNoteDialog(task['id'].toString(), false, initialNote: task['completion_note']),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    tooltip: 'تعديل الرد',
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],

                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              if (task['completion_note'] == null || task['completion_note'].toString().isEmpty)
                                                OutlinedButton.icon(
                                                  onPressed: () => _showNoteDialog(task['id'].toString(), false),
                                                  icon: const Icon(Icons.add_comment, size: 14),
                                                  label: const Text('إضافة رد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                              const SizedBox(width: 8),
                                              ElevatedButton.icon(
                                                onPressed: () => _showNoteDialog(task['id'].toString(), !isDone),
                                                icon: Icon(isDone ? Icons.undo : Icons.check_circle, size: 15),
                                                label: Text(
                                                  isDone ? 'إعادة للمهام الحالية' : 'إنجاز وترحيل للأرشيف',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isDone ? Colors.orange : Colors.green.shade800,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                ),
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
      ),
    );
  }
}
