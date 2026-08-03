import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ActivationView extends StatefulWidget {
  final VoidCallback onActivated;
  final bool autoRequestCode;

  const ActivationView({
    super.key,
    required this.onActivated,
    this.autoRequestCode = false,
  });

  @override
  State<ActivationView> createState() => _ActivationViewState();
}

class _ActivationViewState extends State<ActivationView> {
  @override
  void initState() {
    super.initState();
    if (widget.autoRequestCode) {
      Future.delayed(Duration.zero, () {
        _handleRequestCode();
      });
    }
  }
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _requestingCode = false;
  String? _error;
  String? _info;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  final Color royalGreen = const Color(0xFF1E3D30);
  final Color goldColor = const Color(0xFFB8963A);

  @override
  void dispose() {
    _codeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleActivate() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final success = await ApiService().activateDevice(code);
    
    if (mounted) {
      setState(() => _loading = false);
      if (success) {
        widget.onActivated();
      } else {
        setState(() => _error = 'رمز التنشيط المدخل غير صحيح.');
      }
    }
  }

  Future<void> _handleRequestCode() async {
    if (_cooldownSeconds > 0) return;

    setState(() {
      _requestingCode = true;
      _error = null;
      _info = null;
    });

    final res = await ApiService().requestActivation();

    if (mounted) {
      setState(() {
        _requestingCode = false;
        if (res['success'] == true) {
          _info = res['message'];
          _cooldownSeconds = 60;
          _startCooldownTimer();
        } else {
          _error = res['message'];
        }
      });
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_cooldownSeconds > 0) {
            _cooldownSeconds--;
          } else {
            _cooldownTimer?.cancel();
          }
        });
      } else {
        _cooldownTimer?.cancel();
      }
    });
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
              // Shield Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: royalGreen,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: royalGreen.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ],
                  border: Border.all(color: goldColor, width: 1.5),
                ),
                child: Icon(Icons.phonelink_lock, size: 32, color: goldColor),
              ),
              const SizedBox(height: 24),
              const Text(
                'تنشيط الجهاز المحمول',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'عذراً، هذا الجهاز غير مسجل للوصول للمنصة. يرجى إدخال رمز التنشيط للبدء بالدخول الآمن.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),

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

              if (_info != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _info!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // Code Input
              TextField(
                controller: _codeController,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(letterSpacing: 4),
                decoration: InputDecoration(
                  labelText: 'رمز تنشيط الجهاز (Activation Code)',
                  labelStyle: const TextStyle(fontSize: 12, letterSpacing: 0),
                  prefixIcon: const Icon(Icons.vpn_key),
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
              const SizedBox(height: 20),

              // Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleActivate,
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
                              'تنشيط وتوثيق هذا الجهاز',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.lock_open, size: 16),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Request Code Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: (_loading || _requestingCode || _cooldownSeconds > 0)
                      ? null
                      : _handleRequestCode,
                  style: TextButton.styleFrom(
                    foregroundColor: goldColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: goldColor.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                  ),
                  child: _requestingCode
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: goldColor,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _cooldownSeconds > 0
                              ? 'إعادة المحاولة بعد $_cooldownSeconds ثانية'
                              : 'إرسال الكود فقط إلى المطور',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
