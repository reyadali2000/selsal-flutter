import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constants/approval_status.dart';
import '../services/api/dynamic_reports_api_service.dart';
import '../models/dynamic_report_models.dart';
import '../services/user_session_service.dart';
import '../services/api/api.dart';
import '../services/sync/sync_manager.dart';
import '../utils/dynamic_report_pdf_generator.dart';

class DynamicReportRecordsController extends GetxController {
  
  final isLoading = true.obs;
  final isExportingBatch = false.obs;
  
  final records = <DynamicReportRecord>[].obs;
  final TextEditingController searchController = TextEditingController();
  final searchQuery = ''.obs;

  /// فلتر الحالة: 'all' أو قيمة approval_status محددة
  final statusFilter = 'all'.obs;

  /// قائمة الحالات المتاحة للفلترة (تُبنى ديناميكياً من السجلات)
  List<String> get availableStatuses {
    final set = <String>{};
    for (var r in records) {
      set.add(r.approvalStatus);
    }
    return set.toList()..sort();
  }

  /// هل السجل في دورة الإجراء التصحيحي (مرفوض أو إحدى حالاتها)؟
  bool isCorrectiveCycle(DynamicReportRecord r) =>
      ApprovalStatus.requiresCorrectiveAction(r.approvalStatus) ||
      r.approvalStatus == ApprovalStatus.closed;
  
  int? reportId;
  final reportName = 'التقرير'.obs;
  DynamicReport? report;

  @override
  void onInit() {
    super.onInit();
    reportId = Get.arguments as int?;
    if (reportId != null) {
      loadRecords();
      // تسجيل شاشة السجلات في المزامنة اللحظية (تحديث دوري صامت)
      if (Get.isRegistered<SyncManager>()) {
        SyncManager.to.registerRefresher('dynamic_records_$reportId', () => loadRecords(silent: true));
      }
    } else {
      isLoading.value = false;
      Get.snackbar('خطأ', 'لم يتم تحديد التقرير');
    }

    if (Get.isRegistered<UserSessionService>()) {
      ever(UserSessionService.to.currentUser, (_) => loadRecords());
      ever(UserSessionService.to.currentRole, (_) => loadRecords());
      // اعادة التحميل تلقائياً عند تغيير فلتر المصنع
      ever(UserSessionService.to.activeBranchFilter, (_) => loadRecords());
    }
  }

  @override
  void onClose() {
    if (reportId != null && Get.isRegistered<SyncManager>()) {
      SyncManager.to.unregisterRefresher('dynamic_records_$reportId');
    }
    searchController.dispose();
    super.onClose();
  }

