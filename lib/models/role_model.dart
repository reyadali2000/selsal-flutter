import 'dart:convert';
import 'package:flutter/material.dart';

/// تعريف الصلاحية في النظام
class SystemPermissionDef {
  final String code;
  final String title;
  final String description;
  final String category;
  final IconData icon;

  const SystemPermissionDef({
    required this.code,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
  });
}

/// كتالوج الصلاحيات القياسية في مصنع المياه
class SystemPermissions {
  // فئات الصلاحيات
  static const String categoryReports = 'فحوصات وتقارير الجودة';
  static const String categoryApprovals = 'سلسلة الاعتماد والتوقيع';
  static const String categoryDynamic = 'التقارير والنماذج الديناميكية';
  static const String categoryFoodSafety = 'سلامة الغذاء والصحة';
  static const String categoryOperations = 'العمليات والورديات';
  static const String categoryAdmin = 'إدارة النظام والأمان';

  // أكواد الصلاحيات
  static const String createWaterReports = 'create_water_reports';
  static const String createRawMaterialReports = 'create_raw_material_reports';
  static const String createHygieneReports = 'create_hygiene_reports';
  static const String fillDynamicReports = 'fill_dynamic_reports';
  // صلاحيات منفصلة لتعبئة النماذج الديناميكية حسب القسم
  static const String fillQualityDynamicReports =
      'fill_quality_dynamic_reports';
  static const String fillFoodSafetyDynamicReports =
      'fill_food_safety_dynamic_reports';
  static const String editReports = 'edit_reports';
  static const String deleteReports = 'delete_reports';
  static const String viewReports = 'view_reports';

  static const String approveQM = 'approve_qm';
  static const String approveQSupervisor = 'approve_qsupervisor';
  static const String approveGM = 'approve_gm';
  static const String rejectReports = 'reject_reports';

  static const String designDynamicReports = 'design_dynamic_reports';

  static const String fillHealthReports = 'fill_health_reports';
  static const String viewHealthReports = 'view_health_reports';

  /// صلاحية قديمة موحَّدة — تُستخدم فقط لترحيل الأدوار المخزنة سابقاً إلى الصلاحيتين المنفصلتين
  static const String legacyManageHealthAffairs = 'manage_health_affairs';

  static const String viewShifts = 'view_shifts';
  static const String manageShifts = 'manage_shifts';

  static const String manageUsers = 'manage_users';
  static const String manageRoles = 'manage_roles';
  static const String manageSettings = 'manage_settings';
  static const String manageProducts = 'manage_products';

  /// إدارة سجل العمالة اليومية (إضافة/تعديل/إيقاف العمال وربطهم بالفروع)
  static const String manageDailyWorkers = 'manage_daily_workers';

  /// متابعة التزام العمالة اليومية واحتساب الحضور والورديات من فحص النظافة
  static const String viewDailyWorkersCommitment =
      'view_daily_workers_commitment';

  /// تقرير تحليل ومتابعة التزام المصانع اليومي بالفحوصات والتقارير المنفذة والمتخلفة
  static const String viewFactoryComplianceReport =
      'view_factory_compliance_report';

  static const String exportPdf = 'export_pdf';

  /// نوافذ الأمان الشخصي في شاشة الإعدادات — تتحكم بإظهار نافذتي التوقيع الرقمي وتغيير كلمة المرور
  static const String manageSignature = 'manage_signature';
  static const String changePassword = 'change_password';

  // تفعيل الأقسام (المصفوفة الجديدة)
  static const String deptQuality = 'dept_quality';
  static const String deptFoodSafety = 'dept_food_safety';

  // صلاحيات تقارير الجودة الثابتة
  static const String fillRawMaterial = 'fill_rpt_raw_material';
  static const String viewRawMaterial = 'view_rpt_raw_material';
  static const String printRawMaterial = 'print_rpt_raw_material';
  static const String enabledRawMaterial = 'enabled_rpt_raw_material';

  static const String fillFinalProduct = 'fill_rpt_final_product';
  static const String viewFinalProduct = 'view_rpt_final_product';
  static const String printFinalProduct = 'print_rpt_final_product';
  static const String enabledFinalProduct = 'enabled_rpt_final_product';

  static const String fillRawWater = 'fill_rpt_raw_water';
  static const String viewRawWater = 'view_rpt_raw_water';
  static const String printRawWater = 'print_rpt_raw_water';
  static const String enabledRawWater = 'enabled_rpt_raw_water';

