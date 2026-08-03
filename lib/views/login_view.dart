import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      backgroundColor: const Color(0xFFF4F6F8),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Secret Staff Entry wrapped around Logo Header
              GestureDetector(
                onTap: () async {
                  final api = ApiService();
                  if (api.isDeviceActivated) {
                    setState(() {
                      _isStaffPortal = !_isStaffPortal; // Toggle! If staff, toggles back to client.
                      _error = null;
                    });
                  } else {
                    // Open activation screen with auto request code
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
                    // Logo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: royalGreen,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: royalGreen.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                        border: Border.all(color: goldColor, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'منصة حجاج الضويحي',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'شركة حجاج عبدالرحمن الضويحي للمحاماة',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: goldColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Portal Identifier Label (Clean, premium text instead of tab switcher)
              Text(
                _isStaffPortal
                    ? 'بوابة الموظفين — دخول آمن للمنصة'
                    : 'بوابة الموكلين — دخول سريع وآمن',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: royalGreen,
                ),
              ),
              const SizedBox(height: 20),

              // Error banner
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
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // Form fields based on portal
              if (_isStaffPortal) ...[
                // Staff Portal (Username + Password)
                TextField(
                  controller: _usernameController,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'اسم المستخدم',
                    prefixIcon: const Icon(Icons.person_outline),
                    fillColor: Colors.white,
                    filled: true,
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
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    fillColor: Colors.white,
                    filled: true,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      activeColor: royalGreen,
                      checkColor: Colors.white,
                      onChanged: (val) {
                        setState(() {
                          _rememberMe = val ?? false;
                        });
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _rememberMe = !_rememberMe;
                        });
                      },
                      child: const Text(
                        'تذكرني',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _handleStaffLogin,
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
                              Text(
                                'دخول آمن للمنصة',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 16),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isStaffPortal = false;
                      _error = null;
                    });
                  },
                  child: Text(
                    'العودة لبوابة الموكلين',
                    style: TextStyle(
                      color: goldColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ] else ...[
                // Client Portal (Password-based login/setup flow)
                if (!_isFirstTimeSetup) ...[
                  // Direct login view (Phone + Password immediately)
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'رقم الجوال المسجل',
                      prefixIcon: const Icon(Icons.phone_iphone),
                      helperText: 'مثال: 05xxxxxxxx أو 9665xxxxxxxx',
                      fillColor: Colors.white,
                      filled: true,
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: _clientPasswordController,
                    obscureText: _obscureClientPassword,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureClientPassword ? Icons.visibility_off : Icons.visibility,
                          color: const Color(0xFF64748B),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureClientPassword = !_obscureClientPassword;
                          });
                        },
                      ),
                      fillColor: Colors.white,
                      filled: true,
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleClientLoginWithPassword,
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
                                Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.login, size: 16),
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
                    child: Text(
                      'تفعيل الحساب لأول مرة / تعيين كلمة المرور',
                      style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ] else ...[
                  // First-time setup flow (checking phone then setting password)
                  if (!_clientChecked) ...[
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: 'رقم الجوال للتحقق والتفعيل',
                        prefixIcon: const Icon(Icons.phone_iphone),
                        helperText: 'سنتحقق من وجود حسابك لتفعيل كلمة المرور',
                        fillColor: Colors.white,
                        filled: true,
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleClientCheck,
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
                                  Text(
                                    'تحقق واستمرار',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 16),
                                ],
                              ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isFirstTimeSetup = false;
                          _error = null;
                        });
                      },
                      child: Text(
                        'العودة لبوابة الدخول المباشر',
                        style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ] else ...[
                    // Welcome message
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: royalGreen.withOpacity(0.05),
                        border: Border.all(color: royalGreen.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'أهلاً بك، $_clientName',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: royalGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _clientHasPassword
                                ? 'لديك كلمة مرور مسجلة بالفعل!'
                                : 'يرجى تعيين كلمة مرور جديدة لحسابك لتتمكن من الدخول مستقبلاً',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (!_clientHasPassword) ...[
                      // First time login: Set password
                      TextField(
                        controller: _clientPasswordController,
                        obscureText: _obscureClientPassword,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور الجديدة',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureClientPassword ? Icons.visibility_off : Icons.visibility,
                              color: const Color(0xFF64748B),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureClientPassword = !_obscureClientPassword;
                              });
                            },
                          ),
                          fillColor: Colors.white,
                          filled: true,
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
                      const SizedBox(height: 16),
                      TextField(
                        controller: _clientConfirmPasswordController,
                        obscureText: _obscureClientPassword,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'تأكيد كلمة المرور الجديدة',
                          prefixIcon: const Icon(Icons.lock_outline),
                          fillColor: Colors.white,
                          filled: true,
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
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _handleClientSetPassword,
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
                                    Text(
                                      'تعيين كلمة المرور والدخول',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.check_circle_outline, size: 16),
                                  ],
                                ),
                          ),
                        ),
                    ] else ...[
                      // Returning login: already has password, direct them to use standard login
                      const Text(
                        'حسابك مفعّل بالفعل ولديك كلمة مرور. يرجى العودة واستخدام الدخول المباشر.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isFirstTimeSetup = false;
                              _clientChecked = false;
                              _error = null;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: royalGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(color: goldColor),
                          ),
                          child: const Text('العودة للدخول المباشر', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isFirstTimeSetup = false;
                          _clientChecked = false;
                          _clientPasswordController.clear();
                          _clientConfirmPasswordController.clear();
                          _error = null;
                        });
                      },
                      child: Text(
                        'العودة لبوابة الدخول المباشر',
                        style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ],

              const SizedBox(height: 24),

              // Contact Support
              GestureDetector(
                onTap: _openWhatsApp,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFF25D366)),
                    const SizedBox(width: 6),
                    Text(
                      _isStaffPortal
                          ? 'نسيت كلمة المرور؟ تواصل مع الإدارة'
                          : 'تواجه مشكلة في تسجيل الدخول؟ تواصل معنا',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
