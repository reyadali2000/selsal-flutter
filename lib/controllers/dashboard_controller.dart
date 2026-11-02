import '../controllers/raw_water_report_display_controller.dart';
import '../controllers/final_product_report_display_controller.dart';
import '../services/api/water_quality_api_service.dart';
import '../models/water_quality_models.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../constants/approval_status.dart';
import '../services/database_helper.dart';
import '../services/dashboard_sync_service.dart';
import '../services/api/dynamic_reports_api_service.dart';
import '../services/user_session_service.dart';
import '../services/user_signature_service.dart';
import '../services/factory_shifts_service.dart';
import '../models/branch_model.dart';
import '../routes/app_routes.dart';
import '../views/raw_water_report_display_view.dart';
import '../views/final_product_report_display_view.dart';
import '../views/hygiene_report_display_view.dart';
import '../views/raw_material_report_display_view.dart';
import '../views/dynamic_report_display_view.dart';
import '../utils/executive_dashboard_pdf_generator.dart';

class DashboardController extends GetxController {
  var totalSamples = 0.obs;
  var compliantSamples = 0.obs;
  var complianceRate = 0.0.obs;
  var isLoading = true.obs;

  // Multi-Factory Branches & Active Shift
  var selectedBranchId = 0.obs; // 0 = كافة المصانع, 1 = مصنع أرتل, 2 = مصنع سنحان
  var branches = <BranchModel>[].obs;
  var activeShift = Rxn<ShiftModel>();
  var activeShiftName = 'الوردية الأولى (الصباحية)'.obs;
  var activeShiftTime = '06:00 ص - 02:00 م'.obs;
  var currentSeasonName = 'التوقيت الصيفي'.obs;
  var factoryComparison = <Map<String, dynamic>>[].obs;
  var shiftsList = <Map<String, dynamic>>[].obs;

  // Pending Approvals & Action Center
  var pendingApprovalsCount = 0.obs;
  var pendingItems = <Map<String, dynamic>>[].obs;

  // Corrective Actions (دورة الإجراء التصحيحي لمدير المصنع)
  var correctiveActionCount = 0.obs;
  var correctiveActionItems = <Map<String, dynamic>>[].obs;

  // Dynamic Reports Metrics
  var dynamicReportsCount = 0.obs;
  var dynamicRecordsCount = 0.obs;
  var dynamicApprovedCount = 0.obs;
  var dynamicPendingCount = 0.obs;
  var dynamicRejectedCount = 0.obs;

  // Phase 2: 7-Day Performance & Trends
  var weeklyDays = <Map<String, dynamic>>[].obs;
  var weeklyMaxCount = 1.obs;
  var weeklyTrendPercentage = 0.0.obs;
  var thisWeekTotal = 0.obs;

  // Phase 2: Shift Distribution
  var shift1Count = 0.obs;
  var shift2Count = 0.obs;
  var shift3Count = 0.obs;

  // Phase 2: Outliers & Recent Activities
  var nonCompliantLogs = <Map<String, dynamic>>[].obs;
  var recentActivities = <Map<String, dynamic>>[].obs;

