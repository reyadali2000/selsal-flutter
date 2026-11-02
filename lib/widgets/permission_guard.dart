import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/user_session_service.dart';

/// يخفي العنصر الملفوف تماماً عند انعدام الصلاحية، ويتفاعل مع تغيير الجلسة/الدور
class PermissionGuard extends StatelessWidget {
  final String permissionCode;
  final Widget child;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.permissionCode,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // الاشتراك في تغييرات المستخدم/الدور النشط لتحديث الإخفاء فورياً
      UserSessionService.to.currentUser.value;
      if (UserSessionService.to.hasPermissionCode(permissionCode)) {
        return child;
      }
      return fallback ?? const SizedBox.shrink();
    });
  }
}
