/// أسماء المسارات الثابتة للتنقل بين الصفحات
/// يمنع الأخطاء الإملائية ويسهل إدارة التنقل مركزياً
abstract class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String dynamicReportsManagement = '/dynamic_reports_management';
  static const String dynamicReportBuilder = '/dynamic_report_builder';
  static const String dynamicReportForm = '/dynamic_report_form';
  static const String dynamicReportRecords = '/dynamic-report-records';
  static const String dynamicReportDisplay = '/dynamic-report-display';
  static const String usersManagement = '/users_management';
  static const String rolesManagement = '/roles_management';
  static const String packagesManagement = '/packages_management';
  static const String dailyWorkersManagement = '/daily_workers_management';
  static const String dailyWorkersCommitment = '/daily_workers_commitment';
  static const String factoryComplianceReport = '/factory_compliance_report';
  static const String shifts = '/shifts';
  static const String unauthorized = '/unauthorized';
}