  // صلاحيات تقارير سلامة الغذاء الثابتة
  static const String fillHygiene = 'fill_rpt_hygiene';
  static const String viewHygiene = 'view_rpt_hygiene';
  static const String printHygiene = 'print_rpt_hygiene';
  static const String enabledHygiene = 'enabled_rpt_hygiene';

  // دوال مساعدة لإنشاء أكواد الصلاحيات للتقارير الديناميكية
  static String fillDynamicReportCode(int id) => 'fill_dyn_rpt_$id';
  static String viewDynamicReportCode(int id) => 'view_dyn_rpt_$id';
  static String printDynamicReportCode(int id) => 'print_dyn_rpt_$id';
  static String enabledDynamicReportCode(int id) => 'enabled_dyn_rpt_$id';

  /// إجمالي عدد الصلاحيات القياسية المعرفة في الكتالوج الثابت للنظام
  static int get staticPermissionsCount => all.length;

  /// يحسب إجمالي الصلاحيات المتوفرة في النظام ديناميكياً مع مراعاة عدد التقارير الديناميكية المعرفة
  /// كل تقرير ديناميكي يولد 4 صلاحيات (تفعيل، تعبئة، عرض، طباعة).
  static int calculateTotalPermissionsCount(int dynamicReportsCount) {
    return all.length + (dynamicReportsCount * 4);
  }

  /// إصدار هيكل الصلاحيات — يُستخدم لترحيل الأدوار المخزنة عند إضافة صلاحيات جديدة
  ///
  /// v12: إضافة دور مشرف الجودة (QS) وسلسلة الاعتماد المرنة
  static const int schemaVersion = 12;

