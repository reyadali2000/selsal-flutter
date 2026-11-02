import 'package:get/get.dart';
import 'app_routes.dart';
import '../middlewares/permission_middleware.dart';
import '../models/role_model.dart';
import '../views/login_view.dart';
import '../views/home_view.dart';
import '../bindings/home_binding.dart';
import '../views/dynamic_reports_management_view.dart';
import '../views/dynamic_report_builder_view.dart';
import '../views/dynamic_report_form_view.dart';
import '../views/dynamic_report_records_view.dart';
import '../views/dynamic_report_display_view.dart';
import '../views/users_management_view.dart';
import '../views/roles_management_view.dart';
import '../views/packages_management_view.dart';
import '../views/daily_workers_management_view.dart';
import '../views/daily_workers_commitment_view.dart';
import '../views/factory_reports_compliance_view.dart';
import '../views/shifts_view.dart';
import '../views/unauthorized_view.dart';

/// قائمة صفحات التطبيق مع ربط كل مسار بالصفحة والـ Binding المناسب
class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.dynamicReportsManagement,
      page: () => const DynamicReportsManagementView(),
      middlewares: [
        PermissionMiddleware(SystemPermissions.designDynamicReports),
      ],
    ),
    GetPage(
      name: AppRoutes.dynamicReportBuilder,
      page: () => const DynamicReportBuilderView(),
      middlewares: [
        PermissionMiddleware(SystemPermissions.designDynamicReports),
      ],
    ),
    GetPage(
      name: AppRoutes.dynamicReportForm,
      page: () => const DynamicReportFormView(),
      middlewares: [
        DynamicReportFormMiddleware(),
      ],
    ),
    GetPage(
      name: AppRoutes.dynamicReportRecords,
      page: () => const DynamicReportRecordsView(),
      middlewares: [
        DynamicReportViewMiddleware(),
      ],
    ),
    GetPage(
      name: AppRoutes.dynamicReportDisplay,
      page: () => const DynamicReportDisplayView(),
      middlewares: [
        DynamicReportViewMiddleware(),
      ],
    ),
    GetPage(
      name: AppRoutes.usersManagement,
      page: () => const UsersManagementView(),
      middlewares: [
        PermissionMiddleware(SystemPermissions.manageUsers),
      ],
    ),
    GetPage(
      name: AppRoutes.rolesManagement,
      page: () => const RolesManagementView(),
      middlewares: [
        PermissionMiddleware(SystemPermissions.manageRoles),
      ],
    ),
    GetPage(
      name: AppRoutes.packagesManagement,
      page: () => const PackagesManagementView(),
      middlewares: [
        PermissionMiddleware(SystemPermissions.manageProducts),
      ],
    ),
    GetPage(
      name: AppRoutes.dailyWorkersManagement,
      page: () => DailyWorkersManagementView(),
      middlewares: [
        PermissionMiddleware(SystemPermissions.manageDailyWorkers),
      ],
    ),
    GetPage(
      name: AppRoutes.dailyWorkersCommitment,
      page: () => DailyWorkersCommitmentView(),
      middlewares: [
        PermissionMiddleware(SystemPermissions.viewDailyWorkersCommitment),
      ],
    ),
    GetPage(
      name: AppRoutes.factoryComplianceReport,
      page: () => const FactoryReportsComplianceView(),
      middlewares: [
        PermissionMiddleware(SystemPermissions.viewFactoryComplianceReport),
      ],
    ),
    GetPage(
      name: AppRoutes.shifts,
      page: () => const ShiftsView(),
      middlewares: [
        PermissionMiddleware(SystemPermissions.viewShifts),
      ],
    ),
    GetPage(
      name: AppRoutes.unauthorized,
      page: () => const UnauthorizedView(),
    ),
  ];
}
