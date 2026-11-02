import 'dart:io';
import 'services/realtime_notification_client.dart';

import 'constants/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'routes/app_routes.dart';
import 'routes/app_pages.dart';

import 'services/user_session_service.dart';
import 'services/notification_service.dart';
import 'services/pending_approvals_service.dart';
import 'services/theme_service.dart';

import 'services/api/api.dart';
import 'services/sync/sync_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة قاعدة بيانات SQLite عبر FFI لدعم الديسك توب (Windows/Linux/macOS)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // خدمات الاتصال السحابي بالـ API
  Get.put(ApiClient(), permanent: true);
  Get.put(AuthApiService(), permanent: true);
  Get.put(MasterDataApiService(), permanent: true);
  Get.put(WaterQualityApiService(), permanent: true);
  Get.put(HygieneApiService(), permanent: true);
  Get.put(RawMaterialsApiService(), permanent: true);
  Get.put(DynamicReportsApiService(), permanent: true);
  Get.put(NotificationsApiService(), permanent: true);
  Get.put(AuditApiService(), permanent: true);

  // مدير المزامنة المركزي: مراقبة الاتصال + التحديث الدوري + طابور الكتابة
  Get.put(SyncManager(), permanent: true);

  Get.put(UserSessionService(), permanent: true);

  Get.put(NotificationService(), permanent: true);
  Get.put(RealtimeNotificationClient(), permanent: true);
  Get.put(PendingApprovalsService(), permanent: true);
  Get.put(ThemeService(), permanent: true);
  await ThemeService.to.ensureLoaded();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDark = ThemeService.to.isDarkMode.value;
      return GetMaterialApp(
        title: 'إدارة الجودة',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        // Set Arabic layout directions
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar', 'AE'), // Arabic
          Locale('en', 'US'), // English (Added for LTR support if needed for the login screen)
        ],
        locale: const Locale('ar', 'AE'),
        // ===== النظام الجديد: Routes مركزية =====
        initialRoute: AppRoutes.login,
        getPages: AppPages.pages,
      );
    });
  }
}