  /// قائمة كافة الصلاحيات المعرفة في النظام
  static const List<SystemPermissionDef> all = [
    // 1. أقسام وفحوصات وتقارير الجودة
    SystemPermissionDef(
      code: deptQuality,
      title: 'تفعيل قسم إدارة الجودة',
      description: 'إظهار قسم إدارة الجودة وجميع تقاريره للمستخدم',
      category: categoryReports,
      icon: Icons.dashboard_outlined,
    ),
    SystemPermissionDef(
      code: enabledRawMaterial,
      title: 'تفعيل تقرير المواد الخام',
      description: 'السماح بالوصول لتقرير فحص المواد الخام واستلامها',
      category: categoryReports,
      icon: Icons.inventory_2_outlined,
    ),
    SystemPermissionDef(
      code: fillRawMaterial,
      title: 'تعبئة تقرير المواد الخام',
      description: 'إدخال وتعبئة سجلات فحص المواد الخام',
      category: categoryReports,
      icon: Icons.edit_note_rounded,
    ),
    SystemPermissionDef(
      code: viewRawMaterial,
      title: 'عرض تقارير المواد الخام',
      description: 'استعراض سجلات فحص المواد الخام',
      category: categoryReports,
      icon: Icons.visibility_outlined,
    ),
    SystemPermissionDef(
      code: printRawMaterial,
      title: 'طباعة تقرير المواد الخام',
      description: 'طباعة وتصدير PDF لتقرير فحص المواد الخام',
      category: categoryReports,
      icon: Icons.print_outlined,
    ),
    SystemPermissionDef(
      code: enabledFinalProduct,
      title: 'تفعيل تقرير المنتج النهائي',
      description: 'السماح بالوصول لتقرير فحص المنتج النهائي',
      category: categoryReports,
      icon: Icons.verified_outlined,
    ),
    SystemPermissionDef(
      code: fillFinalProduct,
      title: 'تعبئة تقرير المنتج النهائي',
      description: 'إدخال وتعبئة سجلات فحص المنتج النهائي',
      category: categoryReports,
      icon: Icons.edit_note_rounded,
    ),
    SystemPermissionDef(
      code: viewFinalProduct,
      title: 'عرض تقارير المنتج النهائي',
      description: 'استعراض سجلات فحص المنتج النهائي',
      category: categoryReports,
      icon: Icons.visibility_outlined,
    ),
    SystemPermissionDef(
      code: printFinalProduct,
      title: 'طباعة تقرير المنتج النهائي',
      description: 'طباعة وتصدير PDF لتقرير فحص المنتج النهائي',
      category: categoryReports,
      icon: Icons.print_outlined,
    ),
    SystemPermissionDef(
      code: enabledRawWater,
      title: 'تفعيل تقرير المياه الخام',
      description: 'السماح بالوصول لتقرير فحص المياه الخام والآبار',
      category: categoryReports,
      icon: Icons.water_drop_outlined,
    ),
    SystemPermissionDef(
      code: fillRawWater,
      title: 'تعبئة تقرير المياه الخام',
      description: 'إدخال وتعبئة سجلات فحص المياه الخام',
      category: categoryReports,
      icon: Icons.edit_note_rounded,
    ),
    SystemPermissionDef(
      code: viewRawWater,
      title: 'عرض تقارير المياه الخام',
      description: 'استعراض سجلات فحص المياه الخام',
      category: categoryReports,
      icon: Icons.visibility_outlined,
    ),
    SystemPermissionDef(
      code: printRawWater,
      title: 'طباعة تقرير المياه الخام',
      description: 'طباعة وتصدير PDF لتقرير فحص المياه الخام',
      category: categoryReports,
      icon: Icons.print_outlined,
    ),
    SystemPermissionDef(
      code: createWaterReports,
      title: 'إدخال فحوصات المياه والمنتج النهائي',
      description:
          'تسجيل قراءات المياه الخام، المياه اليومية، وفحوصات المنتج النهائي والمختبر',
      category: categoryReports,
      icon: Icons.water_drop_rounded,
    ),
    SystemPermissionDef(
      code: createRawMaterialReports,
      title: 'إدخال فحوصات المواد الخام',
      description: 'تسجيل واستلام بيانات المواد الخام وتقاريرها',
      category: categoryReports,
      icon: Icons.inventory_2_rounded,
    ),
    SystemPermissionDef(
      code: createHygieneReports,
      title: 'إدخال تقارير النظافة والهايجين',
      description:
          'تسجيل التفتيش الصحي اليومي ومطابقة النظافة الشخصية والمعدات',
      category: categoryReports,
      icon: Icons.cleaning_services_rounded,
    ),
    SystemPermissionDef(
      code: fillQualityDynamicReports,
      title: 'تعبئة نماذج الجودة الديناميكية',
      description: 'تعبئة التقارير الديناميكية التابعة لقسم إدارة الجودة فقط',
      category: categoryDynamic,
      icon: Icons.post_add_rounded,
    ),
    SystemPermissionDef(
      code: fillFoodSafetyDynamicReports,
      title: 'تعبئة نماذج سلامة الغذاء الديناميكية',
      description: 'تعبئة التقارير الديناميكية التابعة لقسم سلامة الغذاء فقط',
      category: categoryFoodSafety,
      icon: Icons.post_add_rounded,
    ),
    SystemPermissionDef(
      code: viewReports,
      title: 'استعراض التقارير والسجلات',
      description: 'مشاهدة سجلات الفحوصات والاطلاع على نتائج الجودة',
      category: categoryReports,
      icon: Icons.visibility_rounded,
    ),
    SystemPermissionDef(
      code: editReports,
      title: 'تعديل السجلات والمسودات',
      description: 'تعديل بيانات فحص قبل اعتماده النهائي',
      category: categoryReports,
      icon: Icons.edit_note_rounded,
    ),
    SystemPermissionDef(
      code: deleteReports,
      title: 'حذف السجلات غير المعتمدة',
      description: 'حذف السجلات الخاطئة والمسودات',
      category: categoryReports,
      icon: Icons.delete_outline_rounded,
    ),

    // 2. سلسلة الاعتماد والتوقيع
    SystemPermissionDef(
      code: approveQM,
      title: 'اعتماد مدير الجودة (المستوى الأول)',
      description:
          'التوقيع واعتماد الفحوصات بصفة مدير الجودة ونقلها لمدير المصنع',
      category: categoryApprovals,
      icon: Icons.verified_rounded,
    ),
    SystemPermissionDef(
      code: approveQSupervisor,
      title: 'اعتماد مشرف الجودة',
      description: 'المراجعة والاعتماد المبدئي للتقارير قبل رفعها لمدير الجودة',
      category: categoryApprovals,
      icon: Icons.policy_rounded,
    ),
    SystemPermissionDef(
      code: approveGM,
      title: 'اعتماد مدير المصنع (الاعتماد النهائي)',
      description: 'الموافقة النهائية على تقارير الجودة وإصدار شهادة المطابقة',
      category: categoryApprovals,
      icon: Icons.verified_user_rounded,
    ),
    SystemPermissionDef(
      code: rejectReports,
      title: 'رفض التقارير وإعادتها',
      description: 'رفض فحص غير مطابق مع تسجيل ملاحظات الرفض الإلزامية',
      category: categoryApprovals,
      icon: Icons.cancel_outlined,
    ),

    // 3. التقارير الديناميكية
    SystemPermissionDef(
      code: designDynamicReports,
      title: 'تصميم وبناء قوالب التقارير',
      description: 'إنشاء وتعديل هياكل التقارير الديناميكية وتحديد حقولها',
      category: categoryDynamic,
      icon: Icons.dashboard_customize_rounded,
    ),

    // 4. سلامة الغذاء والصحة
    SystemPermissionDef(
      code: deptFoodSafety,
      title: 'تفعيل قسم سلامة الغذاء والصحة',
      description: 'إظهار قسم سلامة الغذاء والصحة وجميع تقاريره للمستخدم',
      category: categoryFoodSafety,
      icon: Icons.health_and_safety_rounded,
    ),
    SystemPermissionDef(
      code: enabledHygiene,
      title: 'تفعيل تقرير النظافة',
      description: 'السماح بالوصول لتقرير النظافة والاشتراطات الصحية اليومية',
      category: categoryFoodSafety,
      icon: Icons.cleaning_services_outlined,
    ),
    SystemPermissionDef(
      code: fillHygiene,
      title: 'تعبئة تقرير النظافة والاشتراطات',
      description: 'إدخال وتعبئة سجلات تقرير النظافة اليومية',
      category: categoryFoodSafety,
      icon: Icons.edit_note_rounded,
    ),
    SystemPermissionDef(
      code: viewHygiene,
      title: 'عرض تقارير النظافة والاشتراطات',
      description: 'استعراض سجلات تقرير النظافة والاشتراطات',
      category: categoryFoodSafety,
      icon: Icons.visibility_outlined,
    ),
    SystemPermissionDef(
      code: printHygiene,
      title: 'طباعة تقرير النظافة والاشتراطات',
      description: 'طباعة وتصدير PDF لتقرير النظافة والاشتراطات',
      category: categoryFoodSafety,
      icon: Icons.print_outlined,
    ),
    SystemPermissionDef(
      code: fillHealthReports,
      title: 'تعبئة نماذج سلامة الغذاء',
      description:
          'إدخال بيانات فحوصات النظافة، درجات الحرارة، المواد الكيميائية، الصحة البدنية والمصائد',
      category: categoryFoodSafety,
      icon: Icons.edit_note_rounded,
    ),
    SystemPermissionDef(
      code: viewHealthReports,
      title: 'استعراض تقارير سلامة الغذاء',
      description:
          'مشاهدة سجلات ونتائج فحوصات سلامة الغذاء دون إدخال أو تعديل البيانات',
      category: categoryFoodSafety,
      icon: Icons.visibility_rounded,
    ),

    // 5. العمليات والورديات
    SystemPermissionDef(
      code: viewShifts,
      title: 'استعراض الورديات وجداول العمل',
      description: 'مشاهدة جداول الورديات والمصانع دون تعديلها',
      category: categoryOperations,
      icon: Icons.access_time_rounded,
    ),
    SystemPermissionDef(
      code: manageShifts,
      title: 'إدارة الورديات والمصانع',
      description: 'إضافة وتعديل وحذف الورديات وبيانات المصانع',
      category: categoryOperations,
      icon: Icons.edit_calendar_rounded,
    ),

    // 6. إدارة النظام والأمان
    SystemPermissionDef(
      code: manageUsers,
      title: 'إدارة حسابات المستخدمين',
      description: 'إضافة وتعديل وتعطيل حسابات الموظفين وتعيين كلمات المرور',
      category: categoryAdmin,
      icon: Icons.people_alt_rounded,
    ),
    SystemPermissionDef(
      code: manageRoles,
      title: 'إدارة الأدوار والصلاحيات المخصصة',
      description: 'إنشاء أدوار وظيفية جديدة وتخصيص صلاحياتها بدقة',
      category: categoryAdmin,
      icon: Icons.security_rounded,
    ),
    SystemPermissionDef(
      code: exportPdf,
      title: 'طباعة وتصدير التقارير (PDF)',
      description: 'تصدير التقارير الرسمية وحفظها ومشاركتها كملفات PDF',
      category: categoryAdmin,
      icon: Icons.picture_as_pdf_rounded,
    ),
    SystemPermissionDef(
      code: manageSettings,
      title: 'إدارة إعدادات المصنع والمعايير',
      description: 'تعديل المعايير القياسية، الفروع، والورديات',
      category: categoryAdmin,
      icon: Icons.settings_applications_rounded,
    ),
    SystemPermissionDef(
      code: manageProducts,
      title: 'إدارة العبوات وربطها بالمصانع',
      description:
          'إضافة وتعديل أحجام العبوات وتخصيص المصنع الذي تنتمي إليه كل عبوة',
      category: categoryOperations,
      icon: Icons.water_drop_rounded,
    ),
    SystemPermissionDef(
      code: manageDailyWorkers,
      title: 'إدارة سجل العمالة اليومية',
      description:
          'إضافة وتعديل وإيقاف العمال اليوميين وربطهم بالمصانع (مرجع الاقتراحات في فحص النظافة)',
      category: categoryOperations,
      icon: Icons.engineering_rounded,
    ),
    SystemPermissionDef(
      code: viewDailyWorkersCommitment,
      title: 'لوحة التزام وأداء العمالة والورديات',
      description:
          'الاطلاع على تقارير حضور العمالة اليومية وتفاصيل الورديات ومستوى التزامهم المشتق من تقارير النظافة',
      category: categoryOperations,
      icon: Icons.analytics_outlined,
    ),
    SystemPermissionDef(
      code: viewFactoryComplianceReport,
      title: 'تحليل ومتابعة التزام المصانع بالفحوصات',
      description:
          'الاطلاع على تقرير التزام المصانع اليومي بالفحوصات والتقارير المنفذة والمتخلفة وعدد التكرار',
      category: categoryOperations,
      icon: Icons.fact_check_rounded,
    ),
    SystemPermissionDef(
      code: manageSignature,
      title: 'إظهار نافذة التوقيع الرقمي المعتمد',
      description:
          'فتح نافذة رسم أو رفع صورة التوقيع الرقمي المعتمد للتوقيع على التقارير',
      category: categoryAdmin,
      icon: Icons.draw_rounded,
    ),
    SystemPermissionDef(
      code: changePassword,
      title: 'إظهار نافذة تغيير كلمة المرور',
      description:
          'فتح نافذة تحديث كلمة مرور حساب المستخدم الخاص للدخول للنظام',
      category: categoryAdmin,
      icon: Icons.password_rounded,
    ),
  ];

