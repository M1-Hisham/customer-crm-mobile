import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ChatView extends StatefulWidget {
  final List<SystemUser> staff;
  final String? activeRoomId;
  final Set<String> unreadRoomIds;
  final ValueChanged<String?> onActiveRoomChanged;

  const ChatView({
    super.key,
    required this.staff,
    this.activeRoomId,
    required this.unreadRoomIds,
    required this.onActiveRoomChanged,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  List<ChatRoom> _rooms = [];
  bool _loadingRooms = false;
  ChatRoom? _activeRoom;
  List<ChatMessage> _messages = [];
  bool _loadingMessages = false;
  bool _sending = false;
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  Timer? _roomsTimer;
  Timer? _messagesTimer;

  final Color royalGreen = const Color(0xFF1E3D30);
  final Color goldColor = const Color(0xFFB8963A);

  @override
  void initState() {
    super.initState();
    _loadingRooms = true;
    _fetchRooms().whenComplete(() => setState(() => _loadingRooms = false));
    
    // Poll rooms every 6 seconds
    _roomsTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted && _activeRoom == null) _fetchRooms();
    });
  }

  @override
  void dispose() {
    _roomsTimer?.cancel();
    _messagesTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    widget.onActiveRoomChanged(null);
    super.dispose();
  }

  Future<void> _fetchRooms() async {
    try {
      final chatRooms = await ApiService().getChatRooms();
      if (mounted) {
        setState(() => _rooms = chatRooms);
      }
    } catch (_) {}
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

  void _openRoom(ChatRoom room) {
    setState(() {
      _activeRoom = room;
      _messages = [];
      _loadingMessages = true;
    });

    widget.onActiveRoomChanged(room.id);
    ApiService().markMessagesAsRead(room.id).catchError((_) {});

    _fetchMessages(room.id).whenComplete(() => setState(() => _loadingMessages = false));

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
    });
    widget.onActiveRoomChanged(null);
    _fetchRooms();
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
      _msgController.text = text; // Restore
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إرسال الرسالة.')));
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _startNewChat(SystemUser targetUser) async {
    Navigator.pop(context); // Close dialog
    final currentUser = ApiService().currentUser;
    if (currentUser == null) return;

    setState(() => _loadingRooms = true);
    try {
      // Find if room already exists
      final existing = _rooms.firstWhere(
        (r) => r.type == 'individual' && r.participantIds.contains(targetUser.uid) && r.participantIds.contains(currentUser.uid),
        orElse: () => ChatRoom(id: '', type: '', participantIds: [], createdAt: '', lastMessageAt: ''),
      );

      if (existing.id.isNotEmpty) {
        _openRoom(existing);
      } else {
        final newRoom = await ApiService().createChatRoom({
          'type': 'individual',
          'participantIds': [currentUser.uid, targetUser.uid]
        });
        setState(() => _rooms.insert(0, newRoom));
        _openRoom(newRoom);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل بدء محادثة جديدة.')));
    } finally {
      setState(() => _loadingRooms = false);
    }
  }

  String _getRoomName(ChatRoom room) {
    if (room.type == 'group') return room.name ?? 'مجموعة عمل جماعية';
    final currentUser = ApiService().currentUser;
    if (currentUser == null) return 'محادثة شخصية';
    
    if (room.participants != null && room.participants!.isNotEmpty) {
      final other = room.participants!.firstWhere((p) => p.id != currentUser.uid, orElse: () => ChatRoomParticipant(id: '', name: '', role: ''));
      if (other.id.isNotEmpty) {
        return other.role == 'client' ? '${other.name} (موكل)' : other.name;
      }
    }

    final otherId = room.participantIds.firstWhere((id) => id != currentUser.uid, orElse: () => '');
    if (otherId.isEmpty) return 'محادثة شخصية';
    final partner = widget.staff.firstWhere((u) => u.uid == otherId, orElse: () => SystemUser(uid: '', email: '', username: '', name: 'موظف سابق', role: '', createdAt: ''));
    return partner.name;
  }

  String _getRoomRole(ChatRoom room) {
    if (room.type == 'group') return 'مناقشة قضائية';
    final currentUser = ApiService().currentUser;
    if (currentUser == null) return '';

    if (room.participants != null && room.participants!.isNotEmpty) {
      final other = room.participants!.firstWhere((p) => p.id != currentUser.uid, orElse: () => ChatRoomParticipant(id: '', name: '', role: ''));
      if (other.id.isNotEmpty) {
        if (other.role == 'client') return 'موكل';
        switch (other.role) {
          case 'lawyer': return 'محامي مستشار';
          case 'admin':
          case 'super_admin': return 'مشرف النظام';
          case 'receptionist':
          case 'reception': return 'استقبال';
          case 'manager': return 'مدير إداري';
          default: return 'عضو الفريق';
        }
      }
    }

    final otherId = room.participantIds.firstWhere((id) => id != currentUser.uid, orElse: () => '');
    if (otherId.isEmpty) return '';
    final partner = widget.staff.firstWhere((u) => u.uid == otherId, orElse: () => SystemUser(uid: '', email: '', username: '', name: '', role: '', createdAt: ''));
    
    switch (partner.role) {
      case 'lawyer': return 'محامي مستشار';
      case 'admin':
      case 'super_admin': return 'مشرف النظام';
      case 'receptionist':
      case 'reception': return 'استقبال';
      case 'manager': return 'مدير إداري';
      default: return 'عضو الفريق';
    }
  }

  bool _isRoomPartnerOnline(ChatRoom room) {
    if (room.type == 'group') return false;
    final currentUser = ApiService().currentUser;
    if (currentUser == null) return false;
    final otherId = room.participantIds.firstWhere((id) => id != currentUser.uid, orElse: () => '');
    if (otherId.isEmpty) return false;
    return widget.staff.any((u) => u.uid == otherId && u.isOnline);
  }

  void _showNewChatDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final currentUser = ApiService().currentUser;
        final list = widget.staff.where((u) => u.uid != currentUser?.uid).toList();

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('بدء محادثة ثنائية جديدة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('اختر موظفاً من قائمة زملائك لبدء تشاور آمن:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('لا يوجد زملاء عمل آخرين حالياً'))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final staff = list[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ListTile(
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: royalGreen,
                                    foregroundColor: Colors.white,
                                    child: Text(staff.name.substring(0, 1)),
                                  ),
                                  if (staff.isOnline)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(staff.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              subtitle: Text(staff.role == 'lawyer' ? 'محامي مستشار' : 'موظف البوابة', style: TextStyle(fontSize: 9, color: goldColor, fontWeight: FontWeight.bold)),
                              onTap: () => _startNewChat(staff),
                            ),
                          );
                        },
                      ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Screen A: Active Chat Room
    if (_activeRoom != null) {
      final currentUser = ApiService().currentUser;
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _closeRoom,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(_getRoomName(_activeRoom!), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Text(_getRoomRole(_activeRoom!), style: TextStyle(fontSize: 9, color: goldColor, fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
          centerTitle: true,
        ),
        body: Column(
          children: [
            // Messages Area
            Expanded(
              child: _loadingMessages && _messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 40, color: Colors.black26),
                              SizedBox(height: 8),
                              Text('لا توجد رسائل سابقة. ابدأ المحادثة الآن!', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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
                            
                            // Parse time
                            String timeStr = '';
                            try {
                              timeStr = DateFormat('hh:mm a').format(DateTime.parse(msg.createdAt));
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
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(timeStr, style: const TextStyle(fontSize: 7, color: Color(0xFF94A3B8))),
                                        if (isMe) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            msg.isRead ? '✓✓' : '✓',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: msg.isRead ? Colors.blue : Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Input Bar
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).viewPadding.bottom + 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالة قانونية مشفرة...',
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
                      child: _sending ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.send, color: Colors.white, size: 16),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      );
    }

    // Screen B: Conversations Rooms List
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => MainAppController.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('الدردشة الداخلية للفريق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: _showNewChatDialog,
          )
        ],
      ),
      body: _loadingRooms && _rooms.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 40, color: Colors.black26),
                      const SizedBox(height: 8),
                      const Text('لا توجد محادثات جارية حالياً', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _showNewChatDialog,
                        style: ElevatedButton.styleFrom(backgroundColor: royalGreen, foregroundColor: Colors.white),
                        child: const Text('بدء أول محادثة ثنائية', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _rooms.length,
                  itemBuilder: (context, index) {
                    final room = _rooms[index];
                    
                    // Parse date
                    String dateStr = '';
                    if (room.lastMessageAt.isNotEmpty) {
                      try {
                        dateStr = DateFormat('dd/MM').format(DateTime.parse(room.lastMessageAt));
                      } catch (_) {
                        dateStr = room.lastMessageAt.split('T')[0];
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor: royalGreen.withOpacity(0.08),
                              foregroundColor: royalGreen,
                              child: const Icon(Icons.person, size: 20),
                            ),
                            if (_isRoomPartnerOnline(room))
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(_getRoomName(room), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text(_getRoomRole(room), style: TextStyle(fontSize: 9, color: goldColor, fontWeight: FontWeight.bold)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.unreadRoomIds.contains(room.id))
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: goldColor,
                                  shape: BoxShape.circle,
                                ),
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                              ),
                            Text(dateStr, style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8))),
                          ],
                        ),
                        onTap: () => _openRoom(room),
                      ),
                    );
                  },
                ),
    );
  }
}
