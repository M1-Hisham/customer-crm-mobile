import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/api_service.dart';
import 'models/models.dart';
import 'views/activation_view.dart';
import 'views/login_view.dart';
import 'views/home_view.dart';
import 'views/reception_view.dart';
import 'views/directory_view.dart';
import 'views/cases_view.dart';
import 'views/chat_view.dart';
import 'views/appointments_view.dart';
import 'views/alerts_view.dart';
import 'views/client_dashboard_view.dart';
import 'views/attendance_view.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final api = ApiService();
  await api.init();
  
  runApp(const HajjajLawApp());
}

class HajjajLawApp extends StatelessWidget {
  const HajjajLawApp({super.key});

  @override
  Widget build(BuildContext context) {
    final Color royalGreen = const Color(0xFF1E3D30);
    final Color goldColor = const Color(0xFFB8963A);

    return MaterialApp(
      title: 'منصة شركة حجاج الضويحي للمحاماة',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [
        Locale('ar', 'SA'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        fontFamily: 'Cairo',
        primaryColor: royalGreen,
        colorScheme: ColorScheme.light(
          primary: royalGreen,
          secondary: goldColor,
        ),
        useMaterial3: true,
      ),
      home: const MainAppController(),
    );
  }
}

class MainAppController extends StatefulWidget {
  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  const MainAppController({super.key});

  @override
  State<MainAppController> createState() => _MainAppControllerState();
}

class _MainAppControllerState extends State<MainAppController> {
  bool _loading = true;
  bool _needsActivation = false;
  SystemUser? _currentUser;

  // Data Lists
  List<Customer> _customers = [];
  List<Case> _cases = [];
  List<Appointment> _appointments = [];
  List<SystemUser> _staff = [];

  int _currentIndex = 0;
  Timer? _pollingTimer;

  // Chat Notifications States
  String? _activeRoomId;
  final Set<String> _unreadRoomIds = {};
  bool _isFirstChatFetch = true;
  final Map<String, String> _roomsLastSeenAt = {};

  // Appointment Notifications States
  bool _isFirstApptFetch = true;
  final Set<String> _knownAppointmentIds = {};
  final Set<String> _upcomingNotifiedApptIds = {};
  final Set<String> _appointmentAlertIds = {};

  final Color royalGreen = const Color(0xFF1E3D30);
  final Color goldColor = const Color(0xFFB8963A);

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _loading = true);
    final api = ApiService();
    
    // Check auth
    final profile = await api.authMe();
    
    if (profile == null) {
      if (mounted) {
        setState(() {
          _needsActivation = false;
          _currentUser = null;
          _loading = false;
        });
      }
      return;
    }