  static SystemPermissionDef? getDef(String code) {
    try {
      return all.firstWhere((p) => p.code == code);
    } catch (_) {
      return null;
    }
  }

  /// يُرجع صلاحية التعبئة الديناميكية المناسبة لفئة التقرير
  static String dynamicFillPermissionForCategory(int? categoryId) {
    return categoryId == 2
        ? fillFoodSafetyDynamicReports
        : fillQualityDynamicReports;
  }

  /// يتحقق إن كان المستخدم يملك صلاحية تعبئة تقرير ديناميكي حسب فئته
  static bool canFillDynamicInCategory(
    int? categoryId,
    List<String> permissions,
  ) {
    return permissions.contains(dynamicFillPermissionForCategory(categoryId));
  }

  /// ترحيل صلاحيات الأدوار المخزنة من الإصدارات السابقة إلى الصلاحيات الواسعة الجديدة.
  /// القاعدة: كل صلاحية قديمة كانت تمنح ضمناً تُفتح لمالكيها تلقائياً.
  static const Map<String, List<String>> legacyMigrationMap = {
    // الصلاحية الموحَّدة القديمة تُفكَّك إلى صلاحيتي التعبئة والاستعراض
    legacyManageHealthAffairs: [fillHealthReports, viewHealthReports],
    manageSettings: [viewShifts, manageShifts, manageProducts],
    // تقسيم صلاحية التعبئة الديناميكية الموحَّدة إلى صلاحيتين حسب القسم
    fillDynamicReports: [
      fillQualityDynamicReports,
      fillFoodSafetyDynamicReports,
    ],
  };

