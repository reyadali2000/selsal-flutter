import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/user_session_service.dart';

/// يخفي العنصر الملفوف تماماً ما لم يكن الدور النشط ضمن الأدوار المسموح بها.
/// يتكيف فورياً مع تبديل الدور (Role Switching) مثل PermissionGuard تماماً.
class RoleGuard extends StatelessWidget {
  final List<UserRole> allowedRoles;
  final Widget child;
  final Widget? fallback;

  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // الاشتراك في تغييرات المستخدم/الدور النشط لتحديث الإخفاء فورياً
      UserSessionService.to.currentUser.value;
      final role = UserSessionService.to.currentRole.value;
      if (allowedRoles.contains(role)) {
        return child;
      }
      return fallback ?? const SizedBox.shrink();
    });
  }
}
