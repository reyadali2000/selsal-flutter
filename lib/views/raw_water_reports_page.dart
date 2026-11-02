import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../controllers/raw_water_entry_controller.dart';
import '../models/water_quality_models.dart';
import '../services/user_session_service.dart';
import '../widgets/ds/ds.dart';
import '../widgets/branch_filter_selector.dart';
import '../widgets/notification_bell.dart';
import 'raw_water_report_display_view.dart';

class RawWaterReportsPage extends StatefulWidget {
  const RawWaterReportsPage({super.key});

  @override
  State<RawWaterReportsPage> createState() => _RawWaterReportsPageState();
}

class _RawWaterReportsPageState extends State<RawWaterReportsPage> {
  final RawWaterEntryController controller = Get.put(RawWaterEntryController());
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
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
            'تقارير فحص المياه الخام',
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
                  return const AppLoading(message: 'جاري تحميل سجلات المياه الخام...');
                }

                final reports = _getFilteredReports();

                if (reports.isEmpty) {
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
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: reports.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final report = reports[index];
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
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'بحث برقم الفحص أو البئر أو التاريخ...',
            hintStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.grey),
            prefixIcon: const Icon(Icons.search, color: AppColors.primaryDark),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('الكل', 'all'),
            const SizedBox(width: 8),
            _buildFilterChip('بانتظار اعتمادي ⏳', 'my_pending'),
            const SizedBox(width: 8),
            _buildFilterChip('المعتمدة نهائياً ✅', 'approved'),
            const SizedBox(width: 8),
            _buildFilterChip('مسودات ومرفوضة 📝', 'drafts_rejected'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
          color: isSelected ? Colors.white : null,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primaryDark,
      backgroundColor: Colors.grey.withValues(alpha: 0.1),
      showCheckmark: false,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedFilter = key;
          });
        }
      },
    );
  }

  List<WaterQualityLog> _getFilteredReports() {
    final all = controller.reportsList;
    final role = UserSessionService.to.currentRole.value;

    List<WaterQualityLog> list;
    switch (_selectedFilter) {
      case 'my_pending':
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
              r.approvalStatus == 'Pending_QM' ||
              r.approvalStatus == 'Pending_GM' ||
              r.approvalStatus == 'Pending_Micro_QM' ||
              r.approvalStatus == 'Pending_Micro_GM' ||
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
      default:
        list = all.toList();
        break;
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase().replaceAll('#', '');
      list = list.where((r) {
        final idStr = r.id?.toString() ?? '';
        final well = (r.wellNumber ?? '').toLowerCase();
        final ncr = (r.ncrNumber ?? '').toLowerCase();
        final batch = (r.batchNumber ?? '').toLowerCase();
        final source = (r.waterSource ?? '').toLowerCase();
        final sampleTaker = (r.sampleTaker ?? '').toLowerCase();
        final createdDate1 = DateFormat('yyyy-MM-dd').format(r.createdAt);
        final createdDate2 = DateFormat('yyyy/MM/dd').format(r.createdAt);

        return idStr.contains(q) ||
            well.contains(q) ||
            ncr.contains(q) ||
            batch.contains(q) ||
            source.contains(q) ||
            sampleTaker.contains(q) ||
            createdDate1.contains(q) ||
            createdDate2.contains(q);
      }).toList();
    }

    return list;
  }

  Widget _buildReportCard(WaterQualityLog report) {
    final formattedDate = DateFormat('yyyy/MM/dd - hh:mm a', 'en_US').format(report.createdAt);
    final status = report.approvalStatus;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'Draft':
        statusColor = Colors.grey.shade600;
        statusText = 'مسودة';
        statusIcon = Icons.edit_note;
        break;
      case 'Pending_QM':
        statusColor = const Color(0xFFE65100);
        statusText = 'بانتظار مدير الجودة';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'Pending_GM':
        statusColor = const Color(0xFF6A1B9A);
        statusText = 'بانتظار مدير المصنع';
        statusIcon = Icons.verified_user_outlined;
        break;
      case 'Awaiting_Micro_Results':
        statusColor = const Color(0xFF00838F);
        statusText = 'معتمد مبدئياً — بانتظار الميكروبيولوجي';
        statusIcon = Icons.science_outlined;
        break;
      case 'Pending_Micro_QM':
        statusColor = const Color(0xFFE65100);
        statusText = 'الميكروبيولوجي بانتظار مدير الجودة';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'Pending_Micro_GM':
        statusColor = const Color(0xFF6A1B9A);
        statusText = 'الميكروبيولوجي بانتظار مدير المصنع';
        statusIcon = Icons.verified_user_outlined;
        break;
      case 'Approved':
      case 'Closed':
        statusColor = const Color(0xFF2E7D32);
        statusText = status == 'Closed' ? 'معتمد بعد إجراء تصحيحي' : 'معتمد نهائياً';
        statusIcon = status == 'Closed' ? Icons.task_alt : Icons.check_circle;
        break;
      case 'Rejected':
        statusColor = const Color(0xFFC62828);
        final rejectorShort = report.rejectedBy != null && report.rejectedBy!.isNotEmpty
            ? ' (${report.rejectedBy})'
            : '';
        statusText = 'مرفوض$rejectorShort';
        statusIcon = Icons.cancel;
        break;
      case 'Corrective_In_Progress':
        statusColor = const Color(0xFF1565C0);
        statusText = 'تصحيحي قيد التنفيذ';
        statusIcon = Icons.build_circle;
        break;
      case 'Pending_GM_Decision':
        statusColor = const Color(0xFFAD6800);
        statusText = 'بانتظار قرار مدير المصنع';
        statusIcon = Icons.pending_actions;
        break;
      case 'Rejected_By_GM':
        statusColor = const Color(0xFF8B0000);
        statusText = 'مرفوض نهائياً';
        statusIcon = Icons.cancel_presentation;
        break;
      default:
        statusColor = Colors.blueGrey;
        statusText = status;
        statusIcon = Icons.info;
    }

    return AppCard(
      onTap: () {
        Get.to(() => RawWaterReportDisplayView(), arguments: report)?.then((_) {
          controller.loadReports();
        });
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'عينة رقم: ${report.batchNumber ?? "بدون رقم"}',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'التاريخ: $formattedDate',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                if (report.sampleTaker != null && report.sampleTaker!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'المنفذ: ${report.sampleTaker}',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (status == 'Rejected' && report.rejectionReason != null && report.rejectionReason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'سبب الرفض: ${report.rejectionReason}',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: Colors.red.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }
}