  /// يعالج الأدوار النظامية التي حُفظت قبل فصل قسمي الجودة وسلامة الغذاء.
  /// لا يُطبّق على الأدوار المخصصة حتى لا تُغيّر صلاحيات تم إعدادها يدوياً.
  static List<String> removeCrossDepartmentPermissionsForSystemRole(
    String roleCode,
    List<String> permissions,
  ) {
    final cleaned = <String>{...permissions};
    switch (roleCode.trim().toLowerCase()) {
      case 'quality_specialist':
        cleaned.removeAll([
          createHygieneReports,
          fillHealthReports,
          viewHealthReports,
          fillFoodSafetyDynamicReports,
        ]);
        break;
      case 'quality_manager':
        // التنظيف الترحيلي: إزالة أي صلاحيات سلامة الغذاء عالقة من إصدارات قديمة
        // (create_hygiene_reports كانت تُمنح لمدير الجودة قبل حصرها بسلامة الغذاء).
        cleaned.removeAll([
          createHygieneReports,
          fillHealthReports,
          viewHealthReports,
          fillFoodSafetyDynamicReports,
        ]);
        break;
      case 'food_safety_engineer':
        cleaned.removeAll([
          createWaterReports,
          createRawMaterialReports,
          viewReports,
          fillQualityDynamicReports,
        ]);
        break;
    }
    return cleaned.toList();
  }

