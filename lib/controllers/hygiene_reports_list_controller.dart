import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../services/user_session_service.dart';
import '../services/api/api.dart';
import '../services/sync/sync_manager.dart';

class HygieneReportSummary {
  final String id;
  final String date;
  final String shift;
  final String supervisorName;
  final String approvalStatus;
  final String? rejectionReason;

  HygieneReportSummary({
    required this.id,
    required this.date,
    required this.shift,
    required this.supervisorName,
    required this.approvalStatus,
    this.rejectionReason,
  });
}

class HygieneReportsListController extends GetxController {
  final RxList<HygieneReportSummary> allReports = <HygieneReportSummary>[].obs;
  final RxList<HygieneReportSummary> filteredReports = <HygieneReportSummary>[].obs;
  final TextEditingController searchController = TextEditingController();
  final RxString selectedFilter = 'all'.obs;

  @override
  void onInit() {
    super.onInit();
    loadReports();

    if (Get.isRegistered<SyncManager>()) {
      SyncManager.to.registerRefresher('hygiene_reports', () => loadReports(silent: true));
    }

    if (Get.isRegistered<UserSessionService>()) {
      ever(UserSessionService.to.currentUser, (_) => loadReports());
      ever(UserSessionService.to.currentRole, (_) => loadReports());
      ever(UserSessionService.to.activeBranchFilter, (_) => loadReports());
    }
  }

  @override
  void onClose() {
    if (Get.isRegistered<SyncManager>()) {
      SyncManager.to.unregisterRefresher('hygiene_reports');
    }
    searchController.dispose();
    super.onClose();
  }

  Future<void> loadReports({bool silent = false}) async {
    final branchId = Get.isRegistered<UserSessionService>()
        ? UserSessionService.to.effectiveBranchFilter
        : null;

    List<Map<String, dynamic>> savedReports = [];

    if (Get.isRegistered<HygieneApiService>()) {
      try {
        final apiReports = await HygieneApiService.to.getReports(branchId: branchId);
        savedReports = apiReports;
      } catch (e) {
        if (!silent) debugPrint('API load hygiene reports error: $e');
      }
    }

    if (savedReports.isEmpty && !silent) {
      savedReports = await DatabaseHelper.instance.getHygieneReports(branchId: branchId);
    }
    if (savedReports.isEmpty) return;

    final reports = savedReports.map((report) {
      final dateRaw = (report['created_at'] ?? report['createdAt'] ?? report['date'])?.toString();
      final createdAt = dateRaw != null ? (DateTime.tryParse(dateRaw) ?? DateTime.now()) : DateTime.now();
      final empCount = report['employee_count'] ?? report['employeeCount'] ?? 0;
      final supervisor = report['supervisor_name'] ?? report['supervisorName'] ?? 'مفتش الجودة';
      final status = report['approval_status'] ?? report['approvalStatus'] ?? 'Pending_QM';
      final rejection = report['rejection_reason'] ?? report['rejectionReason'];

      return HygieneReportSummary(
        id: '${report['id']}',
        date: DateFormat('yyyy/MM/dd - HH:mm').format(createdAt),
        shift: '$empCount موظف',
        supervisorName: supervisor.toString(),
        approvalStatus: status.toString(),
        rejectionReason: rejection?.toString(),
      );
    }).toList();
    allReports.assignAll(reports);
    applyFilter();
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;
    applyFilter();
  }

  void applyFilter() {
    final query = searchController.text;
    List<HygieneReportSummary> list = allReports.toList();

    // 1. Text Search Filter
    if (query.isNotEmpty) {
      final cleanQ = query.trim().toLowerCase().replaceAll('#', '');
      list = list.where((r) =>
        r.id.contains(cleanQ) ||
        r.date.contains(query) ||
        r.supervisorName.toLowerCase().contains(query.toLowerCase())
      ).toList();
    }

    // 2. Status Filter
    final session = UserSessionService.to;
    final role = session.currentRole.value;

    switch (selectedFilter.value) {
      case 'pending_my_approval':
        if (role == UserRole.qualityManager) {
          list = list.where((r) => r.approvalStatus == 'Pending_QM').toList();
        } else if (role == UserRole.factoryManager) {
          list = list.where((r) =>
              r.approvalStatus == 'Pending_GM' ||
              r.approvalStatus == 'Pending_GM_Decision').toList();
        } else {
          list = list.where((r) => r.approvalStatus.startsWith('Pending')).toList();
        }
        break;
      case 'approved':
        list = list.where((r) => r.approvalStatus == 'Approved' || r.approvalStatus == 'Closed').toList();
        break;
      case 'drafts_rejected':
        list = list.where((r) =>
            r.approvalStatus == 'Draft' ||
            r.approvalStatus == 'Rejected' ||
            r.approvalStatus == 'Corrective_In_Progress' ||
            r.approvalStatus == 'Pending_GM_Decision' ||
            r.approvalStatus == 'Rejected_By_GM').toList();
        break;
      case 'all':
      default:
        break;
    }

    filteredReports.assignAll(list);
  }

  void filterByDate(String query) {
    applyFilter();
  }

  void selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      searchController.text = formattedDate;
      filterByDate(formattedDate);
    }
  }

  void clearSearch() {
    searchController.clear();
    applyFilter();
  }
}
