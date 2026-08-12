import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../services/api_service.dart';
import 'activation_view.dart';


class LoginView extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginView({super.key, required this.onLoginSuccess});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  // Common states
  bool _loading = false;
  String? _error;
  final Color royalGreen = const Color(0xFF1E3D30);
  final Color goldColor = const Color(0xFFB8963A);

  // Toggle between portals
  bool _isStaffPortal = false;

  // Staff Portal states
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;

  // Client Portal states
  final _phoneController = TextEditingController();
  final _clientPasswordController = TextEditingController();
  final _clientConfirmPasswordController = TextEditingController();
  bool _clientChecked = false;
  bool _clientHasPassword = false;
  bool _obscureClientPassword = true;
  String _clientName = '';
  bool _isFirstTimeSetup = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedUsername();
  }

  Future<void> _loadRememberedUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('remembered_username');
      if (saved != null && saved.isNotEmpty) {
        setState(() {
          _usernameController.text = saved;
          _rememberMe = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleStaffLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'الرجاء إدخال اسم المستخدم وكلمة المرور.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiService().login(username, password);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_staff_username', username);
        await prefs.setString('saved_staff_password', password);
        if (_rememberMe) {
          await prefs.setString('remembered_username', username);
        } else {
          await prefs.remove('remembered_username');
        }
      } catch (_) {}
      if (mounted) {
        widget.onLoginSuccess();
      }
    } catch (err) {
      if (mounted) {
        setState(() => _error = err.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        setState(() => _error = 'الجهاز لا يدعم البصمة الحيوية (الوجه أو الإصبع).');
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'الرجاء التحقق ببصمة الوجه (Face ID) أو بصمة الإصبع لدخول تطبيق المنصة',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate) {
        final prefs = await SharedPreferences.getInstance();
        final savedUsername = prefs.getString('saved_staff_username');
        final savedPassword = prefs.getString('saved_staff_password');

        if (savedUsername != null && savedPassword != null && savedUsername.isNotEmpty && savedPassword.isNotEmpty) {
          setState(() {
            _loading = true;
            _error = null;
          });
          await ApiService().login(savedUsername, savedPassword);
          if (mounted) {
            widget.onLoginSuccess();
          }
        } else {
          setState(() => _error = 'يرجى الدخول بكلمة المرور لمرة واحدة لربط البصمة (الوجه/الإصبع) بالحساب.');
        }
      }
    } catch (e) {
      setState(() => _error = 'تعذر الاتصال بالبصمة الحيوية: ${e.toString()}');
    }
 finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }


  Future<void> _handleClientCheck() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'الرجاء إدخال رقم الجوال.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService().checkClientLoginStatus(phone);
      setState(() {
        _clientChecked = true;
        _clientHasPassword = data['hasPassword'] ?? false;
        _clientName = data['name'] ?? '';
      });
    } catch (err) {
      if (mounted) {
        setState(() => _error = err.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleClientLoginWithPassword() async {
    final phone = _phoneController.text.trim();
    final password = _clientPasswordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      setState(() => _error = 'الرجاء إدخال رقم الجوال وكلمة المرور.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiService().loginClientWithPassword(phone, password);
      if (mounted) {
        widget.onLoginSuccess();
      }
    } catch (err) {
      if (mounted) {
        setState(() => _error = err.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleClientSetPassword() async {
    final phone = _phoneController.text.trim();
    final password = _clientPasswordController.text.trim();
    final confirm = _clientConfirmPasswordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      setState(() => _error = 'الرجاء إدخال كلمة المرور الجديدة.');
      return;
    }

    if (password.length < 4) {
      setState(() => _error = 'كلمة المرور يجب أن لا تقل عن 4 خانات.');
      return;
    }

    if (password != confirm) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiService().setClientPassword(phone, password);
      if (mounted) {
        widget.onLoginSuccess();
      }
    } catch (err) {
      if (mounted) {
        setState(() => _error = err.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openWhatsApp() async {
    final url = Uri.parse('https://wa.me/966550340929?text=${Uri.encodeComponent('السلام عليكم، أحتاج مساعدة في الدخول للنظام')}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E3D30), Color(0xFF0B132B)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Card
                  GestureDetector(
                    onTap: () async {
                      final api = ApiService();
                      if (api.isDeviceActivated) {
                        setState(() {
                          _isStaffPortal = !_isStaffPortal;
                          _error = null;
                        });
                      } else {
                        final activated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ActivationView(
                              onActivated: () => Navigator.pop(context, true),
                              autoRequestCode: true,
                            ),
                          ),
                        );
                        if (activated == true) {
                          setState(() {
                            _isStaffPortal = true;
                            _error = null;
                          });
                        }
                      }
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFB8963A), Color(0xFFE2C875)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFB8963A).withOpacity(0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              )
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3D30),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'منصة حجاج الضويحي',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'شركة حجاج عبدالرحمن الضويحي للمحاماة والاستشارات',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE2C875),
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Glassmorphism Main Login Container
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: const Color(0xFFB8963A).withOpacity(0.35), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        // Portal Toggle Tabs (الموكلين vs الموظفين)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() {
                                    _isStaffPortal = false;
                                    _error = null;
                                  }),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !_isStaffPortal ? const Color(0xFF1E3D30) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: !_isStaffPortal ? Border.all(color: const Color(0xFFB8963A), width: 1) : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'بوابة الموكلين',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: !_isStaffPortal ? const Color(0xFFE2C875) : Colors.white60,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() {
                                    _isStaffPortal = true;
                                    _error = null;
                                  }),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _isStaffPortal ? const Color(0xFF1E3D30) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: _isStaffPortal ? Border.all(color: const Color(0xFFB8963A), width: 1) : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'بوابة الموظفين',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _isStaffPortal ? const Color(0xFFE2C875) : Colors.white60,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Error Banner
                        if (_error != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              border: Border.all(color: Colors.red.withOpacity(0.4)),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFECDD3),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),

                        // Staff Portal Form
                        if (_isStaffPortal) ...[
                          TextField(
                            controller: _usernameController,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'اسم المستخدم',
                              labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
                              prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFE2C875)),
                              fillColor: const Color(0xFF0F172A),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Colors.white12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFB8963A), width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
                              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFE2C875)),
                              fillColor: const Color(0xFF0F172A),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Colors.white12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFB8963A), width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                activeColor: const Color(0xFFB8963A),
                                checkColor: Colors.black,
                                side: const BorderSide(color: Colors.white38),
                                onChanged: (val) => setState(() => _rememberMe = val ?? false),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _rememberMe = !_rememberMe),
                                child: const Text(
                                  'تذكرني على هذا الجهاز',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70, fontFamily: 'Cairo'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Primary Staff Login Button
                          Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E3D30), Color(0xFF142B22)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFB8963A), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1E3D30).withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _loading ? null : _handleStaffLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _loading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('دخول آمن للمنصة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white, fontFamily: 'Cairo')),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward, size: 18, color: Color(0xFFE2C875)),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Biometrics Button (Face ID & Fingerprint)
                          Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFB8963A).withOpacity(0.5), width: 1.2),
                            ),
                            child: OutlinedButton(
                              onPressed: _loading ? null : _handleBiometricLogin,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.fingerprint, size: 22, color: Color(0xFFE2C875)),
                                  SizedBox(width: 6),
                                  Icon(Icons.face_rounded, size: 22, color: Color(0xFF34D399)),
                                  SizedBox(width: 8),
                                  Text(
                                    'الدخول بالبصمة الحيوية (الوجه / الإصبع)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white, fontFamily: 'Cairo'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          // Client Portal (Password-based login/setup flow)
                          if (!_isFirstTimeSetup) ...[
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: 'رقم الجوال المسجل',
                                labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
                                prefixIcon: const Icon(Icons.phone_iphone, color: Color(0xFFE2C875)),
                                helperText: 'مثال: 05xxxxxxxx أو 9665xxxxxxxx',
                                helperStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                                fillColor: const Color(0xFF0F172A),
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Colors.white12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFB8963A), width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _clientPasswordController,
                              obscureText: _obscureClientPassword,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور',
                                labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
                                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFE2C875)),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureClientPassword ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () => setState(() => _obscureClientPassword = !_obscureClientPassword),
                                ),
                                fillColor: const Color(0xFF0F172A),
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Colors.white12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFB8963A), width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1E3D30), Color(0xFF142B22)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFB8963A), width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1E3D30).withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _loading ? null : _handleClientLoginWithPassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: _loading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text('تسجيل الدخول للموكلين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white, fontFamily: 'Cairo')),
                                          SizedBox(width: 8),
                                          Icon(Icons.login, size: 18, color: Color(0xFFE2C875)),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isFirstTimeSetup = true;
                                  _clientChecked = false;
                                  _clientPasswordController.clear();
                                  _clientConfirmPasswordController.clear();
                                  _error = null;
                                });
                              },
                              child: const Text(
                                'تفعيل الحساب لأول مرة / تعيين كلمة المرور',
                                style: TextStyle(color: Color(0xFFE2C875), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo'),
                              ),
                            ),
                          ] else ...[
                            if (!_clientChecked) ...[
                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  labelText: 'رقم الجوال للتحقق والتفعيل',
                                  labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
                                  prefixIcon: const Icon(Icons.phone_iphone, color: Color(0xFFE2C875)),
                                  helperText: 'سنتحقق من وجود حسابك لتفعيل كلمة المرور',
                                  helperStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                                  fillColor: const Color(0xFF0F172A),
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Colors.white12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFB8963A), width: 1.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1E3D30), Color(0xFF142B22)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFB8963A), width: 1.2),
                                ),
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _handleClientCheck,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: _loading
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text('تحقق واستمرار', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white, fontFamily: 'Cairo')),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward, size: 18, color: Color(0xFFE2C875)),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => setState(() {
                                  _isFirstTimeSetup = false;
                                  _error = null;
                                }),
                                child: const Text(
                                  'العودة لبوابة الدخول المباشر',
                                  style: TextStyle(color: Color(0xFFE2C875), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo'),
                                ),
                              ),
                            ] else ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E3D30).withOpacity(0.5),
                                  border: Border.all(color: const Color(0xFFB8963A).withOpacity(0.4)),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'أهلاً بك، $_clientName',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Color(0xFFE2C875), fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _clientHasPassword
                                          ? 'لديك كلمة مرور مسجلة بالفعل!'
                                          : 'يرجى تعيين كلمة مرور جديدة لحسابك لتتمكن من الدخول مستقبلاً',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Cairo'),
                                    ),
                                  ],
                                ),
                              ),
                              if (!_clientHasPassword) ...[
                                TextField(
                                  controller: _clientPasswordController,
                                  obscureText: _obscureClientPassword,
                                  textDirection: TextDirection.ltr,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    labelText: 'كلمة المرور الجديدة',
                                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
                                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFE2C875)),
                                    fillColor: const Color(0xFF0F172A),
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFB8963A), width: 1.5)),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _clientConfirmPasswordController,
                                  obscureText: _obscureClientPassword,
                                  textDirection: TextDirection.ltr,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    labelText: 'تأكيد كلمة المرور الجديدة',
                                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
                                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFE2C875)),
                                    fillColor: const Color(0xFF0F172A),
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFB8963A), width: 1.5)),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  width: double.infinity,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFF1E3D30), Color(0xFF142B22)]),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFB8963A), width: 1.2),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _handleClientSetPassword,
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                    child: _loading
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text('تعيين كلمة المرور والدخول', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white, fontFamily: 'Cairo')),
                                              SizedBox(width: 8),
                                              Icon(Icons.check_circle_outline, size: 18, color: Color(0xFFE2C875)),
                                            ],
                                          ),
                                  ),
                                ),
                              ] else ...[
                                const Text(
                                  'حسابك مفعّل بالفعل ولديك كلمة مرور. يرجى العودة واستخدام الدخول المباشر.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFF1E3D30), Color(0xFF142B22)]),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFB8963A), width: 1.2),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () => setState(() {
                                      _isFirstTimeSetup = false;
                                      _clientChecked = false;
                                      _error = null;
                                    }),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                    child: const Text('العودة للدخول المباشر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white, fontFamily: 'Cairo')),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => setState(() {
                                  _isFirstTimeSetup = false;
                                  _clientChecked = false;
                                  _clientPasswordController.clear();
                                  _clientConfirmPasswordController.clear();
                                  _error = null;
                                }),
                                child: const Text(
                                  'العودة لبوابة الدخول المباشر',
                                  style: TextStyle(color: Color(0xFFE2C875), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo'),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // WhatsApp Floating Support Button Pill
                  InkWell(
                    onTap: _openWhatsApp,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF25D366)),
                          const SizedBox(width: 8),
                          Text(
                            _isStaffPortal ? 'نسيت كلمة المرور؟ تواصل مع الدعم الفني' : 'تواجه مشكلة في تسجيل الدخول؟ تواصل معنا',
                            style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600, fontFamily: 'Cairo'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}
