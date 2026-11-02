import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../routes/app_routes.dart';
import '../services/user_session_service.dart';

/// حارس مسار: يعيد التوجيه لشاشة "غير مصرح" عند محاولة الدخول المباشر لمسار محمي
class PermissionMiddleware extends GetMiddleware {
  final String permissionCode;

  PermissionMiddleware(this.permissionCode, {int priority = 1}) : super(priority: priority);

  @override
  RouteSettings? redirect(String? route) {
    final session = UserSessionService.to;
    if (session.currentUser.value != null && session.hasPermissionCode(permissionCode)) {
      return null;
    }
    return const RouteSettings(name: AppRoutes.unauthorized);
  }
}

/// حارس لمسار يمكن فتحه بأية صلاحية من مجموعة محددة.
class AnyPermissionMiddleware extends GetMiddleware {
  final List<String> permissionCodes;

  AnyPermissionMiddleware(this.permissionCodes, {int priority = 1})
      : super(priority: priority);

  @override
  RouteSettings? redirect(String? route) {
    final session = UserSessionService.to;
    if (session.currentUser.value != null &&
        permissionCodes.any(session.hasPermissionCode)) {
      return null;
    }
    return const RouteSettings(name: AppRoutes.unauthorized);
  }
}

/// حارس خاص لمسار تعبئة التقارير الديناميكية
class DynamicReportFormMiddleware extends GetMiddleware {
  DynamicReportFormMiddleware({int priority = 1}) : super(priority: priority);

  @override
  RouteSettings? redirect(String? route) {
    final session = UserSessionService.to;
    if (session.currentUser.value != null && session.canFillDynamicReports) {
      return null;
    }
    return const RouteSettings(name: AppRoutes.unauthorized);
  }
}

/// حارس خاص لمسار عرض وسجلات التقارير الديناميكية
class DynamicReportViewMiddleware extends GetMiddleware {
  DynamicReportViewMiddleware({int priority = 1}) : super(priority: priority);

  @override
  RouteSettings? redirect(String? route) {
    final session = UserSessionService.to;
    if (session.currentUser.value != null && (session.canViewReports || session.canViewHealthReports || session.canFillDynamicReports)) {
      return null;
    }
    return const RouteSettings(name: AppRoutes.unauthorized);
  }
}
