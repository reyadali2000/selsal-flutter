import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/approval_status.dart';
import 'api/dynamic_reports_api_service.dart';
import 'database_helper.dart';
import 'user_session_service.dart';

/// خدمة تجميع التقارير بحاجة للاعتماد للدور النشط حالياً.
/// تُستخدم في الإشعار المنبثق عند فتح النظام وفي بطاقة الاعتمادات المعلقة
/// بلوحة التحكم، وتوحّد منطق "ما الذي ينتظرني كمعتمد؟" بين كل الشاشات.
class PendingApprovalsService extends GetxService {
  static PendingApprovalsService get to => Get.find<PendingApprovalsService>();

  /// هل يملك المستخدم الحالي صلاحية الاعتماد/الرفض — وبالتالي يستحق الإشعار المنبثق؟
  bool get currentUserCanApprove {
    if (!Get.isRegistered<UserSessionService>()) return false;
    final session = UserSessionService.to;
    return session.canApproveQSupervisor ||
        session.canApproveQM ||
        session.canApproveGM ||
        session.canRejectReports ||
        session.canEditReports;
  }

  /// حالات الاعتماد المعلقة الخاصة بدور المستخدم النشط:
  /// - مشرف الجودة: تقارير المرحلة الأولى (Pending_QS).
  /// - مدير الجودة: تقاريره + قرارات الإجراء التصحيحي (Pending_QM_Decision) + نتائج الميكروبيولوجي (المرحلة الثانية).
  /// - مدير المصنع: تقاريره + القرار النهائي للإجراء التصحيحي (Pending_GM_Decision) + نتائج الميكروبيولوجي (المرحلة الثانية).
  /// - بقية المخوّلين بالاعتماد/التعديل: التقارير المرفوضة (دورة الإجراء التصحيحي) وبانتظار نتائج الميكروبيولوجي.
  List<String> get pendingStatusesForCurrentRole {
    final session = UserSessionService.to;
    final role = session.currentRole.value;
    if (role == UserRole.qualitySupervisor) {
      return [ApprovalStatus.pendingQS];
    }
    if (role == UserRole.qualityManager) {
      return [
        ApprovalStatus.pendingQM,
        ApprovalStatus.pendingQMDecision,
        ApprovalStatus.pendingMicroQM,
      ];
    }
    if (role == UserRole.factoryManager) {
      return [
        ApprovalStatus.pendingGM,
        ApprovalStatus.pendingGMDecision,
        ApprovalStatus.pendingMicroGM,
      ];
    }
    return [
      ApprovalStatus.rejected,
      ApprovalStatus.correctiveInProgress,
      ApprovalStatus.awaitingMicroResults,
      ApprovalStatus.microResamplePending,
      ApprovalStatus.microCorrectiveInProgress,
      ApprovalStatus.microRejected,
    ];
  }

  /// جلب قائمة التقارير بحاجة لاعتماد الدور النشط (مرتبة من الأحدث للأقدم).
  /// تُدمج السجلات الديناميكية مع السجلات الثابتة (مياه خام، منتج نهائي،
  /// مواد أولية، نظافة) في قائمة واحدة موحّدة.
  Future<List<Map<String, dynamic>>> fetchPendingApprovalsForCurrentRole() async {
    if (!currentUserCanApprove) return [];

    final session = UserSessionService.to;
    final int? branchId = session.effectiveBranchFilter;

    final statuses = pendingStatusesForCurrentRole;
    final combined = <Map<String, dynamic>>[];
    final seenKeys = <String>{};

    final canWater = session.isAdmin || session.isGeneralManager || session.canViewReports || session.canCreateWaterReports || session.canApproveQSupervisor || session.canApproveQM || session.canApproveGM;
    final canHygiene = session.isAdmin || session.isGeneralManager || session.canViewHealthReports || session.canCreateHygieneReports || session.canApproveQSupervisor || session.canApproveQM || session.canApproveGM;
    final canRawMaterial = session.isAdmin || session.isGeneralManager || session.canViewReports || session.canCreateRawMaterialReports || session.canApproveQSupervisor || session.canApproveQM || session.canApproveGM;

    for (final st in statuses) {
      if (st == ApprovalStatus.pendingMicroQM || st == ApprovalStatus.pendingMicroGM) continue;

      // 1. السجلات الديناميكية عبر خادم الـ API
      try {
        final dynamicPending = await DynamicReportsApiService.to
            .getPendingRecordsForRole(st, branchId: branchId);
        for (var r in dynamicPending) {
          final rptId = r['report_id'] as int?;
          final catId = r['category_id'] as int?;
          final recBranch = r['branch_id'] as int?;
          if (!session.canViewBranchData(recBranch)) continue;
          if (!session.canViewDynamicReport(rptId, catId)) continue;

          final key = 'dynamic_${r['record_id']}';
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            combined.add({
              'id': r['record_id'],
              'report_id': r['report_id'],
              'category_id': r['category_id'],
              'branch_id': r['branch_id'],
              'type': 'dynamic',
              'title': '${r['report_name'] ?? "تقرير ديناميكي"} #${r['record_id']}',
              'created_at': r['created_at'],
              'created_by': r['created_by'],
              'approval_status': r['approval_status'],
            });
          }
        }
      } catch (e) {
        debugPrint('PendingApprovalsService(dynamic) fetch error for $st: $e');
      }

      // 2. السجلات الثابتة من قاعدة البيانات المحلية
      try {
        final microSt = (st == ApprovalStatus.pendingQM)
            ? ApprovalStatus.pendingMicroQM
            : ((st == ApprovalStatus.pendingGM) ? ApprovalStatus.pendingMicroGM : null);
        final staticLogs = await DatabaseHelper.instance.getPendingLogsForRole(
          st,
          branchId: branchId,
          microStatus: microSt,
          includeWater: canWater,
          includeHygiene: canHygiene,
          includeRawMaterial: canRawMaterial,
        );
        for (var l in staticLogs) {
          final recBranch = l['branch_id'] as int?;
          if (!session.canViewBranchData(recBranch)) continue;
          final key = '${l['type']}_${l['id']}';
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            combined.add(l);
          }
        }
      } catch (e) {
        debugPrint('PendingApprovalsService(static) fetch error for $st: $e');
      }
    }

    // ترتيب من الأحدث للأقدم
    combined.sort((a, b) {
      final dateA = (a['created_at'] ?? '').toString();
      final dateB = (b['created_at'] ?? '').toString();
      return dateB.compareTo(dateA);
    });

    return combined;
  }
}
