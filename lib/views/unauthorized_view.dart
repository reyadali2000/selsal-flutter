import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/user_session_service.dart';
import '../routes/app_routes.dart';
import '../widgets/ds/ds.dart';

/// تُعرض عند محاولة الوصول لقسم لا يملك المستخدم صلاحية الدخول إليه
class UnauthorizedView extends StatelessWidget {
  const UnauthorizedView({super.key});

  void _goBack() {
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
    } else {
      Get.offAllNamed(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AppScaffold(
        title: 'غير مصرح',
        showAppBar: false,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AppCard.glass(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppButton.dangerColor.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppButton.dangerColor.withValues(alpha: 0.25),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_person_rounded,
                          size: 56,
                          color: AppButton.dangerColor,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'غير مصرح بالدخول',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: isDark ? AppColors.darkInk : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Obx(() {
                        final roleTitle = UserSessionService.to.roleTitle;
                        return Text(
                          'حسابك الحالي ($roleTitle) لا يملك صلاحية الوصول لهذا القسم من النظام. '
                          'يرجى التواصل مع مسؤول النظام لمنحك الصلاحية المطلوبة.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13.5,
                            height: 1.6,
                            color: isDark ? AppColors.darkMuted : AppColors.muted,
                          ),
                        );
                      }),
                      const SizedBox(height: 28),
                      AppButton.primary(
                        label: 'العودة',
                        icon: Icons.arrow_back_rounded,
                        expanded: true,
                        onPressed: _goBack,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