  /// توسيع قائمة صلاحيات دور مخزن بأكواد الصلاحيات الجديدة المشتقة من القديمة
  static List<String> migratePermissions(List<String> current) {
    final expanded = <String>{...current};
    if (current.isNotEmpty) {
      expanded.addAll([manageSignature, changePassword]);
    }
    for (final entry in legacyMigrationMap.entries) {
      if (current.contains(entry.key)) {
        expanded.addAll(entry.value);
      }
    }

    // ترحيل الإصدار v10 لمصفوفة التقارير التفصيلية
    if (current.contains(createWaterReports)) {
      expanded.addAll([
        deptQuality,
        fillFinalProduct,
        viewFinalProduct,
        printFinalProduct,
        enabledFinalProduct,
        fillRawWater,
        viewRawWater,
        printRawWater,
        enabledRawWater,
      ]);
    }
    if (current.contains(createRawMaterialReports)) {
      expanded.addAll([
        deptQuality,
        fillRawMaterial,
        viewRawMaterial,
        printRawMaterial,
        enabledRawMaterial,
      ]);
    }
    if (current.contains(createHygieneReports) ||
        current.contains(fillHealthReports)) {
      expanded.addAll([
        deptFoodSafety,
        fillHygiene,
        viewHygiene,
        printHygiene,
        enabledHygiene,
      ]);
    }
    if (current.contains(viewReports)) {
      expanded.addAll([
        deptQuality,
        viewFinalProduct,
        viewRawWater,
        viewRawMaterial,
        enabledFinalProduct,
        enabledRawWater,
        enabledRawMaterial,
      ]);
    }
    if (current.contains(viewHealthReports)) {
      expanded.addAll([deptFoodSafety, viewHygiene, enabledHygiene]);
    }
    if (current.contains(exportPdf)) {
      if (expanded.contains(enabledFinalProduct)) {
        expanded.add(printFinalProduct);
      }
      if (expanded.contains(enabledRawWater)) {
        expanded.add(printRawWater);
      }
      if (expanded.contains(enabledRawMaterial)) {
        expanded.add(printRawMaterial);
      }
      if (expanded.contains(enabledHygiene)) {
        expanded.add(printHygiene);
      }
    }

    // ترحيل الإصدار v11: إضافة صلاحية متابعة التزام المصانع للأدوار القيادية
    if (current.contains(manageDailyWorkers) ||
        current.contains(manageRoles) ||
        current.contains(approveQM) ||
        current.contains(approveGM)) {
      expanded.add(viewDailyWorkersCommitment);
      expanded.add(viewFactoryComplianceReport);
    }
    
    // ترحيل الإصدار v12: إعطاء صلاحية اعتماد المشرف لمدير الجودة تلقائياً
    if (current.contains(approveQM)) {
      expanded.add(approveQSupervisor);
    }

    final validCodes = all.map((p) => p.code).toSet();
    return expanded
        .where(
          (code) =>
              validCodes.contains(code) ||
              code.startsWith('fill_dyn_rpt_') ||
              code.startsWith('view_dyn_rpt_') ||
              code.startsWith('print_dyn_rpt_') ||
              code.startsWith('enabled_dyn_rpt_'),
        )
        .toList();
  }
}

/// نموذج الدور الوظيفي (أساسي أو مخصص)
class RoleModel {
  final int? id;
  final String code;
  final String title;
  final String? description;
  final int color;
  final String iconName;
  final List<String> permissions;
  final bool isSystem;
  final DateTime? createdAt;

  RoleModel({
    this.id,
    required this.code,
    required this.title,
    this.description,
    required this.color,
    this.iconName = 'security',
    required this.permissions,
    this.isSystem = false,
    this.createdAt,
  });

