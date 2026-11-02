import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../controllers/raw_water_entry_controller.dart';
import '../models/standards_models.dart';
import '../widgets/ds/ds.dart';
import '../widgets/wavy_header.dart';

class RawWaterEntryPage extends StatelessWidget {
  RawWaterEntryPage({super.key});

  final RawWaterEntryController controller = Get.put(RawWaterEntryController());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: isDark ? theme.scaffoldBackgroundColor : AppColors.primaryLightest,
          body: Stack(
            children: [
              // Wavy Background
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 300,
                child: Stack(
                  children: [
                    ClipPath(
                      clipper: BackgroundClipper(),
                      child: Container(
                        height: 300,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primaryMedium.withValues(alpha: 0.5),
                              AppColors.primaryLightest.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ClipPath(
                      clipper: MainClipper(),
                      child: Container(
                        height: 270,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primaryDark,
                              AppColors.primaryMedium,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Header Content
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                          onPressed: () {
                            if (controller.isFormVisible.value) {
                              controller.isFormVisible.value = false;
                            } else {
                              Get.back();
                            }
                          },
                        ),
                        const Text(
                          'فحص المياه الخام',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        Obx(() => controller.isFormVisible.value
                            ? const SizedBox(width: 48)
                            : IconButton(
                                icon: const Icon(Icons.add, color: Colors.white),
                                tooltip: 'إضافة تقرير جديد',
                                onPressed: () {
                                  controller.startNewReport();
                                },
                              )),
                      ],
                    ),
                  ),
                ),
              ),

              // Main Content
              Positioned.fill(
                top: 100,
                child: Obx(() => controller.isFormVisible.value ? _buildForm(context) : _buildDraftsList(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildResponsiveGrid(BuildContext context, List<Widget> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 550;
        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: items.map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w)).toList(),
          );
        }
        final itemWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 12,
          children: items.map((w) => SizedBox(width: itemWidth, child: w)).toList(),
        );
      },
    );
  }

  Widget _buildStickyBottomActionBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 620;

            Widget buildStatsInfo() {
              return Obx(() {
                final total = controller.standards.length;
                int filled = 0;
                int nonCompliant = 0;
                for (var s in controller.standards) {
                  final val = controller.formValidations[s.parameterId]?.value;
                  if (val != null) filled++;
                  if (val == false) nonCompliant++;
                }

                if (isCompact) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'المعايير المكتملة: $filled من $total',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (nonCompliant > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Text(
                            '⚠️ $nonCompliant غير مطابق',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              color: Colors.red.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                          ),
                        )
                      else if (filled == total && total > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Text(
                            '✅ كافة المعايير مطابقة',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              color: Colors.green.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                          ),
                        )
                      else
                        Text(
                          'جاري فحص العينات...',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المعايير المكتملة: $filled من $total',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (nonCompliant > 0)
                      Text(
                        '⚠️ يوجد $nonCompliant غير مطابق',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          color: Colors.red.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else if (filled == total && total > 0)
                      Text(
                        '✅ كافة المعايير مطابقة',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          color: Colors.green.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        'جاري فحص العينات...',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                );
              });
            }

            if (isCompact) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildStatsInfo(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Obx(() => AppButton.outlined(
                          label: 'حفظ مسودة',
                          icon: Icons.save_outlined,
                          height: 44,
                          foregroundColor: Colors.blue.shade700,
                          color: Colors.blue.shade400,
                          onPressed: controller.isSaving.value ? null : controller.saveAsDraft,
                        )),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Obx(() => AppButton.primary(
                          label: 'رفع للاعتماد',
                          icon: Icons.send_rounded,
                          height: 44,
                          color: AppColors.primaryDark,
                          isLoading: controller.isSaving.value,
                          onPressed: controller.isSaving.value ? null : controller.submitForm,
                        )),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: buildStatsInfo()),
                const SizedBox(width: 16),
                Obx(() => AppButton.outlined(
                  label: 'حفظ مسودة',
                  icon: Icons.save_outlined,
                  foregroundColor: Colors.blue.shade700,
                  color: Colors.blue.shade400,
                  onPressed: controller.isSaving.value ? null : controller.saveAsDraft,
                )),
                const SizedBox(width: 10),
                Obx(() => AppButton.primary(
                  label: 'رفع للاعتماد',
                  icon: Icons.send_rounded,
                  color: AppColors.primaryDark,
                  isLoading: controller.isSaving.value,
                  onPressed: controller.isSaving.value ? null : controller.submitForm,
                )),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Obx(() {
            if (controller.isLoading.value) {
              return const AppLoading(message: 'جاري تحميل نموذج المياه الخام...');
            }

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 24.0, bottom: 120.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Rejection Notice
                  if (controller.currentRejectionReason.value.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ملاحظة الرفض${controller.currentRejectedBy.value.isNotEmpty ? " (من: ${controller.currentRejectedBy.value})" : " من الإدارة"}:',
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  controller.currentRejectionReason.value,
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Section 1: Sample Data Card
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('بيانات العينة', Icons.water_drop_outlined, AppColors.primaryDark),
                        const SizedBox(height: 16),
                        const Text('تحديد الوردية *', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        _buildShiftSelector(),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: controller.waterSourceController,
                                label: 'مصدر المياه',
                                hint: 'مثال: بئر',
                                prefixIcon: Icons.source,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppTextField(
                                controller: controller.wellNumberController,
                                label: 'رقم البئر',
                                hint: 'مثال: 12',
                                prefixIcon: Icons.numbers,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        AppTextField(
                          controller: controller.sampleTakerController,
                          label: 'اسم آخذ العينة',
                          hint: 'اسم الموظف',
                          prefixIcon: Icons.person_outline,
                        ),
                        const SizedBox(height: 12),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: controller.batchNumberController,
                                label: 'رقم العينة / الدفعة *',
                                hint: 'RW231015',
                                prefixIcon: Icons.tag,
                              ),
                            ),
                            const SizedBox(width: 10),
                            AppButton.outlined(
                              label: 'توليد تلقائي',
                              icon: Icons.autorenew,
                              foregroundColor: AppColors.primaryDark,
                              color: AppColors.primaryLight,
                              onPressed: controller.generateBatchNumber,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        AppTextField(
                          controller: controller.notesController,
                          label: 'ملاحظات عامة',
                          hint: 'أضف ملاحظاتك هنا...',
                          maxLines: 2,
                          prefixIcon: Icons.comment_outlined,
                        ),
                      ],
                    ),
                  ),

                  // Section 2: Sensory Standards
                  if (controller.sensoryStandards.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('الفحص الحسي', Icons.visibility_outlined, Colors.teal),
                          const SizedBox(height: 14),
                          _buildResponsiveGrid(
                            context,
                            controller.sensoryStandards.map((std) => _buildSensoryToggleField(context, std)).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Section 3: Physico-Chemical Tests
                  if (controller.physioChemicalStandards.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('الفحوصات الفيزيائية والكيميائية', Icons.science_outlined, Colors.indigo),
                          const SizedBox(height: 14),
                          _buildResponsiveGrid(
                            context,
                            controller.physioChemicalStandards.map((std) => _buildParameterField(std)).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Section 4: Microbiological Tests
                  if (controller.microbiologicalStandards.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('الفحوصات الميكروبيولوجية', Icons.biotech_outlined, Colors.teal.shade800),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F7FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.teal.shade800, size: 20),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'اختياري عند الرفع — نتائج الفحص الميكروبيولوجي تصل خلال 24 ساعة. '
                                    'إذا تُركت فارغة، يُعتمد التقرير مبدئياً وتُكمل النتائج لاحقاً بجولة اعتماد ثانية.',
                                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Color(0xFF006064), height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildResponsiveGrid(
                            context,
                            controller.microbiologicalStandards.map((std) => _buildParameterField(std)).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Section 5: Compliance Banner and Decision
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: _buildComplianceSection(),
                  ),

                  const SizedBox(height: 24),

                  // Submit Actions
                  Row(
                    children: [
                      Expanded(
                        child: Obx(() => AppButton.outlined(
                          label: 'حفظ كمسودة',
                          icon: Icons.save_as_outlined,
                          foregroundColor: AppColors.primaryDark,
                          color: AppColors.primaryDark,
                          onPressed: controller.isSaving.value ? null : controller.saveAsDraft,
                        )),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: Obx(() => AppButton.primary(
                          label: 'رفع للاعتماد',
                          icon: Icons.send_rounded,
                          color: AppColors.primaryDark,
                          isLoading: controller.isSaving.value,
                          onPressed: controller.isSaving.value ? null : controller.submitForm,
                        )),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildStickyBottomActionBar(context),
            ),
          ],
        );
      }),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 15, color: color),
        ),
      ],
    );
  }

  Widget _buildShiftSelector() {
    return Obx(() {
      final shifts = controller.shifts;
      if (shifts.isEmpty) return const SizedBox.shrink();

      return Row(
        children: shifts.map((shift) {
          return Obx(() {
            final isSelected = controller.selectedShiftObj.value?.id == shift.id;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => controller.selectShift(shift),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryDark : AppColors.primaryLightest,
                      border: Border.all(
                        color: isSelected ? AppColors.primaryDark : Colors.grey.shade300,
                        width: isSelected ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      shift.name,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            );
          });
        }).toList(),
      );
    });
  }

  Widget _buildSensoryToggleField(BuildContext context, QualityStandard std) {
    final param = controller.getParameterDetails(std.parameterId);
    if (param == null) return const SizedBox.shrink();

    if (param.inputType == 'Numeric') {
      return _buildParameterField(std);
    }

    final expected = (std.expectedText != null && std.expectedText!.isNotEmpty)
        ? std.expectedText!
        : 'طبيعي';

    return Obx(() {
      final currentVal = controller.formControllers[std.parameterId]?.text ?? '';
      final hasValue = currentVal.isNotEmpty;
      final isCompliant = hasValue && (currentVal.toLowerCase() == expected.toLowerCase());
      final isNotCompliant = hasValue && !isCompliant;
      final isNoteVis = controller.isNoteVisible[std.parameterId]?.value ?? false;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: !hasValue
              ? Colors.grey.withValues(alpha: 0.04)
              : (isCompliant
                  ? Colors.green.withValues(alpha: 0.08)
                  : Colors.red.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: !hasValue
                ? Colors.grey.shade200
                : (isCompliant ? Colors.green.shade300 : Colors.red.shade300),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(param.nameAr, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text('معيار القبول: $expected', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade600, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.note_add_outlined,
                    size: 20,
                    color: isNoteVis ? AppColors.primaryDark : Colors.grey.shade500,
                  ),
                  tooltip: 'إضافة ملاحظة',
                  onPressed: () => controller.toggleParamNote(std.parameterId),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => controller.setParamValue(
                      std.parameterId,
                      isCompliant ? '' : expected,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isCompliant ? Colors.green : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCompliant ? Colors.green : Colors.grey.shade300,
                          width: isCompliant ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isCompliant) ...[
                            const Icon(Icons.check_circle, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            expected,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isCompliant ? Colors.white : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => controller.setParamValue(
                      std.parameterId,
                      isNotCompliant ? '' : 'غير مطابق',
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isNotCompliant ? Colors.red : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isNotCompliant ? Colors.red : Colors.grey.shade300,
                          width: isNotCompliant ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isNotCompliant) ...[
                            const Icon(Icons.cancel, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            'غير مطابق',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isNotCompliant ? Colors.white : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (isNoteVis) ...[
              const SizedBox(height: 10),
              AppTextField(
                controller: controller.formNoteControllers[std.parameterId],
                hint: 'ملاحظة حول ${param.nameAr}...',
                prefixIcon: Icons.edit_note,
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildParameterField(QualityStandard std) {
    final param = controller.getParameterDetails(std.parameterId);
    if (param == null) return const SizedBox.shrink();

    final isNumeric = param.inputType == 'Numeric';
    String limitsText = '';

    if (isNumeric) {
      if (std.minValue != null && std.maxValue != null && std.minValue != std.maxValue) {
        limitsText = '${std.minValue} - ${std.maxValue}';
      } else if (std.maxValue != null) {
        limitsText = 'الحد الأقصى ${std.maxValue}';
      }
    } else {
      limitsText = 'المتوقع: ${std.expectedText ?? ""}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                param.nameAr,
                style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              if (limitsText.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text('($limitsText)', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade600, fontSize: 11)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Obx(() {
            final isValid = controller.formValidations[std.parameterId]?.value;
            final isNoteVisible = controller.isNoteVisible[std.parameterId]?.value ?? false;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: controller.formControllers[std.parameterId],
                        hint: param.nameAr,
                        keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
                        suffixIcon: (isValid == true)
                            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                            : (isValid == false ? const Icon(Icons.cancel, color: Colors.red, size: 20) : null),
                      ),
                    ),
                    if (param.unit != null && param.unit!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          param.unit!,
                          style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.note_add_outlined, size: 20),
                      color: isNoteVisible ? AppColors.primaryDark : Colors.grey,
                      tooltip: 'إضافة ملاحظة',
                      onPressed: () {
                        controller.isNoteVisible[std.parameterId]?.value = !isNoteVisible;
                      },
                    ),
                  ],
                ),
                if (isNoteVisible) ...[
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: controller.formNoteControllers[std.parameterId],
                    hint: 'ملاحظة (اختياري)...',
                    prefixIcon: Icons.edit_note,
                  ),
                ],
                if (isValid == false) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'تنبيه: القيمة خارج المواصفة المعتمدة ($limitsText)',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              color: Colors.red.shade800,
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
            );
          }),
        ],
      ),
    );
  }

  Widget _buildComplianceSection() {
    return Obx(() {
      final isValid = controller.isAllCompliant.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('قرار المطابقة النهائي', Icons.gavel_outlined, AppColors.primaryDark),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: isValid ? Colors.green.shade50 : Colors.red.shade50,
              border: Border.all(color: isValid ? Colors.green.shade300 : Colors.red.shade300),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  isValid ? Icons.check_circle : Icons.warning_rounded,
                  color: isValid ? Colors.green.shade700 : Colors.red.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isValid ? 'العينة مطابقة للمواصفات القياسية المعتمدة' : 'يوجد قراءات غير مطابقة، يتطلب اتخاذ إجراءات تصحيحية',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: isValid ? Colors.green.shade900 : Colors.red.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (!isValid) ...[
            const SizedBox(height: 16),
            AppTextField(
              controller: controller.ncrNumberController,
              label: 'رقم تقرير عدم المطابقة (NCR)',
              hint: 'NCR-2026-XXXX',
              prefixIcon: Icons.tag,
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              value: controller.managerNotified.value,
              onChanged: (val) => controller.managerNotified.value = val ?? false,
              title: const Text('تم إخطار مدير إدارة الجودة', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primaryDark,
            ),
            CheckboxListTile(
              value: controller.sourceSuspended.value,
              onChanged: (val) => controller.sourceSuspended.value = val ?? false,
              title: const Text('تم تعليق استخدام المصدر', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primaryDark,
            ),
          ],
        ],
      );
    });
  }

  Widget _buildDraftsList(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Obx(() {
            final drafts = controller.reportsList.where((r) => r.approvalStatus == 'Draft').toList();

            if (drafts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppEmptyState(
                        icon: Icons.edit_document,
                        title: 'لا توجد مسودات حالياً',
                        message: 'انقر على الزر أدناه لبدء تسجيل وإدخال فحص مياه خام جديدة',
                      ),
                      const SizedBox(height: 20),
                      AppButton.primary(
                        label: 'إنشاء تقرير جديد',
                        icon: Icons.add,
                        color: AppColors.primaryDark,
                        onPressed: () => controller.startNewReport(),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: drafts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final draft = drafts[index];
                final date = DateFormat('yyyy-MM-dd HH:mm').format(draft.createdAt);

                return AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_document, color: Colors.orange, size: 20),
                    ),
                    title: Text(
                      'رقم التشغيلة: ${draft.batchNumber}',
                      style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(date, style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade600)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppButton.primary(
                          label: 'متابعة',
                          color: AppColors.primaryDark,
                          onPressed: () => controller.loadReport(draft),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
