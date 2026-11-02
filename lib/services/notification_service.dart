import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/notification_model.dart';
import '../models/water_quality_models.dart';
import '../routes/app_routes.dart';
import '../views/hygiene_report_display_view.dart';
import '../views/raw_material_report_display_view.dart';
import '../views/final_product_report_display_view.dart';
import '../views/raw_water_report_display_view.dart';
import '../views/dynamic_report_display_view.dart';
import 'api/notifications_api_service.dart';
import 'api/water_quality_api_service.dart';
import 'api/dynamic_reports_api_service.dart';
import 'database_helper.dart';
import 'user_session_service.dart';

class NotificationService extends GetxService {
  static NotificationService get to => Get.find<NotificationService>();

  var notifications = <AppNotification>[].obs;
  var unreadCount = 0.obs;
  var isLoading = false.obs;

  Timer? _pollingTimer;
  OverlayEntry? _toastOverlayEntry;
  Timer? _toastDismissTimer;

  void dismissActiveToast() {
    _toastDismissTimer?.cancel();
    _toastDismissTimer = null;
    try {
      _toastOverlayEntry?.remove();
    } catch (_) {}
    _toastOverlayEntry = null;
  }

  void clearOnLogout() {
    notifications.clear();
    unreadCount.value = 0;
    dismissActiveToast();
  }

