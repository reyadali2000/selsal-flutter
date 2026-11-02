import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../controllers/final_product_controller.dart';
import '../models/water_quality_models.dart';
import '../services/user_session_service.dart';
import '../widgets/ds/ds.dart';
import '../widgets/branch_filter_selector.dart';
import '../widgets/notification_bell.dart';
import 'final_product_entry_page.dart';
import 'final_product_report_display_view.dart';

class FinalProductReportsPage extends StatefulWidget {
  const FinalProductReportsPage({super.key});

  @override
  State<FinalProductReportsPage> createState() => _FinalProductReportsPageState();
}

class _FinalProductReportsPageState extends State<FinalProductReportsPage> {
  final FinalProductController controller = Get.put(FinalProductController());
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // all, pending_my_approval, approved, drafts_rejected
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadReports();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'اختر تاريخ الفحص',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
    if (picked != null) {
      final formatted = DateFormat('yyyy-MM-dd').format(picked);
      _searchController.text = formatted;
      setState(() {
        _searchQuery = formatted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : Colors.grey.shade50,
        appBar: AppBar(
          title: const Text(
            'تقارير فحص المنتج النهائي',
            style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          centerTitle: false,
          actions: [
            BranchFilterSelector(
              compact: true,
              onChanged: () => controller.loadReports(),
            ),
            const NotificationBell(),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  children: [
                    _buildSearchBar(),
                    _buildFilterBar(),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const AppLoading(message: 'جاري تحميل تقارير المنتج النهائي...');
                }

                final filteredList = _getFilteredReports();

                if (filteredList.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: AppEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'لا توجد تقارير في هذا التصنيف',
                        message: _searchQuery.isNotEmpty
                            ? 'لم يتم العثور على نتائج تطابق "$_searchQuery"'
                            : 'لا توجد تقارير مسجلة ضمن الفلتر المختار',
                      ),
                    ),
                  );
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: RefreshIndicator(
                      onRefresh: () => controller.loadReports(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final report = filteredList[index];
                          return _buildReportCard(report);
                        },
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
        floatingActionButton: UserSessionService.to.canCreateWaterReports
            ? FloatingActionButton.extended(
                onPressed: () {
                  controller.startNewReport();
                  Get.to(() => FinalProductEntryPage());
                },
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('تقرير جديد', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              )
            : null,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'بحث برقم الفحص أو التشغيلة أو التاريخ...',
                  hintStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.grey),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              ),
            IconButton(
              icon: const Icon(Icons.calendar_month, color: AppColors.primaryDark),
              tooltip: 'اختيار تاريخ',
              onPressed: () => _selectDate(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('all', 'الكل'),
          const SizedBox(width: 8),
          _buildFilterChip('pending_my_approval', 'بانتظار اعتمادي ⏳'),
          const SizedBox(width: 8),
          _buildFilterChip('approved', 'المعتمدة نهائياً ✅'),
          const SizedBox(width: 8),
          _buildFilterChip('drafts_rejected', 'مسودات ومرفوضة 📝'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
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
          setState(() => _selectedFilter = key);
        }
      },
    );
  }

  List<WaterQualityLog> _getFilteredReports() {
    final all = controller.reportsList;
    final session = UserSessionService.to;
    final role = session.currentRole.value;

    List<WaterQualityLog> list;
    switch (_selectedFilter) {
      case 'pending_my_approval':
        if (role == UserRole.qualityManager) {
          list = all.where((r) =>
              r.approvalStatus == 'Pending_QM' ||
              r.approvalStatus == 'Pending_Micro_QM').toList();
        } else if (role == UserRole.factoryManager) {
          list = all.where((r) =>
              r.approvalStatus == 'Pending_GM' ||
              r.approvalStatus == 'Pending_GM_Decision' ||
              r.approvalStatus == 'Pending_Micro_GM').toList();
        } else {
          list = all.where((r) =>
              r.approvalStatus.startsWith('Pending') ||
              r.approvalStatus == 'Awaiting_Micro_Results').toList();
        }
        break;
      case 'approved':
        list = all.where((r) => r.approvalStatus == 'Approved' || r.approvalStatus == 'Closed').toList();
        break;
      case 'drafts_rejected':
        list = all.where((r) =>
            r.approvalStatus == 'Draft' ||
            r.approvalStatus == 'Rejected' ||
            r.approvalStatus == 'Corrective_In_Progress' ||
            r.approvalStatus == 'Pending_GM_Decision' ||
            r.approvalStatus == 'Rejected_By_GM').toList();
        break;
      case 'all':
      default:
        list = all.toList();
        break;
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase().replaceAll('#', '');
      list = list.where((r) {
        final idStr = r.id?.toString() ?? '';
        final batch = (r.batchNumber ?? '').toLowerCase();
        final prodName = (r.productName ?? '').toLowerCase();
        final prodDate = (r.productionDate ?? '').toLowerCase();
        final createdDate1 = DateFormat('yyyy-MM-dd').format(r.createdAt);
        final createdDate2 = DateFormat('yyyy/MM/dd').format(r.createdAt);

        return idStr.contains(q) ||
            batch.contains(q) ||
            prodName.contains(q) ||
            prodDate.contains(q) ||
            createdDate1.contains(q) ||
            createdDate2.contains(q);
      }).toList();
    }

    return list;
  }

  Widget _buildReportCard(WaterQualityLog report) {
    final formattedDate = DateFormat('yyyy/MM/dd - HH:mm').format(report.createdAt);
    final isDraft = report.approvalStatus == 'Draft';
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
      case 'Awaiting_Micro_Results':
        statusColor = Colors.teal.shade700;
        statusText = 'معتمد مبدئياً — بانتظار الميكروبيولوجي';
        statusIcon = Icons.science_outlined;
        break;
      case 'Pending_Micro_QM':
        statusColor = Colors.orange.shade800;
        statusText = 'الميكروبيولوجي بانتظار مدير الجودة';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'Pending_Micro_GM':
        statusColor = Colors.purple.shade700;
        statusText = 'الميكروبيولوجي بانتظار مدير المصنع';
        statusIcon = Icons.verified_user;
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        borderColor: statusColor.withValues(alpha: 0.3),
        borderWidth: 1.2,
        padding: const EdgeInsets.all(16),
        onTap: () {
          if (isDraft) {
            controller.initForEdit(report);
            Get.to(() => FinalProductEntryPage());
          } else {
            Get.to(() => FinalProductReportDisplayView(), arguments: report)?.then((_) {
              controller.loadReports(silent: true);
            });
          }
        },
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
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: report.isCompliant
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.isCompliant ? 'مطابق ✅' : 'غير مطابق ⚠️',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: report.isCompliant ? Colors.green.shade800 : Colors.red.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
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
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.water_drop_outlined, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تشغيلة: ${report.batchNumber ?? "-"} | ${report.productName ?? "مياه معبأة"} (${report.bottleSize ?? ""})',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'مكان العينة: ${report.samplingLocation ?? "أثناء التشغيل"} | الكمية: ${report.producedQuantity ?? "5000 كرتون"}',
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
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'المنفذ: ${report.sampleTaker ?? "صلاح الجابري"}',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  formattedDate,
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade600),
                ),
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
      ),
    );
  }
}