    // Only staff roles require device activation
    if (profile.role != 'client') {
      if (!api.isDeviceActivated) {
        if (mounted) {
          setState(() {
            _needsActivation = true;
            _loading = false;
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _needsActivation = false;
        _currentUser = profile;
        _loading = false;
      });
      
      if (_currentUser != null) {
        _startPolling();
      }
    }
  }

  void _startPolling() {
    _fetchDashboardData();
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _currentUser != null) {
        _fetchDashboardData();
      }
    });
  }

  Future<void> _fetchDashboardData() async {
    if (_currentUser == null || _currentUser!.role == 'client') return;
    try {
      final api = ApiService();
      final String role = _currentUser?.role ?? '';
      final isArchive = ['archive', 'lawyer', 'trainee_lawyer', 'secretary', ...['admin', 'super_admin', 'manager']].contains(role);
      final canAccessAppointments = isArchive && !['reception', 'receptionist'].contains(role);

      final List<Customer> customersData = await api.getCustomers();
      final List<Case> casesData = isArchive ? await api.getCases() : [];
      final List<Appointment> appointmentsData = canAccessAppointments
          ? await api.getAppointments()
          : [];
      final List<SystemUser> staffData = await api.getUsers();

      // Fetch Chat Rooms for notifications
      List<ChatRoom> chatRooms = [];
      try {
        chatRooms = await api.getChatRooms();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _customers = customersData;
          _cases = casesData;
          _appointments = appointmentsData;
          _staff = staffData;
        });

        if (chatRooms.isNotEmpty && _currentUser != null) {
          _processChatNotifications(chatRooms);
        }
        if (_appointments.isNotEmpty && _currentUser != null) {
          _processAppointmentsNotifications(_appointments);
        }
      }
    } catch (_) {}
  }

  void _processChatNotifications(List<ChatRoom> rooms) async {
    if (_isFirstChatFetch) {
      for (final room in rooms) {
        _roomsLastSeenAt[room.id] = room.lastMessageAt;
      }
      _isFirstChatFetch = false;
      return;
    }

    bool playedSound = false;

    // Role-based Nav Tabs check to see where 'chat' view stands
    final role = _currentUser!.role;
    final isAdmin = ['admin', 'super_admin', 'manager'].contains(role);
    final isReception = ['reception', 'receptionist', 'lawyer', ...['admin', 'super_admin', 'manager']].contains(role);
    final isArchive = ['archive', 'lawyer', 'trainee_lawyer', 'secretary', ...['admin', 'super_admin', 'manager']].contains(role);
    final canAccessAppointments = isArchive && !['reception', 'receptionist'].contains(role);
    final canAccessAlerts = isArchive && !['reception', 'receptionist'].contains(role);

    final List<Map<String, dynamic>> tabs = [];
    tabs.add({'id': 'home'});
    if (isReception) tabs.add({'id': 'reception'});
    tabs.add({'id': 'directory'});
    if (isArchive) tabs.add({'id': 'cases'});
    if (canAccessAppointments) tabs.add({'id': 'appointments'});
    if (canAccessAlerts) tabs.add({'id': 'alerts'});
    tabs.add({'id': 'chat'});

    final currentTabId = _currentIndex < tabs.length ? tabs[_currentIndex]['id'] : '';

    for (final room in rooms) {
      final prevTime = _roomsLastSeenAt[room.id];
      if (prevTime == null || DateTime.parse(room.lastMessageAt).isAfter(DateTime.parse(prevTime))) {
        // Fetch messages to verify the sender
        try {
          final msgs = await ApiService().getChatMessages(room.id);
          if (msgs.isNotEmpty) {
            final lastMsg = msgs.last;
            
            // Only trigger if last message was sent by someone else
            if (lastMsg.senderId != _currentUser?.uid) {
              final lastMsgTime = DateTime.parse(lastMsg.createdAt);
              final prevDateTime = prevTime != null ? DateTime.parse(prevTime) : DateTime.fromMillisecondsSinceEpoch(0);
              
              if (lastMsgTime.isAfter(prevDateTime)) {
                final isViewingThisRoom = currentTabId == 'chat' && _activeRoomId == room.id;
                
                if (!isViewingThisRoom) {
                  setState(() {
                    _unreadRoomIds.add(room.id);
                  });
                  
                  if (!playedSound) {
                    FlutterRingtonePlayer().playNotification();
                    playedSound = true;
                  }
                } else {
                  if (!playedSound) {
                    FlutterRingtonePlayer().playNotification();
                    playedSound = true;
                  }
                }
              }
            }
          }
        } catch (_) {}
        
        _roomsLastSeenAt[room.id] = room.lastMessageAt;
      }
    }
  }

  void _processAppointmentsNotifications(List<Appointment> appts) {
    if (_isFirstApptFetch) {
      for (final appt in appts) {
        _knownAppointmentIds.add(appt.id);
      }
      _isFirstApptFetch = false;
      return;
    }

    final now = DateTime.now();
    bool playedSound = false;
    bool stateUpdated = false;

    for (final appt in appts) {
      // 1. Detect newly created appointments
      if (!_knownAppointmentIds.contains(appt.id)) {
        _knownAppointmentIds.add(appt.id);
        _appointmentAlertIds.add(appt.id);
        stateUpdated = true;

        if (!playedSound) {
          FlutterRingtonePlayer().playNotification();
          playedSound = true;
        }

        // Show a Snackbar/Toast
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تمت جدولة جلسة جديدة: "${appt.title}"\nالمحكمة: ${appt.court.isNotEmpty ? appt.court : "غير محدد"}',
              style: const TextStyle(fontSize: 12),
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: royalGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // 2. Alert for upcoming appointments starting within the next 24 hours
      if (appt.status == 'scheduled' || appt.status.isEmpty) {
        try {
          final apptDate = DateTime.parse(appt.date);
          final diff = apptDate.difference(now);
          final hoursDiff = diff.inHours;

          if (!diff.isNegative && hoursDiff <= 24 && !_upcomingNotifiedApptIds.contains(appt.id)) {
            _upcomingNotifiedApptIds.add(appt.id);
            _appointmentAlertIds.add(appt.id);
            stateUpdated = true;

            if (!playedSound) {
              FlutterRingtonePlayer().playNotification();
              playedSound = true;
            }

            // Show a warning Snackbar
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'تنبيه: جلسة قريبة جداً - "${appt.title}"\nالمحكمة: ${appt.court.isNotEmpty ? appt.court : "غير محدد"} تبدأ خلال 24 ساعة!',
                  style: const TextStyle(fontSize: 12),
                  textDirection: TextDirection.rtl,
                ),
                backgroundColor: Colors.orange.shade800,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } catch (_) {}
      }
    }

    if (stateUpdated) {
      setState(() {});
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل خروج', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('تسجيل خروج', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      _pollingTimer?.cancel();
      await ApiService().logout();
      if (mounted) {
        setState(() {
          _currentUser = null;
          _currentIndex = 0;
        });
      }
    }
  }

  // كل التابات (bottom + drawer)
  List<Map<String, dynamic>> _buildAllTabs() {
    if (_currentUser == null) return [];

    final role = _currentUser!.role;
    final isReception = ['reception', 'receptionist', 'lawyer', 'admin', 'super_admin', 'manager'].contains(role);
    final isArchive = ['archive', 'lawyer', 'trainee_lawyer', 'secretary', 'admin', 'super_admin', 'manager'].contains(role);
    final canAccessAppointments = isArchive && !['reception', 'receptionist'].contains(role);
    final canAccessAlerts = isArchive && !['reception', 'receptionist'].contains(role);

    return [
      // ── 6 التابات السفلية المعتمدة بالترتيب ──
      {
        'id': 'directory',
        'label': 'الموكلين',
        'icon': Icons.folder_shared_outlined,
        'activeIcon': Icons.folder_shared_rounded,
        'inBottomNav': true,
        'view': DirectoryView(customers: _customers, staff: _staff, onCustomerUpdated: _fetchDashboardData),
      },
      if (isArchive) {
        'id': 'cases',
        'label': 'القضايا',
        'icon': Icons.gavel_outlined,
        'activeIcon': Icons.gavel_rounded,
        'inBottomNav': true,
        'view': CasesView(
          key: const ValueKey('cases_view_active'),
          cases: _cases,
          appointments: _appointments,
          staff: _staff,
          onCaseUpdated: _fetchDashboardData,
          initialIsArchivedView: false,
        ),
      },
      if (isArchive) {
        'id': 'archive',
        'label': 'الأرشيف',
        'icon': Icons.archive_outlined,
        'activeIcon': Icons.archive_rounded,
        'inBottomNav': true,
        'view': CasesView(
          key: const ValueKey('cases_view_archived'),
          cases: _cases,
          appointments: _appointments,
          staff: _staff,
          onCaseUpdated: _fetchDashboardData,
          initialIsArchivedView: true,
        ),
      },
      if (canAccessAppointments) {
        'id': 'appointments',
        'label': 'الأجندة',
        'icon': Icons.calendar_month_outlined,
        'activeIcon': Icons.calendar_month_rounded,
        'inBottomNav': true,
        'view': AppointmentsView(
          appointments: _appointments,
          cases: _cases,
          staff: _staff,
          onAppointmentsUpdated: _fetchDashboardData,
        ),
      },
      {
        'id': 'chat',
        'label': 'الدردشة',
        'icon': Icons.chat_bubble_outline,
        'activeIcon': Icons.chat_bubble_rounded,
        'inBottomNav': true,
        'view': ChatView(
          staff: _staff,
          activeRoomId: _activeRoomId,
          unreadRoomIds: _unreadRoomIds,
          onActiveRoomChanged: (roomId) {
            setState(() {
              _activeRoomId = roomId;
              if (roomId != null) _unreadRoomIds.remove(roomId);
            });
          },
        ),
      },
      if (role != 'client') {
        'id': 'attendance',
        'label': 'الحضور',
        'icon': Icons.location_on_outlined,
        'activeIcon': Icons.location_on_rounded,
        'inBottomNav': true,
        'view': const AttendanceView(),
      },

      // ── التابات الفرعية التي ستظهر في الـ Drawer ──
      {
        'id': 'home',
        'label': 'الرئيسية',
        'icon': Icons.home_outlined,
        'activeIcon': Icons.home_rounded,
        'inBottomNav': false,
        'view': HomeView(
          customers: _customers,
          cases: _cases,
          appointments: _appointments,
          onTabChange: (tabId) {
            final allTabs = _buildAllTabs();
            final index = allTabs.indexWhere((t) => t['id'] == tabId);
            if (index != -1) setState(() => _currentIndex = index);
          },
        ),
      },
      if (isReception) {
        'id': 'reception',
        'label': 'الاستقبال',
        'icon': Icons.person_add_alt_1_outlined,
        'activeIcon': Icons.person_add_alt_1_rounded,
        'inBottomNav': false,
        'view': ReceptionView(staff: _staff, onCustomerRegistered: _fetchDashboardData),
      },
      if (canAccessAlerts) {
        'id': 'alerts',
        'label': 'التنبيهات',
        'icon': Icons.notifications_none_outlined,
        'activeIcon': Icons.notifications_rounded,
        'inBottomNav': false,
        'view': AlertsView(
          appointments: _appointments,
          onRefresh: _fetchDashboardData,
        ),
      },
      {
        'id': 'profile',
        'label': 'حسابي',
        'icon': Icons.person_outline,
        'activeIcon': Icons.person_rounded,
        'inBottomNav': false,
        'view': _buildProfileView(),
      },
    ];
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
              const Text('منصة حجاج — جاري التحميل...', style: TextStyle(fontSize: 12, fontFamily: 'Cairo')),
            ],
          ),
        ),
      );
    }

    if (_needsActivation) {
      return ActivationView(
        onActivated: () {
          setState(() => _needsActivation = false);
          _checkStatus();
        },
      );
    }

    if (_currentUser == null) {
      return LoginView(
        onLoginSuccess: () {
          setState(() => _currentUser = ApiService().currentUser);
          _startPolling();
        },
      );
    }

    if (_currentUser!.role == 'client') {
      return ClientDashboardView(onLogout: _handleLogout);
    }

    final allTabs = _buildAllTabs();
    final bottomTabs = allTabs.where((t) => t['inBottomNav'] == true).toList();
    final drawerTabs = allTabs.where((t) => t['inBottomNav'] == false).toList();

    // تأكد الـ index في النطاق
    if (_currentIndex >= allTabs.length) _currentIndex = 0;

    // إيجاد الـ bottom nav index الصح
    final currentTab = _currentIndex < allTabs.length ? allTabs[_currentIndex] : allTabs[0];
    final isInBottomNav = currentTab['inBottomNav'] == true;

    return Scaffold(
      key: MainAppController.scaffoldKey,
      backgroundColor: const Color(0xFFF4F6F8),
      body: allTabs[_currentIndex < allTabs.length ? _currentIndex : 0]['view'] as Widget,

      // ── Drawer الجانبي ──────────────────────────────────────────
      drawer: Drawer(
        backgroundColor: const Color(0xFFF8F9FA),
        child: SafeArea(
          child: Column(
            children: [
              // Header الـ Drawer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                decoration: BoxDecoration(
                  color: royalGreen,
                  border: Border(bottom: BorderSide(color: goldColor, width: 1.5)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: goldColor.withOpacity(0.2),
                      child: Text(
                        _currentUser!.name.substring(0, 1),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: goldColor,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentUser!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${_currentUser!.username}',
                            style: TextStyle(
                              color: goldColor,
                              fontSize: 11,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // قائمة التابات الإضافية
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'القائمة الكاملة',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey[500],
                          letterSpacing: 0.5,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    ...drawerTabs.map((tab) {
                      final tabIndex = allTabs.indexWhere((t) => t['id'] == tab['id']);
                      final isSelected = _currentIndex == tabIndex;
                      final bool isAlerts = tab['id'] == 'alerts';
                      final int pendingAlertsCount = _appointments.where((a) => a.requiresReply == true && a.status == 'scheduled').length;

                      return _DrawerItem(
                        icon: tab['activeIcon'] as IconData,
                        label: tab['label'] as String,
                        isSelected: isSelected,
                        badge: isAlerts && pendingAlertsCount > 0 ? pendingAlertsCount : null,
                        royalGreen: royalGreen,
                        goldColor: goldColor,
                        onTap: () {
                          Navigator.pop(context); // أغلق الـ drawer
                          setState(() => _currentIndex = tabIndex);
                        },
                      );
                    }),

                    const Divider(height: 24, indent: 16, endIndent: 16),

                    // زر تسجيل الخروج
                    _DrawerItem(
                      icon: Icons.logout_rounded,
                      label: 'تسجيل خروج آمن',
                      isSelected: false,
                      isLogout: true,
                      royalGreen: royalGreen,
                      goldColor: goldColor,
                      onTap: () {
                        Navigator.pop(context);
                        _handleLogout();
                      },
                    ),
                  ],
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'مكتب حجاج الضويحي للمحاماة',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[400],
                    fontFamily: 'Cairo',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),

      // ── Bottom Navigation Bar ────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border(
            top: BorderSide(color: goldColor.withOpacity(0.3), width: 1),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                ...bottomTabs.map((tab) {
                  final tabIndex = allTabs.indexWhere((t) => t['id'] == tab['id']);
                  final isSelected = _currentIndex == tabIndex;
                  final bool isChat = tab['id'] == 'chat';
                  final int unreadCount = _unreadRoomIds.length;

                  return Expanded(
                    child: _BottomNavItem(
                      icon: isSelected
                          ? tab['activeIcon'] as IconData
                          : tab['icon'] as IconData,
                      label: tab['label'] as String,
                      isSelected: isSelected,
                      badge: isChat && unreadCount > 0 ? unreadCount : null,
                      royalGreen: royalGreen,
                      goldColor: goldColor,
                      onTap: () {
                        setState(() {
                          _currentIndex = tabIndex;
                          if (tab['id'] == 'chat' && _activeRoomId != null) {
                            _unreadRoomIds.remove(_activeRoomId);
                          }
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileView() {
    final String label = _currentUser!.role == 'super_admin' ? 'مشرف عام أول' : _currentUser!.role == 'admin' ? 'مشرف عام' : _currentUser!.role == 'lawyer' ? 'محامي مستشار' : _currentUser!.role == 'trainee_lawyer' ? 'محامي متدرب' : 'موظف المنصة';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('الملف الشخصي للموظف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: royalGreen,
                    child: Text(
                      _currentUser!.name.substring(0, 1),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: goldColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_currentUser!.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('@${_currentUser!.username}', style: TextStyle(fontSize: 12, color: goldColor, fontWeight: FontWeight.bold)),
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
                  _buildProfileRow('البريد الإلكتروني:', _currentUser!.email),
                  _buildProfileRow('المسمى الوظيفي:', label),
                  _buildProfileRow('صلاحية النظام:', _currentUser!.role, isBadge: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _handleLogout,
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
      ),
    );
  }

  Widget _buildProfileRow(String label, String val, {bool isBadge = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          isBadge
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(val, style: const TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.bold)),
                )
              : Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final int? badge;
  final Color royalGreen;
  final Color goldColor;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.royalGreen,
    required this.goldColor,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // الأيقونة مع indicator
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 44 : 36,
                  height: isSelected ? 28 : 28,
                  decoration: isSelected
                      ? BoxDecoration(
                          color: royalGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        )
                      : null,
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? royalGreen : Colors.grey[400],
                  ),
                ),
                if (badge != null && badge! > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        badge.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? royalGreen : Colors.grey[400],
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreNavItem extends StatelessWidget {
  final bool hasAlert;
  final bool isDrawerTab;
  final String currentLabel;
  final IconData currentIcon;
  final Color goldColor;
  final Color royalGreen;
  final VoidCallback onTap;

  const _MoreNavItem({
    required this.hasAlert,
    required this.isDrawerTab,
    required this.currentLabel,
    required this.currentIcon,
    required this.goldColor,
    required this.royalGreen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isDrawerTab ? 44 : 36,
                  height: 28,
                  decoration: isDrawerTab
                      ? BoxDecoration(
                          color: goldColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        )
                      : null,
                  child: Icon(
                    isDrawerTab ? currentIcon : Icons.grid_view_rounded,
                    size: 20,
                    color: isDrawerTab ? goldColor : Colors.grey[400],
                  ),
                ),
                if (hasAlert && !isDrawerTab)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              isDrawerTab ? currentLabel : 'المزيد',
              style: TextStyle(
                fontSize: 9,
                fontWeight: isDrawerTab ? FontWeight.w800 : FontWeight.w500,
                color: isDrawerTab ? goldColor : Colors.grey[400],
                fontFamily: 'Cairo',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isLogout;
  final int? badge;
  final Color royalGreen;
  final Color goldColor;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.royalGreen,
    required this.goldColor,
    required this.onTap,
    this.isLogout = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = isLogout ? Colors.red : royalGreen;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: isSelected ? royalGreen.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: royalGreen.withOpacity(0.15))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? royalGreen
                      : isLogout
                          ? Colors.red
                          : Colors.grey[600],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? royalGreen
                          : isLogout
                              ? Colors.red
                              : Colors.grey[800],
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                if (badge != null && badge! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: royalGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
