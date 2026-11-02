import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/factory_compliance_models.dart';
import '../services/factory_reports_compliance_service.dart';
import '../services/user_session_service.dart';
import '../utils/factory_reports_compliance_pdf_generator.dart';
import '../widgets/ds/ds.dart';

class FactoryReportsComplianceController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final selectedDate = DateTime.now().obs;
  final selectedBranchId = 1.obs; // 1 = أرتل، 2 = سنحان، 0 = كافة المصانع
  final isLoading = true.obs;

  final report = Rxn<FactoryDailyComplianceReport>();
  final multiSummary = Rxn<FactoryComplianceKPISummary>();

  late TabController tabController;

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 2, vsync: this);

    // ضبط الفرع بناءً على قيود المستخدم
    final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
    if (session != null && session.isBranchRestricted && session.assignedBranchId != null) {
      selectedBranchId.value = session.assignedBranchId!;
    }

    loadReportData();
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }

  Future<void> loadReportData() async {
    isLoading.value = true;
    try {
      final date = selectedDate.value;
      final bId = selectedBranchId.value;

      if (bId == 0) {
        final summary = await FactoryReportsComplianceService.instance
            .getMultiFactoryDailyCompliance(date: date);
        multiSummary.value = summary;
        // افتراضياً نعرض تقرير المصنع الأول مدمجاً أو الفرع الأول
        if (summary.branchReports.isNotEmpty) {
          report.value = summary.branchReports.first;
        }
      } else {
        final rep = await FactoryReportsComplianceService.instance
            .getFactoryDailyCompliance(date: date, branchId: bId);
        report.value = rep;
        multiSummary.value = null;
      }
    } catch (e) {
      debugPrint('Error loading compliance report: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void switchBranch(int branchId) {
    if (selectedBranchId.value == branchId) return;
    selectedBranchId.value = branchId;
    loadReportData();
  }

  void setDate(DateTime date) {
    selectedDate.value = date;
    loadReportData();
  }

  void setQuickDate(int daysAgo) {
    final now = DateTime.now();
    setDate(DateTime(now.year, now.month, now.day).subtract(Duration(days: daysAgo)));
  }

  Future<void> printReport() async {
    final rep = report.value;
    if (rep == null) return;

    try {
      final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
      final pdfBytes = await FactoryReportsCompliancePdfGenerator.generateDailyCompliancePdf(
        report: rep,
        printedBy: session?.currentUserName.value,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'تقرير_التزام_المصنع_${DateFormat('yyyy_MM_dd').format(rep.date)}.pdf',
      );
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر تصدير تقرير PDF: $e');
    }
  }
}

class FactoryReportsComplianceView extends StatelessWidget {
  const FactoryReportsComplianceView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(FactoryReportsComplianceController());
    final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
    final isRestricted = session?.isBranchRestricted ?? false;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCanvas : const Color(0xFFF4F7FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : const Color(0xFF003853),
          foregroundColor: Colors.white,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تحليل ومتابعة التزام المصانع',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  fontSize: 16.5,
                  color: Colors.white,
                ),
              ),
              Text(
                'رصد الفحوصات المنجزة، التكرارات، والتقارير المتخلفة لليوم',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 10.5,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'تصدير وطباعة التقرير الرسمي (PDF)',
              onPressed: controller.printReport,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث البيانات',
              onPressed: controller.loadReportData,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            // 1. شريط التحكم الزمني واختيار المصنع
            _buildTopControlBar(context, controller, isRestricted),

            // 2. المحتوى الرئيسي
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF007791)),
                  );
                }

                final rep = controller.report.value;
                if (rep == null) {
                  return const Center(
                    child: Text('لا توجد بيانات متاحة لهذا التاريخ'),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // بطاقة ملخص الالتزام الشامل
                          _buildExecutiveSummaryBanner(context, controller, rep),
                          const SizedBox(height: 14),

                          // بطاقات المؤشرات الرقمية KPIs
                          _buildKpiGrid(context, rep),
                          const SizedBox(height: 16),

                          // شريط التبويب
                          _buildTabSelector(context, controller, rep),
                          const SizedBox(height: 14),

                          // محتوى التبويب المختار
                          _buildTabContent(context, controller, rep),
                        ],
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

  Widget _buildTopControlBar(
    BuildContext context,
    FactoryReportsComplianceController controller,
    bool isRestricted,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              // اختيار المصنع (إذا لم يكن المستخدم مقيداً بفرع)
              if (!isRestricted) ...[
                Obx(() {
                  final sel = controller.selectedBranchId.value;
                  return Row(
                    children: [
                      Expanded(
                        child: _buildBranchButton(
                          title: 'مصنع أرتل (الرئيسي)',
                          icon: Icons.factory_rounded,
                          isSelected: sel == 1,
                          onTap: () => controller.switchBranch(1),
                          color: const Color(0xFF007791),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildBranchButton(
                          title: 'مصنع سنحان (الثاني)',
                          icon: Icons.factory_outlined,
                          isSelected: sel == 2,
                          onTap: () => controller.switchBranch(2),
                          color: const Color(0xFF8E24AA),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 10),
              ],

              // محدد التاريخ السريع
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 16, color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimaryLight : const Color(0xFF003853)),
                  const SizedBox(width: 8),
                  Obx(() {
                    final date = controller.selectedDate.value;
                    final isToday = _isSameDay(date, DateTime.now());
                    final isYesterday = _isSameDay(date, DateTime.now().subtract(const Duration(days: 1)));

                    return Row(
                      children: [
                        _buildQuickDateChip(
                          label: 'اليوم',
                          isSelected: isToday,
                          onTap: () => controller.setQuickDate(0),
                        ),
                        const SizedBox(width: 6),
                        _buildQuickDateChip(
                          label: 'الأمس',
                          isSelected: isYesterday,
                          onTap: () => controller.setQuickDate(1),
                        ),
                      ],
                    );
                  }),
                  const Spacer(),
                  Obx(() {
                    final date = controller.selectedDate.value;
                    final dateFormatted = DateFormat('yyyy/MM/dd', 'en_US').format(date);
                    return OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2023),
                          lastDate: DateTime.now(),
                          locale: const Locale('ar', 'SA'),
                        );
                        if (picked != null) {
                          controller.setDate(picked);
                        }
                      },
                      icon: const Icon(Icons.event_rounded, size: 14),
                      label: Text(
                        dateFormatted,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimaryLight : const Color(0xFF003853),
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBranchButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    final isDark = (Get.context != null && Theme.of(Get.context!).brightness == Brightness.dark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? const Color(0xFF131D2E) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color : (isDark ? AppColors.darkBorder : Colors.grey.shade300)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : (isDark ? AppColors.darkMuted : Colors.grey.shade700)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : (isDark ? AppColors.darkInk : Colors.grey.shade800),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDateChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = (Get.context != null && Theme.of(Get.context!).brightness == Brightness.dark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.darkPrimary : const Color(0xFF003853))
              : (isDark ? const Color(0xFF1E2B3E) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.darkPrimary : const Color(0xFF003853))
                : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkMuted : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveSummaryBanner(
    BuildContext context,
    FactoryReportsComplianceController controller,
    FactoryDailyComplianceReport rep,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: Theme.of(context).brightness == Brightness.dark ? const [Color(0xFF0369A1), Color(0xFF0EA5E9)] : const [Color(0xFF002B40), Color(0xFF004D6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF003853).withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            rep.branchName,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            rep.complianceGrade,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تاريخ الرصد: ${DateFormat('yyyy/MM/dd', 'en_US').format(rep.date)} • إجمالي الفحوصات: ${rep.totalInspectionsCount} فحصاً منجزاً',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        color: Colors.white70,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${rep.complianceRate.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64FFDA),
                    ),
                  ),
                  const Text(
                    'نسبة الالتزام',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 10.5,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (rep.missedReportsCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF8A80), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تنبيه إداري: يوجد ${rep.missedReportsCount} تقارير وفحوصات مفعلة لم يُسجل لها المصنع أي إدخال اليوم.',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
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
  }

  Widget _buildKpiGrid(BuildContext context, FactoryDailyComplianceReport rep) {
    final isWide = MediaQuery.of(context).size.width > 700;

    final card1 = _buildKpiCard(context: context,
      title: 'التقارير المقررة',
      value: '${rep.totalActiveReports}',
      subtitle: 'نماذج مفعلة بالنظام',
      icon: Icons.checklist_rtl_rounded,
      color: const Color(0xFF003853),
    );

    final card2 = _buildKpiCard(context: context,
      title: 'التقارير المنجزة',
      value: '${rep.executedReportsCount}',
      subtitle: 'تم عملها اليوم',
      icon: Icons.check_circle_rounded,
      color: const Color(0xFF2E7D32),
    );

    final card3 = _buildKpiCard(context: context,
      title: 'التقارير المتخلفة',
      value: '${rep.missedReportsCount}',
      subtitle: 'لم يقم بها المصنع',
      icon: Icons.cancel_rounded,
      color: rep.missedReportsCount > 0 ? const Color(0xFFC62828) : Colors.grey,
    );

    final card4 = _buildKpiCard(context: context,
      title: 'إجمالي الفحوصات (التكرار)',
      value: '${rep.totalInspectionsCount}',
      subtitle: 'سجلات منشأة اليوم',
      icon: Icons.repeat_rounded,
      color: const Color(0xFF007791),
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: card1),
          const SizedBox(width: 10),
          Expanded(child: card2),
          const SizedBox(width: 10),
          Expanded(child: card3),
          const SizedBox(width: 10),
          Expanded(child: card4),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: 10),
            Expanded(child: card2),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: card3),
            const SizedBox(width: 10),
            Expanded(child: card4),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = (color == const Color(0xFF003853) && isDark) ? AppColors.darkPrimaryLight : color;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: effectiveColor.withValues(alpha: isDark ? 0.35 : 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.04 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: effectiveColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: effectiveColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkInk : effectiveColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 10,
              color: isDark ? AppColors.darkMuted : Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector(
    BuildContext context,
    FactoryReportsComplianceController controller,
    FactoryDailyComplianceReport rep,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D2E) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: controller.tabController,
        indicator: BoxDecoration(
          color: isDark ? AppColors.darkPrimary : const Color(0xFF003853),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? AppColors.darkMuted : Colors.grey.shade700,
        labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12.5),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
        tabs: [
          Tab(
            text: 'التقارير المنجزة اليوم (${rep.executedReportsCount})',
            icon: const Icon(Icons.task_alt_rounded, size: 16),
          ),
          Tab(
            text: 'التقارير المتخلفة (${rep.missedReportsCount})',
            icon: const Icon(Icons.error_outline_rounded, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    FactoryReportsComplianceController controller,
    FactoryDailyComplianceReport rep,
  ) {
    return AnimatedBuilder(
      animation: controller.tabController,
      builder: (context, _) {
        if (controller.tabController.index == 0) {
          return _buildExecutedReportsList(context, rep.executedReports);
        } else {
          return _buildMissedReportsList(context, rep.missedReports);
        }
      },
    );
  }

  Widget _buildExecutedReportsList(BuildContext context, List<ReportExecutionDetail> list) {
    if (list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Column(
          children: [
            Icon(Icons.assignment_late_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'لم يتم تسجيل أي فحص لهذا المصنع في هذا اليوم.',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final item = list[i];
        return _buildExecutedReportCard(context, item);
      },
    );
  }

  Widget _buildExecutedReportCard(BuildContext context, ReportExecutionDetail item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = item.lastExecutionTime != null
        ? DateFormat('hh:mm a', 'en_US').format(item.lastExecutionTime!)
        : '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFF007791).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.04 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.sourceType.color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.sourceType.icon, color: item.sourceType.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.reportName,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkInk : const Color(0xFF003853),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.departmentName,
                            style: TextStyle(fontFamily: 'Tajawal', fontSize: 9.5, color: Colors.grey.shade700),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: item.sourceType.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.sourceType.label,
                            style: TextStyle(fontFamily: 'Tajawal', fontSize: 9.5, fontWeight: FontWeight.bold, color: item.sourceType.color),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkPrimary : const Color(0xFF003853),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      '${item.executionCount} مرات',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'أُنشئ اليوم',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 8.5,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        item.shiftsCovered.isNotEmpty
                            ? item.shiftsCovered.join(' • ')
                            : 'وردية صباحية',
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: isDark ? AppColors.darkMuted : Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 13, color: isDark ? AppColors.darkMuted : Colors.grey),
                  const SizedBox(width: 3),
                  Text(
                    'آخر فحص: $timeStr',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: isDark ? AppColors.darkMuted : Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMissedReportsList(BuildContext context, List<ReportExecutionDetail> list) {
    if (list.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF059669).withValues(alpha: 0.5) : const Color(0xFFA5D6A7)),
        ),
        child: Column(
          children: [
            Icon(Icons.verified_rounded, size: 48, color: isDark ? const Color(0xFF34D399) : const Color(0xFF2E7D32)),
            const SizedBox(height: 10),
            Text(
              'التزام مثالي بنسبة 100%!',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF34D399) : const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'قام المصنع بإجراء كافة الفحوصات والتقارير المفعلة في النظام لليوم دون أي تقصير.',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF2E7D32)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final item = list[i];
        return _buildMissedReportCard(context, item);
      },
    );
  }

  Widget _buildMissedReportCard(BuildContext context, ReportExecutionDetail item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF381215) : const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFFEF4444).withValues(alpha: 0.4) : const Color(0xFFFFA39E)),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF5C1D24) : const Color(0xFFFFCDD2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close_rounded, color: isDark ? const Color(0xFFFF8A80) : const Color(0xFFC62828), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.reportName,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFFF8A80) : const Color(0xFFC62828),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      'القسم: ${item.departmentName}',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: isDark ? const Color(0xFFFCA5A5) : Colors.red.shade900),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• النوع: ${item.sourceType.label}',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: isDark ? AppColors.darkMuted : Colors.grey.shade700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFC62828),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'متخلّف ⚠️',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
