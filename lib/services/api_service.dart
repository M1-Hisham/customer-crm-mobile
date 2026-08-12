import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  SharedPreferences? _prefs;
  String? _deviceToken;
  String? _sessionToken;
  SystemUser? currentUser;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _deviceToken = _prefs?.getString('device_token');
    _sessionToken = _prefs?.getString('session_token');
  }

  bool get isDeviceActivated => _deviceToken != null;
  bool get isAuthenticated => _sessionToken != null;

  Map<String, String> _getHeaders() {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-App-Client': 'hajaj-crm-mobile'
    };
    List<String> cookies = [];
    if (_deviceToken != null) cookies.add('device_token=$_deviceToken');
    if (_sessionToken != null) cookies.add('session_token=$_sessionToken');
    if (cookies.isNotEmpty) {
      headers['Cookie'] = cookies.join('; ');
    }
    return headers;
  }

  void _updateCookies(Map<String, String> responseHeaders) {
    final rawCookie = responseHeaders['set-cookie'];
    if (rawCookie != null) {
      final cookies = rawCookie.split(',');
      for (var cookie in cookies) {
        final parts = cookie.split(';')[0].trim().split('=');
        if (parts.length == 2) {
          final key = parts[0].trim();
          final val = parts[1].trim();
          if (key == 'device_token') {
            _deviceToken = val;
            _prefs?.setString('device_token', val);
          } else if (key == 'session_token') {
            _sessionToken = val;
            _prefs?.setString('session_token', val);
          }
        }
      }
    }
  }

  Future<void> clearSession() async {
    _sessionToken = null;
    await _prefs?.remove('session_token');
    currentUser = null;
  }

  // Device Activation
  Future<bool> activateDevice(String code) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/devices/activate');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-App-Client': 'hajaj-crm-mobile'
        },
        body: jsonEncode({'code': code}),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        _updateCookies(response.headers);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> requestActivation() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/devices/request-activation');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-App-Client': 'hajaj-crm-mobile'
        },
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'تم إرسال طلب التنشيط بنجاح.'};
      } else {
        return {'success': false, 'message': data['error'] ?? 'فشل إرسال طلب التنشيط.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'حدث خطأ في الاتصال بالخادم.'};
    }
  }

  // Authentication
  Future<SystemUser> login(String username, String password) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/auth/login');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({'username': username, 'password': password}),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      _updateCookies(response.headers);
      final data = jsonDecode(response.body);
      currentUser = SystemUser.fromJson(data);
      return currentUser!;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'فشل تسجيل الدخول');
    }
  }

  // Client OTP Authentication
  Future<bool> requestClientOtp(String phone) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/auth/client-otp-request');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      return true;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'فشل طلب رمز التحقق');
    }
  }

  Future<SystemUser> verifyClientOtp(String phone, String code) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/auth/client-otp-verify');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({'phone': phone, 'code': code}),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      _updateCookies(response.headers);
      final data = jsonDecode(response.body);
      currentUser = SystemUser.fromJson(data);
      return currentUser!;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'رمز التحقق غير صحيح');
    }
  }

  // Client Password Authentication
  Future<Map<String, dynamic>> checkClientLoginStatus(String phone) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/auth/client-login-check');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 5));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'فشل التحقق من رقم الجوال');
    }
  }

  Future<SystemUser> setClientPassword(String phone, String password) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/auth/client-set-password');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({'phone': phone, 'password': password}),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      _updateCookies(response.headers);
      final data = jsonDecode(response.body);
      currentUser = SystemUser.fromJson(data);
      return currentUser!;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'فشل تعيين كلمة المرور');
    }
  }

  Future<SystemUser> loginClientWithPassword(String phone, String password) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/auth/client-login');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({'phone': phone, 'password': password}),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      _updateCookies(response.headers);
      final data = jsonDecode(response.body);
      currentUser = SystemUser.fromJson(data);
      return currentUser!;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'كلمة المرور غير صحيحة');
    }
  }

  // Client Specific APIs
  Future<List<Case>> getClientCases() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/client/cases');
    final response = await http.get(url, headers: _getHeaders()).timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((i) => Case.fromJson(i)).toList();
    }
    throw Exception('فشل جلب قضايا الموكل');
  }

  Future<List<Appointment>> getClientAppointments() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/client/appointments');
    final response = await http.get(url, headers: _getHeaders()).timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((i) => Appointment.fromJson(i)).toList();
    }
    throw Exception('فشل جلب مواعيد جلسات الموكل');
  }

  Future<void> logout() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/auth/logout');
    try {
      await http.post(url, headers: _getHeaders());
    } finally {
      await clearSession();
    }
  }

  Future<SystemUser?> authMe() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/auth/me');
    try {
      final response = await http.get(url, headers: _getHeaders()).timeout(const Duration(seconds: 5));
      // Check if intercepted by device lock screen HTML
      if (response.statusCode == 403 || response.body.trim().startsWith('<!') || response.body.contains('activation-code')) {
        _deviceToken = null;
        await _prefs?.remove('device_token');
        return null;
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        currentUser = SystemUser.fromJson(data);
        return currentUser;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Staff list
  Future<List<SystemUser>> getUsers() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/users');
    final response = await http.get(url, headers: _getHeaders());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((i) => SystemUser.fromJson(i)).toList();
    }
    throw Exception('فشل جلب قائمة الموظفين');
  }

  // Customers
  Future<List<Customer>> getCustomers() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/customers');
    final response = await http.get(url, headers: _getHeaders());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((i) => Customer.fromJson(i)).toList();
    }
    throw Exception('فشل جلب قائمة الموكلين');
  }

  Future<Customer> createCustomer(Map<String, dynamic> customerData) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/customers');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode(customerData),
    );
    if (response.statusCode == 200) {
      return Customer.fromJson(jsonDecode(response.body));
    }
    final data = jsonDecode(response.body);
    throw Exception(data['error'] ?? 'فشل تسجيل الموكل');
  }

  Future<Customer> updateCustomer(String id, Map<String, dynamic> customerData) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/customers/$id');
    final response = await http.put(
      url,
      headers: _getHeaders(),
      body: jsonEncode(customerData),
    );
    if (response.statusCode == 200) {
      return Customer.fromJson(jsonDecode(response.body));
    }
    final data = jsonDecode(response.body);
    throw Exception(data['error'] ?? 'فشل تعديل الموكل');
  }

  Future<void> deleteCustomer(String id) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/customers/$id');
    final response = await http.delete(url, headers: _getHeaders());
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'فشل حذف الموكل');
    }
  }

  // Cases
  Future<List<Case>> getCases() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/cases');
    final response = await http.get(url, headers: _getHeaders());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((i) => Case.fromJson(i)).toList();
    }
    throw Exception('فشل جلب أرشيف القضايا');
  }

  Future<Case> createCase(Map<String, dynamic> caseData) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/cases');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode(caseData),
    );
    if (response.statusCode == 200) {
      return Case.fromJson(jsonDecode(response.body));
    }
    final data = jsonDecode(response.body);
    throw Exception(data['error'] ?? 'فشل تسجيل ملف القضية');
  }

  Future<Case> updateCase(String id, Map<String, dynamic> caseData) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/cases/$id');
    final response = await http.put(
      url,
      headers: _getHeaders(),
      body: jsonEncode(caseData),
    );
    if (response.statusCode == 200) {
      return Case.fromJson(jsonDecode(response.body));
    }
    final data = jsonDecode(response.body);
    throw Exception(data['error'] ?? 'فشل تعديل بيانات القضية');
  }

  Future<void> addCaseAction(String caseId, String text) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/cases/$caseId/actions');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({'text': text}),
    );
    if (response.statusCode != 200) {
      throw Exception('فشل إضافة الإجراء');
    }
  }

  Future<void> addCaseNote(String caseId, String text) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/cases/$caseId/notes');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({'text': text}),
    );
    if (response.statusCode != 200) {
      throw Exception('فشل إضافة الملاحظة');
    }
  }

  Future<void> addCaseAttachment(String caseId, String name, String urlBase64, String size) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/cases/$caseId/attachments');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({
        'name': name,
        'url': urlBase64,
        'size': size,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('فشل رفع المستند المرفق');
    }
  }

  Future<void> deleteCaseAttachment(String caseId, String name) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/cases/$caseId/attachments/${Uri.encodeComponent(name)}');
    final response = await http.delete(url, headers: _getHeaders());
    if (response.statusCode != 200) {
      throw Exception('فشل حذف المرفق');
    }
  }

  // Appointments
  Future<List<Appointment>> getAppointments() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/appointments');
    final response = await http.get(url, headers: _getHeaders());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((i) => Appointment.fromJson(i)).toList();
    }
    throw Exception('فشل جلب مواعيد الجلسات');
  }

  Future<void> createAppointment(Map<String, dynamic> data) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/appointments');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('فشل جدولة الموعد');
    }
  }

  Future<void> updateAppointment(String id, Map<String, dynamic> data) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/appointments/$id');
    final response = await http.put(
      url,
      headers: _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      final resData = jsonDecode(response.body);
      throw Exception(resData['error'] ?? 'فشل تعديل موعد الجلسة');
    }
  }

  Future<void> deleteAppointment(String id) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/appointments/$id');
    final response = await http.delete(url, headers: _getHeaders());
    if (response.statusCode != 200) {
      throw Exception('فشل إلغاء الموعد');
    }
  }

  // Chat
  Future<List<ChatRoom>> getChatRooms() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/chat/rooms');
    final response = await http.get(url, headers: _getHeaders());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((i) => ChatRoom.fromJson(i)).toList();
    }
    throw Exception('فشل جلب غرف الدردشة');
  }

  Future<ChatRoom> createChatRoom(Map<String, dynamic> data) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/chat/rooms');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return ChatRoom.fromJson(jsonDecode(response.body));
    }
    throw Exception('فشل بدء محادثة جديدة');
  }

  Future<List<ChatMessage>> getChatMessages(String roomId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/chat/rooms/$roomId/messages');
    final response = await http.get(url, headers: _getHeaders());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((i) => ChatMessage.fromJson(i)).toList();
    }
    throw Exception('فشل جلب رسائل المحادثة');
  }

  Future<ChatMessage> sendChatMessage(String roomId, String text) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/chat/rooms/$roomId/messages');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({'text': text}),
    );
    if (response.statusCode == 200) {
      return ChatMessage.fromJson(jsonDecode(response.body));
    }
    throw Exception('فشل إرسال الرسالة');
  }

  Future<void> markMessagesAsRead(String roomId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/chat/rooms/$roomId/read');
    final response = await http.post(
      url,
      headers: _getHeaders(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('فشل تحديث حالة الرسائل المقروءة');
    }
  }

  // Admin
  Future<List<AuditLog>> getAuditLogs() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/admin/audit-logs');
    final response = await http.get(url, headers: _getHeaders());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((i) => AuditLog.fromJson(i)).toList();
    }
    throw Exception('فشل جلب سجل العمليات');
  }

  Future<void> registerSystemUser(Map<String, dynamic> data) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/admin/users');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      final resData = jsonDecode(response.body);
      throw Exception(resData['error'] ?? 'فشل تسجيل الموظف الجديد');
    }
  }

  Future<void> updateUserRole(String uid, String role) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/admin/users/$uid/role');
    final response = await http.put(
      url,
      headers: _getHeaders(),
      body: jsonEncode({'role': role}),
    );
    if (response.statusCode != 200) {
      throw Exception('فشل تعديل الصلاحية');
    }
  }

  // Attendance
  Future<Map<String, dynamic>> getTodayAttendance() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/attendance/today');
    final response = await http.get(url, headers: _getHeaders());
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('فشل جلب حالة الحضور اليومي');
  }

  Future<Map<String, dynamic>> checkIn(double lat, double lng) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/attendance/check-in');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({
        'latitude': lat,
        'longitude': lng,
        'device_info': 'تطبيق الجوال (Flutter)'
      }),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> checkOut(double lat, double lng) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/attendance/check-out');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({
        'latitude': lat,
        'longitude': lng,
        'device_info': 'تطبيق الجوال (Flutter)'
      }),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getAttendanceReport(String date) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/attendance/report?date=$date');
    final response = await http.get(url, headers: _getHeaders());
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('فشل جلب تقرير الحضور');
  }

  // Daily Tasks
  Future<List<Map<String, dynamic>>> getDailyTasks({String? date}) async {
    final query = date != null ? '?date=$date' : '';
    final url = Uri.parse('${AppConfig.baseUrl}/api/tasks/daily$query');
    final response = await http.get(url, headers: _getHeaders());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    }
    throw Exception('فشل جلب المهام اليومية');
  }

  Future<void> createDailyTask(Map<String, dynamic> data) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/tasks/daily');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('فشل إنشاء المهمة اليومية');
    }
  }

  Future<void> deleteDailyTask(String taskId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/tasks/daily/$taskId');
    final response = await http.delete(url, headers: _getHeaders());
    if (response.statusCode != 200) {
      throw Exception('فشل حذف المهمة');
    }
  }

  Future<void> completeDailyTask(String taskId, {String? note}) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/tasks/daily/$taskId/complete');
    final response = await http.patch(
      url,
      headers: _getHeaders(),
      body: jsonEncode({'note': note ?? ''}),
    );
    if (response.statusCode != 200) {
      throw Exception('فشل تحديث حالة المهمة');
    }
  }

  Future<void> updateDailyTaskNote(String taskId, String note) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/tasks/daily/$taskId/note');
    final response = await http.put(
      url,
      headers: _getHeaders(),
      body: jsonEncode({'note': note}),
    );
    if (response.statusCode != 200) {
      throw Exception('فشل إضافة الملاحظة');
    }
  }
}
