import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/branch_model.dart';
import '../models/worker_commitment_models.dart';
import '../services/daily_workers_commitment_service.dart';
import '../services/factory_shifts_service.dart';
import '../services/user_session_service.dart';
import '../utils/workers_commitment_pdf_generator.dart';
import '../widgets/ds/ds.dart';

class DailyWorkersCommitmentController extends GetxController {
  final isLoading = true.obs;
  final isPdfLoading = false.obs;

  final selectedYear = DateTime.now().year.obs;
  final selectedMonth = DateTime.now().month.obs;
  final selectedBranchId = RxnInt(null);
  final selectedShiftFilter = RxnInt(null);
  final searchQuery = ''.obs;
  final sortBy = 'commitment'.obs; // 'commitment', 'attendance', 'hygiene', 'name'

  final workers = <WorkerMonthlyCommitment>[].obs;
  final kpiSummary = Rxn<WorkersCommitmentKPISummary>(null);
  final branches = <BranchModel>[].obs;

  final searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    _initBranchFilter();
    if (Get.isRegistered<UserSessionService>()) {
      ever(UserSessionService.to.activeBranchFilter, (branchId) {
        selectedBranchId.value = branchId;
        loadData();
      });
    }
    loadAll();
  }

  void _initBranchFilter() {
    selectedBranchId.value = UserSessionService.to.effectiveBranchFilter;
  }

  Future<void> loadAll() async {
    isLoading.value = true;
    try {
      final branchList = await FactoryShiftsService.instance.getAllBranches();
      branches.assignAll(branchList);
      await loadData();
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحميل بيانات الالتزام: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadData() async {
    final effectiveBranch = UserSessionService.to.isBranchRestricted
        ? UserSessionService.to.effectiveBranchFilter
        : selectedBranchId.value;

    // مزامنة أحدث السجلات والعمالة من السيرفر قبل الاحتساب
    await DailyWorkersCommitmentService.instance.syncFromApi(branchId: effectiveBranch);

    final reportList =
        await DailyWorkersCommitmentService.instance.getMonthlyCommitmentReport(
      year: selectedYear.value,
      month: selectedMonth.value,
      branchId: effectiveBranch,
      shiftFilterId: selectedShiftFilter.value,
    );

    final summary = await DailyWorkersCommitmentService.instance.getKPISummary(
      year: selectedYear.value,
      month: selectedMonth.value,
      branchId: effectiveBranch,
    );

    workers.assignAll(reportList);
    kpiSummary.value = summary;
  }

  void prevMonth() {
    if (selectedMonth.value == 1) {
      selectedMonth.value = 12;
      selectedYear.value -= 1;
    } else {
      selectedMonth.value -= 1;
    }
    loadData();
  }

  void nextMonth() {
    if (selectedMonth.value == 12) {
      selectedMonth.value = 1;
      selectedYear.value += 1;
    } else {
      selectedMonth.value += 1;
    }
    loadData();
  }

  void setBranchFilter(int? branchId) {
    if (UserSessionService.to.isBranchRestricted) return;
    selectedBranchId.value = branchId;
    loadData();
  }

  void setShiftFilter(int? shiftId) {
    selectedShiftFilter.value = shiftId;
    loadData();
  }

  void setSortBy(String sort) {
    sortBy.value = sort;
  }

  void onSearchChanged(String query) {
    searchQuery.value = query;
  }

  void clearSearch() {
    searchQuery.value = '';
    searchController.clear();
  }

  List<WorkerMonthlyCommitment> get filteredWorkers {
    var list = workers.toList();

    // البحث بالاسم
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((w) => w.fullName.toLowerCase().contains(q)).toList();
    }

    // الفرز
    switch (sortBy.value) {
      case 'attendance':
        list.sort((a, b) => b.attendanceRate.compareTo(a.attendanceRate));
        break;
      case 'hygiene':
        list.sort((a, b) => b.avgHygieneScore.compareTo(a.avgHygieneScore));
        break;
      case 'name':
        list.sort((a, b) => a.fullName.compareTo(b.fullName));
        break;
      case 'commitment':
      default:
        list.sort((a, b) {
          int cmp = b.compositeCommitmentScore.compareTo(a.compositeCommitmentScore);
          if (cmp != 0) return cmp;
          return b.daysPresent.compareTo(a.daysPresent);
        });
        break;
    }

    return list;
  }

  String get currentMonthName {
    const monthNames = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    final m = selectedMonth.value;
    final y = selectedYear.value;
    if (m >= 1 && m <= 12) {
      return '${monthNames[m - 1]} $y';
    }
    return '$m / $y';
  }

  String get currentBranchName {
    final bId = UserSessionService.to.isBranchRestricted
        ? UserSessionService.to.effectiveBranchFilter
        : selectedBranchId.value;
    if (bId == 2) return 'مصنع سنحان';
    if (bId == 1) return 'مصنع أرتل';
    return 'كافة المصانع';
  }

  Future<void> exportPdf() async {
    isPdfLoading.value = true;
    try {
      final summary = kpiSummary.value ??
          WorkersCommitmentKPISummary(
            totalRegisteredWorkers: workers.length,
            totalAttendedWorkers: workers.where((w) => w.daysPresent > 0).length,
            avgAttendanceRate: 0,
            avgHygieneScore: 0,
            totalShiftsCovered: 0,
            targetWorkingDays: 0,
          );

      final supervisor = UserSessionService.to.currentUserName.value.isNotEmpty
          ? UserSessionService.to.currentUserName.value
          : 'مفتش الجودة';

      await WorkersCommitmentPdfGenerator.printMonthlyReport(
        year: selectedYear.value,
        month: selectedMonth.value,
        branchName: currentBranchName,
        workers: workers,
        kpiSummary: summary,
        supervisorName: supervisor,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر طباعة التقرير: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isPdfLoading.value = false;
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}

class DailyWorkersCommitmentView extends StatelessWidget {
  DailyWorkersCommitmentView({super.key});

  final controller = Get.put(DailyWorkersCommitmentController());

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      title: 'متابعة التزام العمالة اليومية والورديات',
      maxContentWidth: 1250,
      actions: [
        Obx(() => IconButton(
              icon: controller.isPdfLoading.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'تصدير التقرير الشهري PDF',
              onPressed: controller.isPdfLoading.value
                  ? null
                  : controller.exportPdf,
            )),
      ],
      body: Obx(() {
        if (controller.isLoading.value) {
          return const AppLoading(message: 'جاري احتساب سجلات التزام العمال والورديات...');
        }

        return RefreshIndicator(
          onRefresh: controller.loadAll,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterHeader(context, isDark),
                const SizedBox(height: 16),
                _buildKPISummary(context, isDark),
                const SizedBox(height: 16),
                _buildSearchAndSortBar(context, isDark),
                const SizedBox(height: 16),
                _buildWorkersList(context, isDark),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFilterHeader(BuildContext context, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Month Navigator
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'الشهر القادم',
                onPressed: controller.nextMonth,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.canvas,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Obx(() => Text(
                          controller.currentMonthName,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? AppColors.darkInk : AppColors.primaryDark,
                          ),
                        )),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'الشهر السابق',
                onPressed: controller.prevMonth,
              ),
            ],
          ),

          // Branch Filter (if not restricted)
          if (!UserSessionService.to.isBranchRestricted)
            Obx(() => Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'المصنع: ',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? AppColors.darkInk : AppColors.ink,
                      ),
                    ),
                    _buildBranchChip(null, 'الكل', isDark),
                    _buildBranchChip(1, 'مصنع أرتل', isDark),
                    _buildBranchChip(2, 'مصنع سنحان', isDark),
                  ],
                )),

          // Shift Filter
          Obx(() => Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'الوردية: ',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? AppColors.darkInk : AppColors.ink,
                    ),
                  ),
                  _buildShiftFilterChip(null, 'الكل', isDark),
                  _buildShiftFilterChip(1, 'وردية 1 (صباحية)', isDark),
                  _buildShiftFilterChip(2, 'وردية 2 (مسائية)', isDark),
                  _buildShiftFilterChip(3, 'وردية 3 (ليلية)', isDark),
                ],
              )),
        ],
      ),
    );
  }

  Widget _buildBranchChip(int? branchId, String label, bool isDark) {
    final isSelected = controller.selectedBranchId.value == branchId;
    return InkWell(
      onTap: () => controller.setBranchFilter(branchId),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
              : (isDark ? AppColors.darkSurface : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
                : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? AppColors.darkMuted : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildShiftFilterChip(int? shiftId, String label, bool isDark) {
    final isSelected = controller.selectedShiftFilter.value == shiftId;
    return InkWell(
      onTap: () => controller.setShiftFilter(shiftId),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primaryMedium : AppColors.primaryDark)
              : (isDark ? AppColors.darkSurface : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
                : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkMuted : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildKPISummary(BuildContext context, bool isDark) {
    final kpi = controller.kpiSummary.value;
    if (kpi == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : (constraints.maxWidth > 550 ? 2 : 1);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth > 900 ? 2.1 : 2.4,
          children: [
            _buildKpiCard(
              title: 'العمال الحاضرون',
              value: '${kpi.totalAttendedWorkers}',
              subtitle: 'من أصل ${kpi.totalRegisteredWorkers} عامل مسجل',
              icon: Icons.people_alt_rounded,
              color: const Color(0xFF1B365D),
              isDark: isDark,
            ),
            _buildKpiCard(
              title: 'متوسط معدل الحضور',
              value: '${kpi.avgAttendanceRate}%',
              subtitle: 'المستهدف: ${kpi.targetWorkingDays} يوم عمل',
              icon: Icons.event_available_rounded,
              color: const Color(0xFF0D9488),
              isDark: isDark,
            ),
            _buildKpiCard(
              title: 'متوسط درجة النظافة',
              value: '${kpi.avgHygieneScore}%',
              subtitle: 'مشتق من تقارير الفحص اليومي',
              icon: Icons.clean_hands_rounded,
              color: const Color(0xFF2563EB),
              isDark: isDark,
            ),
            _buildKpiCard(
              title: 'إجمالي الورديات المنجزة',
              value: '${kpi.totalShiftsCovered}',
              subtitle: 'وردية عمل للعمالة اليومية',
              icon: Icons.schedule_rounded,
              color: const Color(0xFFD97706),
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: isDark ? AppColors.darkMuted : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkInk : AppColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    color: isDark ? AppColors.darkMuted : Colors.grey.shade500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSortBar(BuildContext context, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search Field
          SizedBox(
            width: 280,
            child: AppTextField(
              controller: controller.searchController,
              label: 'ابحث عن اسم العامل...',
              prefixIcon: Icons.search_rounded,
              onChanged: controller.onSearchChanged,
              suffixIcon: controller.searchQuery.value.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: controller.clearSearch,
                    )
                  : null,
            ),
          ),

          // Sorting Chips
          Obx(() => Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'الترتيب: ',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkMuted : Colors.grey.shade700,
                    ),
                  ),
                  _buildSortChip('commitment', 'الأعلى التزاماً 🏆', isDark),
                  _buildSortChip('attendance', 'الأكثر حضوراً 📅', isDark),
                  _buildSortChip('hygiene', 'الأعلى نظافة 🧼', isDark),
                  _buildSortChip('name', 'الأبجدي 🔤', isDark),
                ],
              )),
        ],
      ),
    );
  }

  Widget _buildSortChip(String key, String label, bool isDark) {
    final isSelected = controller.sortBy.value == key;
    return InkWell(
      onTap: () => controller.setSortBy(key),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
                : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? AppColors.darkMuted : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkersList(BuildContext context, bool isDark) {
    final workersList = controller.filteredWorkers;

    if (workersList.isEmpty) {
      return const AppEmptyState(
        title: 'لا توجد سجلات مطابقة',
        message: 'لم يتم العثور على أي عمالة مسجلة في هذا الشهر أو معايير البحث المحددة.',
        icon: Icons.person_search_rounded,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: workersList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final worker = workersList[index];
        return _buildWorkerCard(context, worker, isDark);
      },
    );
  }

  Widget _buildWorkerCard(
    BuildContext context,
    WorkerMonthlyCommitment worker,
    bool isDark,
  ) {
    final isTop3 = worker.rank <= 3 && worker.daysPresent > 0;
    Color rankColor;
    IconData rankIcon;
    if (worker.rank == 1 && worker.daysPresent > 0) {
      rankColor = const Color(0xFFD97706); // Gold
      rankIcon = Icons.emoji_events_rounded;
    } else if (worker.rank == 2 && worker.daysPresent > 0) {
      rankColor = const Color(0xFF64748B); // Silver
      rankIcon = Icons.military_tech_rounded;
    } else if (worker.rank == 3 && worker.daysPresent > 0) {
      rankColor = const Color(0xFFB45309); // Bronze
      rankIcon = Icons.workspace_premium_rounded;
    } else {
      rankColor = isDark ? AppColors.darkMuted : Colors.grey.shade400;
      rankIcon = Icons.tag_rounded;
    }

    Color scoreColor;
    if (worker.compositeCommitmentScore >= 85) {
      scoreColor = const Color(0xFF10B981);
    } else if (worker.compositeCommitmentScore >= 70) {
      scoreColor = const Color(0xFF2563EB);
    } else if (worker.compositeCommitmentScore >= 50) {
      scoreColor = const Color(0xFFF59E0B);
    } else {
      scoreColor = const Color(0xFFEF4444);
    }

    return InkWell(
      onTap: () => _openWorkerDetailsSheet(context, worker),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isTop3
                ? rankColor.withValues(alpha: 0.6)
                : (isDark ? AppColors.darkBorder : AppColors.border),
            width: isTop3 ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isTop3
                  ? rankColor.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Rank Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: rankColor.withValues(alpha: 0.4)),
                  ),
                  child: Center(
                    child: worker.daysPresent > 0
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(rankIcon, size: 16, color: rankColor),
                              Text(
                                '#${worker.rank}',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: rankColor,
                                ),
                              ),
                            ],
                          )
                        : Icon(Icons.person_outline_rounded,
                            size: 20, color: Colors.grey.shade400),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Job
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              worker.fullName,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkInk : AppColors.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isTop3) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: rankColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                worker.rank == 1
                                    ? 'الأعلى التزاماً 👑'
                                    : 'أفضل أداء ⭐',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: rankColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              worker.jobTitle,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkMuted
                                    : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${worker.branchName}',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.primaryLight
                                  : AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Composite Commitment Ring / Box
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border:
                        Border.all(color: scoreColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${worker.compositeCommitmentScore}%',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: scoreColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.military_tech_outlined,
                              size: 16, color: scoreColor),
                        ],
                      ),
                      Text(
                        'مؤشر الالتزام',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 9,
                          color: isDark
                              ? AppColors.darkMuted
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Badges Bar: Days Present, Shifts Breakdown, Hygiene Compliance
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildStatPill(
                  icon: Icons.calendar_today_rounded,
                  label:
                      'الحضور: ${worker.daysPresent} / ${worker.targetWorkingDays} يوم (${worker.attendanceRate}%)',
                  color: const Color(0xFF0284C7),
                  isDark: isDark,
                ),
                _buildStatPill(
                  icon: Icons.schedule_rounded,
                  label:
                      'وردية 1: ${worker.shift1Count} | وردية 2: ${worker.shift2Count} | وردية 3: ${worker.shift3Count}',
                  color: const Color(0xFF6366F1),
                  isDark: isDark,
                ),
                _buildStatPill(
                  icon: Icons.clean_hands_rounded,
                  label:
                      'النظافة: ${worker.avgHygieneScore}% ${worker.totalViolations > 0 ? "(${worker.totalViolations} مخالفة)" : "✅"}',
                  color: worker.totalViolations > 0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : color.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }

  void _openWorkerDetailsSheet(
    BuildContext context,
    WorkerMonthlyCommitment worker,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WorkerCommitmentDetailsSheet(worker: worker),
    );
  }
}

