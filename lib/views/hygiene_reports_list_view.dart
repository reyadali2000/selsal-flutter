import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/hygiene_report_controller.dart';
import '../controllers/hygiene_reports_list_controller.dart';
import '../widgets/branch_filter_selector.dart';
import '../widgets/ds/ds.dart';
import 'hygiene_report_display_view.dart';

class HygieneReportsListView extends StatelessWidget {
  HygieneReportsListView({super.key});

  final HygieneReportsListController controller = Get.put(HygieneReportsListController());
  final HygieneReportController formController = Get.put(HygieneReportController());

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'سجل تقارير النظافة الشخصية',
      maxContentWidth: 900,
      actions: [
        BranchFilterSelector(
          compact: true,
          onChanged: () => controller.loadReports(),
        ),
      ],
      body: Column(
        children: [
          _buildFilterBar(),
          _buildSearchBar(context),
          Expanded(child: _buildArchiveBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(() => Row(
          children: [
            _buildFilterChip('all', 'الكل'),
            const SizedBox(width: 8),
            _buildFilterChip('pending_my_approval', 'بانتظار اعتمادي ⏳'),
            const SizedBox(width: 8),
            _buildFilterChip('approved', 'المعتمدة نهائياً ✅'),
            const SizedBox(width: 8),
            _buildFilterChip('drafts_rejected', 'مسودات ومرفوضة 📝'),
          ],
        )),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = controller.selectedFilter.value == key;
    return ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.primaryDark,
        backgroundColor: Colors.grey.shade100,
        showCheckmark: false,
        onSelected: (selected) {
          if (selected) {
            controller.setFilter(key);
          }
        },
    );
  }

  Widget _buildArchiveBody() {
    return Obx(() {
      final reports = controller.filteredReports;
      if (reports.isEmpty) {
        return const AppEmptyState(
          title: 'لا توجد تقارير محفوظة',
          message: 'لا يوجد أي تقارير سابقة لعرضها.',
          icon: Icons.folder_open_rounded,
        );
      }

      return RefreshIndicator(
        onRefresh: _refreshArchive,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            return _buildReportCard(reports[index]);
          },
        ),
      );
    });
  }

  Future<void> _refreshArchive() async {
    await controller.loadReports();
  }



  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
         color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: controller.searchController,
        onChanged: (val) {
          controller.filterByDate(val);
        },
        decoration: InputDecoration(
          hintText: 'بحث برقم الفحص أو التاريخ (مثال: 2023-10-25 أو #12)...',
          hintStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: AppColors.primaryDark),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                  onPressed: () {
                    controller.searchController.clear();
                    controller.filterByDate('');
                  },
                ),
              IconButton(
                icon: const Icon(Icons.calendar_month, color: AppColors.primaryLight),
                tooltip: 'اختيار تاريخ',
                onPressed: () => controller.selectDate(context),
              ),
            ],
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14),
      ),
    );
  }

  Widget _buildReportCard(HygieneReportSummary report) {
    final isRejected = report.approvalStatus == 'Rejected';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (report.approvalStatus) {
      case 'Approved':
      case 'Closed':
        statusColor = Colors.green.shade700;
        statusText = report.approvalStatus == 'Closed' ? 'معتمد بعد إجراء تصحيحي' : 'معتمد نهائياً';
        statusIcon = report.approvalStatus == 'Closed' ? Icons.task_alt : Icons.verified;
        break;
      case 'Pending_GM':
        statusColor = Colors.purple.shade700;
        statusText = 'بانتظار مدير المصنع';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'Rejected':
        statusColor = Colors.red.shade700;
        statusText = 'مرفوض — تصحيحي مطلوب';
        statusIcon = Icons.cancel_outlined;
        break;
      case 'Corrective_In_Progress':
        statusColor = Colors.blue.shade700;
        statusText = 'تصحيحي قيد التنفيذ';
        statusIcon = Icons.build_circle;
        break;
      case 'Pending_GM_Decision':
        statusColor = Colors.amber.shade800;
        statusText = 'بانتظار قرار مدير المصنع';
        statusIcon = Icons.pending_actions;
        break;
      case 'Rejected_By_GM':
        statusColor = const Color(0xFF8B0000);
        statusText = 'مرفوض نهائياً';
        statusIcon = Icons.cancel_presentation;
        break;
      case 'Draft':
        statusColor = Colors.blueGrey;
        statusText = 'مسودة';
        statusIcon = Icons.edit_note;
        break;
      case 'Pending_QM':
      default:
        statusColor = Colors.orange.shade800;
        statusText = 'بانتظار مدير الجودة';
        statusIcon = Icons.pending_actions;
        break;
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () {
        Get.to(() => HygieneReportDisplayView(reportId: int.parse(report.id)));
      },
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.clean_hands_outlined, color: AppColors.primaryDark, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تقرير النظافة (${report.date})',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'الوردية: ${report.shift} | المراقب: ${report.supervisorName}',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
            ],
          ),
          if (isRejected && report.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'ملاحظة الرفض: ${report.rejectionReason}',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: Colors.red.shade900,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