  @override
  void onInit() {
    super.onInit();
    final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
    if (session != null && session.isLoggedIn.value) {
      loadNotifications();
    }
    // صمام أمان: تحديث دوري هادئ كل 30 ثانية في الخلفية للمستخدم المسجل حصراً
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final s = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
      if (s != null && s.isLoggedIn.value && Get.currentRoute != AppRoutes.login) {
        loadNotifications(silent: true);
      }
    });
  }

  @override
  void onClose() {
    _pollingTimer?.cancel();
    dismissActiveToast();
    super.onClose();
  }

  /// التحقق الصارم من صلاحية المستخدم الحالي للوصول إلى التقرير المرفق بالإشعار
  bool canAccessNotification(AppNotification notif) {
    if (!Get.isRegistered<UserSessionService>()) return false;
    final session = UserSessionService.to;
    if (!session.isLoggedIn.value) return false;
    if (Get.currentRoute == AppRoutes.login) return false;
    if (session.isAdmin || session.isGeneralManager) return true;

    // 1. التحقق من مطابقة الدور المستهدف
    final currentRole = session.roleKey;
    if (notif.targetRole != 'All' && notif.targetRole != currentRole) {
      return false;
    }

    // 2. التحقق من تقييد الفرع
    final userBranchId = session.assignedBranchId;
    if (session.isBranchRestricted && notif.branchId != null && notif.branchId! > 0) {
      if (userBranchId != null && userBranchId > 0 && notif.branchId != userBranchId) {
        return false;
      }
    }

    // 3. التحقق من صلاحيات الأقسام والتقارير التفصيلية
    final cat = (notif.reportCategory ?? '').toLowerCase().trim();
    final title = notif.title.toLowerCase();
    final body = notif.body.toLowerCase();

    // فحص النظافة الشخصية / سلامة الغذاء
    if (cat.contains('hygiene') || cat.contains('نظافة') || title.contains('نظافة') || body.contains('نظافة')) {
      return session.canViewHygiene;
    }

    // فحص المواد الخام
    if (cat.contains('material') || cat.contains('مواد') || title.contains('مواد خام') || title.contains('مادة خام') || body.contains('مواد خام')) {
      return session.canViewRawMaterial;
    }

    // فحص المنتج النهائي
    if (cat.contains('final') || cat.contains('نهائي') || title.contains('منتج نهائي') || body.contains('منتج نهائي')) {
      return session.canViewFinalProduct;
    }

    // فحص المياه الخام
    if (cat.contains('water') || cat.contains('مياه') || title.contains('مياه خام') || body.contains('مياه خام')) {
      return session.canViewRawWater;
    }

    // فحص التقارير الديناميكية
    if (cat.contains('dynamic') || cat.contains('ديناميكي') || title.contains('ديناميكي') || body.contains('ديناميكي')) {
      return session.canViewReports || session.canViewHealthReports || session.hasAnySpecificDynamicReportViewPermission;
    }

    return true;
  }

  Future<void> loadNotifications({bool silent = false}) async {
    try {
      if (!Get.isRegistered<UserSessionService>()) {
        if (!silent) isLoading.value = false;
        return;
      }
      final session = UserSessionService.to;
      if (!session.isLoggedIn.value || Get.currentRoute == AppRoutes.login) {
        if (!silent) isLoading.value = false;
        return;
      }
      if (!silent) isLoading.value = true;
      final role = Get.isRegistered<UserSessionService>()
          ? UserSessionService.to.roleKey
          : null;
      final branchId = Get.isRegistered<UserSessionService>()
          ? UserSessionService.to.assignedBranchId
          : null;

      List<AppNotification> rawList = [];
      if (Get.isRegistered<NotificationsApiService>()) {
        final apiList = await NotificationsApiService.to.getNotifications(role: role, branchId: branchId);
        rawList = apiList.map((m) => AppNotification.fromMap(m)).toList();
      } else {
        rawList = await DatabaseHelper.instance.getNotifications(role: role, branchId: branchId);
      }

      // تصفية الإشعارات بدقة وفق صلاحيات المستخدم النشط
      final allowedList = rawList.where(canAccessNotification).toList();
      notifications.value = allowedList;
      unreadCount.value = allowedList.where((n) => !n.isRead).length;
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    } finally {
      if (!silent) isLoading.value = false;
    }
  }

  /// معالجة الإشعار اللحظي القادم عبر الـ WebSocket وإظهار النافذة المنبثقة فوراً
  void handleIncomingRealtimeNotification(AppNotification notif) {
    if (!Get.isRegistered<UserSessionService>()) return;
    final session = UserSessionService.to;
    if (!session.isLoggedIn.value) return;
    if (Get.currentRoute == AppRoutes.login) return;

    // 1. تحقق صارم من صلاحية المستخدم للوصول للتقرير ومطابقة دوره وفرعه
    if (!canAccessNotification(notif)) {
      return;
    }

    // 2. تجنب التكرار
    if (notif.id != null && notifications.any((n) => n.id == notif.id)) {
      return;
    }

    // 3. تحديث القائمة والعداد في نفس اللحظة
    notifications.insert(0, notif);
    unreadCount.value++;

    // 4. إظهار الإشعار المنبثق التفاعلي الفوري (Instant Real-time Banner)
    showInstantNotificationPopup(notif);
  }

  /// إظهار بطاقة التنبيه المنبثقة الفورية أعلى الشاشة (Executive Toast)
  /// مصممة خصيصاً لتناسب شاشات الحاسوب والتابلت والهواتف الصغيرة بدقة تامة دون أخطاء بكسل
  void showInstantNotificationPopup(AppNotification notif) {
    if (!Get.isRegistered<UserSessionService>()) return;
    final session = UserSessionService.to;
    if (!session.isLoggedIn.value || Get.currentRoute == AppRoutes.login) return;

    // إغلاق أي إشعار نشط حالياً
    dismissActiveToast();

    final overlayState = Get.overlayContext != null
        ? Overlay.of(Get.overlayContext!)
        : Get.key.currentState?.overlay;
    if (overlayState == null) return;

    final Color indicatorColor;
    final IconData iconData;
    final String badgeText;

    switch (notif.tone) {
      case NotificationTone.approval:
        indicatorColor = const Color(0xFF2E7D32); // أخضر زيتي ملكي راقٍ
        iconData = Icons.check_circle_outline_rounded;
        badgeText = 'معتمد';
        break;
      case NotificationTone.rejection:
        indicatorColor = const Color(0xFFC62828); // عنّابي / قرمزي رصين
        iconData = Icons.error_outline_rounded;
        badgeText = 'مرفوض';
        break;
      case NotificationTone.pending:
        indicatorColor = const Color(0xFF1E3A8A); // أزرق كحلي تنفيذي
        iconData = Icons.schedule_rounded;
        badgeText = 'بانتظار الإجراء';
        break;
      case NotificationTone.info:
        indicatorColor = const Color(0xFF0284C7); // أزرق سماوي إداري هادئ
        iconData = Icons.notifications_none_rounded;
        badgeText = 'تنبيه';
        break;
    }

    _toastOverlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: FocusScope(
              canRequestFocus: false, // يمنع تماماً سحب التركيز من حقول الإدخال والجداول
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: -20, end: 0),
                  builder: (context, yOffset, child) {
                    return Transform.translate(
                      offset: Offset(0, yOffset),
                      child: Opacity(
                        opacity: ((yOffset + 20) / 20).clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            InkWell(
                              onTap: notif.reportId != null
                                  ? () {
                                      dismissActiveToast();
                                      navigateToReport(notif);
                                    }
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  right: 13,
                                  left: 6,
                                  top: 8,
                                  bottom: 8,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: indicatorColor.withValues(alpha: 0.09),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        iconData,
                                        color: indicatorColor,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  notif.title.isNotEmpty ? notif.title : 'إشعار جديد',
                                                  style: const TextStyle(
                                                    fontFamily: 'Tajawal',
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF0F172A),
                                                    height: 1.25,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: indicatorColor.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: indicatorColor.withValues(alpha: 0.22),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Text(
                                                  badgeText,
                                                  style: TextStyle(
                                                    fontFamily: 'Tajawal',
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: indicatorColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2.5),
                                          Text(
                                            notif.body,
                                            style: const TextStyle(
                                              fontFamily: 'Tajawal',
                                              fontSize: 11,
                                              fontWeight: FontWeight.normal,
                                              color: Color(0xFF64748B),
                                              height: 1.25,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (notif.reportId != null) ...[
                                      const SizedBox(width: 6),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () {
                                          dismissActiveToast();
                                          navigateToReport(notif);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                                          decoration: BoxDecoration(
                                            color: indicatorColor.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: indicatorColor.withValues(alpha: 0.25),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'معاينة',
                                                style: TextStyle(
                                                  fontFamily: 'Tajawal',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: indicatorColor,
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              Icon(
                                                Icons.arrow_back_ios_new_rounded,
                                                size: 9.5,
                                                color: indicatorColor,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 2),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => dismissActiveToast(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 15,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 4.5,
                                color: indicatorColor,
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
          ),
        );
      },
    );

    overlayState.insert(_toastOverlayEntry!);

    _toastDismissTimer = Timer(const Duration(seconds: 5), () {
      dismissActiveToast();
    });
  }

  /// فتح شاشة التقرير مباشرة عند النقر على الإشعار
  Future<void> navigateToReport(AppNotification item) async {
    if (item.id != null && !item.isRead) {
      await markAsRead(item.id!);
    }

    if (!canAccessNotification(item)) {
      Get.snackbar(
        'تنبيه الصلاحيات',
        'حسابك الحالي لا يملك صلاحية للوصول إلى هذا التقرير',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.lock_outline, color: Colors.white),
      );
      return;
    }

    if (item.reportId == null) return;

    final cat = item.reportCategory?.toLowerCase().trim() ?? '';

    if (cat.contains('hygiene') || cat.contains('نظافة')) {
      Get.to(() => HygieneReportDisplayView(reportId: item.reportId!));
    } else if (cat.contains('material') || cat.contains('مواد')) {
      Get.to(() => RawMaterialReportDisplayView(reportId: item.reportId!));
    } else if (cat.contains('final') || cat.contains('نهائي')) {
      WaterQualityLog? log;
      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          final apiData = await WaterQualityApiService.to.getLogById(item.reportId!);
          if (apiData != null) {
            final logData = apiData['log'] is Map ? Map<String, dynamic>.from(apiData['log']) : apiData;
            log = WaterQualityLog.fromMap(logData);
          }
        } catch (_) {}
      }
      log ??= await DatabaseHelper.instance.getWaterQualityLogById(item.reportId!);
      if (log != null) {
        Get.to(() => FinalProductReportDisplayView(), arguments: log);
      }
    } else if (cat.contains('dynamic') || cat.contains('ديناميكي')) {
      if (Get.isRegistered<DynamicReportDisplayController>()) {
        Get.delete<DynamicReportDisplayController>();
      }
      final record = await DynamicReportsApiService.to.getRecordDetails(item.reportId!);
      if (record != null) {
        Get.toNamed(AppRoutes.dynamicReportDisplay, arguments: {
          'reportId': record.reportId,
          'recordId': record.id,
        });
      } else {
        Get.snackbar('تنبيه', 'لم يتم العثور على سجل التقرير المطلوب');
      }
    } else {
      WaterQualityLog? log;
      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          final apiData = await WaterQualityApiService.to.getLogById(item.reportId!);
          if (apiData != null) {
            final logData = apiData['log'] is Map ? Map<String, dynamic>.from(apiData['log']) : apiData;
            log = WaterQualityLog.fromMap(logData);
          }
        } catch (_) {}
      }
      log ??= await DatabaseHelper.instance.getWaterQualityLogById(item.reportId!);
      if (log != null) {
        Get.to(() => RawWaterReportDisplayView(), arguments: log);
      }
    }
  }

  Future<void> sendNotification({
    required String title,
    required String body,
    int? reportId,
    String? reportCategory,
    String targetRole = 'All',
    int? branchId,
  }) async {
    final effectiveBranchId = branchId ?? (Get.isRegistered<UserSessionService>()
        ? UserSessionService.to.assignedBranchId
        : null);

    if (Get.isRegistered<NotificationsApiService>()) {
      await NotificationsApiService.to.createNotification(
        title: title,
        body: body,
        reportId: reportId,
        reportCategory: reportCategory,
        targetRole: targetRole,
        branchId: effectiveBranchId,
      );
    } else {
      final notif = AppNotification(
        title: title,
        body: body,
        reportId: reportId,
        reportCategory: reportCategory,
        targetRole: targetRole,
        branchId: effectiveBranchId,
        createdAt: DateTime.now(),
      );
      await DatabaseHelper.instance.insertNotification(notif);
    }
    await loadNotifications(silent: true);
  }

  Future<void> markAsRead(int id) async {
    if (Get.isRegistered<NotificationsApiService>()) {
      await NotificationsApiService.to.markAsRead(id);
    } else {
      await DatabaseHelper.instance.markNotificationAsRead(id);
    }
    await loadNotifications(silent: true);
  }

  Future<void> markAllAsRead() async {
    // 1. تحديث لحظي وفوري في الذاكرة لتصفير العداد وتغيير مظهر البطاقات فوراً
    final updatedList = notifications.map((n) => AppNotification(
      id: n.id,
      branchId: n.branchId,
      title: n.title,
      body: n.body,
      reportId: n.reportId,
      reportCategory: n.reportCategory,
      targetRole: n.targetRole,
      isRead: true,
      createdAt: n.createdAt,
    )).toList();
    notifications.value = updatedList;
    unreadCount.value = 0;

    final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
    final bool isSuperUser = session?.isAdmin == true || session?.isGeneralManager == true;
    
    // المدير العام ومسؤول النظام يقرؤون كافة إشعارات النظام بلا حصر لدور معين
    final String? role = isSuperUser
        ? null
        : (session != null ? UserModel.roleToString(session.currentRole.value) : null);
    final int? branchId = (isSuperUser || session?.isBranchRestricted != true)
        ? null
        : session?.assignedBranchId;

    if (Get.isRegistered<NotificationsApiService>()) {
      await NotificationsApiService.to.markAllAsRead(role: role, branchId: branchId);
    } else {
      await DatabaseHelper.instance.markAllNotificationsAsRead(role: role, branchId: branchId);
    }
    await loadNotifications(silent: true);
  }

  Future<void> deleteNotification(int id) async {
    if (Get.isRegistered<NotificationsApiService>()) {
      await NotificationsApiService.to.deleteNotification(id);
    } else {
      await DatabaseHelper.instance.deleteNotification(id);
    }
    await loadNotifications(silent: true);
  }
}