class _WorkerCommitmentDetailsSheet extends StatelessWidget {
  final WorkerMonthlyCommitment worker;

  const _WorkerCommitmentDetailsSheet({required this.worker});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Sheet Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          AppColors.primaryDark.withValues(alpha: 0.15),
                      child: Text(
                        worker.fullName.isNotEmpty
                            ? worker.fullName.substring(0, 1)
                            : 'ع',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            worker.fullName,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkInk : AppColors.ink,
                            ),
                          ),
                          Text(
                            '${worker.jobTitle} • ${worker.branchName}',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkMuted
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Body Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Quick Stats Summary
                    _buildQuickSummaryRow(isDark),
                    const SizedBox(height: 20),

                    // Visual Monthly Attendance Calendar
                    _buildMonthlyCalendarSection(isDark),
                    const SizedBox(height: 20),

                    // Shift Breakdown Cards
                    _buildShiftsBreakdownSection(isDark),
                    const SizedBox(height: 20),

                    // Daily Inspection Log
                    _buildInspectionLogSection(isDark),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickSummaryRow(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickStatItem(
            label: 'مؤشر الالتزام',
            value: '${worker.compositeCommitmentScore}%',
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
          _buildStatDivider(isDark),
          _buildQuickStatItem(
            label: 'أيام الحضور',
            value: '${worker.daysPresent} / ${worker.targetWorkingDays}',
            color: const Color(0xFF0284C7),
            isDark: isDark,
          ),
          _buildStatDivider(isDark),
          _buildQuickStatItem(
            label: 'مطابقة النظافة',
            value: '${worker.avgHygieneScore}%',
            color: const Color(0xFF6366F1),
            isDark: isDark,
          ),
          _buildStatDivider(isDark),
          _buildQuickStatItem(
            label: 'الرتبة في المصنع',
            value: worker.daysPresent > 0 ? '#${worker.rank}' : '-',
            color: const Color(0xFFD97706),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      width: 1,
      height: 32,
      color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
    );
  }

  Widget _buildQuickStatItem({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 10,
            color: isDark ? AppColors.darkMuted : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyCalendarSection(bool isDark) {
    // بناء مصفوفة أيام الشهر
    final daysInMonth = DateTime(worker.year, worker.month + 1, 0).day;
    final attendedDaysMap = <int, WorkerDailyAttendanceRecord>{};
    for (final record in worker.dailyRecords) {
      attendedDaysMap[record.date.day] = record;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'تقويم الحضور والورديات لشهر ${worker.month}/${worker.year}',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? AppColors.darkInk : AppColors.ink,
              ),
            ),
            Row(
              children: [
                _buildCalendarLegendDot(const Color(0xFF3B82F6), 'وردية 1'),
                const SizedBox(width: 8),
                _buildCalendarLegendDot(const Color(0xFF8B5CF6), 'وردية 2'),
                const SizedBox(width: 8),
                _buildCalendarLegendDot(const Color(0xFFEC4899), 'وردية 3'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.1,
            ),
            itemCount: daysInMonth,
            itemBuilder: (context, index) {
              final dayNumber = index + 1;
              final record = attendedDaysMap[dayNumber];
              final isAttended = record != null;

              Color dayBg;
              Color dayTextColor;
              Color borderColor;

              if (isAttended) {
                if (record.shiftId == 1) {
                  dayBg = const Color(0xFF3B82F6).withValues(alpha: 0.15);
                  dayTextColor = const Color(0xFF1D4ED8);
                  borderColor = const Color(0xFF3B82F6);
                } else if (record.shiftId == 2) {
                  dayBg = const Color(0xFF8B5CF6).withValues(alpha: 0.15);
                  dayTextColor = const Color(0xFF6D28D9);
                  borderColor = const Color(0xFF8B5CF6);
                } else {
                  dayBg = const Color(0xFFEC4899).withValues(alpha: 0.15);
                  dayTextColor = const Color(0xFFBE185D);
                  borderColor = const Color(0xFFEC4899);
                }
              } else {
                dayBg = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50;
                dayTextColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;
                borderColor = Colors.transparent;
              }

              return Container(
                decoration: BoxDecoration(
                  color: dayBg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: borderColor,
                    width: isAttended ? 1.5 : 0.5,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: isAttended ? FontWeight.bold : FontWeight.normal,
                        color: dayTextColor,
                      ),
                    ),
                    if (isAttended && !record.isFullCompliant)
                      const Positioned(
                        top: 2,
                        right: 2,
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 10,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildShiftsBreakdownSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'توزيع الورديات لهذا الشهر',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? AppColors.darkInk : AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildShiftCountCard(
                title: 'وردية 1 (صباحية)',
                count: worker.shift1Count,
                color: const Color(0xFF3B82F6),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildShiftCountCard(
                title: 'وردية 2 (مسائية)',
                count: worker.shift2Count,
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildShiftCountCard(
                title: 'وردية 3 (ليلية)',
                count: worker.shift3Count,
                color: const Color(0xFFEC4899),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShiftCountCard({
    required String title,
    required int count,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: isDark ? AppColors.darkMuted : Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '$count يوم',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionLogSection(bool isDark) {
    if (worker.dailyRecords.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سجل فحوصات النظافة اليومية (${worker.dailyRecords.length} فحص)',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? AppColors.darkInk : AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: worker.dailyRecords.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final record = worker.dailyRecords[index];
            final dateStr = DateFormat('yyyy-MM-dd').format(record.date);

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: record.isFullCompliant
                      ? (isDark ? AppColors.darkBorder : AppColors.border)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            record.isFullCompliant
                                ? Icons.check_circle_rounded
                                : Icons.warning_rounded,
                            size: 16,
                            color: record.isFullCompliant
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? AppColors.darkInk : AppColors.ink,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              record.shiftName,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.primaryLight
                                    : AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${record.compliantCriteria}/${record.totalCriteria} (${record.complianceScore.toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: record.isFullCompliant
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                  if (record.violationNotes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الملاحظات والإجراءات التصحيحية:',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...record.violationNotes.map(
                            (note) => Text(
                              '• $note',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11,
                                color: Color(0xFF78350F),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
