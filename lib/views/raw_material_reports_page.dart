import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/raw_material_models.dart';
import '../services/api/raw_materials_api_service.dart';
import '../services/database_helper.dart';
import '../services/user_session_service.dart';
import '../widgets/ds/ds.dart';
import 'raw_material_report_display_view.dart';
import '../widgets/branch_filter_selector.dart';
import '../services/sync/sync_manager.dart';

class RawMaterialReportsController extends GetxController {
  final reports = <RawMaterialReport>[].obs;
  final filteredReports = <RawMaterialReport>[].obs;
  final isLoading = false.obs;
  final searchQuery = ''.obs;
  final TextEditingController searchController = TextEditingController();
  final selectedFilter = 'all'.obs;

  @override
  void onInit() {
    super.onInit();
    loadReports();

    if (Get.isRegistered<SyncManager>()) {
      SyncManager.to.registerRefresher('raw_material_reports', () => loadReports(silent: true));
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
      SyncManager.to.unregisterRefresher('raw_material_reports');
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
      helpText: 'اختر تاريخ الفحص',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
    if (picked != null) {
      final formatted = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      searchController.text = formatted;
      setSearchQuery(formatted);
    }
  }

  Future<void> loadReports({bool silent = false}) async {
    try {
      if (!silent) isLoading.value = true;
      final branchId = Get.isRegistered<UserSessionService>()
          ? UserSessionService.to.effectiveBranchFilter
          : null;
      if (Get.isRegistered<RawMaterialsApiService>()) {
        try {
          final rawList = await RawMaterialsApiService.to.getReports(branchId: branchId);
          final list = rawList.map((m) => RawMaterialReport.fromMap(m)).toList();
          reports.value = list;
        } catch (e) {
          debugPrint('API load raw material reports error: $e');
        }
      }
      if (reports.isEmpty) {
        final list = await DatabaseHelper.instance.getRawMaterialReports(branchId: branchId);
        reports.value = list;
      }
      applyFilters();
    } catch (e) {
      debugPrint('Error loading raw material reports: $e');
    } finally {
      if (!silent) isLoading.value = false;
    }
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;
    applyFilters();
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
    applyFilters();
  }

  void applyFilters() {
    final query = searchQuery.value.trim().toLowerCase();
    final cleanQuery = query.replaceAll('#', '');
    final role = Get.isRegistered<UserSessionService>()
        ? UserSessionService.to.currentRole.value
        : UserRole.qualitySpecialist;

    filteredReports.value = reports.where((r) {
      bool matchesStatus = true;
      if (selectedFilter.value == 'pending_my_approval') {
        if (role == UserRole.qualitySupervisor) {
          matchesStatus = r.approvalStatus == 'Pending_QS';
        } else if (role == UserRole.qualityManager) {
          matchesStatus = r.approvalStatus == 'Pending_QM';
        } else if (role == UserRole.factoryManager) {
          matchesStatus = r.approvalStatus == 'Pending_GM' ||
              r.approvalStatus == 'Pending_GM_Decision';
        } else {
          matchesStatus = r.approvalStatus == 'Pending_QS' ||
              r.approvalStatus == 'Pending_QM' ||
              r.approvalStatus == 'Pending_GM';
        }
      } else if (selectedFilter.value == 'approved') {
        matchesStatus = r.approvalStatus == 'Approved' || r.approvalStatus == 'Closed';
      } else if (selectedFilter.value == 'pending') {
        matchesStatus = r.approvalStatus == 'Pending_QS' ||
            r.approvalStatus == 'Pending_QM' ||
            r.approvalStatus == 'Pending_GM';
      } else if (selectedFilter.value == 'drafts_rejected') {
        matchesStatus = r.approvalStatus == 'Draft' ||
            r.approvalStatus == 'Rejected' ||
            r.approvalStatus == 'Corrective_In_Progress' ||
            r.approvalStatus == 'Pending_GM_Decision' ||
            r.approvalStatus == 'Rejected_By_GM';
      }

      if (!matchesStatus) return false;

      if (query.isEmpty) return true;

      final idStr = r.id.toString();
      final supplier = r.supplierName.toLowerCase();
      final material = r.materialName.toLowerCase();
      final batch = r.batchNumber.toLowerCase();
      final date = r.dateStr.toLowerCase();

      return idStr.contains(cleanQuery) ||
          supplier.contains(query) ||
          material.contains(query) ||
          batch.contains(query) ||
          date.contains(query);
    }).toList();
  }
}

class RawMaterialReportsPage extends StatelessWidget {
  RawMaterialReportsPage({super.key});