  bool hasPermission(String permCode) {
    return permissions.contains(permCode);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code.toLowerCase().trim(),
      'title': title.trim(),
      'description': description?.trim(),
      'color': color,
      'icon_name': iconName,
      'permissions_json': jsonEncode(permissions),
      'permissionsJson': jsonEncode(permissions),
      'is_system': isSystem ? 1 : 0,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory RoleModel.fromMap(Map<String, dynamic> map) {
    List<String> perms = [];
    final permJsonStr = map['permissions_json'] ?? map['permissionsJson'];
    if (permJsonStr != null) {
      try {
        final decoded = jsonDecode(permJsonStr);
        if (decoded is List) {
          perms = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return RoleModel(
      id: map['id'],
      code: map['code'] ?? '',
      title: map['title'] ?? 'دور غير مسمى',
      description: map['description'],
      color:
          map['color'] != null
              ? (map['color'] as num).toInt()
              : const Color(0xFF007791).toARGB32(),
      iconName: map['icon_name'] ?? map['iconName'] ?? 'security',
      permissions: perms,
      isSystem: (map['is_system'] == 1 || map['is_system'] == true) || (map['isSystem'] == 1 || map['isSystem'] == true),
      createdAt:
          map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : (map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null),
    );
  }

  RoleModel copyWith({
    int? id,
    String? code,
    String? title,
    String? description,
    int? color,
    String? iconName,
    List<String>? permissions,
    bool? isSystem,
    DateTime? createdAt,
  }) {
    return RoleModel(
      id: id ?? this.id,
      code: code ?? this.code,
      title: title ?? this.title,
      description: description ?? this.description,
      color: color ?? this.color,
      iconName: iconName ?? this.iconName,
      permissions: permissions ?? this.permissions,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// تحويل اسم الأيقونة إلى IconData
  IconData get iconData {
    switch (iconName) {
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'gmanager':
        return Icons.supervisor_account_rounded;
      case 'qm':
      case 'verified':
        return Icons.verified_user_rounded;
      case 'gm':
      case 'business':
        return Icons.business_center_rounded;
      case 'inspector':
      case 'science':
        return Icons.science_rounded;
      case 'foodsafety':
      case 'health':
        return Icons.health_and_safety_rounded;
      case 'water':
        return Icons.water_drop_rounded;
      case 'badge':
        return Icons.badge_rounded;
      case 'supervisor':
        return Icons.supervisor_account_rounded;
      case 'work':
        return Icons.engineering_rounded;
      default:
        return Icons.security_rounded;
    }
  }

  /// الأدوار الافتراضية الأساسية للنظام
  static List<RoleModel> get defaultSystemRoles => [
    RoleModel(
      code: 'admin',
      title: 'مسؤول النظام (المدير التقني)',
      description: 'كامل الصلاحيات الفنية والإدارية وإدارة المستخدمين والأدوار',
      color: const Color(0xFF37474F).toARGB32(),
      iconName: 'admin',
      permissions: SystemPermissions.all.map((p) => p.code).toList(),
      isSystem: true,
    ),
    RoleModel(
      code: 'general_manager',
      title: 'المدير العام',
      description: 'أعلى سلطة في الشركة، صلاحيات شاملة واستعراض كل المصانع',
      color: const Color(0xFF0D47A1).toARGB32(),
      iconName: 'gmanager',
      permissions: SystemPermissions.all.map((p) => p.code).toList(),
      isSystem: true,
    ),
    RoleModel(
      code: 'quality_manager',
      title: 'مدير الجودة',
      description: 'إدخال الفحوصات، اعتماد المستوى الأول QM، وتصميم النماذج',
      color: const Color(0xFF2E7D32).toARGB32(),
      iconName: 'qm',
      permissions: [
        SystemPermissions.deptQuality,
        SystemPermissions.enabledFinalProduct,
        SystemPermissions.fillFinalProduct,
        SystemPermissions.viewFinalProduct,
        SystemPermissions.printFinalProduct,
        SystemPermissions.enabledRawWater,
        SystemPermissions.fillRawWater,
        SystemPermissions.viewRawWater,
        SystemPermissions.printRawWater,
        SystemPermissions.enabledRawMaterial,
        SystemPermissions.fillRawMaterial,
        SystemPermissions.viewRawMaterial,
        SystemPermissions.printRawMaterial,
        SystemPermissions.createWaterReports,
        SystemPermissions.createRawMaterialReports,
        SystemPermissions.fillQualityDynamicReports,
        SystemPermissions.viewReports,
        SystemPermissions.editReports,
        SystemPermissions.approveQSupervisor,
        SystemPermissions.approveQM,
        SystemPermissions.rejectReports,
        SystemPermissions.designDynamicReports,
        SystemPermissions.viewShifts,
        SystemPermissions.manageProducts,
        SystemPermissions.manageDailyWorkers,
        SystemPermissions.viewDailyWorkersCommitment,
        SystemPermissions.viewFactoryComplianceReport,
        SystemPermissions.exportPdf,
        SystemPermissions.manageSignature,
        SystemPermissions.changePassword,
      ],
      isSystem: true,
    ),
    RoleModel(
      code: 'factory_manager',
      title: 'مدير المصنع',
      description: 'استعراض التقارير والاعتماد النهائي GM وتصدير الوثائق',
      color: const Color(0xFF6A1B9A).toARGB32(),
      iconName: 'gm',
      permissions: [
        SystemPermissions.deptQuality,
        SystemPermissions.deptFoodSafety,
        SystemPermissions.enabledFinalProduct,
        SystemPermissions.viewFinalProduct,
        SystemPermissions.printFinalProduct,
        SystemPermissions.enabledRawWater,
        SystemPermissions.viewRawWater,
        SystemPermissions.printRawWater,
        SystemPermissions.enabledRawMaterial,
        SystemPermissions.viewRawMaterial,
        SystemPermissions.printRawMaterial,
        SystemPermissions.enabledHygiene,
        SystemPermissions.viewHygiene,
        SystemPermissions.printHygiene,
        SystemPermissions.viewReports,
        SystemPermissions.approveGM,
        SystemPermissions.rejectReports,
        SystemPermissions.viewHealthReports,
        SystemPermissions.viewShifts,
        SystemPermissions.manageDailyWorkers,
        SystemPermissions.viewDailyWorkersCommitment,
        SystemPermissions.viewFactoryComplianceReport,
        SystemPermissions.exportPdf,
        SystemPermissions.manageSignature,
        SystemPermissions.changePassword,
      ],
      isSystem: true,
    ),
    RoleModel(
      code: 'quality_specialist',
      title: 'أخصائي الجودة / منفذ الفحص',
      description: 'إدخال قراءات وفحوصات المياه وتعبئة السجلات اليومية',
      color: const Color(0xFF007791).toARGB32(),
      iconName: 'inspector',
      permissions: [
        SystemPermissions.deptQuality,
        SystemPermissions.enabledFinalProduct,
        SystemPermissions.fillFinalProduct,
        SystemPermissions.viewFinalProduct,
        SystemPermissions.printFinalProduct,
        SystemPermissions.enabledRawWater,
        SystemPermissions.fillRawWater,
        SystemPermissions.viewRawWater,
        SystemPermissions.printRawWater,
        SystemPermissions.enabledRawMaterial,
        SystemPermissions.fillRawMaterial,
        SystemPermissions.viewRawMaterial,
        SystemPermissions.printRawMaterial,
        SystemPermissions.createWaterReports,
        SystemPermissions.createRawMaterialReports,
        SystemPermissions.fillQualityDynamicReports,
        SystemPermissions.viewReports,
        SystemPermissions.editReports,
        SystemPermissions.exportPdf,
        SystemPermissions.manageSignature,
        SystemPermissions.changePassword,
      ],
      isSystem: true,
    ),
    RoleModel(
      code: 'quality_supervisor',
      title: 'مشرف الجودة والرقابة',
      description: 'مراجعة التقارير المرفوعة من الأخصائي واعتمادها أولياً',
      color: const Color(0xFF00897B).toARGB32(),
      iconName: 'supervisor',
      permissions: [
        SystemPermissions.deptQuality,
        SystemPermissions.viewFinalProduct,
        SystemPermissions.viewRawWater,
        SystemPermissions.viewRawMaterial,
        SystemPermissions.viewReports,
        SystemPermissions.approveQSupervisor,
        SystemPermissions.rejectReports,
        SystemPermissions.exportPdf,
        SystemPermissions.manageSignature,
        SystemPermissions.changePassword,
      ],
      isSystem: true,
    ),
    RoleModel(
      code: 'food_safety_engineer',
      title: 'مهندس سلامة الغذاء',
      description:
          'تعبئة نماذج سلامة الغذاء والنظافة وتقارير المواد الخام ومراجعتها',
      color: const Color(0xFFE65100).toARGB32(),
      iconName: 'foodsafety',
      permissions: [
        SystemPermissions.deptFoodSafety,
        SystemPermissions.enabledHygiene,
        SystemPermissions.fillHygiene,
        SystemPermissions.viewHygiene,
        SystemPermissions.printHygiene,
        SystemPermissions.createHygieneReports,
        SystemPermissions.fillFoodSafetyDynamicReports,
        SystemPermissions.editReports,
        SystemPermissions.fillHealthReports,
        SystemPermissions.viewHealthReports,
        SystemPermissions.viewDailyWorkersCommitment,
        SystemPermissions.viewFactoryComplianceReport,
        SystemPermissions.exportPdf,
        SystemPermissions.manageSignature,
        SystemPermissions.changePassword,
      ],
      isSystem: true,
    ),
  ];
}