  // Phase 3: Timeframe Filter & Key Parameters Gauge
  var selectedTimeframe = 'all'.obs; // 'today', 'week', 'month', 'all'
  var keyParameters = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<UserSessionService>()) {
      if (UserSessionService.to.isBranchRestricted) {
        selectedBranchId.value = UserSessionService.to.assignedBranchId!;
      }
      ever(UserSessionService.to.currentUser, (_) {
        if (UserSessionService.to.isBranchRestricted) {
          selectedBranchId.value = UserSessionService.to.assignedBranchId!;
        }
        loadStats();
      });
      ever(UserSessionService.to.currentRole, (_) {
        if (UserSessionService.to.isBranchRestricted) {
          selectedBranchId.value = UserSessionService.to.assignedBranchId!;
        }
        loadStats();
      });
    }

    loadBranches();
    loadStats();
  }

  Future<void> loadBranches() async {
    try {
      final list = await FactoryShiftsService.instance.getAllBranches();
      branches.assignAll(list);
    } catch (_) {}
  }

  void switchBranch(int branchId) {
    if (Get.isRegistered<UserSessionService>() && UserSessionService.to.isBranchRestricted) {
      selectedBranchId.value = UserSessionService.to.assignedBranchId!;
      loadStats();
      return;
    }
    if (selectedBranchId.value != branchId) {
      selectedBranchId.value = branchId;
      loadStats();
    }
  }

  void changeTimeframe(String tf) {
    if (selectedTimeframe.value != tf) {
      selectedTimeframe.value = tf;
      loadStats();
    }
  }

  Future<void> loadStats({bool silent = false}) async {
    if (!silent) isLoading.value = true;
    try {
      final db = DatabaseHelper.instance;
      final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
      final int? branchId = (session != null && session.isBranchRestricted)
          ? session.assignedBranchId
          : (selectedBranchId.value > 0 ? selectedBranchId.value : null);

      // مزامنة أحدث الفحوصات والبيانات من السيرفر قبل استخراج الإحصائيات
      await DashboardSyncService.instance.syncAllDashboardData(branchId: branchId);

      // تُحمَّل فقط الأقسام التي يملك المستخدم صلاحية رؤيتها أو تصديرها
      final canViewQuality = session?.canViewReports ?? false;
      final canViewAnyReports = canViewQuality || (session?.canViewHealthReports ?? false);
      final canApproveFlow = (session?.canApproveQM ?? false) ||
          (session?.canApproveGM ?? false) ||
          (session?.canRejectReports ?? false) ||
          (session?.canEditReports ?? false);
      final canShifts = (session?.canViewShifts ?? false) || (session?.canManageShifts ?? false);
      final canDynamic = (session?.canFillDynamicReports ?? false) ||
          (session?.canDesignDynamicReports ?? false);
      final canExport = session?.canExportPdf ?? false;

      // 1. Water Quality Log Stats
      if (canViewAnyReports || canExport) {
        final stats = await db.getDashboardStats(
          timeframe: selectedTimeframe.value,
          branchId: branchId,
        );
        totalSamples.value = stats['totalSamples'] as int;
        compliantSamples.value = stats['compliantSamples'] as int;
        complianceRate.value = stats['complianceRate'] as double;
      }

      // 2. Dynamic Reports Stats
      if (canViewAnyReports || canDynamic || canExport) {
        final dynStats = await DynamicReportsApiService.to.getDynamicReportStats(
          timeframe: selectedTimeframe.value,
          branchId: branchId,
        );
        dynamicReportsCount.value = dynStats['totalReports'] ?? 0;
        dynamicRecordsCount.value = dynStats['totalRecords'] ?? 0;
        dynamicApprovedCount.value = dynStats['approvedRecords'] ?? 0;
        dynamicPendingCount.value = (dynStats['pendingQM'] ?? 0) + (dynStats['pendingGM'] ?? 0);
        dynamicRejectedCount.value = dynStats['rejectedRecords'] ?? 0;
      }

      // 3. Key Parameters Gauges
      if (canViewQuality || canExport) {
        keyParameters.assignAll(await db.getLatestKeyParameters(branchId: branchId));
      }

      // 4. 7-Day Performance & Trends
      if (canViewQuality || canShifts || canExport) {
        final weekly = await db.getWeeklyDailyStats(branchId: branchId);
        weeklyDays.assignAll((weekly['days'] as List).map((e) => Map<String, dynamic>.from(e)).toList());
        weeklyMaxCount.value = weekly['maxCount'] as int;
        weeklyTrendPercentage.value = (weekly['trendPercentage'] as num).toDouble();
        thisWeekTotal.value = weekly['thisWeekTotal'] as int;
      }

      // 5. Shift Distribution
      if (canShifts || canExport) {
        final shifts = await db.getShiftDistribution(branchId: branchId);
        shift1Count.value = shifts['shift1'] ?? 0;
        shift2Count.value = shifts['shift2'] ?? 0;
        shift3Count.value = shifts['shift3'] ?? 0;
        if (shifts['shiftsList'] != null) {
          shiftsList.assignAll((shifts['shiftsList'] as List).map((e) => Map<String, dynamic>.from(e)).toList());
        }
      }

      // 6. Outliers and Recent Activities
      if (canViewAnyReports || canExport || (session?.isFactoryManager ?? false)) {
        nonCompliantLogs.assignAll(await db.getNonCompliantLogs(branchId: branchId));

        final canWater = (session?.canViewReports ?? false) ||
            (session?.canCreateWaterReports ?? false) ||
            (session?.isAdmin ?? false) ||
            (session?.isGeneralManager ?? false) ||
            (session?.isFactoryManager ?? false);
        final canHygiene = (session?.canViewHealthReports ?? false) ||
            (session?.canCreateHygieneReports ?? false) ||
            (session?.isAdmin ?? false) ||
            (session?.isGeneralManager ?? false) ||
            (session?.isFactoryManager ?? false);
        final canRawMaterial = (session?.canViewReports ?? false) ||
            (session?.canCreateRawMaterialReports ?? false) ||
            (session?.isAdmin ?? false) ||
            (session?.isGeneralManager ?? false) ||
            (session?.isFactoryManager ?? false);

        final List<int>? allowedCategories = (session != null && !session.isAdmin && !session.isGeneralManager && !session.isFactoryManager)
            ? [
                if (session.isDepartmentEnabled(1)) 1,
                if (session.isDepartmentEnabled(2)) 2,
              ]
            : null;

        final rawActivities = await db.getRecentActivities(
          branchId: branchId,
          includeWater: canWater,
          includeHygiene: canHygiene,
          includeRawMaterial: canRawMaterial,
          includeDynamic: canDynamic || (session?.isFactoryManager ?? false),
          allowedCategoryIds: allowedCategories,
        );

        // فلترة دقيقة إضافية للتأكد من حظر أي سجل لا يملك المستخدم صلاحية استعراضه
        final filtered = rawActivities.where((item) {
          if (session == null) return true;
          final bId = item['branch_id'] as int?;
          if (!session.canViewBranchData(bId)) return false;

          final itemType = item['type']?.toString();
          if (itemType == 'dynamic') {
            final rptId = item['report_id'] as int?;
            final catId = item['category_id'] as int?;
            return session.canViewDynamicReport(rptId, catId);
          } else if (itemType == 'hygiene') {
            return session.canViewHygiene || session.isFactoryManager;
          } else if (itemType == 'raw_material') {
            return session.canViewRawMaterial || session.isFactoryManager;
          } else {
            return session.canViewRawWater || session.canViewFinalProduct || session.isFactoryManager;
          }
        }).toList();

        recentActivities.assignAll(filtered);
      }

      // 7. Factory Comparison Stats (when All factories selected)
      if (canViewQuality) {
        factoryComparison.assignAll(await db.getFactoryComparisonStats());
      }

      // 8. Active Shift for Selected Factory
      final targetBranchForShift = selectedBranchId.value > 0 ? selectedBranchId.value : 1;
      final liveShift = await FactoryShiftsService.instance.getActiveShiftNow(targetBranchForShift);
      activeShift.value = liveShift;
      if (liveShift != null) {
        activeShiftName.value = liveShift.name;
        activeShiftTime.value = liveShift.formattedDisplayTime;
        currentSeasonName.value = liveShift.seasonName;
      }

      // 9. Role-based Pending Approvals — للمعتمدين ومن يصحّح التقارير المرفوضة فقط
      if (canApproveFlow) {
        List<String> roleApprovalStatuses = ['Pending_QM'];
        String? microApprovalStatus;
        if (Get.isRegistered<UserSessionService>()) {
          final role = UserSessionService.to.currentRole.value;
          if (role == UserRole.qualitySupervisor) {
            roleApprovalStatuses = ['Pending_QS'];
          } else if (role == UserRole.qualityManager) {
            roleApprovalStatuses = ['Pending_QM'];
            microApprovalStatus = 'Pending_Micro_QM';
          } else if (role == UserRole.factoryManager) {
            roleApprovalStatuses = ['Pending_GM', 'Pending_GM_Decision'];
            microApprovalStatus = 'Pending_Micro_GM';
          } else {
            roleApprovalStatuses = ['Rejected', 'Corrective_In_Progress'];
          }
        }

        final canWater = (session?.isAdmin ?? false) || (session?.isGeneralManager ?? false) || (session?.canViewReports ?? false) || (session?.canCreateWaterReports ?? false) || (session?.canApproveQM ?? false) || (session?.canApproveGM ?? false);
        final canHygiene = (session?.isAdmin ?? false) || (session?.isGeneralManager ?? false) || (session?.canViewHealthReports ?? false) || (session?.canCreateHygieneReports ?? false) || (session?.canApproveQM ?? false) || (session?.canApproveGM ?? false);
        final canRawMaterial = (session?.isAdmin ?? false) || (session?.isGeneralManager ?? false) || (session?.canViewReports ?? false) || (session?.canCreateRawMaterialReports ?? false) || (session?.canApproveQM ?? false) || (session?.canApproveGM ?? false);

        int totalStatic = 0;
        int totalDynamic = 0;
        final combined = <Map<String, dynamic>>[];
        final seenKeys = <String>{};

        for (final st in roleApprovalStatuses) {
          final microSt = (st == 'Pending_QM' || st == 'Pending_GM') ? microApprovalStatus : null;
          final sCount = await db.getQualityLogsPendingCount(
            st,
            branchId: branchId,
            microStatus: microSt,
            includeWater: canWater,
            includeHygiene: canHygiene,
            includeRawMaterial: canRawMaterial,
          );
          totalStatic += sCount;

          final dynRecords = await DynamicReportsApiService.to.getPendingRecordsForRole(st, branchId: branchId);

          for (var r in dynRecords) {
            final rptId = r['report_id'] as int?;
            final catId = r['category_id'] as int?;
            final recBranch = r['branch_id'] as int?;
            if (session != null && !session.canViewBranchData(recBranch)) continue;
            if (session != null && !session.canViewDynamicReport(rptId, catId)) continue;

            totalDynamic++;
            final key = 'dynamic_${r['record_id']}';
            if (!seenKeys.contains(key)) {
              seenKeys.add(key);
              combined.add({
                'id': r['record_id'],
                'report_id': r['report_id'],
                'category_id': r['category_id'],
                'branch_id': r['branch_id'],
                'type': 'dynamic',
                'title': '${r['report_name']} #${r['record_id']}',
                'created_at': r['created_at'],
                'created_by': r['created_by'],
                'approval_status': r['approval_status'],
              });
            }
          }

          final staticList = await db.getPendingLogsForRole(
            st,
            branchId: branchId,
            microStatus: microSt,
            includeWater: canWater,
            includeHygiene: canHygiene,
            includeRawMaterial: canRawMaterial,
          );
          for (var l in staticList) {
            final recBranch = l['branch_id'] as int?;
            if (session != null && !session.canViewBranchData(recBranch)) continue;
            final key = '${l['type']}_${l['id']}';
            if (!seenKeys.contains(key)) {
              seenKeys.add(key);
              combined.add(l);
            }
          }
        }

        pendingApprovalsCount.value = totalStatic + totalDynamic;
        pendingItems.assignAll(combined);
      } else {
        pendingApprovalsCount.value = 0;
        pendingItems.clear();
      }

      // 10. Corrective Actions — بطاقة الإجراءات التصحيحية لمدير المصنع
      if (canApproveFlow) {
        final canWater = (session?.isAdmin ?? false) || (session?.isGeneralManager ?? false) || (session?.canViewReports ?? false) || (session?.canCreateWaterReports ?? false) || (session?.canApproveQM ?? false) || (session?.canApproveGM ?? false);
        final canHygiene = (session?.isAdmin ?? false) || (session?.isGeneralManager ?? false) || (session?.canViewHealthReports ?? false) || (session?.canCreateHygieneReports ?? false) || (session?.canApproveQM ?? false) || (session?.canApproveGM ?? false);
        final canRawMaterial = (session?.isAdmin ?? false) || (session?.isGeneralManager ?? false) || (session?.canViewReports ?? false) || (session?.canCreateRawMaterialReports ?? false) || (session?.canApproveQM ?? false) || (session?.canApproveGM ?? false);

        final legacyCorrective = await db.getCorrectiveActionLegacyReports(
          branchId: branchId,
          includeWater: canWater,
          includeHygiene: canHygiene,
          includeRawMaterial: canRawMaterial,
        );
        final dynamicCorrective = await DynamicReportsApiService.to.getCorrectiveActionRecords(branchId: branchId);

        final combinedCorrective = <Map<String, dynamic>>[];

        // السجلات الثابتة
        for (var item in legacyCorrective) {
          final recBranch = item['branch_id'] as int?;
          if (session != null && !session.canViewBranchData(recBranch)) continue;
          final status = item['approval_status']?.toString();
          if (status == 'Rejected_By_GM' || status == 'Closed' || status == 'Approved') continue;
          combinedCorrective.add({
            ...item,
            'source': 'legacy',
          });
        }

        // السجلات الديناميكية
        for (var r in dynamicCorrective) {
          final rptId = r['report_id'] as int?;
          final catId = r['category_id'] as int?;
          final recBranch = r['branch_id'] as int?;
          if (session != null && !session.canViewBranchData(recBranch)) continue;
          if (session != null && !session.canViewDynamicReport(rptId, catId)) continue;
          final status = r['approval_status']?.toString();
          if (status == 'Rejected_By_GM' || status == 'Closed' || status == 'Approved') continue;

          combinedCorrective.add({
            'id': r['record_id'],
            'type': 'dynamic',
            'category': 'Dynamic',
            'title': '${r['report_name'] ?? "تقرير"} #${r['record_id']}',
            'created_at': r['created_at'],
            'created_by': r['created_by'],
            'approval_status': r['approval_status'],
            'rejection_reason': r['rejection_reason'],
            'rejected_by': r['rejected_by'],
            'rejection_category': r['rejection_category'],
            'severity_level': r['severity_level'],
            'affected_products': r['affected_products'],
            'immediate_action': r['immediate_action'],
            'corrective_action': r['corrective_action'],
            'corrective_owner': r['corrective_owner'],
            'corrective_due_date': r['corrective_due_date'],
            'gm_decision': r['gm_decision'],
            'gm_decision_by': r['gm_decision_by'],
            'gm_decision_notes': r['gm_decision_notes'],
            'source': 'dynamic',
            'report_id': r['report_id'],
            'category_id': r['category_id'],
            'branch_id': r['branch_id'],
          });
        }

        // ترتيب حسب مستوى الخطورة ثم التاريخ
        combinedCorrective.sort((a, b) {
          final sevA = SeverityLevel.weight(a['severity_level'] as String? ?? '');
          final sevB = SeverityLevel.weight(b['severity_level'] as String? ?? '');
          if (sevA != sevB) return sevB.compareTo(sevA);
          final dateA = a['created_at'] as String? ?? '';
          final dateB = b['created_at'] as String? ?? '';
          return dateB.compareTo(dateA);
        });

        correctiveActionCount.value = combinedCorrective.length;
        correctiveActionItems.assignAll(combinedCorrective);
      } else {
        correctiveActionCount.value = 0;
        correctiveActionItems.clear();
      }
    } catch (e, stackTrace) {
      debugPrint('Dashboard loadStats error: $e\n$stackTrace');
      // لا نعرض إشعار منبثق مزعج للمستخدم إذا فشل قسم فرعي بل نسجله فقط
    } finally {
      if (!silent) isLoading.value = false;
    }
  }

  Future<void> openPendingItem(Map<String, dynamic> item) async {
    final type = item['type'];
    final id = item['id'] as int;
    final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;

    final itemBranch = item['branch_id'] as int?;
    if (session != null && !session.canViewBranchData(itemBranch)) {
      Get.snackbar(
        'غير مصرح',
        'غير مصرح لك بالاطلاع على سجلات تابعة لمصنع آخر.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    if (type == 'dynamic') {
      final rptId = item['report_id'] as int?;
      final catId = item['category_id'] as int?;
      if (session != null && !session.canViewDynamicReport(rptId, catId)) {
        Get.snackbar(
          'غير مصرح',
          'لا تملك صلاحية استعراض هذا النموذج الديناميكي.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        return;
      }
      if (Get.isRegistered<DynamicReportDisplayController>()) {
        Get.delete<DynamicReportDisplayController>();
      }
      await Get.toNamed(AppRoutes.dynamicReportDisplay, arguments: {
        'reportId': item['report_id'],
        'recordId': id,
      });
      loadStats();
    } else if (type == 'hygiene') {
      final canHygiene = session == null ||
          session.isAdmin ||
          session.isGeneralManager ||
          session.isFactoryManager ||
          session.isQualityManager ||
          session.canViewHealthReports ||
          session.canCreateHygieneReports ||
          session.canViewHygiene ||
          session.canApproveQM ||
          session.canApproveGM;

      if (!canHygiene) {
        Get.snackbar(
          'غير مصرح',
          'لا تملك صلاحية استعراض تقارير النظافة العامة.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        return;
      }
      await Get.to(() => HygieneReportDisplayView(reportId: id));
      loadStats();
    } else if (type == 'raw_material') {
      final canRm = session == null ||
          session.isAdmin ||
          session.isGeneralManager ||
          session.isFactoryManager ||
          session.isQualityManager ||
          session.canViewReports ||
          session.canCreateRawMaterialReports ||
          session.canViewRawMaterial ||
          session.canApproveQM ||
          session.canApproveGM;

      if (!canRm) {
        Get.snackbar(
          'غير مصرح',
          'لا تملك صلاحية استعراض تقارير فحص المواد الأولية.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        return;
      }
      await Get.to(() => RawMaterialReportDisplayView(reportId: id));
      loadStats();
    } else {
      // Water quality log
      final canWater = session == null ||
          session.isAdmin ||
          session.isGeneralManager ||
          session.isFactoryManager ||
          session.isQualityManager ||
          session.canViewReports ||
          session.canCreateWaterReports ||
          session.canViewRawWater ||
          session.canViewFinalProduct ||
          session.canApproveQM ||
          session.canApproveGM;

      if (!canWater) {
        Get.snackbar(
          'غير مصرح',
          'لا تملك صلاحية استعراض تقارير فحص جودة المياه.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        return;
      }

      WaterQualityLog? log;
      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          final apiData = await WaterQualityApiService.to.getLogById(id);
          if (apiData != null) {
            final logData = apiData['log'] is Map ? Map<String, dynamic>.from(apiData['log']) : apiData;
            log = WaterQualityLog.fromMap(logData);
          }
        } catch (_) {}
      }
      log ??= await DatabaseHelper.instance.getWaterQualityLogById(id);

      if (log != null) {
        final cat = item['category'];
        if (cat == 'Final Product') {
          if (Get.isRegistered<FinalProductReportDisplayController>()) {
            Get.delete<FinalProductReportDisplayController>();
          }
          await Get.to(() => FinalProductReportDisplayView(), arguments: log);
        } else if (cat == 'Raw Material') {
          await Get.to(() => RawMaterialReportDisplayView(reportId: id));
        } else {
          if (Get.isRegistered<RawWaterReportDisplayController>()) {
            Get.delete<RawWaterReportDisplayController>();
          }
          await Get.to(() => RawWaterReportDisplayView(), arguments: log);
        }
        loadStats();
      } else {
        Get.snackbar(
          'تنبيه',
          'تعذر العثور على بيانات التقرير المحدد.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange.shade800,
          colorText: Colors.white,
        );
      }
    }
  }

  /// حوار اختيار وتصدير التقرير التنفيذي اليومي
  bool get canExportOwnExecutiveReport {
    if (!Get.isRegistered<UserSessionService>()) return false;
    final role = UserSessionService.to.currentRole.value;
    return role == UserRole.factoryManager || role == UserRole.qualityManager;
  }

  bool _canExportExecutiveReportType(UserRole role, String type) {
    return (type == 'factory' && role == UserRole.factoryManager) ||
        (type == 'quality' && role == UserRole.qualityManager);
  }

  void _showExecutiveReportAccessDenied() {
    Get.snackbar(
      'غير مسموح',
      'يمكن لكل مدير طباعة تقريره التنفيذي اليومي فقط.',
      snackPosition: SnackPosition.TOP,
    );
  }

  void showExecutiveReportOptionsDialog() {
    if (!canExportOwnExecutiveReport) {
      _showExecutiveReportAccessDenied();
      return;
    }
    final role = UserSessionService.to.currentRole.value;
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primaryDark, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تصدير التقرير التنفيذي اليومي',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'اختر النموذج التنفيذي المطلوب تصديره (PDF)',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // خيار 1: تقرير مدير المصنع
              if (role == UserRole.factoryManager)
                _buildReportOptionCard(
                title: 'التقرير اليومي لمدير المصنع',
                subtitle: 'متابعة الأداء اليومي، الإنتاج، الصيانة، المواد الخام، والسلامة',
                icon: Icons.factory_rounded,
                accentColor: const Color(0xFF0F3B60),
                onTap: () {
                  Get.back();
                  exportDailySummaryPdf(type: 'factory');
                },
              ),
              if (role == UserRole.factoryManager) const SizedBox(height: 10),

              // خيار 2: تقرير مدير الجودة
              if (role == UserRole.qualityManager)
                _buildReportOptionCard(
                title: 'التقرير اليومي لمدير الجودة',
                subtitle: 'نتائج الفحوصات المخبرية، نسب المطابقة، العيوب، والإجراءات الوقائية',
                icon: Icons.biotech_rounded,
                accentColor: const Color(0xFF16A34A),
                onTap: () {
                  Get.back();
                  exportDailySummaryPdf(type: 'quality');
                },
              ),
              if (role == UserRole.generalManager) const SizedBox(height: 10),

              // خيار 3: التقرير الموحد المدمج
              if (role == UserRole.generalManager)
                _buildReportOptionCard(
                title: 'تصدير التقريرين معاً (ملف تنفيذي موحد)',
                subtitle: 'ملف PDF متكامل من صفحتين يشمل تقرير المصنع وتقرير الجودة معاً',
                icon: Icons.layers_rounded,
                accentColor: const Color(0xFF0891B2),
                onTap: () {
                  Get.back();
                  exportDailySummaryPdf(type: 'combined');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDarkest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  /// تصدير التقرير التنفيذي اليومي — يتيح تصدير تقرير مدير المصنع أو مدير الجودة أو كلاهما
  Future<void> exportDailySummaryPdf({String? type}) async {
    final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
    final userName = session?.currentUserName.value ?? 'مسؤول الجودة';
    final role = session?.currentRole.value ?? UserRole.qualitySpecialist;
    if (type == null) {
      if (role == UserRole.factoryManager) {
        return exportDailySummaryPdf(type: 'factory');
      }
      if (role == UserRole.qualityManager) {
        return exportDailySummaryPdf(type: 'quality');
      }
      _showExecutiveReportAccessDenied();
      return;
    }
    if (!_canExportExecutiveReportType(role, type)) {
      _showExecutiveReportAccessDenied();
      return;
    }
    final roleTitle = session?.roleLabels[role] ?? 'أخصائي الجودة';

    String targetBranchName = 'كافة المصانع (مصنع أرتل ومصنع سنحان)';
    if (selectedBranchId.value == 1) {
      targetBranchName = 'مصنع أرتل (الرئيسي)';
    } else if (selectedBranchId.value == 2) {
      targetBranchName = 'مصنع سنحان (المصنع الثاني)';
    }

    final shiftSummary = '${activeShiftName.value} (${activeShiftTime.value})';

    // جلب توقيع المُعِد الحالي (من الجلسة) لعرضه أسفل التقرير
    Uint8List? preparerSignature;
    try {
      final sessionUser = session?.currentUser.value;
      final effectiveUserId = (sessionUser?.id != null && sessionUser!.id! > 0) ? sessionUser.id : null;
      preparerSignature = await UserSignatureService.instance.getSignatureBytesForUser(
        userId: effectiveUserId,
        userName: userName,
        userPosition: roleTitle,
      );
    } catch (_) {
      preparerSignature = null;
    }

    // سجلات الإجراءات التصحيحية بانتظار قرار مدير المصنع
    final gmDecisionItems = correctiveActionItems
        .where((i) => i['approval_status'] == 'Pending_GM_Decision')
        .toList();

    // 1) تصدير تقرير مدير المصنع
    if (type == 'factory') {
      try {
        await ExecutiveDashboardPdfGenerator.generateFactoryManagerReport(
          userName: userName,
          roleTitle: roleTitle,
          branchName: targetBranchName,
          activeShiftName: shiftSummary,
          totalSamples: totalSamples.value,
          compliantSamples: compliantSamples.value,
          complianceRate: complianceRate.value,
          dynamicRecords: dynamicRecordsCount.value,
          dynamicApproved: dynamicApprovedCount.value,
          pendingGmCount: pendingApprovalsCount.value,
          pendingGmDecisionCount: gmDecisionItems.length,
          factoryComparison: factoryComparison.toList(),
          pendingItems: pendingItems.toList(),
          correctiveActionItems: gmDecisionItems.isNotEmpty ? gmDecisionItems : correctiveActionItems.toList(),
          recentActivities: recentActivities.toList(),
          preparerSignatureBytes: preparerSignature,
        );
      } catch (error) {
        Get.snackbar(
          'تعذر إنشاء التقرير',
          'حدث خطأ أثناء تجهيز تقرير مدير المصنع. حاول مرة أخرى.',
          snackPosition: SnackPosition.TOP,
        );
        debugPrint('Factory executive PDF error: $error');
      }
      return;
    }

    // 2) تصدير تقرير مدير الجودة
    if (type == 'quality') {
      await ExecutiveDashboardPdfGenerator.generateQualityManagerReport(
        userName: userName,
        roleTitle: roleTitle,
        branchName: targetBranchName,
        activeShiftName: shiftSummary,
        totalSamples: totalSamples.value,
        compliantSamples: compliantSamples.value,
        complianceRate: complianceRate.value,
        dynamicRecords: dynamicRecordsCount.value,
        dynamicApproved: dynamicApprovedCount.value,
        dynamicPending: dynamicPendingCount.value,
        correctiveActionCount: correctiveActionCount.value,
        pendingItems: pendingItems.toList(),
        nonCompliantLogs: nonCompliantLogs.toList(),
        correctiveActionItems: correctiveActionItems.toList(),
        shift1Count: shift1Count.value,
        shift2Count: shift2Count.value,
        shift3Count: shift3Count.value,
        preparerSignatureBytes: preparerSignature,
      );
      return;
    }

    // 3) تصدير التقريرين معاً في ملف تنفيذي موحد
    if (type == 'combined') {
      await ExecutiveDashboardPdfGenerator.generateCombinedExecutiveReport(
        userName: userName,
        roleTitle: roleTitle,
        branchName: targetBranchName,
        activeShiftName: shiftSummary,
        totalSamples: totalSamples.value,
        compliantSamples: compliantSamples.value,
        complianceRate: complianceRate.value,
        dynamicRecords: dynamicRecordsCount.value,
        dynamicApproved: dynamicApprovedCount.value,
        dynamicPending: dynamicPendingCount.value,
        correctiveActionCount: correctiveActionCount.value,
        nonCompliantLogs: nonCompliantLogs.toList(),
        correctiveActionItems: correctiveActionItems.toList(),
        preparerSignatureBytes: preparerSignature,
      );
      return;
    }

    // في حال الاستدعاء المباشر دون تحديد: يختار حسب دور المستخدم
    if (role == UserRole.qualityManager || role == UserRole.qualitySpecialist) {
      await exportDailySummaryPdf(type: 'quality');
      return;
    }

    if (role == UserRole.factoryManager || role == UserRole.admin || role == UserRole.generalManager) {
      await exportDailySummaryPdf(type: 'factory');
      return;
    }

    // باقي الأدوار
    Get.snackbar(
      'تنبيه',
      'التقرير التنفيذي اليومي مخصص لمدير الجودة ومدير المصنع والإدارة',
      snackPosition: SnackPosition.TOP,
    );
  }
}

