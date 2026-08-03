import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import '../config.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ClientDashboardView extends StatefulWidget {
  final VoidCallback onLogout;

  const ClientDashboardView({super.key, required this.onLogout});

  @override
  State<ClientDashboardView> createState() => _ClientDashboardViewState();
}

class _ClientDashboardViewState extends State<ClientDashboardView> {
  int _currentIndex = 0;
  bool _loading = true;
  String? _error;

  List<Case> _cases = [];
  List<Appointment> _appointments = [];
  List<ChatRoom> _chatRooms = [];
  List<SystemUser> _staff = [];

  // Active chat room details
  ChatRoom? _activeRoom;
  List<ChatMessage> _messages = [];
  bool _loadingMessages = false;
  bool _sending = false;
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _messagesTimer;
  Timer? _pollingTimer;
  bool _clientClosedRoom = false;

  final Color royalGreen = const Color(0xFF1E3D30);
  final Color goldColor = const Color(0xFFB8963A);

  @override
  void initState() {
    super.initState();
    _fetchData();
    _startGeneralPolling();
  }

  @override
  void dispose() {
    _messagesTimer?.cancel();
    _pollingTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ApiService();
      // Fetch client specific cases & appointments
      final casesData = await api.getClientCases();
      final apptsData = await api.getClientAppointments();
      
      // Fetch chat rooms
      List<ChatRoom> rooms = [];
      try {
        rooms = await api.getChatRooms();
      } catch (_) {}

      // Fetch staff (to map lawyer names/photos in chat if needed)
      List<SystemUser> staffList = [];
      try {
        staffList = await api.getUsers();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _cases = casesData;
          _appointments = apptsData;
          _chatRooms = rooms;
          _staff = staffList;
          _loading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _startGeneralPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted && _activeRoom == null) {
        _silentFetchData();
      }
    });
  }

  Future<void> _silentFetchData() async {
    try {
      final api = ApiService();
      final casesData = await api.getClientCases();
      final apptsData = await api.getClientAppointments();
      List<ChatRoom> rooms = [];
      try {
        rooms = await api.getChatRooms();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _cases = casesData;
          _appointments = apptsData;
          _chatRooms = rooms;
        });
      }
    } catch (_) {}
  }

  // --- Calendar Export Helper ---
  Future<void> _addToCalendar(Appointment appt) async {
    try {
      final dateStr = appt.date;
      final parsedDate = DateTime.parse(dateStr);

      final Event event = Event(
        title: 'جلسة مرافعة: ${appt.caseTitle ?? appt.title} - مكتب حجاج',
        description: 'الموضوع: ${appt.caseSubject ?? appt.title}\nالمحكمة: ${appt.court}\nالمحامي المسؤول: ${appt.lawyerName ?? "مكتب حجاج للمحاماة"} \n\n* تنبيه تلقائي قبل الجلسة بـ 30 دقيقة.',
        location: appt.court,
        startDate: parsedDate,
        endDate: parsedDate.add(const Duration(hours: 1)),
        iosParams: const IOSParams(
          reminder: Duration(minutes: 30),
        ),
      );

      final success = await Add2Calendar.addEvent2Cal(event);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم فتح تقويم الهاتف لإضافة موعد الجلسة بنجاح.', textDirection: TextDirection.rtl),
            backgroundColor: royalGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إضافة الموعد للتقويم: $err', textDirection: TextDirection.rtl),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- Direct Chat Helpers ---
  void _openRoom(ChatRoom room) {
    setState(() {
      _activeRoom = room;
      _messages = [];
      _loadingMessages = true;
      _clientClosedRoom = false;
    });

    _fetchMessages(room.id).whenComplete(() {
      if (mounted) setState(() => _loadingMessages = false);
    });

    // Poll messages every 3 seconds
    _messagesTimer?.cancel();
    _messagesTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _activeRoom != null) {
        _fetchMessages(_activeRoom!.id);
      }
    });
  }

  void _closeRoom() {
    _messagesTimer?.cancel();
    setState(() {
      _activeRoom = null;
      _messages = [];
      _clientClosedRoom = true;
    });
    _silentFetchData();
  }

  Future<void> _fetchMessages(String roomId) async {
    try {
      final chatMessages = await ApiService().getChatMessages(roomId);
      if (mounted) {
        setState(() => _messages = chatMessages);
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _msgController.text.trim();
    if (_activeRoom == null || text.isEmpty || _sending) return;

    _msgController.clear();
    setState(() => _sending = true);

    try {
      final newMsg = await ApiService().sendChatMessage(_activeRoom!.id, text);
      if (mounted) {
        setState(() => _messages.add(newMsg));
        _scrollToBottom();
      }
    } catch (_) {
      _msgController.text = text;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إرسال الرسالة. يرجى المحاولة لاحقاً.')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startChatWithLawyer(String lawyerId, String lawyerName) async {
    final currentUser = ApiService().currentUser;
    if (currentUser == null) return;

    setState(() => _loading = true);
    try {
      // Check if room already exists
      final existing = _chatRooms.firstWhere(
        (r) => r.type == 'individual' && r.participantIds.contains(lawyerId) && r.participantIds.contains(currentUser.uid),
        orElse: () => ChatRoom(id: '', type: '', participantIds: [], createdAt: '', lastMessageAt: ''),
      );

      if (existing.id.isNotEmpty) {
        setState(() => _loading = false);
        _openRoom(existing);
      } else {
        final newRoom = await ApiService().createChatRoom({
          'type': 'individual',
          'participantIds': [currentUser.uid, lawyerId]
        });
        setState(() {
          _chatRooms.insert(0, newRoom);
          _loading = false;
        });
        _openRoom(newRoom);
      }
    } catch (_) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل بدء محادثة مع المحامي.')));
    }
  }

  String _getRoomName(ChatRoom room) {
    if (room.type == 'group') return room.name ?? 'مجموعة القضية';
    final currentUser = ApiService().currentUser;
    if (currentUser == null) return 'المحامي المسؤول';

    if (room.participants != null && room.participants!.isNotEmpty) {
      final other = room.participants!.firstWhere((p) => p.id != currentUser.uid, orElse: () => ChatRoomParticipant(id: '', name: '', role: ''));
      if (other.id.isNotEmpty) {
        return other.role == 'client' ? '${other.name} (موكل)' : other.name;
      }
    }

    final otherId = room.participantIds.firstWhere((id) => id != currentUser.uid, orElse: () => '');
    if (otherId.isEmpty) return 'المحامي المسؤول';
    final partner = _staff.firstWhere((u) => u.uid == otherId, orElse: () => SystemUser(uid: '', email: '', username: '', name: 'المحامي المسؤول', role: '', createdAt: ''));
    return partner.name;
  }

  // --- UI Views ---

  // Tab 1: My Cases
  Widget _buildCasesTab() {
    if (_cases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.gavel_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'لا توجد قضايا مسجلة باسمك حالياً',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                'إذا كنت تملك قضية قائمة، يرجى التواصل مع مكتب المحاماة لربطها برقم هاتفك.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: royalGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _cases.length,
        itemBuilder: (context, index) {
          final c = _cases[index];
          
          Color statusColor = Colors.grey;
          if (c.status == 'مفتوح') statusColor = Colors.green;
          if (c.status == 'قيد النظر') statusColor = Colors.amber.shade700;
          if (c.status == 'تحت المراجعة') statusColor = Colors.blue;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: statusColor, width: 5)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  title: Text(
                    c.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text('رقم القضية: #${c.caseNumber}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Text('المحكمة: ${c.court}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      if (c.lawyerName != null) ...[
                        const SizedBox(height: 4),
                        Text('المحامي المسؤول: ${c.lawyerName}', style: TextStyle(fontSize: 11, color: goldColor, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                  trailing: Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.grey[400]),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CaseDetailScreen(kase: c, onAddToCalendar: _addToCalendar, onStartChat: _startChatWithLawyer)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Tab 2: My Sessions (Agenda)
  Widget _buildSessionsTab() {
    if (_appointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'لا توجد جلسات مجدولة لقضاياك حالياً',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: royalGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _appointments.length,
        itemBuilder: (context, index) {
          final appt = _appointments[index];
          
          final dateStr = appt.date;
          final [datePart, timePart] = dateStr.contains('T') ? dateStr.split('T') : [dateStr, ''];
          
          String timeFormatted = '--:--';
          if (timePart.isNotEmpty) {
            try {
              timeFormatted = intl.DateFormat('hh:mm a').format(DateTime.parse(appt.date));
            } catch (_) {
              timeFormatted = timePart;
            }
          }

          String dateFormatted = datePart;
          try {
            dateFormatted = intl.DateFormat('dd MMMM yyyy', 'ar').format(DateTime.parse(datePart));
          } catch (_) {}

          final isUpcoming = appt.status == 'scheduled';

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isUpcoming ? royalGreen.withOpacity(0.15) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isUpcoming ? royalGreen.withOpacity(0.08) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, size: 12, color: isUpcoming ? royalGreen : Colors.grey[700]),
                            const SizedBox(width: 4),
                            Text(
                              timeFormatted,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isUpcoming ? royalGreen : Colors.grey[800]),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isUpcoming ? Colors.blue.shade50.withOpacity(0.8) : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isUpcoming ? Colors.blue.shade200 : Colors.green.shade200,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          isUpcoming ? 'مجدولة قادمة' : 'جلسة مكتملة',
                          style: TextStyle(
                            fontSize: 9, 
                            fontWeight: FontWeight.bold, 
                            color: isUpcoming ? Colors.blue.shade900 : Colors.green.shade900
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    appt.caseSubject ?? appt.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),
                  Text('🗓️ التاريخ: $dateFormatted', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text('🏢 المحكمة: ${appt.court}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  if (appt.lawyerName != null) ...[
                    const SizedBox(height: 4),
                    Text('👨‍⚖️ المحامي المسؤول: ${appt.lawyerName}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                  if (appt.notes != null && appt.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200.withOpacity(0.5)),
                      ),
                      child: Text(
                        '📝 قرارات الجلسة:\n${appt.notes}',
                        style: const TextStyle(fontSize: 10, color: Colors.black87, height: 1.4),
                      ),
                    )
                  ],
                  if (isUpcoming) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: ElevatedButton.icon(
                        onPressed: () => _addToCalendar(appt),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: const Text('إضافة لتقويم الهاتف مع تنبيه (30 دقيقة)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: royalGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: royalGreen, width: 1),
                          )
                        ),
                      ),
                    )
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Tab 3: Chat with Lawyer
  Widget _buildChatTab() {
    if (_activeRoom != null) {
      final currentUser = ApiService().currentUser;
      return Column(
        children: [
          // Subheader/Back button
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _closeRoom,
                ),
                Text(
                  _getRoomName(_activeRoom!),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 48), // Spacer to center title
              ],
            ),
          ),

          // Messages
          Expanded(
            child: _loadingMessages && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 40, color: Colors.black26),
                            SizedBox(height: 8),
                            Text('لا توجد رسائل سابقة. تواصل مع محاميك الآن!', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(14),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.senderId == currentUser?.uid;
                          
                          String timeStr = '';
                          try {
                            timeStr = intl.DateFormat('hh:mm a').format(DateTime.parse(msg.createdAt));
                          } catch (_) {
                            timeStr = msg.createdAt;
                          }

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? royalGreen.withOpacity(0.08) : const Color(0xFFF1F5F9),
                                border: Border.all(color: isMe ? royalGreen.withOpacity(0.15) : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(2),
                                  bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 3.0),
                                      child: Text(msg.senderName, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: goldColor)),
                                    ),
                                  Text(msg.text, style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.4)),
                                  const SizedBox(height: 4),
                                  Text(timeStr, style: const TextStyle(fontSize: 7, color: Color(0xFF94A3B8))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Message input bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).viewPadding.bottom + 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك للمحامي المسؤول...',
                      hintStyle: const TextStyle(fontSize: 11),
                      fillColor: const Color(0xFFF8FAFC),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: goldColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _handleSendMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: royalGreen,
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                      side: BorderSide(color: goldColor, width: 0.5),
                    ),
                    child: _sending 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Icon(Icons.send, color: Colors.white, size: 16),
                  ),
                )
              ],
            ),
          )
        ],
      );
    }

    // List of rooms or direct launcher
    if (_chatRooms.isEmpty) {
      // Check if we can find any lawyer assigned to their cases to initiate a chat
      final lawyerId = _cases.firstWhere((c) => c.lawyerId != null && c.lawyerId!.isNotEmpty, orElse: () => Case(id: '', caseNumber: '', title: '', customerId: '', customerName: '', description: '', status: '', archivedById: '', archivedByName: '', court: '', caseType: '', actionHistory: [], notesHistory: [], attachments: [], createdAt: '', updatedAt: '')).lawyerId;
      final lawyerName = _cases.firstWhere((c) => c.lawyerName != null && c.lawyerName!.isNotEmpty, orElse: () => Case(id: '', caseNumber: '', title: '', customerId: '', customerName: '', description: '', status: '', archivedById: '', archivedByName: '', court: '', caseType: '', actionHistory: [], notesHistory: [], attachments: [], createdAt: '', updatedAt: '')).lawyerName;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'بوابة الدردشة المشفرة مع المحامي',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                'تتيح لك هذه البوابة إرسال مستندات ورسائل قانونية مباشرة إلى محاميك بشكل مشفر تماماً.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              if (lawyerId != null && lawyerId.isNotEmpty) ...[
                ElevatedButton.icon(
                  onPressed: () => _startChatWithLawyer(lawyerId, lawyerName ?? 'المحامي المسؤول'),
                  icon: const Icon(Icons.chat),
                  label: Text('بدء دردشة مع المحامي $lawyerName'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: royalGreen,
                    foregroundColor: Colors.white,
                    side: BorderSide(color: goldColor),
                  ),
                )
              ] else ...[
                const Text(
                  'سيتم تفعيل الدردشة بمجرد تعيين محامٍ لقضيتك.',
                  style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                )
              ]
            ],
          ),
        ),
      );
    }

    // If there is exactly one room, let's open it automatically to save the client a step!
    if (_chatRooms.length == 1 && _activeRoom == null && !_clientClosedRoom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activeRoom == null) {
          _openRoom(_chatRooms.first);
        }
      });
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _chatRooms.length,
      itemBuilder: (context, index) {
        final room = _chatRooms[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: royalGreen.withOpacity(0.08),
              foregroundColor: royalGreen,
              child: const Icon(Icons.person, size: 20),
            ),
            title: Text(_getRoomName(room), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            subtitle: const Text('المحامي المستشار المسؤول', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
            trailing: Icon(Icons.arrow_back_ios_new, size: 12, color: goldColor),
            onTap: () => _openRoom(room),
          ),
        );
      },
    );
  }

  // Tab 4: My Account
  Widget _buildAccountTab() {
    final currentUser = ApiService().currentUser;
    if (currentUser == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: royalGreen,
                  child: Text(
                    currentUser.name.substring(0, 1),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: goldColor),
                  ),
                ),
                const SizedBox(height: 12),
                Text(currentUser.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(currentUser.username, style: TextStyle(fontSize: 12, color: goldColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'حساب موكل معتمد',
                    style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildAccountRow('الاسم الكامل:', currentUser.name),
                _buildAccountRow('رقم الجوال:', currentUser.username),
                if (currentUser.email.isNotEmpty)
                  _buildAccountRow('البريد الإلكتروني:', currentUser.email),
                _buildAccountRow('نوع العضوية:', 'موكل / عميل للشركة'),
                _buildAccountRow('درجة التشفير:', 'تشفير عسكري آمن 256-bit'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.15)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.blue, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'اتصالك آمن ومحمي بنظام التشفير التابع لشركة حجاج الضويحي للمحاماة، ولا يمكن لأي طرف ثالث الاطلاع على قضاياك ومرفقاتك.',
                    style: TextStyle(fontSize: 9, color: Colors.blueGrey, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Google Maps Rating Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: goldColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: goldColor.withOpacity(0.3), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: goldColor, size: 24),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'تقييم خدماتنا على Google Maps',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E3D30)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'عميلنا العزيز،\n\n'
                  'يسعدنا مشاركة تجربتكم الصادقة معنا وتقييم خدماتنا على Google. تعليقكم يمثل لنا حافزاً دائماً لتقديم الأفضل، ويساعدنا على مواصلة تقديم خدماتنا القانونية بأعلى مستويات الجودة والاحترافية.\n\n'
                  '⭐ تسرنا كتابة رأيك وتقييمك الصادق لخدماتنا.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.5),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse('https://g.page/r/Ccwmt_i2Qzq9EBE/review');
                      try {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } catch (_) {
                        try {
                          await launchUrl(url, mode: LaunchMode.platformDefault);
                        } catch (_) {}
                      }
                    },
                    icon: const Icon(Icons.rate_review_outlined, size: 16),
                    label: const Text('اضغط هنا لمشاركة تقييمك', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: royalGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: goldColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'شكرًا لكم على ثقتكم، ونتطلع دائمًا لخدمتكم وأفراد عائلتكم بكل احترافية ومصداقية.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('تسجيل خروج آمن', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                foregroundColor: Colors.red,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Colors.redAccent, width: 0.5),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAccountRow(String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: royalGreen),
              const SizedBox(height: 16),
              const Text('بوابة الموكلين — جاري تحميل قضاياك...', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('حدث خطأ: $_error', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _fetchData,
                  style: ElevatedButton.styleFrom(backgroundColor: royalGreen, foregroundColor: Colors.white),
                  child: const Text('إعادة المحاولة'),
                )
              ],
            ),
          ),
        ),
      );
    }

    final views = [
      _buildCasesTab(),
      _buildSessionsTab(),
      _buildChatTab(),
      _buildAccountTab(),
    ];

    // Hide Bottom Navigation if actively in a chat room
    final hideNavBar = _currentIndex == 2 && _activeRoom != null;

    return Scaffold(
      appBar: _currentIndex == 2 && _activeRoom != null
          ? null // Let the chat tab draw its own app bar
          : AppBar(
              title: Text(
                _currentIndex == 0
                    ? 'قضاياي الجارية'
                    : _currentIndex == 1
                        ? 'مواعيد جلساتي'
                        : _currentIndex == 2
                            ? 'المحادثة مع المستشار'
                            : 'حسابي القانوني',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0.5,
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchData,
                )
              ],
            ),
      body: views[_currentIndex],
      bottomNavigationBar: hideNavBar
          ? null
          : BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: goldColor,
              unselectedItemColor: Colors.black54,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
              unselectedLabelStyle: const TextStyle(fontSize: 10),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.gavel_outlined, size: 20), label: 'قضاياي'),
                BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined, size: 20), label: 'جلساتي'),
                BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline, size: 20), label: 'المحادثة'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline, size: 20), label: 'حسابي'),
              ],
            ),
    );
  }
}