  final controller = Get.put(RawMaterialReportsController());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF4F7FA),
        appBar: AppBar(
          title: const Text(
            'سجل تقارير فحص المواد الخام',
            style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF00695C),
          centerTitle: true,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Get.back(),
          ),
          actions: [
            BranchFilterSelector(
              compact: true,
              onChanged: () => controller.loadReports(),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'تحديث',
              onPressed: () => controller.loadReports(),
            ),
          ],
        ),
        body: Column(
          children: [
            // Search & Filter Header
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: isDark ? theme.colorScheme.surface : Colors.white,
                  child: Column(
                    children: [
                      // Search Input
                      TextField(
                        controller: controller.searchController,
                        onChanged: (val) => controller.setSearchQuery(val),
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'بحث برقم الفحص أو التشغيلة أو المادة أو التاريخ...',
                          hintStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF00695C)),
                          suffixIcon: Obx(() => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (controller.searchQuery.value.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                  onPressed: () {
                                    controller.searchController.clear();
                                    controller.setSearchQuery('');
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.calendar_month, color: Color(0xFF00695C)),
                                tooltip: 'اختيار تاريخ',
                                onPressed: () => controller.selectDate(context),
                              ),
                            ],
                          )),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF4F7FA),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Obx(() => Row(
                          children: [
                            _buildFilterChip('الكل', 'all'),
                            const SizedBox(width: 8),
                            _buildFilterChip('بانتظار اعتمادي ⏳', 'pending_my_approval'),
                            const SizedBox(width: 8),
                            _buildFilterChip('المعتمدة نهائياً ✅', 'approved'),
                            const SizedBox(width: 8),
                            _buildFilterChip('قيد الاعتماد', 'pending'),
                            const SizedBox(width: 8),
                            _buildFilterChip('مسودات ومرفوضة 📝', 'drafts_rejected'),
                          ],
                        )),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Reports List
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const AppLoading(message: 'جاري تحميل سجلات المواد الخام...');
                }

                if (controller.filteredReports.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: AppEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'لا توجد تقارير مطابقة',
                        message: controller.searchQuery.value.isNotEmpty
                            ? 'لم يتم العثور على نتائج تطابق "${controller.searchQuery.value}"'
                            : 'لا توجد تقارير في هذا التصنيف حالياً',
                      ),
                    ),
                  );
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: controller.filteredReports.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final report = controller.filteredReports[index];
                        final cat = RawMaterialCategoryInfo.getByKey(report.categoryKey);

                        return _buildReportCard(context, report, cat);
                      },
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = controller.selectedFilter.value == value;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : Colors.grey.shade700,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF00695C),
      backgroundColor: Colors.grey.withValues(alpha: 0.1),
      showCheckmark: false,
      onSelected: (_) => controller.setFilter(value),
    );
  }

  Widget _buildReportCard(BuildContext context, RawMaterialReport report, RawMaterialCategoryInfo cat) {
    Color statusBg;
    Color statusFg;
    String statusText;

    switch (report.approvalStatus) {
      case 'Pending_QS':
      statusBg = const Color(0xFFFFF8E1);
      statusFg = const Color(0xFFF57F17);
      statusText = 'بانتظار مشرف الجودة';
      break;
      case 'Approved':
      case 'Closed':
        statusBg = const Color(0xFFE8F5E9);
        statusFg = const Color(0xFF2E7D32);
        statusText = report.approvalStatus == 'Closed' ? 'معتمد بعد إجراء تصحيحي' : 'معتمد نهائياً';
        break;
      case 'Pending_GM':
        statusBg = const Color(0xFFEDE7F6);
        statusFg = const Color(0xFF6A1B9A);
        statusText = 'بانتظار مدير المصنع';
        break;
      case 'Rejected':
        statusBg = const Color(0xFFFFEBEE);
        statusFg = const Color(0xFFC62828);
        statusText = 'مرفوض — تصحيحي مطلوب';
        break;
      case 'Corrective_In_Progress':
        statusBg = const Color(0xFFE3F2FD);
        statusFg = const Color(0xFF1565C0);
        statusText = 'تصحيحي قيد التنفيذ';
        break;
      case 'Pending_GM_Decision':
        statusBg = const Color(0xFFFFF8E1);
        statusFg = const Color(0xFFAD6800);
        statusText = 'بانتظار قرار مدير المصنع';
        break;
      case 'Rejected_By_GM':
        statusBg = const Color(0xFFFFEBEE);
        statusFg = const Color(0xFF8B0000);
        statusText = 'مرفوض نهائياً';
        break;
      case 'Draft':
        statusBg = const Color(0xFFE3F2FD);
        statusFg = const Color(0xFF1565C0);
        statusText = 'مسودة';
        break;
      default:
        statusBg = const Color(0xFFFFF3E0);
        statusFg = const Color(0xFFE65100);
        statusText = 'بانتظار مدير الجودة';
        break;
    }

    return AppCard(
      onTap: () {
        Get.to(() => RawMaterialReportDisplayView(reportId: report.id!));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: cat.color.withValues(alpha: 0.12),
                radius: 20,
                child: Icon(cat.icon, color: cat.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.materialName.isNotEmpty ? report.materialName : cat.title,
                      style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'المورد: ${report.supplierName.isNotEmpty ? report.supplierName : "---"} • تشغيلة: ${report.batchNumber}',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
                child: Text(statusText, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 11, color: statusFg)),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(report.dateStr, style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.grey.shade600)),
                    const SizedBox(width: 12),
                    Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        report.inspectorName,
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat.annexCode.split('-').last, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 11, color: cat.color)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
