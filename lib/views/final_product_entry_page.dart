import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../controllers/final_product_controller.dart';
import '../models/standards_models.dart';
import '../widgets/ds/ds.dart';
import '../widgets/wavy_header.dart';

class FinalProductEntryPage extends StatelessWidget {
  FinalProductEntryPage({super.key});

  final FinalProductController controller = Get.put(FinalProductController());

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
                              Color(0xFF004D40), // Dark Teal / Ocean Blue for Finished Product
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
                          'فحص المنتج النهائي',
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
                        child: AppButton.outlined(
                          label: 'حفظ مسودة',
                          icon: Icons.save_outlined,
                          height: 44,
                          foregroundColor: Colors.blue.shade700,
                          color: Colors.blue.shade400,
                          onPressed: () => controller.submitForm(isDraft: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppButton.primary(
                          label: 'رفع للاعتماد',
                          icon: Icons.send_rounded,
                          height: 44,
                          color: const Color(0xFF007791),
                          onPressed: () => controller.submitForm(isDraft: false),
                        ),
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
                AppButton.outlined(
                  label: 'حفظ مسودة',
                  icon: Icons.save_outlined,
                  foregroundColor: Colors.blue.shade700,
                  color: Colors.blue.shade400,
                  onPressed: () => controller.submitForm(isDraft: true),
                ),
                const SizedBox(width: 10),
                AppButton.primary(
                  label: 'رفع للاعتماد',
                  icon: Icons.send_rounded,
                  color: const Color(0xFF007791),
                  onPressed: () => controller.submitForm(isDraft: false),
                ),
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
              return const AppLoading(message: 'جاري تحميل نموذج فحص المنتج النهائي...');
            }

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 24.0, bottom: 120.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  // Rejection Banner if rejected
                  if (controller.currentRejectionReason.value.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade400, width: 1.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 26),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'تم رفض هذا التقرير سابقاً',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (controller.currentRejectedBy.value.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        'بواسطة: ${controller.currentRejectedBy.value}',
                                        style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red.shade800,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ملاحظة الرفض: ${controller.currentRejectionReason.value}',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    color: Colors.red.shade900,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'يرجى مراجعة وتصحيح القيم وإعادة الرفع للاعتماد.',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 1. Batch & Sample Info
                  _buildSectionCard(context,
                    title: 'أولاً: بيانات التشغيلة والعينة',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFF007791),
                    children: [
                      _buildResponsiveGrid(context, [
                        _buildProductSelector(),
                        _buildBottleSizeSelector(),
                        _buildBatchRow(),
                        _buildDateTimeRow(context),
                        _buildSamplingLocationSelector(),
                        _buildQuantityAndInspectorRow(),
                        _buildShiftSelector(),
                      ]),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 2. Visual & Packaging Inspection
                  _buildSectionCard(context,
                    title: 'ثانياً: الفحص الظاهري والتغليف',
                    icon: Icons.visibility_outlined,
                    color: const Color(0xFFE65100),
                    children: [
                      if (controller.visualStandards.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Center(child: Text('جاري تحميل معايير الفحص الظاهري...')),
                        )
                      else
                        _buildResponsiveGrid(
                          context,
                          controller.visualStandards.map((std) {
                            final param = controller.getParameterDetails(std.parameterId);
                            if (param?.inputType == 'Numeric') {
                              return _buildParameterField(std);
                            }
                            return _buildVisualToggleField(std);
                          }).toList(),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 3. Physicochemical Tests
                  _buildSectionCard(context,
                    title: 'ثالثاً: الفحوصات الفيزيائية والكيميائية',
                    icon: Icons.science_outlined,
                    color: const Color(0xFF1565C0),
                    children: [
                      if (controller.physiochemicalStandards.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Center(child: Text('جاري تحميل المعايير الفيزيوكيميائية...')),
                        )
                      else
                        _buildResponsiveGrid(
                          context,
                          controller.physiochemicalStandards.map((std) => _buildParameterField(std)).toList(),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 4. Microbiological Tests
                  _buildSectionCard(context,
                    title: 'رابعاً: الفحوصات الميكروبيولوجية',
                    icon: Icons.biotech_outlined,
                    color: const Color(0xFF2E7D32),
                    children: [
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
                      if (controller.microbiologicalStandards.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Center(child: Text('جاري تحميل المعايير الميكروبيولوجية...')),
                        )
                      else
                        ...controller.microbiologicalStandards.map((std) => _buildMicrobiologicalField(std)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 5. Compliance Decision & Non-Compliance Actions
                  _buildSectionCard(context,
                    title: 'خامساً: قرار المطابقة وإجراءات عدم المطابقة',
                    icon: Icons.verified_user_outlined,
                    color: const Color(0xFF455A64),
                    children: [
                      _buildComplianceDecisionSelector(),
                      const SizedBox(height: 12),
                      _buildNonComplianceActions(),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 6. Notes & Submit
                  _buildSectionCard(context,
                    title: 'سادساً: الملاحظات وإجراء الحفظ',
                    icon: Icons.note_alt_outlined,
                    color: const Color(0xFF6A1B9A),
                    children: [
                      AppTextField(
                        controller: controller.notesController,
                        maxLines: 3,
                        hint: 'اكتب أية ملاحظات فنية أو تشغيلية هنا...',
                        prefixIcon: Icons.edit_note,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton.outlined(
                              label: 'حفظ كمسودة',
                              icon: Icons.save_outlined,
                              foregroundColor: Colors.blue.shade700,
                              color: Colors.blue.shade400,
                              onPressed: () => controller.submitForm(isDraft: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: AppButton.primary(
                              label: 'رفع للاعتماد',
                              icon: Icons.send_rounded,
                              color: const Color(0xFF007791),
                              onPressed: () => controller.submitForm(isDraft: false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildStickyBottomActionBar(context),
            ),
            ],
          );
          }),
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProductSelector() {
    return AppTextField(
      controller: controller.productNameController,
      label: 'اسم المنتج',
      hint: 'مياه شرب معبأة سلسال',
      prefixIcon: Icons.water_drop_outlined,
    );
  }

  Widget _buildBottleSizeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('حجم العبوة:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        Obx(() {
          final available = controller.products.where((p) => p.isActive).toList();
          if (available.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لا توجد عبوات مخصصة لمصنعكم بعد. تواصل مع مسؤول النظام لإضافتها.',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.amber.shade800),
                    ),
                  ),
                ],
              ),
            );
          }
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: available.map((prod) {
              final isSelected = controller.selectedBottleSize.value == prod.name;
              return ChoiceChip(
                label: Text(
                  prod.name,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF007791),
                backgroundColor: Colors.grey.withValues(alpha: 0.1),
                onSelected: (_) => controller.selectBottleSize(prod.name),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildBatchRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: AppTextField(
            controller: controller.batchNumberController,
            label: 'رقم التشغيلة *',
            hint: 'رقم التشغيلة',
            prefixIcon: Icons.tag,
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: AppButton.outlined(
            label: 'توليد تلقائي',
            icon: Icons.autorenew,
            foregroundColor: const Color(0xFF007791),
            color: const Color(0xFF007791).withValues(alpha: 0.5),
            onPressed: controller.generateBatchNumber,
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                controller.productionDateController.text = DateFormat('yyyy-MM-dd').format(picked);
              }
            },
            child: IgnorePointer(
              child: AppTextField(
                controller: controller.productionDateController,
                label: 'تاريخ الإنتاج',
                prefixIcon: Icons.calendar_today,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (picked != null) {
                controller.samplingTimeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
              }
            },
            child: IgnorePointer(
              child: AppTextField(
                controller: controller.samplingTimeController,
                label: 'وقت أخذ العينة',
                prefixIcon: Icons.access_time,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSamplingLocationSelector() {
    final stages = ['بداية التشغيل', 'أثناء التشغيل', 'نهاية التشغيل'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('مكان أخذ العينة:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        Row(
          children: stages.map((stage) {
            return Expanded(
              child: Obx(() {
                final isSelected = controller.samplingLocation.value == stage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => controller.selectSamplingLocation(stage),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF007791) : Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? const Color(0xFF007791) : Colors.grey.shade300),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        stage,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuantityAndInspectorRow() {
    return Row(
      children: [
        Expanded(
          child: AppTextField(
            controller: controller.producedQuantityController,
            label: 'الكمية المنتجة',
            hint: '5000 كرتون',
            prefixIcon: Icons.inventory_2_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppTextField(
            controller: controller.sampleTakerController,
            label: 'اسم آخذ العينة',
            hint: 'اسم الموظف',
            prefixIcon: Icons.person_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildShiftSelector() {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الوردية:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: controller.shifts.map((shift) {
              final isSelected = controller.selectedShiftObj.value?.id == shift.id;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => controller.selectShift(shift),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF007791).withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? const Color(0xFF007791) : Colors.grey.shade300, width: isSelected ? 1.5 : 1),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        shift.name,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF007791) : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    });
  }

  Widget _buildVisualToggleField(QualityStandard std) {
    final param = controller.getParameterDetails(std.parameterId);
    if (param == null) return const SizedBox.shrink();

    final expected = std.expectedText ?? 'مطابق';

    return Obx(() {
      final currentVal = controller.formControllers[std.parameterId]?.text ?? '';
      final hasValue = currentVal.isNotEmpty;
      final isCompliant = hasValue && (currentVal.toLowerCase() == expected.toLowerCase());
      final isNotCompliant = hasValue && !isCompliant;
      final isNoteVis = controller.isNoteVisible[std.parameterId]?.value ?? false;

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: !hasValue
              ? Colors.grey.withValues(alpha: 0.04)
              : (isCompliant ? Colors.green.withValues(alpha: 0.08) : Colors.red.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: !hasValue ? Colors.grey.shade200 : (isCompliant ? Colors.green.shade200 : Colors.red.shade200),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        param.nameAr,
                        style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'معيار القبول: $expected',
                        style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade600, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.note_add_outlined,
                    size: 20,
                    color: isNoteVis ? Colors.blue : Colors.grey.shade500,
                  ),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  onPressed: () => controller.toggleParamNote(std.parameterId),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => controller.setParamValue(std.parameterId, isCompliant ? '' : expected),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isCompliant ? Colors.green : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isCompliant ? Colors.green : Colors.grey.shade300, width: isCompliant ? 1.5 : 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isCompliant) ...[
                            const Icon(Icons.check_circle, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              expected,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isCompliant ? Colors.white : Colors.green.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                    onTap: () => controller.setParamValue(std.parameterId, isNotCompliant ? '' : 'غير مطابق'),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isNotCompliant ? Colors.red : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isNotCompliant ? Colors.red : Colors.grey.shade300, width: isNotCompliant ? 1.5 : 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isNotCompliant) ...[
                            const Icon(Icons.cancel, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              'غير مطابق',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isNotCompliant ? Colors.white : Colors.red.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 8),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Obx(() {
        final isValid = controller.formValidations[std.parameterId]?.value;
        final isNoteVisible = controller.isNoteVisible[std.parameterId]?.value ?? false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        param.nameAr,
                        style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      if (limitsText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('($limitsText)', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.note_add_outlined,
                    size: 18,
                    color: isNoteVisible ? Colors.blue : Colors.grey.shade400,
                  ),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  onPressed: () => controller.toggleParamNote(std.parameterId),
                ),
              ],
            ),
            const SizedBox(height: 4),
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
              ],
            ),
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
                          fontSize: 11,
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isNoteVisible) ...[
              const SizedBox(height: 6),
              AppTextField(
                controller: controller.formNoteControllers[std.parameterId],
                hint: 'ملاحظة حول ${param.nameAr}...',
                prefixIcon: Icons.edit_note,
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _buildMicrobiologicalField(QualityStandard std) {
    final param = controller.getParameterDetails(std.parameterId);
    if (param == null) return const SizedBox.shrink();

    return Obx(() {
      final currentVal = controller.formControllers[std.parameterId]?.text ?? '';
      final hasValue = currentVal.isNotEmpty;
      final isCompliant = hasValue && (currentVal.toLowerCase() == 'خالية تماماً' || currentVal.toLowerCase() == 'خالية');
      final isNotCompliant = hasValue && !isCompliant;
      final isNoteVis = controller.isNoteVisible[std.parameterId]?.value ?? false;

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: !hasValue
              ? Colors.grey.withValues(alpha: 0.04)
              : (isCompliant ? Colors.green.withValues(alpha: 0.08) : Colors.red.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: !hasValue ? Colors.grey.shade200 : (isCompliant ? Colors.green.shade200 : Colors.red.shade200),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        param.nameAr,
                        style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'معيار القبول: خالية تماماً',
                        style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.note_add_outlined,
                    size: 20,
                    color: isNoteVis ? Colors.blue : Colors.grey.shade500,
                  ),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  onPressed: () => controller.toggleParamNote(std.parameterId),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => controller.setParamValue(std.parameterId, isCompliant ? '' : 'خالية تماماً'),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isCompliant ? Colors.green : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isCompliant ? Colors.green : Colors.grey.shade300, width: isCompliant ? 1.5 : 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isCompliant) ...[
                            const Icon(Icons.check_circle, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              'خالية تماماً',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isCompliant ? Colors.white : Colors.green.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                    onTap: () => controller.setParamValue(std.parameterId, isNotCompliant ? '' : 'موجبة / ملوثة'),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isNotCompliant ? Colors.red : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isNotCompliant ? Colors.red : Colors.grey.shade300, width: isNotCompliant ? 1.5 : 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isNotCompliant) ...[
                            const Icon(Icons.cancel, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              'توجد ميكروبات',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isNotCompliant ? Colors.white : Colors.red.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 8),
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

  Widget _buildComplianceDecisionSelector() {
    return Obx(() {
      final isComp = controller.isCompliantDecision.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('قرار المطابقة العام:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => controller.isCompliantDecision.value = true,
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                      decoration: BoxDecoration(
                        color: isComp ? Colors.green.shade600 : Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'المنتج مطابق للمواصفات ✅',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: isComp ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => controller.isCompliantDecision.value = false,
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                      decoration: BoxDecoration(
                        color: !isComp ? Colors.red.shade600 : Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'المنتج غير مطابق ⚠️',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: !isComp ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildNonComplianceActions() {
    return Obx(() {
      final isComp = controller.isCompliantDecision.value;
      if (isComp) return const SizedBox.shrink();

      return Material(
        color: Colors.red.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.red.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'إجراءات عدم المطابقة الفورية:',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              dense: true,
              value: controller.isIsolated.value,
              title: const Text('تم العزل', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
              onChanged: (v) => controller.isIsolated.value = v ?? false,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              dense: true,
              value: controller.isHoldIssued.value,
              title: const Text('تم إصدار بطاقة HOLD', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
              onChanged: (v) => controller.isHoldIssued.value = v ?? false,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              dense: true,
              value: controller.isRejectIssued.value,
              title: const Text('تم إصدار بطاقة REJECT', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
              onChanged: (v) => controller.isRejectIssued.value = v ?? false,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 6),
            AppTextField(
              controller: controller.ncrNumberController,
              label: 'رقم تقرير عدم المطابقة (NCR No.)',
              prefixIcon: Icons.confirmation_number_outlined,
            ),
            ],
          ),
        ),
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
            if (controller.isLoading.value) {
              return const AppLoading(message: 'جاري تحميل المسودات...');
            }

            final drafts = controller.reportsList
                .where((r) => r.approvalStatus == 'Draft')
                .toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: AppButton.primary(
                    label: 'بدء تقرير فحص منتج نهائي جديد',
                    icon: Icons.add_circle_outline,
                    color: const Color(0xFF007791),
                    onPressed: controller.startNewReport,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      const Icon(Icons.drafts_outlined, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'المسودات للتعديل (${drafts.length})',
                        style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: drafts.isEmpty
                      ? const Center(
                          child: AppEmptyState(
                            icon: Icons.assignment_outlined,
                            title: 'لا توجد مسودات معلقة حالياً',
                            message: 'انقر على الزر أعلاه لإنشاء تقرير فحص منتج نهائي جديد',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: drafts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final log = drafts[index];
                            final isRejected = log.approvalStatus == 'Rejected';

                            return AppCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              borderColor: isRejected ? Colors.red.shade300 : null,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isRejected ? Colors.red.shade100 : Colors.amber.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isRejected ? Icons.replay : Icons.edit_document,
                                    color: isRejected ? Colors.red.shade800 : Colors.amber.shade800,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  'تشغيلة: ${log.batchNumber ?? "بدون رقم"} - ${log.productName ?? "منتج نهائي"} (${log.bottleSize ?? ""})',
                                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(log.createdAt)} | المنفذ: ${log.sampleTaker ?? "صلاح الجابري"}',
                                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade600),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (isRejected && log.rejectionReason != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'سبب الرفض: ${log.rejectionReason}',
                                        style: const TextStyle(fontFamily: 'Tajawal', color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () => controller.initForEdit(log),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
