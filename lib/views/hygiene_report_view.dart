import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../controllers/hygiene_report_controller.dart';
import '../models/hygiene_models.dart';
import '../services/user_session_service.dart';
import '../services/worker_database_service.dart';
import '../widgets/ds/ds.dart';

class HygieneReportView extends StatelessWidget {
  HygieneReportView({super.key});

  final HygieneReportController controller = Get.put(HygieneReportController());

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (controller.isReportOpen.value) {
          controller.isReportOpen.value = false;
        } else {
          Get.back();
        }
      },
      child: AppScaffold(
        title: 'تقرير النظافة الشخصية',
        maxContentWidth: 1200,
        leading: IconButton(
          icon: const BackButtonIcon(),
          onPressed: () {
            if (controller.isReportOpen.value) {
              controller.isReportOpen.value = false;
            } else {
              Get.back();
            }
          },
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const AppLoading(message: 'جاري تحميل تقرير النظافة...');
          }

          if (!controller.isReportOpen.value) {
            return _buildEmptyState(context);
          }

          return Column(
            children: [
              _buildToolbar(context),
              Expanded(
                child: AppCard(
                  margin: const EdgeInsets.all(16.0),
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildDataTable(context),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton.outlined(
                        label: 'حفظ كمسودة',
                        icon: Icons.save_outlined,
                        height: 52,
                        onPressed: () async {
                          if (await controller.archiveDraft()) {
                            controller.isReportOpen.value = false;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton.primary(
                        label: 'إنهاء وحفظ',
                        icon: Icons.check_circle_rounded,
                        height: 52,
                        onPressed: controller.saveReport,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 92,
                width: 92,
                decoration: BoxDecoration(
                  color: AppColors.primaryLightest.withValues(alpha: isDark ? 0.15 : 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.clean_hands_rounded,
                  size: 46,
                  color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'فحص النظافة الشخصية',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkInk : AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ابدأ تقريرًا جديدًا أو استكمل إحدى المسودات السابقة أدناه.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  color: isDark ? AppColors.darkMuted : Colors.grey,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 26),
              AppButton.primary(
                label: 'بدء تقرير جديد',
                icon: Icons.add_rounded,
                height: 54,
                width: 240,
                onPressed: controller.startNewReport,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              Icon(
                Icons.drafts_outlined,
                size: 18,
                color: isDark ? AppColors.darkMuted : Colors.grey,
              ),
              const SizedBox(width: 8),
              Obx(() => Text(
                'المسودات المؤقتة (${controller.drafts.length})',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? AppColors.darkMuted : Colors.grey,
                ),
              )),
            ],
          ),
        ),
        const Divider(height: 20),
        Expanded(
          child: Obx(() {
            if (controller.drafts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 36,
                      color: isDark ? AppColors.darkMuted : Colors.grey.shade300,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'لا توجد مسودات حالياً',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: isDark ? AppColors.darkMuted : Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: controller.drafts.length,
              itemBuilder: (context, index) {
                final draft = controller.drafts[index];
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  onTap: () => controller.restoreDraft(draft),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.edit_document, color: Colors.amber.shade800),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              draft.employeeNames,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? AppColors.darkInk : AppColors.ink,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'آخر حفظ: ${DateFormat('yyyy-MM-dd HH:mm').format(draft.savedAt)}',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                color: isDark ? AppColors.darkMuted : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (UserSessionService.to.canDeleteReports)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppButton.dangerColor),
                          tooltip: 'حذف المسودة',
                          onPressed: () => controller.deleteDraft(draft.id),
                        ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isDark ? AppColors.darkMuted : AppColors.muted,
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.canvas,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 15,
                      color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تاريخ الفحص: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              Obx(() => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.canvas,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: Color(0xFF0D9488),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'الوردية الحالية: ${controller.selectedShiftName.value}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
          const SizedBox(height: 12),
          _buildWorkerAutocomplete(),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppButton.primary(
              label: 'تحديد الكل مطابق',
              icon: Icons.done_all_rounded,
              color: AppColors.success,
              onPressed: controller.setAllCompliant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerAutocomplete() {
    final branchId = Get.isRegistered<UserSessionService>()
        ? (UserSessionService.to.assignedBranchId ?? 1)
        : 1;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RawAutocomplete<DailyWorker>(
        textEditingController: controller.employeeNameController,
        focusNode: FocusNode(),
        displayStringForOption: (worker) => worker.fullName,
        optionsBuilder: (textEditingValue) async {
          final query = textEditingValue.text;
          if (query.trim().isEmpty) return const Iterable<DailyWorker>.empty();
          return await WorkerDatabaseService.instance
              .searchWorkers(query, branchId: branchId);
        },
        onSelected: (worker) {
          controller.addSelectedWorker(worker);
        },
        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
          return AppTextField(
            controller: textEditingController,
            focusNode: focusNode,
            textDirection: TextDirection.rtl,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) async {
              final name = value.trim();
              if (name.isEmpty) return;
              await controller.addNewWorker(name);
            },
            label: 'اكتب اسم العامل لاختياره من السجل',
            prefixIcon: Icons.person_search_rounded,
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topCenter,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: AppPanel(
                radius: AppTheme.radiusMd,
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: options.toList().isEmpty
                          ? _buildNoSuggestionsState(controller.employeeNameController.text)
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: options.toList().length,
                              itemBuilder: (context, index) {
                                final worker = options.toList()[index];
                                return ListTile(
                                  dense: true,
                                  leading: const CircleAvatar(
                                    backgroundColor: AppColors.primaryLightest,
                                    child: Icon(Icons.person_rounded,
                                        size: 18, color: AppColors.primaryDark),
                                  ),
                                  title: Text(
                                    worker.fullName,
                                    style: const TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    '${worker.jobTitle} | ${_branchName(worker.branchId)}',
                                    style: const TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 11,
                                        color: AppColors.muted),
                                  ),
                                  trailing: const Icon(Icons.check_circle_outline_rounded,
                                      color: AppColors.success, size: 18),
                                  onTap: () => onSelected(worker),
                                );
                              },
                            ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      tileColor: AppColors.primaryLightest.withValues(alpha: 0.3),
                      leading: const Icon(Icons.person_add_alt_1_rounded,
                          color: AppColors.primaryDark),
                      title: Text(
                        controller.employeeNameController.text.trim().isEmpty
                            ? 'إضافة عامل جديد للسجل'
                            : 'إضافة "${controller.employeeNameController.text.trim()}" كعامل جديد',
                        style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.primaryDark),
                      ),
                      onTap: () async {
                        final name = controller.employeeNameController.text.trim();
                        await controller.addNewWorker(name);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoSuggestionsState(String query) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 32, color: AppColors.muted),
          const SizedBox(height: 8),
          Text(
            query.trim().isEmpty
                ? 'ابدأ بكتابة اسم العامل'
                : 'لا يوجد عامل بهذا الاسم في السجل',
            style: const TextStyle(
                fontFamily: AppTheme.fontFamily, fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  String _branchName(int? branchId) {
    if (branchId == 2) return 'مصنع سنحان';
    return 'مصنع أرتل';
  }

  Widget _buildDataTable(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: isDark ? AppColors.darkBorder : AppColors.border,
        dataTableTheme: DataTableThemeData(
          headingRowColor: WidgetStateProperty.all(
            isDark
                ? AppColors.primaryMedium.withValues(alpha: 0.15)
                : AppColors.primaryMedium.withValues(alpha: 0.08),
          ),
          dataRowMinHeight: 72,
          dataRowMaxHeight: 96,
        ),
      ),
      child: DataTable(
        columnSpacing: 20,
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
          fontFamily: AppTheme.fontFamily,
        ),
        columns: [
          const DataColumn(label: Text('اسم الموظف')),
          ...controller.criteria.map(
            (c) => DataColumn(
              label: SizedBox(
                width: 80,
                child: Text(
                  c.itemName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ),
          const DataColumn(label: Text('الإجراء التصحيحي')),
        ],
        rows: _buildAllEmployees()
            .map((emp) => _buildDataRow(context, emp, isDark))
            .toList(),
      ),
    );
  }

  List<Employee> _buildAllEmployees() => controller.allEmployees;

  DataRow _buildDataRow(BuildContext context, Employee emp, bool isDark) {
    return DataRow(
      cells: [
        // Employee Name
        DataCell(
          SizedBox(
            width: 120,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        emp.fullName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: AppTheme.fontFamily,
                          color: isDark ? AppColors.darkInk : AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        emp.jobTitle,
                        style: TextStyle(
                          color: isDark ? AppColors.darkMuted : Colors.grey.shade600,
                          fontSize: 11,
                          fontFamily: AppTheme.fontFamily,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (emp.databaseWorkerId != null) {
                      final worker = controller.selectedWorkers
                          .firstWhereOrNull((w) => w.id == emp.databaseWorkerId);
                      if (worker != null) {
                        controller.removeSelectedWorker(worker);
                        return;
                      }
                    }
                    controller.removeEmployee(emp);
                  },
                  tooltip: 'حذف الموظف',
                  icon: const Icon(Icons.close_rounded, color: AppButton.dangerColor, size: 18),
                ),
              ],
            ),
          ),
        ),

        // Criteria Cells
        ...controller.criteria.map(
          (crit) => DataCell(
            Center(
              child: Obx(() {
                final key = '${emp.id}_${crit.id}';
                final isCompliant = controller.complianceMatrix[key];

                Color bgColor = isDark ? AppColors.darkSurface : Colors.grey.shade100;
                Color iconColor = isDark ? AppColors.darkMuted : Colors.grey.shade400;
                IconData icon = Icons.circle_outlined;

                if (isCompliant == true) {
                  bgColor = Colors.green.withValues(alpha: 0.15);
                  iconColor = AppColors.success;
                  icon = Icons.check_circle_rounded;
                } else if (isCompliant == false) {
                  bgColor = AppButton.dangerColor.withValues(alpha: 0.15);
                  iconColor = AppButton.dangerColor;
                  icon = Icons.cancel_rounded;
                }

                return InkWell(
                  onTap: () => controller.toggleCell(emp.id!, crit.id!),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCompliant == null
                            ? (isDark ? AppColors.darkBorder : Colors.grey.shade300)
                            : iconColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Icon(icon, color: iconColor, size: 26),
                  ),
                );
              }),
            ),
          ),
        ),

        // Corrective Action Cell
        DataCell(
          Obx(() {
            final hasViolation = controller.hasViolation(emp.id!);
            final correctiveText = controller.correctiveActions[emp.id!];

            if (!hasViolation) {
              return Center(
                child: Text('-', style: TextStyle(color: isDark ? AppColors.darkMuted : Colors.grey)),
              );
            }

            final isEmpty = correctiveText == null || correctiveText.trim().isEmpty;

            return InkWell(
              onTap: () => _showCorrectiveActionDialog(context, emp),
              child: Container(
                width: 140,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: isEmpty
                      ? AppButton.dangerColor.withValues(alpha: 0.1)
                      : AppColors.primaryLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isEmpty
                        ? AppButton.dangerColor.withValues(alpha: 0.3)
                        : AppColors.primaryLight.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isEmpty ? Icons.edit_note_rounded : Icons.check_rounded,
                      color: isEmpty ? AppButton.dangerColor : AppColors.primaryDark,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isEmpty ? 'أدخل الإجراء...' : correctiveText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: AppTheme.fontFamily,
                          color: isEmpty ? AppButton.dangerColor : (isDark ? AppColors.darkInk : AppColors.primaryDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  void _showCorrectiveActionDialog(BuildContext context, Employee emp) {
    final textController = TextEditingController(
      text: controller.correctiveActions[emp.id!],
    );

    AppDialog.show(
      title: 'الإجراء التصحيحي - ${emp.fullName}',
      icon: Icons.rule_folder_rounded,
      content: AppTextField(
        controller: textController,
        maxLines: 3,
        label: 'الإجراء المتخذ',
        hint: 'ما التصرف الذي قمت به لتصحيح الوضع؟',
      ),
      actions: [
        AppButton.text(label: 'إلغاء', onPressed: () => Get.back()),
        AppButton.primary(
          label: 'حفظ',
          onPressed: () {
            controller.saveCorrectiveAction(emp.id!, textController.text);
            Get.back();
          },
        ),
      ],
    );
  }
}