// --- Case Detail & Vertical Sessions Timeline Screen ---
class CaseDetailScreen extends StatelessWidget {
  final Case kase;
  final Function(Appointment) onAddToCalendar;
  final Function(String, String) onStartChat;

  const CaseDetailScreen({super.key, required this.kase, required this.onAddToCalendar, required this.onStartChat});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'مفتوح': return Colors.green;
      case 'قيد النظر': return Colors.amber.shade700;
      case 'تحت المراجعة': return Colors.blue;
      default: return Colors.grey;
    }
  }

  // File launching helper
  Future<void> _launchUrl(String urlString) async {
    if (urlString.isEmpty) return;

    String fullUrl = urlString;
    if (urlString.startsWith('/')) {
      fullUrl = '${AppConfig.baseUrl}$urlString';
    }

    final Uri uri = Uri.parse(fullUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color royalGreen = const Color(0xFF1E3D30);
    final Color goldColor = const Color(0xFFB8963A);
    final statusColor = _getStatusColor(kase.status);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text(kase.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Case Info Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '#${kase.caseNumber}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: goldColor),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.3), width: 0.5),
                        ),
                        child: Text(
                          kase.status,
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFFF1F5F9)),
                  _buildInfoRow('نوع الدعوى:', kase.caseType),
                  _buildInfoRow('المحكمة:', kase.court),
                  _buildInfoRow('صفة الموكل:', kase.clientType ?? 'مدعي'),
                  if (kase.lawyerName != null) ...[
                    _buildInfoRow('المحامي المسؤول:', kase.lawyerName!),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onStartChat(kase.lawyerId!, kase.lawyerName!);
                        },
                        icon: const Icon(Icons.chat_outlined, size: 16),
                        label: Text('مراسلة المحامي ${kase.lawyerName!}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: royalGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: goldColor),
                          )
                        ),
                      ),
                    )
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Description
            const Text(
              'شرح موضوع الدعوى',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                kase.description.isNotEmpty ? kase.description : 'لا يوجد شرح مفصل مسجل لهذه القضية بعد.',
                style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.6),
              ),
            ),
            const SizedBox(height: 20),

            // Ruling (Final Decision)
            if (kase.ruling != null && kase.ruling!.isNotEmpty) ...[
              const Text(
                '⚖️ منطوق الحكم النهائي الصادر',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade200.withOpacity(0.6)),
                ),
                child: Text(
                  kase.ruling!,
                  style: TextStyle(fontSize: 11, color: Colors.amber.shade900, height: 1.6, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Vertical Timeline of Sessions (Najiz Style)
            const Text(
              '📅 سجل الجلسات المتسلسل (المخطط الزمني)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            _buildVerticalTimeline(kase, royalGreen, goldColor),
            const SizedBox(height: 20),

            // Documents (Attachments)
            const Text(
              '📂 المستندات والمرفقات الرسمية',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            _buildDocumentsList(kase, royalGreen),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  // --- Vertical Timeline builder ---
  Widget _buildVerticalTimeline(Case c, Color royalGreen, Color goldColor) {
    // Standard Flutter doesn't have an appointments list directly inside Case object unless we mapped it.
    // Wait! Let's check: in `server/index.ts`, `GET /api/client/cases` returns cases with:
    // `appointments: mappedAppointments`.
    // Wait, let's see if our Flutter client model parses appointments inside `Case` class!
    // Oh! In `models.dart`, the `Case` class does NOT have an `appointments` field!
    // But wait! Can we fetch appointments and filter them by `caseId`? Yes!
    // But wait! Let's check: does `Case` class in `models.dart` have an `appointments` field?
    // Let's check `Case` class again. No, it had:
    // `final List<String> actionHistory;`
    // `final List<String> notesHistory;`
    // `final List<Attachment> attachments;`
    // Wait! If the Case model in the mobile app doesn't have appointments, how does it know the appointments?
    // In `CaseDetailScreen`, we can pass down the appointments list from the dashboard, OR we can filter the general appointments list!
    // Yes! In `CaseDetailScreen` constructor, we can just pass the appointments of this case, OR we can filter them.
    // Wait, let's see where `CaseDetailScreen` is opened.
    // In `ClientDashboardViewState`, it opens `CaseDetailScreen(kase: c, onAddToCalendar: _addToCalendar, onStartChat: _startChatWithLawyer)`.
    // We can easily change it to pass the appointments!
    // Let's see: `_appointments.where((a) => a.caseId == c.id).toList()`!
    // This is incredibly easy and elegant, and avoids modifying `models.dart`!
    // Let's modify `CaseDetailScreen` to accept `List<Appointment> caseAppointments`.
    // Let's implement the vertical timeline using this list!
    
    return CaseSessionsTimelineWidget(caseId: c.id, onAddToCalendar: onAddToCalendar, royalGreen: royalGreen, goldColor: goldColor);
  }

  // --- Case Documents List ---
  Widget _buildDocumentsList(Case c, Color royalGreen) {
    if (c.attachments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'لا توجد مستندات مرفوعة لهذه القضية بعد.',
            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: c.attachments.length,
      itemBuilder: (context, index) {
        final doc = c.attachments[index];
        final isPdf = doc.name.toLowerCase().endsWith('.pdf');
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPdf ? Colors.red.withOpacity(0.08) : Colors.blue.withOpacity(0.08),
              foregroundColor: isPdf ? Colors.red : Colors.blue,
              child: Icon(isPdf ? Icons.picture_as_pdf_outlined : Icons.description_outlined, size: 18),
            ),
            title: Text(doc.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            subtitle: Text(doc.size, style: const TextStyle(fontSize: 9, color: Colors.grey)),
            trailing: Icon(Icons.open_in_new, size: 16, color: royalGreen),
            onTap: () => _launchUrl(doc.url),
          ),
        );
      },
    );
  }
}

// --- Stateful Sessions Timeline Widget to easily handle filtering and rendering ---
class CaseSessionsTimelineWidget extends StatefulWidget {
  final String caseId;
  final Function(Appointment) onAddToCalendar;
  final Color royalGreen;
  final Color goldColor;

  const CaseSessionsTimelineWidget({
    super.key,
    required this.caseId,
    required this.onAddToCalendar,
    required this.royalGreen,
    required this.goldColor,
  });

  @override
  State<CaseSessionsTimelineWidget> createState() => _CaseSessionsTimelineWidgetState();
}

class _CaseSessionsTimelineWidgetState extends State<CaseSessionsTimelineWidget> {
  List<Appointment> _caseAppointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    try {
      final allAppts = await ApiService().getClientAppointments();
      if (mounted) {
        setState(() {
          _caseAppointments = allAppts.where((a) => a.caseId == widget.caseId).toList();
          // Sort from oldest to newest to show the case journey chronologically
          _caseAppointments.sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator()));
    }

    if (_caseAppointments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'لا توجد جلسات مسجلة لهذه القضية بعد.',
            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _caseAppointments.length,
      itemBuilder: (context, index) {
        final appt = _caseAppointments[index];
        final dateStr = appt.date;
        final [datePart, timePart] = dateStr.contains('T') ? dateStr.split('T') : [dateStr, ''];
        
        String timeFormatted = '--:--';
        if (timePart.isNotEmpty) {
          try {
            timeFormatted = intl.DateFormat('hh:mm a').format(DateTime.parse(appt.date));
          } catch (_) {
            timeFormatted = timePart;
          }
        }

        String dateFormatted = datePart;
        try {
          dateFormatted = intl.DateFormat('dd MMMM yyyy', 'ar').format(DateTime.parse(datePart));
        } catch (_) {}

        final isUpcoming = appt.status == 'scheduled';
        final isLast = index == _caseAppointments.length - 1;

        Color dotColor = Colors.grey;
        if (appt.status == 'scheduled') dotColor = Colors.blue;
        if (appt.status == 'completed') dotColor = Colors.green;
        if (appt.status == 'postponed') dotColor = Colors.amber.shade700;
        if (appt.status == 'cancelled') dotColor = Colors.red;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isUpcoming ? widget.royalGreen.withOpacity(0.15) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            appt.caseSubject ?? appt.title,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isUpcoming ? Colors.blue.withOpacity(0.08) : Colors.grey.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isUpcoming ? 'جلسة قادمة' : 'جلسة سابقة',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isUpcoming ? Colors.blue : Colors.grey[700]),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('🗓️ التاريخ: $dateFormatted | 🕒 الوقت: $timeFormatted', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                      if (appt.court.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('🏢 المحكمة: ${appt.court}', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                      ],
                      if (appt.notes != null && appt.notes!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade100),
                          ),
                          child: Text(
                            '📝 القرارات والتوصيات:\n${appt.notes}',
                            style: const TextStyle(fontSize: 9, color: Colors.black87, height: 1.4),
                          ),
                        )
                      ],
                      if (isUpcoming) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 30,
                          child: TextButton.icon(
                            onPressed: () => widget.onAddToCalendar(appt),
                            icon: Icon(Icons.calendar_today, size: 12, color: widget.royalGreen),
                            label: Text('إضافة للتقويم وتنبيه', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: widget.royalGreen)),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: widget.royalGreen, width: 0.5),
                              )
                            ),
                          ),
                        )
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Timeline Graphics (Vertical line + circle dot)
              Column(
                children: [
                  // Dot
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: dotColor, width: 3),
                      boxShadow: [
                        if (isUpcoming)
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.4),
                            blurRadius: 6,
                            spreadRadius: 2,
                          )
                      ]
                    ),
                  ),
                  // Line
                  Expanded(
                    child: isLast
                        ? const SizedBox()
                        : Container(
                            width: 2,
                            color: const Color(0xFFCBD5E1),
                          ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