  Future<void> selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'اختر تاريخ السجل',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
    if (picked != null) {
      final formatted = DateFormat('yyyy-MM-dd').format(picked);
      searchController.text = formatted;
      searchQuery.value = formatted;
    }
  }

  List<DynamicReportRecord> get filteredRecords {
    final q = searchQuery.value.trim().toLowerCase().replaceAll('#', '');
    Iterable<DynamicReportRecord> source = records;

    // فلتر الحالة
    if (statusFilter.value != 'all') {
      source = source.where((r) => r.approvalStatus == statusFilter.value);
    }

    if (q.isEmpty) return source.toList();
    return source.where((r) {
      final idStr = r.id.toString();
      final serialStr = r.recordSerial?.toString() ?? '';
      final codeStr = (r.recordCode ?? '').toLowerCase();
      final date1 = r.createdAt != null ? DateFormat('yyyy-MM-dd').format(r.createdAt!) : '';
      final date2 = r.createdAt != null ? DateFormat('yyyy/MM/dd').format(r.createdAt!) : '';
      final status = (r.status ?? '').toLowerCase();
      final approval = r.approvalStatus.toLowerCase();
      final creator = (r.createdBy ?? '').toLowerCase();
      final summary = (r.summaryNotes ?? '').toLowerCase();
      final branch = (r.branchName ?? '').toLowerCase();
      final dataJsonStr = (r.dataJson ?? '').toLowerCase();
      return idStr.contains(q) ||
          serialStr.contains(q) ||
          codeStr.contains(q) ||
          date1.contains(q) ||
          date2.contains(q) ||
          status.contains(q) ||
          approval.contains(q) ||
          creator.contains(q) ||
          summary.contains(q) ||
          branch.contains(q) ||
          dataJsonStr.contains(q);
    }).toList();
  }

  Future<void> loadRecords({bool silent = false}) async {
    if (!silent) isLoading.value = true;
    try {
      final fetchedReport = await DynamicReportsApiService.to.getTemplateDetails(reportId!);
      if (fetchedReport != null) {
        if (!UserSessionService.to.canViewDynamicReport(fetchedReport.id, fetchedReport.categoryId)) {
          Get.snackbar('غير مصرح', 'لا تملك صلاحية استعراض هذا التقرير');
          Get.back();
          return;
        }
        report = fetchedReport;
        reportName.value = fetchedReport.name;
        
        final branchId = Get.isRegistered<UserSessionService>()
            ? UserSessionService.to.effectiveBranchFilter
            : null;

        if (Get.isRegistered<DynamicReportsApiService>()) {
          try {
            final apiRecords = await DynamicReportsApiService.to.getRecords(
              reportId: reportId!,
              branchId: branchId,
            );
            if (apiRecords.isNotEmpty) {
              if (silent) {
                final bool hasChanged = apiRecords.length != records.length ||
                    _hasRecordsChanged(records, apiRecords);
                if (hasChanged) {
                  records.assignAll(apiRecords);
                }
              } else {
                records.assignAll(apiRecords);
              }
              isLoading.value = false;
              return;
            }
          } catch (e) {
            debugPrint('API load dynamic records error: $e');
          }
        }

        final fetchedRecords = await DynamicReportsApiService.to.getRecords(reportId: reportId!, branchId: branchId);
        records.assignAll(fetchedRecords);
      }
    } catch (e) {
      if (!silent) {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل السجلات');
      } else {
        debugPrint('silent refresh dynamic records error: $e');
      }
    } finally {
      if (!silent) isLoading.value = false;
    }
  }

  Future<void> deleteRecord(int recordId) async {
    isLoading.value = true;
    try {
      await DynamicReportsApiService.to.deleteRecord(recordId);
      records.removeWhere((r) => r.id == recordId);
      await loadRecords();
      Get.snackbar('نجاح', 'تم حذف السجل بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء حذف السجل: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// بناء وتوليد حزمة التدقيق المجمّعة (Batch Audit Pack PDF) للسجلات المعروضة حالياً
  Future<Uint8List?> generateBatchAuditPackBytes({bool approvedOnly = false}) async {
    if (report == null) return null;
    final targetRecords = approvedOnly
        ? filteredRecords
            .where((r) => r.approvalStatus == 'Approved' || r.approvalStatus == 'Closed')
            .toList()
        : filteredRecords;

    if (targetRecords.isEmpty) {
      Get.snackbar(
        'تنبيه',
        approvedOnly
            ? 'لا توجد سجلات معتمدة ضمن الفلتر الحالي لتصديرها'
            : 'لا توجد سجلات معروضة حالياً لتصديرها',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
      return null;
    }

    isExportingBatch.value = true;
    try {
      final List<({DynamicReportRecord record, List<DynamicReportValue> values, List<ReportApproval>? approvals})> entries = [];
      for (final rec in targetRecords) {
        if (rec.id == null) continue;
        List<DynamicReportValue> vals = [];
        List<ReportApproval>? apps;
        try {
          final details = await DynamicReportsApiService.to.getRecordDetailsWithValues(rec.id!);
          if (details != null && details['values'] is List<DynamicReportValue>) {
            vals = details['values'] as List<DynamicReportValue>;
          }
          apps = await DynamicReportsApiService.to.getApprovalTrail(rec.id!);
        } catch (_) {}
        entries.add((record: rec, values: vals, approvals: apps));
      }

      final filterLabel = approvedOnly
          ? 'السجلات المعتمدة فقط'
          : (statusFilter.value != 'all'
              ? ApprovalStatus.shortLabel(statusFilter.value)
              : 'كافة السجلات المعروضة');

      return await DynamicReportPdfGenerator.generateBatchAuditPack(
        report: report!,
        entries: entries,
        filterLabel: filterLabel,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء تجهيز حزمة التدقيق المجمّعة: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return null;
    } finally {
      isExportingBatch.value = false;
    }
  }
  bool _hasRecordsChanged(List<DynamicReportRecord> oldList, List<DynamicReportRecord> newList) {
    if (oldList.length != newList.length) return true;
    for (int i = 0; i < oldList.length; i++) {
      if (oldList[i].id != newList[i].id ||
          oldList[i].approvalStatus != newList[i].approvalStatus ||
          oldList[i].updatedAt != newList[i].updatedAt) {
        return true;
      }
    }
    return false;
  }
}

