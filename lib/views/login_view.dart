import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_assets.dart';
import '../routes/app_routes.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_session_service.dart';
import '../services/api/api.dart';
import '../widgets/ds/ds.dart';
import '../widgets/pending_approvals_popup.dart';

/// شاشة تسجيل الدخول مع أنيميشن أمواج مائية متكاملة
/// تبدأ الأمواج من الأسفل وتصعد بالشعار للمنتصف ثم تكمل للثلث الأعلى
/// وتظهر بيانات تسجيل الدخول تحت الموجة — كل شيء في شاشة واحدة
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _riseController;
  late Animation<double> _waterLevelAnimation;
  late Animation<double> _loginFadeAnimation;

  // متحكمات حقول الإدخال
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _usernameError;
  String? _passwordError;

  final LocalAuthentication _auth = LocalAuthentication();
  bool _hasLoggedInBefore = false;

  @override
  void initState() {
    super.initState();

    // حركة الأمواج الأفقية المستمرة
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // متحكم الحركة الرئيسي — يتحكم في كل المراحل (صعود + توقف + إكمال)
    _riseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500), // ~3.5 ثوانٍ إجمالية (يمكن تخطيها بالضغط)
    );

    // مستوى الماء يمر بثلاث مراحل في أنيميشن واحد متصل:
    // المرحلة 1 (0%-33.3%): صعود من الأسفل للمنتصف بشكل سلس
    // المرحلة 2 (33.3%-66.6%): ثبات في المنتصف (عرض الشعار)
    // المرحلة 3 (66.6%-100%): إكمال الصعود للثلث الأعلى
    _waterLevelAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 0.5).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 33.33,
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.5), // ثبات في المنتصف
        weight: 33.33,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 0.28).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 33.33,
      ),
    ]).animate(_riseController);

    // بيانات تسجيل الدخول تظهر تدريجياً فقط في المرحلة 3 (عندما يرتفع الماء للأعلى)
    _loginFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _riseController,
        curve: const Interval(0.75, 0.95, curve: Curves.easeIn),
      ),
    );

    // بدء الحركة بمجرد رسم أول فريم
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _riseController.forward();
      _checkBiometricLogin();
    });
  }

  Future<void> _checkBiometricLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final bool loggedInBefore = prefs.getBool('hasLoggedInBefore') ?? false;
    final bool biometricEnabled = prefs.getBool('biometric_login_enabled') ?? false;

    setState(() {
      _hasLoggedInBefore = loggedInBefore && biometricEnabled;
    });

    if (_hasLoggedInBefore) {
      await Future.delayed(const Duration(milliseconds: 2000));
      _authenticateWithBiometrics();
    }
  }

  /// إظهار الإشعار المنبثق بالتقارير بحاجة للاعتماد للشخص المخوّل بالاعتماد
  /// فور دخوله للنظام. يُستدعى بعد الانتقال للشاشة الرئيسية (دخول يدوي أو بصمة)،
  /// ولا يظهر شيء إذا لم تكن هناك تقارير معلقة لدور المستخدم الحالي.
  void _notifyPendingApprovals() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PendingApprovalsPopup.showIfAny();
    });
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (canAuthenticate) {
        final bool didAuthenticate = await _auth.authenticate(
          localizedReason: 'يرجى مسح البصمة لتسجيل الدخول السريع',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false,
          ),
        );

        if (didAuthenticate) {
          await UserSessionService.to.restoreSession();
          Get.offAllNamed(AppRoutes.home);
          _notifyPendingApprovals();
        }
      }
    } catch (e) {
      debugPrint("Biometric error: $e");
    }
  }

  bool _isLoading = false;

  // دالة التحقق من بيانات الدخول
  Future<void> _login() async {
    setState(() {
      _usernameError = null;
      _passwordError = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty) {
      setState(() => _usernameError = 'يرجى إدخال اسم المستخدم');
      return;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = 'يرجى إدخال كلمة المرور');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. تسجيل الدخول الحصري عبر خادم الـ API وسيرفر SQL Server
      if (Get.isRegistered<AuthApiService>()) {
        final apiResult = await AuthApiService.to.login(username, password);
        if (apiResult.isSuccess && apiResult.user != null) {
          await UserSessionService.to.login(apiResult.user!);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('hasLoggedInBefore', true);
          Get.offAllNamed(AppRoutes.home);
          _notifyPendingApprovals();
          return;
        } else {
          setState(() {
            _passwordError = apiResult.message.isNotEmpty
                ? apiResult.message
                : 'فشل الاتصال بخادم SQL Server، يرجى فحص الشبكة وإعدادات السيرفر.';
          });
          return;
        }
      } else {
        setState(() {
          _passwordError = 'خدمة الاتصال بالسيرفر غير مهيأة.';
        });
        return;
      }
    } catch (e) {
      setState(() {
        _passwordError = 'خطأ في الاتصال بالسيرفر: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showServerConfigDialog() {
    final serverController = TextEditingController(text: ApiClient.to.baseUrl);
    bool testing = false;
    String? testResult;
    bool testSuccess = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.wifi_tethering_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('إعدادات اتصال السيرفر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أدخل عنوان IP السيرفر للاتصال عبر شبكة الـ Wi-Fi المحلية للمصنع:',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: serverController,
                  decoration: InputDecoration(
                    labelText: 'رابط الـ API',
                    hintText: 'http://192.168.8.139:5000/api',
                    prefixIcon: const Icon(Icons.link_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 12),
                if (testResult != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: testSuccess ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: testSuccess ? Colors.green : Colors.red),
                    ),
                    child: Row(
                      children: [
                        Icon(testSuccess ? Icons.check_circle : Icons.error, color: testSuccess ? Colors.green : Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            testResult!,
                            style: TextStyle(color: testSuccess ? Colors.green.shade900 : Colors.red.shade900, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: testing
                        ? null
                        : () async {
                            setDialogState(() {
                              testing = true;
                              testResult = null;
                            });
                            try {
                              await ApiClient.to.setBaseUrl(serverController.text.trim());
                              final res = await ApiClient.to.get('/MasterData/branches');
                              setDialogState(() {
                                testing = false;
                                testSuccess = res.isSuccess;
                                testResult = res.isSuccess ? 'تم الاتصال بالسيرفر وقاعدة البيانات بنجاح!' : 'فشل الاتصال: ${res.message}';
                              });
                            } catch (e) {
                              setDialogState(() {
                                testing = false;
                                testSuccess = false;
                                testResult = 'تعذر الوصول: $e';
                              });
                            }
                          },
                    icon: testing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.network_check_rounded, size: 18),
                    label: const Text('اختبار الاتصال المباشر'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                await ApiClient.to.setBaseUrl(serverController.text.trim());
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                Get.snackbar(
                  'نجاح',
                  'تم حفظ رابط السيرفر بنجاح',
                  backgroundColor: AppColors.primary,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.TOP,
                );
              },
              child: const Text('حفظ الإعدادات', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _riseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final topPadding = MediaQuery.of(context).padding.top;
    final isKeyboardOpen = viewInsets.bottom > 0;
    const double normalLogoSize = 220;
    final double activeLogoSize = isKeyboardOpen ? 75 : normalLogoSize;

    return Scaffold(
      backgroundColor: AppColors.primaryLightest,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // إغلاق الكيبورد عند النقر في أي مكان فارغ، وتسريع الأنيميشن إذا لم تكتمل
        onTap: () {
          FocusScope.of(context).unfocus();
          if (!_riseController.isCompleted) {
            _riseController.animateTo(
              1.0,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
            );
          }
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_waveController, _riseController]),
          builder: (context, child) {
            final waterLevel = _waterLevelAnimation.value;
            final loginOpacity = _loginFadeAnimation.value;

            return Stack(
              children: [
                // ===== طبقة 1: الأمواج =====
                CustomPaint(
                  size: Size.infinite,
                  painter: _WaterWavePainter(_waveController.value, waterLevel),
                ),

                // ===== طبقة 2: بطاقة تسجيل الدخول (ترتفع بسلاسة مع الكيبورد) =====
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  top: isKeyboardOpen ? (topPadding + 75) : (size.height * 0.42),
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: loginOpacity,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: isKeyboardOpen ? 18 : 35,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkSurface.withValues(alpha: 0.95)
                                : Colors.white.withValues(alpha: 0.94),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(36),
                              topRight: Radius.circular(36),
                            ),
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkBorder
                                  : Colors.white.withValues(alpha: 0.6),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryDark.withValues(alpha: 0.10),
                                blurRadius: 24,
                                offset: const Offset(0, -6),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'مرحباً بك',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.primaryDarkest,
                                    fontSize: isKeyboardOpen ? 21 : 26,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                                
                                SizedBox(height: isKeyboardOpen ? 16 : 35),

                                // حقل اسم المستخدم
                                _buildTextField(
                                  hint: 'اسم المستخدم',
                                  icon: Icons.person_outline_rounded,
                                  controller: _usernameController,
                                  errorText: _usernameError,
                                  isCompact: isKeyboardOpen,
                                ),
                                SizedBox(height: isKeyboardOpen ? 12 : 18),

                                // حقل كلمة المرور
                                _buildTextField(
                                  hint: 'كلمة المرور',
                                  icon: Icons.lock_outline_rounded,
                                  isPassword: true,
                                  controller: _passwordController,
                                  errorText: _passwordError,
                                  isCompact: isKeyboardOpen,
                                ),

                                SizedBox(height: isKeyboardOpen ? 6 : 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: () {},
                                    child: Text(
                                      'نسيت كلمة المرور؟',
                                      style: TextStyle(
                                        color: isDark ? AppColors.darkPrimaryLight : AppColors.primaryDark,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: isKeyboardOpen ? 14 : 20),

                                // زر تسجيل الدخول
                                AppButton.primary(
                                  label: 'تسجيل الدخول',
                                  height: isKeyboardOpen ? 48 : 54,
                                  expanded: true,
                                  isLoading: _isLoading,
                                  onPressed: _login,
                                ),
                                if (_hasLoggedInBefore) ...[
                                  SizedBox(height: isKeyboardOpen ? 12 : 20),
                                  Center(
                                    child: InkWell(
                                      onTap: _authenticateWithBiometrics,
                                      borderRadius: BorderRadius.circular(50),
                                      child: Container(
                                        padding: EdgeInsets.all(isKeyboardOpen ? 10 : 16),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E2B3E) : AppColors.primaryLightest,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.primaryMedium.withValues(alpha: 0.3)),
                                        ),
                                        child: Icon(
                                          Icons.fingerprint_rounded,
                                          size: isKeyboardOpen ? 28 : 38,
                                          color: isDark ? AppColors.darkPrimaryLight : AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                SizedBox(height: isKeyboardOpen ? 10 : 16),
                                Center(
                                  child: TextButton.icon(
                                    onPressed: _showServerConfigDialog,
                                    icon: const Icon(Icons.settings_ethernet_rounded, size: 16, color: AppColors.primary),
                                    label: const Text(
                                      'تغيير خادم الاتصال أو فحص الشبكة (IP Server) 🌐',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ===== طبقة 3: الشعار (يصغر ويرتفع بنعومة عند ظهور الكيبورد) =====
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  top: isKeyboardOpen
                      ? (topPadding + 6)
                      : ((size.height * waterLevel) - (normalLogoSize / 2)),
                  left: (size.width - activeLogoSize) / 2,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      isKeyboardOpen
                          ? 0.0
                          : (math.sin(_waveController.value * 2 * math.pi) * 12),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      width: activeLogoSize,
                      height: activeLogoSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withValues(
                              alpha: isKeyboardOpen ? 0.08 : 0.15,
                            ),
                            blurRadius: isKeyboardOpen ? 16 : 40,
                            spreadRadius: isKeyboardOpen ? 2 : 10,
                            offset: Offset(0, isKeyboardOpen ? 4 : 15),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        AppAssets.logo,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.water_drop,
                          color: AppColors.primaryDark,
                          size: isKeyboardOpen ? 40 : 120,
                        ),
                      ),
                    ),
                  ),
                ),

                // ===== طبقة 4: زر اتصال السيرفر 🌐 (يختفي بنعومة أثناء فتح الكيبورد لإتاحة المساحة) =====
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  top: isKeyboardOpen ? (topPadding - 40) : (topPadding + 14),
                  left: 16,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isKeyboardOpen ? 0.0 : 1.0,
                    child: IgnorePointer(
                      ignoring: isKeyboardOpen,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showServerConfigDialog,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryDark.withValues(alpha: 0.20),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00C853),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.wifi_tethering_rounded,
                                  color: AppColors.primaryDark,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'اتصال السيرفر 🌐',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDarkest,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===== ويدجتات مساعدة =====

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextEditingController? controller,
    String? errorText,
    bool isCompact = false,
  }) {
    final isDark = (Get.context != null && Theme.of(Get.context!).brightness == Brightness.dark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2B3E) : AppColors.primaryLightest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: errorText != null ? Colors.red.shade400 : (isDark ? AppColors.darkBorder : AppColors.primaryLight),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isDark ? AppColors.darkInk : AppColors.primaryDarkest,
              fontSize: isCompact ? 14 : 15,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? AppColors.darkMuted : Colors.grey.shade500,
                fontSize: isCompact ? 13 : 14,
                fontFamily: 'Tajawal',
              ),
              prefixIcon: Icon(
                icon,
                color: isDark ? AppColors.darkPrimaryLight : AppColors.primaryDark.withValues(alpha: 0.6),
                size: isCompact ? 20 : 22,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                vertical: isCompact ? 14 : 18,
                horizontal: 16,
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 12),
            child: Text(
              errorText,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 12,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
      ],
    );
  }
}

// ===== رسام الأمواج =====
class _WaterWavePainter extends CustomPainter {
  final double animationValue;
  final double waterLevel;

  _WaterWavePainter(this.animationValue, this.waterLevel);

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    final paint2 = Paint()
      ..color = AppColors.primaryMedium.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    final paint3 = Paint()
      ..color = AppColors.primaryDark.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    _drawWave(canvas, size, paint1, animationValue, 1.0, waterLevel - 0.03, 25);
    _drawWave(canvas, size, paint2, animationValue + 0.3, 1.2, waterLevel + 0.01, 20);
    _drawWave(canvas, size, paint3, animationValue + 0.6, 0.8, waterLevel + 0.05, 30);
  }

  void _drawWave(
    Canvas canvas,
    Size size,
    Paint paint,
    double phase,
    double frequency,
    double heightPercent,
    double amplitude,
  ) {
    final path = Path();
    final yOffset = size.height * heightPercent;

    path.moveTo(0, size.height);
    path.lineTo(0, yOffset);

    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        yOffset +
            math.sin((i / size.width * math.pi * 2 * frequency) +
                    (phase * math.pi * 2)) *
                amplitude,
      );
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaterWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.waterLevel != waterLevel;
  }
}
