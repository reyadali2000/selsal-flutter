import '../utils/dynamic_report_color_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../controllers/dynamic_report_builder_controller.dart';
import '../models/dynamic_report_models.dart';
import '../utils/calculated_field_helper.dart';
import 'dart:convert';
import '../widgets/ds/ds.dart';

class DynamicReportBuilderView extends StatelessWidget {
  const DynamicReportBuilderView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DynamicReportBuilderController());

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text(
          'تصميم التقرير',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            tooltip: 'حفظ التقرير',
            onPressed: controller.saveReport,
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDark.withValues(alpha: 0.8), AppColors.canvas],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          return Form(
            key: controller.formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 950;
                if (!isWide) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildReportInfoSection(context, controller),
                      const SizedBox(height: 24),
                      _buildSectionsArea(context, controller),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 380,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildReportInfoSection(context, controller),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(top: 16, bottom: 16, left: 16),
                        children: [
                          _buildSectionsArea(context, controller),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        }),
      ),
      floatingActionButton: AppButton.primary(
        label: 'إضافة قسم',
        icon: Icons.add_box_rounded,
        onPressed: () => _showAddSectionDialog(context, controller, null),
      ),
    );
  }

  Widget _buildReportInfoSection(BuildContext context, DynamicReportBuilderController controller) {
    return AppCard.glass(
      title: 'المعلومات الأساسية للتقرير',
      subtitle: 'حدد اسم التقرير، القسم، وطريقة العرض ومسار الاعتماد',
      icon: Icons.assignment_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            AppTextField(
              controller: controller.nameController,
              label: 'اسم التقرير',
              isRequired: true,
              prefixIcon: Icons.description_outlined,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: controller.descController,
              label: 'وصف التقرير',
              prefixIcon: Icons.notes_rounded,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Obx(() => controller.categories.isEmpty
                ? const SizedBox.shrink()
                : AppDropdown<int>(
                label: 'القسم',
                isRequired: true,
                value: controller.categoryId.value,
                prefixIcon: Icons.category_outlined,
                items: {
                  for (final c in controller.categories)
                    if (c.id != null) c.id!: c.name,
                },
                onChanged: (val) => controller.categoryId.value = val,
              )),
            const SizedBox(height: 16),
            Obx(() => DropdownButtonFormField<String>(
              initialValue: ['three_level_qm', 'three_level', 'two_level', 'single_level', 'none']
                      .contains(controller.approvalType.value)
                  ? controller.approvalType.value
                  : 'two_level',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'مسار الاعتماد والتوقيعات *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'three_level_qm',
                  child: Text('اعتماد ثلاثي (مُعِد التقرير + مشرف الجودة + مدير الجودة)'),
                ),
                DropdownMenuItem(
                  value: 'three_level',
                  child: Text('اعتماد كامل (مشرف الجودة + مدير الجودة + مدير المصنع)'),
                ),
                DropdownMenuItem(
                  value: 'two_level',
                  child: Text('اعتماد ثنائي (مدير الجودة + مدير المصنع) - افتراضي معتمد'),
                ),
                DropdownMenuItem(
                  value: 'single_level',
                  child: Text('اعتماد أحادي (مدير الجودة فقط)'),
                ),
                DropdownMenuItem(
                  value: 'none',
                  child: Text('بدون دورة اعتماد (مكتمل مباشرة)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) controller.approvalType.value = val;
              },
            )),
            const SizedBox(height: 20),
            const Text(
              'طريقة العرض والطباعة للتقرير ككل *',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 280;
                return Obx(() {
                  final portraitCard = _buildOrientationOption(
                    context: context,
                    title: 'طولي (Portrait)',
                    subtitle: 'عمودي A4 - مناسب للنماذج والتقارير القياسية',
                    icon: Icons.stay_current_portrait_rounded,
                    isSelected: controller.orientation.value == 'portrait',
                    onTap: () => controller.orientation.value = 'portrait',
                  );
                  final landscapeCard = _buildOrientationOption(
                    context: context,
                    title: 'عرضي (Landscape)',
                    subtitle: 'أفقي A4 - مناسب لقوائم الفحص والجداول العريضة',
                    icon: Icons.stay_current_landscape_rounded,
                    isSelected: controller.orientation.value == 'landscape',
                    onTap: () => controller.orientation.value = 'landscape',
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        portraitCard,
                        const SizedBox(height: 8),
                        landscapeCard,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: portraitCard),
                      const SizedBox(width: 8),
                      Expanded(child: landscapeCard),
                    ],
                  );
                });
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'أيقونة التقرير *',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _buildIconSelector(context, controller),
            const SizedBox(height: 20),
            const Divider(height: 24),
            const Row(
              children: [
                Icon(Icons.feed_outlined, size: 18, color: AppColors.primaryDark),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'بيانات تذييلة توثيق الجودة (Footer Document Control)',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'تظهر هذه البيانات في أسفل كل صفحة مطبوعة (إصدار رقم / تاريخ الإصدار / رقم الوثيقة)',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: controller.docNumberController,
              label: 'رقم الوثيقة / كود النموذج',
              hint: 'مثال: SELSAL-QA-01 أو QA-SOP-05',
              prefixIcon: Icons.tag_rounded,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: AppTextField(
                    controller: controller.versionNumberController,
                    label: 'إصدار رقم',
                    hint: 'مثال: 01',
                    prefixIcon: Icons.format_list_numbered_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AppTextField(
                    controller: controller.issueDateController,
                    label: 'تاريخ الإصدار',
                    hint: 'YYYY/MM/DD',
                    prefixIcon: Icons.event_note_rounded,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.primaryDark),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                          locale: const Locale('ar', 'SA'),
                        );
                        if (picked != null) {
                          controller.issueDateController.text =
                              DateFormat('yyyy/MM/dd').format(picked);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 24),
            _buildHeaderConfigSection(context, controller),
          ],
        ),
    );
  }

  Widget _buildHeaderConfigSection(BuildContext context, DynamicReportBuilderController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.view_headline_rounded, size: 18, color: AppColors.primaryDark),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'شريط معلومات السجل العلوي (Operating Bar)',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'شريط التشغيل العلوي في وثيقة التقرير. يمكنك تحديد الحقول المراد إظهارها أو إخفاؤها:',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF166534)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'الحقول الإجبارية الدائمة: رقم السجل والحالة (تظهر دائماً لضمان التتبع والرقابة).',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF166534),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Obx(() => _buildHeaderSwitchTile(
          title: 'مُعد التقرير (اسم الفاحص / المنشئ)',
          subtitle: 'إظهار اسم المستخدم الذي قام بإعداد وتعبئة التقرير',
          icon: Icons.person_outline_rounded,
          value: controller.showHeaderCreator.value,
          onChanged: (val) => controller.showHeaderCreator.value = val,
        )),
        const SizedBox(height: 6),
        Obx(() => _buildHeaderSwitchTile(
          title: 'تاريخ الفحص / التعبئة',
          subtitle: 'إظهار تاريخ إجراء الفحص بالسنة والشهر واليوم',
          icon: Icons.calendar_today_outlined,
          value: controller.showHeaderDate.value,
          onChanged: (val) => controller.showHeaderDate.value = val,
        )),
        const SizedBox(height: 6),
        Obx(() => _buildHeaderSwitchTile(
          title: 'اليوم (السبت، الأحد، ...)',
          subtitle: 'إظهار اسم يوم الأسبوع المقابل لتاريخ الفحص',
          icon: Icons.today_outlined,
          value: controller.showHeaderDay.value,
          onChanged: (val) => controller.showHeaderDay.value = val,
        )),
        const SizedBox(height: 6),
        Obx(() => _buildHeaderSwitchTile(
          title: 'خط الإنتاج',
          subtitle: 'إظهار خط الإنتاج الذي تم إجراء الفحص عليه',
          icon: Icons.precision_manufacturing_outlined,
          value: controller.showHeaderLine.value,
          onChanged: (val) => controller.showHeaderLine.value = val,
        )),
      ],
    );
  }

  Widget _buildHeaderSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: value ? AppColors.primaryDark.withValues(alpha: 0.04) : Colors.grey.shade50,
        border: Border.all(
          color: value ? AppColors.primaryDark.withValues(alpha: 0.25) : Colors.grey.shade300,
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: value ? AppColors.primaryDark : Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: value ? AppColors.primaryDark : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primaryDark,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionsArea(BuildContext context, DynamicReportBuilderController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: AppButton.outlined(
                  label: 'قسم بيانات التشغيل القياسي (تاريخ، يوم، خط، وردية)',
                  icon: Icons.flash_on_rounded,
                  onPressed: () => controller.addOperatingInfoSection(),
                ),
              ),
              const SizedBox(width: 8),
              AppButton.primary(
                label: 'إضافة قسم جديد',
                icon: Icons.add_box_rounded,
                onPressed: () => _showAddSectionDialog(context, controller, null),
              ),
            ],
          ),
        ),
        Obx(() {
          if (controller.sections.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const Icon(Icons.dashboard_customize_outlined, size: 44, color: AppColors.primaryLight),
                  const SizedBox(height: 10),
                  const Text('لا توجد أقسام في التقرير بعد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  const Text(
                    'اضغط على "قسم بيانات التشغيل القياسي" للبدء سريعاً، أو اضغط "إضافة قسم جديد".',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorderItem: (oldIndex, newIndex) {
        controller.reorderSection(oldIndex, newIndex);
      },
      children: controller.sections.map((section) {
        final sectionFields = controller.getFieldsForSection(section.id!);
        return Padding(
          key: ValueKey(section.id),
          padding: const EdgeInsets.only(bottom: 16),
          child: UIGlassCard(
            borderRadius: 12,
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              title: Row(
                children: [
                const Icon(Icons.drag_indicator, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (section.description != null && section.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            section.description!,
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.normal),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                  tooltip: 'تعديل القسم',
                  onPressed: () => _showAddSectionDialog(context, controller, section.id),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'حذف القسم',
                  onPressed: () => _confirmDeleteSection(context, controller, section),
                ),
              ],
            ),
            children: [
              if (sectionFields.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('لا يوجد حقول في هذا القسم'),
                )
              else
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderItem: (oldIndex, newIndex) {
                    controller.reorderFields(section.id!, oldIndex, newIndex);
                  },
                  children: sectionFields.map((field) {
                    return ListTile(
                      key: ValueKey('${field.id}_${field.fieldKey}'),
                      leading: ReorderableDragStartListener(
                        index: sectionFields.indexOf(field),
                        child: const Icon(Icons.drag_handle),
                      ),
                      title: Text(field.label),
                      subtitle: Text('النوع: ${field.fieldType} | مطلوب: ${field.isRequired ? "نعم" : "لا"}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                            tooltip: 'تعديل الحقل',
                            onPressed: () => _showAddFieldDialog(
                              context,
                              controller,
                              section.id!,
                              existingField: field,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'حذف الحقل',
                            onPressed: () {
                              controller.deleteField(field);
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: AppButton.outlined(
                  onPressed: () => _showAddFieldDialog(context, controller, section.id!),
                  icon: Icons.add_circle_outline,
                  label: 'إضافة حقل',
                ),
              )
            ],
            ),
          ),
        );
      }).toList(),
    );
    }),
    ],
    );
  }

  Future<void> _confirmDeleteSection(BuildContext context, DynamicReportBuilderController controller, DynamicReportSection section) async {
    final ok = await AppDialog.confirm(
      title: 'تأكيد حذف القسم',
      message: 'هل أنت متأكد من حذف القسم "${section.title}" وجميع الحقول التابعة له؟',
      confirmLabel: 'نعم، احذف',
      isDanger: true,
    );
    if (ok) {
      controller.deleteSection(section.id!);
    }
  }

  void _showAddSectionDialog(BuildContext context, DynamicReportBuilderController controller, int? sectionId) {
    final isEditing = sectionId != null;
    final existing = isEditing ? sectionsById(controller, sectionId) : null;

    final titleController = TextEditingController(text: existing?.title ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    final collapsibleCtrl = (existing?.isCollapsible ?? true).obs;

    AppDialog.show(
      title: isEditing ? 'تعديل القسم' : 'إضافة قسم جديد',
      icon: isEditing ? Icons.edit_note_rounded : Icons.create_new_folder_outlined,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: titleController,
            label: 'اسم القسم',
            isRequired: true,
            prefixIcon: Icons.folder_outlined,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: descController,
            maxLines: 3,
            label: 'وصف القسم (اختياري)',
            hint: 'يظهر كعنوان فرعي تحت اسم القسم عند التعبئة',
            prefixIcon: Icons.notes_outlined,
          ),
          const SizedBox(height: 8),
          Obx(() => SwitchListTile(
            title: const Text('قابل للطي عند التعبئة', style: TextStyle(fontFamily: AppTheme.fontFamily)),
            value: collapsibleCtrl.value,
            onChanged: (val) => collapsibleCtrl.value = val,
          )),
        ],
      ),
      actions: [
        AppButton.text(label: 'إلغاء', onPressed: () => Get.back()),
        AppButton.primary(
          label: isEditing ? 'حفظ التعديل' : 'إضافة',
          onPressed: () {
            if (titleController.text.trim().isEmpty) return;
            if (isEditing) {
              controller.updateSection(
                sectionId,
                title: titleController.text.trim(),
                description: descController.text,
                isCollapsible: collapsibleCtrl.value,
              );
            } else {
              controller.addSection(
                titleController.text.trim(),
                description: descController.text,
                isCollapsible: collapsibleCtrl.value,
              );
            }
            Get.back();
          },
        ),
      ],
    );
  }

  DynamicReportSection? sectionsById(DynamicReportBuilderController controller, int id) {
    try {
      return controller.sections.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  void _showAddFieldDialog(BuildContext context, DynamicReportBuilderController controller, int sectionId, {DynamicReportField? existingField}) {
    final isEditing = existingField != null;

    final labelCtrl = TextEditingController(text: existingField?.label ?? '');
    String initialType = (existingField?.fieldType ?? 'text').toLowerCase().trim();
    if (initialType == 'select') initialType = 'dropdown';
    if (initialType == 'textarea' || initialType == 'multiline') initialType = 'multiline_text';
    if (initialType == 'int' || initialType == 'integer') initialType = 'number';
    if (initialType == 'float' || initialType == 'double') initialType = 'decimal';
    if (initialType == 'bool' || initialType == 'boolean' || initialType == 'toggle') initialType = 'switch';
    final typeCtrl = initialType.obs;
    final optionsCtrl = TextEditingController(text: DynamicReportField.optionsToText(existingField?.options ?? []));
    final requiredCtrl = (existingField?.isRequired ?? false).obs;
    final headerColorCtrl = (existingField?.headerBgColor ?? '').obs;
    final valueColorCtrl = (existingField?.valueBgColor ?? '').obs;

    // إعدادات التحقق والتنسيق
    final hintCtrl = TextEditingController(text: existingField?.hint ?? '');
    final unitCtrl = TextEditingController(text: existingField?.unit ?? '');
    final minCtrl = TextEditingController(text: existingField?.minValue?.toString() ?? '');
    final maxCtrl = TextEditingController(text: existingField?.maxValue?.toString() ?? '');
    // صيغة الحقل المحسوب تُستخرج من validationJson
    String initialFormula = '';
    if (existingField != null && existingField.fieldType == 'calculated') {
      initialFormula = CalculatedFieldHelper.extractFormula(existingField) ?? '';
    }
    final formulaCtrl = TextEditingController(text: initialFormula);

    // نص التعليمات يُخزَّن في defaultValue (نص ثابت يُعرض أثناء التعبئة)
    final instructionsCtrl = TextEditingController(
      text: (existingField != null && existingField.fieldType == 'instructions')
          ? (existingField.defaultValue ?? '')
          : '',
    );

    // عند تعديل حقل تقييم: استرجاع الحدود من validationJson
    // (تُخزَّن هناك وليس في minValue/maxValue)
    if (existingField != null && existingField.fieldType == 'rating') {
      final bounds = CalculatedFieldHelper.ratingBounds(existingField);
      minCtrl.text = bounds.min.toString();
      maxCtrl.text = bounds.max.toString();
    }

    // Table builder state (for Admin/Management only)
    final tableColumns = <DynamicTableColumn>[].obs;
    final predefinedRows = <Map<String, dynamic>>[].obs;
    final isLandscapeCtrl = false.obs;
    final allowAddRowsCtrl = true.obs;
    final rowCountCtrl = TextEditingController(text: '15');
    final selectedTemplate = ''.obs;

    // تعبئة حالة الجدول عند تعديل حقل جدول موجود
    if (isEditing && existingField.fieldType == 'table') {
      final tc = existingField.tableConfig;
      if (tc != null) {
        tableColumns.assignAll(tc.columns);
        predefinedRows.assignAll(tc.defaultRows.map((r) => Map<String, dynamic>.from(r)));
        isLandscapeCtrl.value = tc.isLandscape;
        allowAddRowsCtrl.value = tc.allowAddRows;
        rowCountCtrl.text = '${tc.rowCount}';
      }
    }

    void applyTemplate(String templateKey) {
      selectedTemplate.value = templateKey;
      allowAddRowsCtrl.value = true;
      if (templateKey == 'hygiene') {
        final t = DynamicTableConfig.hygieneInspectionTemplate();
        tableColumns.assignAll(t.columns);
        predefinedRows.assignAll(t.defaultRows.map((r) => Map<String, dynamic>.from(r)));
        isLandscapeCtrl.value = true;
        rowCountCtrl.text = '${t.rowCount}';
        labelCtrl.text = 'قائمة التفتيش على النظافة الشخصية';
      } else if (templateKey == 'raw_materials') {
        final t = DynamicTableConfig.inspectionChecklistTemplate();
        tableColumns.assignAll(t.columns);
        predefinedRows.assignAll(t.defaultRows.map((r) => Map<String, dynamic>.from(r)));
        isLandscapeCtrl.value = false;
        rowCountCtrl.text = '${t.rowCount}';
        labelCtrl.text = 'نتائج الفحص والمطابقة';
      } else if (templateKey == 'ccp_ozone') {
        final t = DynamicTableConfig.ccpOzoneTemplate();
        tableColumns.assignAll(t.columns);
        predefinedRows.assignAll(t.defaultRows.map((r) => Map<String, dynamic>.from(r)));
        isLandscapeCtrl.value = true;
        rowCountCtrl.text = '${t.rowCount}';
        labelCtrl.text = 'جدول مراقبة تركيز الأوزون (24 ساعة)';
      } else if (templateKey == 'ccp_capping') {
        final t = DynamicTableConfig.ccpCappingTemplate();
        tableColumns.assignAll(t.columns);
        predefinedRows.assignAll(t.defaultRows.map((r) => Map<String, dynamic>.from(r)));
        isLandscapeCtrl.value = true;
        rowCountCtrl.text = '${t.rowCount}';
        labelCtrl.text = 'جدول مراقبة سلامة الأغطية وعزم الفتح والتسريب (24 ساعة)';
      } else if (templateKey == 'daily_24h') {
        final t = DynamicTableConfig.daily24HourShiftTemplate();
        tableColumns.assignAll(t.columns);
        predefinedRows.assignAll(t.defaultRows.map((r) => Map<String, dynamic>.from(r)));
        isLandscapeCtrl.value = true;
        rowCountCtrl.text = '${t.rowCount}';
        labelCtrl.text = 'جدول مراقبة دورية على مدار 24 ساعة';
      } else if (templateKey == 'custom') {
        tableColumns.clear();
        predefinedRows.clear();
        labelCtrl.text = 'جدول فحص مخصص';
      }
    }

    void showAddColumnDialog({DynamicTableColumn? existingCol, int? existingIndex}) {
      final isEditing = existingCol != null;
      final colTitleCtrl = TextEditingController(text: existingCol?.title ?? '');
      final colTypeCtrl = (existingCol?.type ?? 'text').obs;

      String initialValuesText = '';
      if (isEditing) {
        final values = <String>[];
        for (var r in predefinedRows) {
          values.add(r[existingCol.key]?.toString() ?? '');
        }
        while (values.isNotEmpty && values.last.isEmpty) {
          values.removeLast();
        }
        initialValuesText = values.join('\n');
      }
      final colValuesCtrl = TextEditingController(text: initialValuesText);

      // خيارات عمود "اختيار واحد" (radio) أو "قائمة منسدلة" (dropdown) — تُخزَّن في column.options
      final colOptionsCtrl = TextEditingController(
        text: (isEditing && (existingCol.type == 'radio' || existingCol.type == 'dropdown')) ? existingCol.options.join('\n') : '',
      );

      Get.dialog(
        AlertDialog(
          title: Text(isEditing ? 'تعديل العمود وقيم الصفوف' : 'إضافة عمود جديد للجدول'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'إضافة عمود شائع بنقرة واحدة:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.person_pin_circle_outlined, size: 14),
                        label: const Text('المسؤول عن المراقبة', style: TextStyle(fontSize: 10.5)),
                        onPressed: () {
                          colTitleCtrl.text = 'المسؤول عن المراقبة';
                          colTypeCtrl.value = 'inspector';
                        },
                      ),
                      const SizedBox(width: 5),
                      ActionChip(
                        avatar: const Icon(Icons.draw_outlined, size: 14),
                        label: const Text('التوقيع', style: TextStyle(fontSize: 10.5)),
                        onPressed: () {
                          colTitleCtrl.text = 'التوقيع';
                          colTypeCtrl.value = 'signature';
                        },
                      ),
                      const SizedBox(width: 5),
                      ActionChip(
                        avatar: const Icon(Icons.repeat_rounded, size: 14),
                        label: const Text('الوردية', style: TextStyle(fontSize: 10.5)),
                        onPressed: () {
                          colTitleCtrl.text = 'الوردية';
                          colTypeCtrl.value = 'label';
                        },
                      ),
                      const SizedBox(width: 5),
                      ActionChip(
                        avatar: const Icon(Icons.schedule, size: 14),
                        label: const Text('الوقت', style: TextStyle(fontSize: 10.5)),
                        onPressed: () {
                          colTitleCtrl.text = 'الوقت';
                          colTypeCtrl.value = 'label';
                        },
                      ),
                      const SizedBox(width: 5),
                      ActionChip(
                        avatar: const Icon(Icons.build_circle_outlined, size: 14),
                        label: const Text('الإجراء التصحيحي', style: TextStyle(fontSize: 10.5)),
                        onPressed: () {
                          colTitleCtrl.text = 'الإجراء التصحيحي في حال الانحراف';
                          colTypeCtrl.value = 'text';
                        },
                      ),
                      const SizedBox(width: 5),
                      ActionChip(
                        avatar: const Icon(Icons.check_circle_outline, size: 14),
                        label: const Text('المطابقة', style: TextStyle(fontSize: 10.5)),
                        onPressed: () {
                          colTitleCtrl.text = 'المطابقة';
                          colTypeCtrl.value = 'match';
                        },
                      ),
                      const SizedBox(width: 5),
                      ActionChip(
                        avatar: const Icon(Icons.arrow_drop_down_circle_outlined, size: 14),
                        label: const Text('قائمة منسدلة', style: TextStyle(fontSize: 10.5)),
                        onPressed: () {
                          colTitleCtrl.text = 'الحالة';
                          colTypeCtrl.value = 'dropdown';
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: colTitleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'عنوان العمود *',
                    hintText: 'مثال: بند الفحص، معيار القبول...',
                  ),
                ),
                const SizedBox(height: 12),
                Obx(() => DropdownButtonFormField<String>(
                  initialValue: colTypeCtrl.value,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'نوع العمود'),
                  items: const [
                    DropdownMenuItem(value: 'text', child: Text('🔤 نص قابل للإدخال (اسم، ملاحظات، كود)')),
                    DropdownMenuItem(value: 'label', child: Text('📌 نص ثابت (مثل بنود الفحص والمعايير)')),
                    DropdownMenuItem(value: 'yes_no', child: Text('⚖️ نعم / لا (تقييم نعم أو لا)')),
                    DropdownMenuItem(value: 'match', child: Text('✅ مطابق / غير مطابق')),
                    DropdownMenuItem(value: 'dropdown', child: Text('🔽 قائمة منسدلة داخل الخلية (خيارات متعددة)')),
                    DropdownMenuItem(value: 'radio', child: Text('🔘 اختيار واحد (أزرار اختيار مخصصة)')),
                    DropdownMenuItem(value: 'number', child: Text('🔢 رقم عددي صحيح')),
                    DropdownMenuItem(value: 'decimal', child: Text('🔬 رقم عشري (مثل pH 7.5، الوزن 1.25)')),
                    DropdownMenuItem(value: 'checkbox', child: Text('☑ خانة اختيار (Checkbox)')),
                    DropdownMenuItem(value: 'date', child: Text('📅 تاريخ (يوم/شهر/سنة)')),
                    DropdownMenuItem(value: 'time', child: Text('🕐 وقت (ساعة:دقيقة)')),
                    DropdownMenuItem(value: 'inspector', child: Text('👤 المسؤول عن المراقبة (تلقائي مع التوقيع)')),
                    DropdownMenuItem(value: 'signature', child: Text('✍️ توقيع المراقب الإلكتروني')),
                  ],
                  onChanged: (val) {
                    if (val != null) colTypeCtrl.value = val;
                  },
                )),
                const SizedBox(height: 12),
                TextField(
                  controller: colValuesCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'قيم هذا العمود في الصفوف (سطر لكل صف - اختياري)',
                    hintText: 'اكتب بنداً في كل سطر، مثلا:\nمطابقة المادة لأمر الشراء\nسلامة العبوات\nنظافة المادة',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                Obx(() {
                  if (colTypeCtrl.value != 'radio' && colTypeCtrl.value != 'dropdown') return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextField(
                      controller: colOptionsCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: colTypeCtrl.value == 'dropdown' ? 'خيارات القائمة المنسدلة (سطر لكل خيار) *' : 'خيارات العمود (سطر لكل خيار) *',
                        hintText: 'مثال:\nمطابق\nغير مطابق\nغير قابل للتطبيق',
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (colTitleCtrl.text.trim().isEmpty) return;
                
                String key = isEditing ? existingCol.key : 'col_${DateTime.now().millisecondsSinceEpoch}_${tableColumns.length}';
                List<String> options = [];
                double width = 1.2;

                if (colTypeCtrl.value == 'signature') {
                  if (!isEditing) key = 'signature';
                  width = 1.2;
                } else if (colTypeCtrl.value == 'inspector') {
                  if (!isEditing) key = 'inspector';
                  width = 1.4;
                } else if (colTypeCtrl.value == 'yes_no') {
                  options = ['نعم', 'لا'];
                  width = 1.1;
                } else if (colTypeCtrl.value == 'match') {
                  options = ['مطابق', 'غير مطابق'];
                  width = 2.0;
                } else if (colTypeCtrl.value == 'radio' || colTypeCtrl.value == 'dropdown') {
                  final parsed = DynamicReportField.parseOptionsText(colOptionsCtrl.text);
                  if (parsed.length < 2) {
                    Get.snackbar('خطأ', 'يجب إدخال خيارين على الأقل لعمود الخيارات أو القائمة المنسدلة');
                    return;
                  }
                  options = parsed;
                  width = colTypeCtrl.value == 'dropdown' ? 1.8 : (parsed.length <= 2 ? 1.6 : 2.4);
                } else if (colTypeCtrl.value == 'label') {
                  width = 2.2;
                } else if (colTypeCtrl.value == 'text') {
                  width = 2.0;
                } else if (colTypeCtrl.value == 'date') {
                  width = 1.3;
                } else if (colTypeCtrl.value == 'time') {
                  width = 1.0;
                } else if (colTypeCtrl.value == 'decimal') {
                  width = 1.0;
                } else if (colTypeCtrl.value == 'checkbox') {
                  width = 0.8;
                }

                final newCol = DynamicTableColumn(
                  key: key,
                  title: colTitleCtrl.text.trim(),
                  type: colTypeCtrl.value,
                  options: options,
                  widthRatio: width,
                );

                if (isEditing && existingIndex != null) {
                  tableColumns[existingIndex] = newCol;
                } else {
                  tableColumns.add(newCol);
                }

                // Apply entered lines to predefinedRows
                final lines = colValuesCtrl.text
                    .split('\n')
                    .map((l) => l.trim())
                    .toList();
                while (lines.isNotEmpty && lines.last.isEmpty) {
                  lines.removeLast();
                }

                if (lines.isNotEmpty) {
                  while (predefinedRows.length < lines.length) {
                    predefinedRows.add(<String, dynamic>{});
                  }
                  for (int i = 0; i < lines.length; i++) {
                    predefinedRows[i][key] = lines[i];
                  }
                  if (predefinedRows.length > (int.tryParse(rowCountCtrl.text) ?? 0)) {
                    rowCountCtrl.text = '${predefinedRows.length}';
                  }
                }

                Get.back();
              },
              child: Text(isEditing ? 'حفظ التعديل' : 'إضافة العمود'),
            ),
          ],
        ),
      );
    }

    void showManageRowValuesDialog() {
      if (tableColumns.isEmpty) {
        Get.snackbar('تنبيه', 'يرجى إضافة أعمدة أولاً لتعبئة قيمها');
        return;
      }

      final selectedColKey = (tableColumns.first.key).obs;
      final valuesTextCtrl = TextEditingController();

      void loadValuesForCol(String colKey) {
        final values = <String>[];
        for (var r in predefinedRows) {
          values.add(r[colKey]?.toString() ?? '');
        }
        while (values.isNotEmpty && values.last.isEmpty) {
          values.removeLast();
        }
        valuesTextCtrl.text = values.join('\n');
      }

      loadValuesForCol(selectedColKey.value);

      Get.dialog(
        AlertDialog(
          title: const Text('تعبئة قيم الأعمدة في الصفوف', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'اختر العمود ثم اكتب أو الصق بنود الصفوف (سطر لكل صف):',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                Obx(() => DropdownButtonFormField<String>(
                  initialValue: selectedColKey.value,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'العمود المستهدف (مثل بند الفحص)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: tableColumns.map((col) {
                    return DropdownMenuItem(
                      value: col.key,
                      child: Text(col.title),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      selectedColKey.value = val;
                      loadValuesForCol(val);
                    }
                  },
                )),
                const SizedBox(height: 12),
                TextField(
                  controller: valuesTextCtrl,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'قيم الصفوف (سطر لكل صف)',
                    hintText: 'مثال:\nمطابقة المادة لأمر الشراء\nسلامة العبوات\nنظافة المادة\nعدم وجود تلف',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '💡 يمكنك نسخ ولصق قائمة البنود مباشرة وسيقوم التطبيق بتعيين كل سطر لصف مستقل.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final key = selectedColKey.value;
                final lines = valuesTextCtrl.text
                    .split('\n')
                    .map((l) => l.trim())
                    .toList();

                while (lines.isNotEmpty && lines.last.isEmpty) {
                  lines.removeLast();
                }

                while (predefinedRows.length < lines.length) {
                  predefinedRows.add(<String, dynamic>{});
                }

                for (int i = 0; i < lines.length; i++) {
                  predefinedRows[i][key] = lines[i];
                }

                for (int i = lines.length; i < predefinedRows.length; i++) {
                  predefinedRows[i].remove(key);
                }

                while (predefinedRows.isNotEmpty && predefinedRows.last.values.every((v) => v == null || v.toString().trim().isEmpty)) {
                  predefinedRows.removeLast();
                }

                if (predefinedRows.isNotEmpty) {
                  rowCountCtrl.text = '${predefinedRows.length}';
                }

                Get.back();
                Get.snackbar('تم الحفظ', 'تم تحديث قيم العمود بنجاح');
              },
              child: const Text('تطبيق على العمود'),
            ),
          ],
        ),
      );
    }

    Get.dialog(
      AlertDialog(
        title: Text(isEditing ? 'تعديل الحقل' : 'إضافة حقل جديد'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'قوالب حقول سريعة وجاهزة:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.calendar_today, size: 14),
                        label: const Text('تاريخ التقرير', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          labelCtrl.text = 'تاريخ التقرير';
                          typeCtrl.value = 'date';
                          hintCtrl.text = 'اختر التاريخ';
                          requiredCtrl.value = true;
                        },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.view_day_outlined, size: 14),
                        label: const Text('اليوم', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          labelCtrl.text = 'اليوم';
                          typeCtrl.value = 'dropdown';
                          optionsCtrl.text = 'السبت\nالأحد\nالإثنين\nالثلاثاء\nالأربعاء\nالخميس\nالجمعة';
                          hintCtrl.text = 'اختر اليوم';
                          requiredCtrl.value = true;
                        },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.precision_manufacturing_outlined, size: 14),
                        label: const Text('رقم خط الإنتاج', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          labelCtrl.text = 'رقم خط الإنتاج';
                          typeCtrl.value = 'dropdown';
                          optionsCtrl.text = 'خط الإنتاج 1\nخط الإنتاج 2\nخط الإنتاج 3\nخط الإنتاج 4\nخط الإنتاج 5';
                          hintCtrl.text = 'اختر خط الإنتاج';
                          requiredCtrl.value = true;
                        },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.access_time_outlined, size: 14),
                        label: const Text('الوردية', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          labelCtrl.text = 'الوردية';
                          typeCtrl.value = 'dropdown';
                          optionsCtrl.text = 'الوردية الأولى\nالوردية الثانية\nالوردية الثالثة';
                          hintCtrl.text = 'اختر الوردية';
                          requiredCtrl.value = false;
                        },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.person_pin_circle_outlined, size: 14),
                        label: const Text('المسؤول عن المراقبة', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          labelCtrl.text = 'المسؤول عن المراقبة';
                          typeCtrl.value = 'text';
                          hintCtrl.text = 'يتم تسجيله تلقائياً';
                          requiredCtrl.value = false;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'اسم الحقل / عنوان الجدول *'),
                ),
                const SizedBox(height: 12),
                Obx(() => DropdownButtonFormField<String>(
                  initialValue: typeCtrl.value,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'نوع الحقل'),
                  items: const [
                    DropdownMenuItem(value: 'text', child: Text('🔤 نص قصير (اسم، كود، بيان)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'multiline_text', child: Text('📝 نص متعدد الأسطر (شرح وملاحظات)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'note', child: Text('📌 صندوق ملاحظة مميز (تنبيه ملون)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'instructions', child: Text('ℹ️ إرشادات وتعليمات ثابتة (للقراءة فقط)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'number', child: Text('🔢 رقم صحيح (كميات وأعداد)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'decimal', child: Text('🔬 رقم عشري (قياسات وأوزان وpH)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'date', child: Text('📅 تاريخ (يوم / شهر / سنة)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'time', child: Text('🕒 وقت (ساعة : دقيقة)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'datetime', child: Text('🗓️ تاريخ ووقت معاً', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'dropdown', child: Text('🔽 قائمة منسدلة (اختيار من متعدد)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'radio', child: Text('🔘 اختيار واحد (أزرار راديو)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'checkbox', child: Text('☑️ صندوق اختيار (نعم / لا)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'switch', child: Text('🎚️ زر تبديل نعم/لا (Switch)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'signature', child: Text('✍️ خانة توقيع إلكتروني / اعتماد', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'rating', child: Text('⭐ شريط تقييم بالنجوم (1 إلى 5)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'calculated', child: Text('🧮 حقل محسوب تلقائياً (معادلة رياضية)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'table', child: Text('📊 جدول فحص ديناميكي (Checklist Table)', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      typeCtrl.value = val;
                      if (val == 'table' && tableColumns.isEmpty) {
                        applyTemplate('hygiene');
                      }
                    }
                  },
                )),
                const SizedBox(height: 12),
                Obx(() {
                  if (typeCtrl.value == 'dropdown' || typeCtrl.value == 'radio') {
                    return TextField(
                      controller: optionsCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'الخيارات (سطر لكل خيار)',
                        hintText: 'مثال:\nمطابق\nغير مطابق\nمطابق جزئياً',
                        alignLabelWithHint: true,
                      ),
                    );
                  }

                  if (typeCtrl.value == 'table') {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        const Text(
                          'إعدادات الجدول:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark),
                        ),
                        const SizedBox(height: 8),
                        // Quick template buttons
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.science_outlined, size: 16),
                                label: const Text('الأوزون (CCP1)', style: TextStyle(fontSize: 11)),
                                onPressed: () => applyTemplate('ccp_ozone'),
                              ),
                              const SizedBox(width: 6),
                              ActionChip(
                                avatar: const Icon(Icons.water_drop_outlined, size: 16),
                                label: const Text('الأغطية والتسريب (CCP2)', style: TextStyle(fontSize: 11)),
                                onPressed: () => applyTemplate('ccp_capping'),
                              ),
                              const SizedBox(width: 6),
                              ActionChip(
                                avatar: const Icon(Icons.history_toggle_off, size: 16),
                                label: const Text('مراقبة 24 ساعة (3 ورديات)', style: TextStyle(fontSize: 11)),
                                onPressed: () => applyTemplate('daily_24h'),
                              ),
                              const SizedBox(width: 6),
                              ActionChip(
                                avatar: const Icon(Icons.people, size: 16),
                                label: const Text('قالب النظافة', style: TextStyle(fontSize: 11)),
                                onPressed: () => applyTemplate('hygiene'),
                              ),
                              const SizedBox(width: 6),
                              ActionChip(
                                avatar: const Icon(Icons.inventory, size: 16),
                                label: const Text('فحص المواد الخام', style: TextStyle(fontSize: 11)),
                                onPressed: () => applyTemplate('raw_materials'),
                              ),
                              const SizedBox(width: 6),
                              ActionChip(
                                avatar: const Icon(Icons.tune, size: 16),
                                label: const Text('جدول مخصص فارغ', style: TextStyle(fontSize: 11)),
                                onPressed: () => applyTemplate('custom'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: rowCountCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'عدد صفوف الإدخال',
                                  hintText: 'مثال: 15',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Obx(() => SwitchListTile(
                                title: const Text('طباعة بالعرض؟ (Landscape)', style: TextStyle(fontSize: 11)),
                                value: isLandscapeCtrl.value,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                onChanged: (val) => isLandscapeCtrl.value = val,
                              )),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Obx(() => SwitchListTile(
                          title: const Text('السماح بإضافة وحذف صفوف أثناء التعبئة', style: TextStyle(fontSize: 12)),
                          value: allowAddRowsCtrl.value,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onChanged: (val) => allowAddRowsCtrl.value = val,
                        )),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Obx(() => Text(
                              'أعمدة الجدول (${tableColumns.length}):',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            )),
                            TextButton.icon(
                              onPressed: () => showAddColumnDialog(),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('إضافة عمود'),
                            ),
                          ],
                        ),
                        Obx(() {
                          if (tableColumns.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('لا توجد أعمدة مضافة. اضغط على "+ إضافة عمود" أو اختر قالباً جاهزاً.'),
                            );
                          }
                          return Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: tableColumns.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final col = tableColumns[idx];
                                  String typeLabel = switch (col.type) {
                                    'yes_no' => 'نعم/لا',
                                    'match' => 'مطابق/غير مطابق',
                                    'number' => 'رقم',
                                    'decimal' => 'عشري',
                                    'date' => 'تاريخ',
                                    'time' => 'وقت',
                                    'radio' => 'اختيار واحد',
                                    'dropdown' => 'قائمة منسدلة',
                                    'checkbox' => 'خانة اختيار',
                                    'label' => 'ثابت',
                                    'inspector' => 'مسؤول المراقبة (تلقائي)',
                                    'signature' => 'توقيع إلكتروني',
                                    _ => 'نص',
                                  };

                                return ListTile(
                                  dense: true,
                                  onTap: () => showAddColumnDialog(existingCol: col, existingIndex: idx),
                                  title: Text(col.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  subtitle: Obx(() {
                                    final count = predefinedRows.where((r) => r[col.key] != null && r[col.key].toString().trim().isNotEmpty).length;
                                    return Text('النوع: $typeLabel | القيم المسبقة: $count بند', style: const TextStyle(fontSize: 10, color: Colors.grey));
                                  }),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                        tooltip: 'تعديل العمود وقيمه',
                                        onPressed: () => showAddColumnDialog(existingCol: col, existingIndex: idx),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                        tooltip: 'حذف العمود',
                                        onPressed: () {
                                          tableColumns.removeAt(idx);
                                          for (var r in predefinedRows) {
                                            r.remove(col.key);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: showManageRowValuesDialog,
                          icon: const Icon(Icons.edit_note, size: 18),
                          label: Obx(() => Text(
                            '📋 تعبئة وتعديل قيم الصفوف المسبقة (${predefinedRows.length} صف مسجل)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          )),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            side: const BorderSide(color: AppColors.primaryDark),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          ),
                        ),
                      ],
                    );
                  }

                  return const SizedBox.shrink();
                }),
                const SizedBox(height: 12),
                // إعدادات التحقق والتنسيق (تظهر حسب نوع الحقل)
                Obx(() {
                  final t = typeCtrl.value;
                  if (t == 'table') return const SizedBox.shrink();

                  final isNumeric = t == 'number' || t == 'decimal';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: hintCtrl,
                        decoration: const InputDecoration(
                          labelText: 'تلميح للحقل (اختياري)',
                          hintText: 'مثال: أدخل القيمة بالملليتر',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (isNumeric) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'الحد الأدنى',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: maxCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'الحد الأقصى',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: unitCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'الوحدة',
                                  hintText: 'مثال: مل',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (typeCtrl.value == 'rating') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'أقل تقييم',
                                  hintText: '1',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: maxCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'أعلى تقييم',
                                  hintText: '5',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (typeCtrl.value == 'calculated') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: formulaCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'صيغة الحساب *',
                            hintText: 'مثال: {field_x} * 2 + {field_y}',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                            helperText: 'استخدم مفاتيح الحقول بين أقواس { }، وعمليات + - * / و ( )',
                          ),
                        ),
                      ],
                      if (typeCtrl.value == 'instructions') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: instructionsCtrl,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'نص التعليمات *',
                            hintText: 'مثال:\nتعليمات الاستخدام:\n1. استخدام الكمامة قبل الفحص\n2. ارتداء ملابس مناسبة\n3. يجب تسليم التقرير يومياً الساعة 11 مساءً',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                            helperText: 'يُعرض هذا النص أثناء التعبئة وفي PDF كصندوق توجيهي (للقراءة فقط)',
                          ),
                        ),
                      ],
                    ],
                  );
                }),
                const SizedBox(height: 12),
                Obx(() => SwitchListTile(
                  title: const Text('مطلوب إدخاله؟'),
                  value: requiredCtrl.value,
                  onChanged: (val) => requiredCtrl.value = val,
                )),
                const Divider(height: 24),
                // --- قسم تخصيص ألوان البند والتفاصيل ---
                Text('تنسيق الألوان (البند والتفاصيل):', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                // لون عنوان البند
                Text('لون عنوان البند (الرأس):', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                const SizedBox(height: 6),
                Obx(() {
                  final presets = [
                    {'name': 'تلقائي (أزرق هادئ)', 'hex': '', 'color': const Color(0xFFBDD7EE)},
                    {'name': 'أزرق رسمي', 'hex': '#BDD7EE', 'color': const Color(0xFFBDD7EE)},
                    {'name': 'أزرق خفيف', 'hex': '#D9E1F2', 'color': const Color(0xFFD9E1F2)},
                    {'name': 'رمادي ناعم', 'hex': '#E2E8F0', 'color': const Color(0xFFE2E8F0)},
                    {'name': 'أخضر هادئ', 'hex': '#C6F6D5', 'color': const Color(0xFFC6F6D5)},
                    {'name': 'برتقالي فاتح', 'hex': '#FEEBC8', 'color': const Color(0xFFFEEBC8)},
                    {'name': 'أصفر باستيل', 'hex': '#FEFCBF', 'color': const Color(0xFFFEFCBF)},
                    {'name': 'وردي ناعم', 'hex': '#FED7E2', 'color': const Color(0xFFFED7E2)},
                    {'name': 'أرجواني', 'hex': '#E9D8FD', 'color': const Color(0xFFE9D8FD)},
                  ];
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: presets.map((p) {
                        final hex = p['hex'] as String;
                        final isSel = headerColorCtrl.value.toUpperCase() == hex.toUpperCase();
                        final col = p['color'] as Color;
                        return GestureDetector(
                          onTap: () => headerColorCtrl.value = hex,
                          child: Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: col,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSel ? Colors.blue.shade900 : Colors.grey.shade400,
                                width: isSel ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSel) const Icon(Icons.check, size: 14, color: Colors.black87),
                                Text(p['name'] as String, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                // لون خلفية التفاصيل
                Text('لون خلفية التفاصيل / القيمة:', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                const SizedBox(height: 6),
                Obx(() {
                  final presets = [
                    {'name': 'تلقائي (أبيض)', 'hex': '', 'color': Colors.white},
                    {'name': 'أبيض ناصع', 'hex': '#FFFFFF', 'color': Colors.white},
                    {'name': 'رمادي فائق النعومة', 'hex': '#F8FAFC', 'color': const Color(0xFFF8FAFC)},
                    {'name': 'عاجي هادئ', 'hex': '#FFFFF0', 'color': const Color(0xFFFFFFF0)},
                    {'name': 'نعناعي خفيف', 'hex': '#F0FDF4', 'color': const Color(0xFFF0FDF4)},
                    {'name': 'أصفر ناعم', 'hex': '#FFFBEB', 'color': const Color(0xFFFFFBEB)},
                  ];
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: presets.map((p) {
                        final hex = p['hex'] as String;
                        final isSel = valueColorCtrl.value.toUpperCase() == hex.toUpperCase();
                        final col = p['color'] as Color;
                        return GestureDetector(
                          onTap: () => valueColorCtrl.value = hex,
                          child: Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: col,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSel ? Colors.blue.shade900 : Colors.grey.shade400,
                                width: isSel ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSel) const Icon(Icons.check, size: 14, color: Colors.black87),
                                Text(p['name'] as String, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                // بطاقة المعاينة الحية
                Obx(() {
                  Color hCol = const Color(0xFFBDD7EE);
                  if (headerColorCtrl.value.isNotEmpty) {
                    final clean = headerColorCtrl.value.replaceAll('#', '').trim();
                    final val = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
                    if (val != null) hCol = Color(val);
                  }
                  Color vCol = Colors.white;
                  if (valueColorCtrl.value.isNotEmpty) {
                    final clean = valueColorCtrl.value.replaceAll('#', '').trim();
                    final val = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
                    if (val != null) vCol = Color(val);
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: vCol,
                      border: Border.all(color: Colors.grey.shade400, width: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'معاينة: محتوى التفاصيل والقيمة هنا...',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            color: hCol,
                            alignment: Alignment.centerRight,
                            child: Text(
                              labelCtrl.text.isNotEmpty ? labelCtrl.text : 'عنوان البند',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (labelCtrl.text.isEmpty) return;
              
              String? optionsJson;
              String? validationJson;
              String? defaultValue;
              if (typeCtrl.value == 'dropdown' || typeCtrl.value == 'radio') {
                final list = DynamicReportField.parseOptionsText(optionsCtrl.text);
                if (list.isEmpty) {
                  Get.snackbar('خطأ', 'يجب إضافة خيار واحد على الأقل');
                  return;
                }
                optionsJson = jsonEncode(list);
              } else if (typeCtrl.value == 'table') {
                if (tableColumns.isEmpty) {
                  Get.snackbar('خطأ', 'يجب إضافة عمود واحد على الأقل للجدول');
                  return;
                }

                final rowCount = int.tryParse(rowCountCtrl.text.trim()) ?? (predefinedRows.isNotEmpty ? predefinedRows.length : 15);
                final defaultRows = List.generate(rowCount, (index) {
                  Map<String, dynamic> row = {};
                  if (index < predefinedRows.length) {
                    row.addAll(predefinedRows[index]);
                  }
                  for (var col in tableColumns) {
                    if (!row.containsKey(col.key) || row[col.key] == null || row[col.key].toString().isEmpty) {
                      if (col.type == 'yes_no') {
                        row[col.key] = 'نعم';
                      } else if (col.type == 'match') {
                        row[col.key] = 'مطابق';
                      }
                    }
                  }
                  return row;
                });

                final tableConfig = DynamicTableConfig(
                  columns: tableColumns.toList(),
                  defaultRows: defaultRows,
                  allowAddRows: allowAddRowsCtrl.value,
                  isLandscape: isLandscapeCtrl.value,
                  rowCount: rowCount,
                );
                optionsJson = tableConfig.toJsonString();
              } else if (typeCtrl.value == 'calculated') {
                final formula = formulaCtrl.text.trim();
                if (formula.isEmpty) {
                  Get.snackbar('خطأ', 'يجب إدخال صيغة الحساب');
                  return;
                }
                validationJson = jsonEncode({'formula': formula});
              } else if (typeCtrl.value == 'rating') {
                final mn = int.tryParse(minCtrl.text.trim()) ?? 1;
                final mx = int.tryParse(maxCtrl.text.trim()) ?? 5;
                if (mx <= mn) {
                  Get.snackbar('خطأ', 'يجب أن يكون أعلى تقييم أكبر من أقل تقييم');
                  return;
                }
                validationJson = jsonEncode({'min': mn, 'max': mx});
              } else if (typeCtrl.value == 'instructions') {
                final text = instructionsCtrl.text.trim();
                if (text.isEmpty) {
                  Get.snackbar('خطأ', 'يجب إدخال نص التعليمات');
                  return;
                }
                defaultValue = text;
              }

              // دمج إعدادات ألوان البند والتفاصيل
              Map<String, dynamic> vMap = {};
              if (validationJson != null) {
                try {
                  final decoded = jsonDecode(validationJson);
                  if (decoded is Map<String, dynamic>) vMap = Map<String, dynamic>.from(decoded);
                } catch (_) {}
              }
              if (headerColorCtrl.value.trim().isNotEmpty) {
                vMap['header_bg_color'] = headerColorCtrl.value.trim();
              } else {
                vMap.remove('header_bg_color');
              }
              if (valueColorCtrl.value.trim().isNotEmpty) {
                vMap['value_bg_color'] = valueColorCtrl.value.trim();
              } else {
                vMap.remove('value_bg_color');
              }
              if (vMap.isNotEmpty) {
                validationJson = jsonEncode(vMap);
              }

              final savedField = DynamicReportField(
                id: existingField?.id,
                reportId: existingField?.reportId ?? controller.reportId.value ?? 0,
                sectionId: sectionId,
                fieldKey: () {
                  if (existingField?.fieldKey != null) return existingField!.fieldKey;
                  final lbl = labelCtrl.text.trim();
                  String k;
                  if (lbl == 'تاريخ التقرير' || lbl.contains('تاريخ')) {
                    k = 'report_date';
                  } else if (lbl == 'اليوم') {
                    k = 'day_name';
                  } else if (lbl == 'رقم خط الإنتاج' || lbl.contains('خط الإنتاج')) {
                    k = 'line_number';
                  } else if (lbl == 'الوردية') {
                    k = 'shift';
                  } else if (lbl.contains('المسؤول عن المراقبة')) {
                    k = 'inspector';
                  } else {
                    return controller.generateFieldKey();
                  }
                  if (controller.fields.any((f) => f.fieldKey == k)) {
                    return '${k}_${DateTime.now().millisecondsSinceEpoch % 1000}';
                  }
                  return k;
                }(),
                label: labelCtrl.text.trim(),
                hint: hintCtrl.text.trim().isEmpty ? null : hintCtrl.text.trim(),
                fieldType: typeCtrl.value,
                isRequired: requiredCtrl.value,
                defaultValue: defaultValue,
                optionsJson: optionsJson,
                validationJson: validationJson,
                minValue: double.tryParse(minCtrl.text.trim()),
                maxValue: double.tryParse(maxCtrl.text.trim()),
                unit: unitCtrl.text.trim().isEmpty ? null : unitCtrl.text.trim(),
                createdAt: existingField?.createdAt,
              );

              if (isEditing) {
                controller.updateField(savedField);
              } else {
                controller.addField(savedField);
              }
              Get.back();
            },
            child: Text(isEditing ? 'حفظ التعديل' : 'إضافة'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrientationOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primaryOf(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final inkColor = AppColors.inkOf(context);
    final mutedColor = AppColors.mutedOf(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.08)
              : (isDark ? surfaceColor : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : (isDark ? borderColor : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? primaryColor : mutedColor,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isSelected ? primaryColor : inkColor,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check_circle_rounded, color: primaryColor, size: 16),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 10,
                color: mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconSelector(BuildContext context, DynamicReportBuilderController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final inkColor = AppColors.inkOf(context);
    final mutedColor = AppColors.mutedOf(context);

    return Obx(() {
      final selectedKey = controller.selectedIcon.value;
      final selectedHex = controller.selectedIconColorHex.value;
      final selectedIconData = DynamicReport.getIconData(selectedKey);
      final activeColor = DynamicReportColorHelper.parseHexColor(selectedHex) ??
          DynamicReportColorHelper.getColorByKey(selectedKey);
      final activeHexStr = DynamicReportColorHelper.colorToHex(activeColor);

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? surfaceColor : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? borderColor : Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // شريط المعاينة الحية للأيقونة واللون المختار
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: isDark ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: activeColor.withValues(alpha: 0.45), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: activeColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: activeColor.withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(selectedIconData, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'الأيقونة: ${_getIconLabel(selectedKey)}',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: inkColor,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: activeColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    activeHexStr,
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
                              'اختر شكل الأيقونة ولونها المميز لضمان عدم تشابه التقارير (أكثر من 64 لوناً)',
                              softWrap: true,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => controller.suggestDistinctColor(),
                        icon: Icon(Icons.auto_awesome_outlined, size: 16, color: activeColor),
                        label: Text(
                          'لون فريد غير مستخدم',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: activeColor,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: activeColor),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showCustomHexDialog(context, controller, activeHexStr),
                        icon: Icon(Icons.colorize_outlined, size: 16, color: inkColor),
                        label: Text(
                          'كود لون #HEX',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            color: inkColor,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '1. اختر شكل الأيقونة (${_availableIcons.length} أيقونة):',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: inkColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableIcons.map((opt) {
                final isSelected = opt.key == selectedKey;
                final chipColor = isSelected
                    ? activeColor
                    : DynamicReportColorHelper.getColorByKey(opt.key);
                return InkWell(
                  onTap: () => controller.selectedIcon.value = opt.key,
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? activeColor
                          : (isDark ? surfaceColor : Colors.white),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? activeColor
                            : (isDark ? borderColor : Colors.grey.shade300),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          opt.icon,
                          size: 18,
                          color: isSelected ? Colors.white : chipColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          opt.label,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.grey.shade200 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.palette_outlined, size: 16, color: activeColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '2. اختر لون التقرير والأيقونة (${DynamicReportColorHelper.curatedPalette.length} لوناً مميزاً):',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: inkColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: List.generate(DynamicReportColorHelper.curatedPalette.length, (index) {
                final paletteColor = DynamicReportColorHelper.curatedPalette[index];
                final paletteHex = DynamicReportColorHelper.colorToHex(paletteColor);
                final isColorSelected = paletteHex.toUpperCase() == activeHexStr.toUpperCase();

                return Tooltip(
                  message: 'لون رقم ${index + 1} ($paletteHex)',
                  child: InkWell(
                    onTap: () => controller.selectedIconColorHex.value = paletteHex,
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: paletteColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isColorSelected
                              ? (isDark ? Colors.white : Colors.black87)
                              : Colors.white.withValues(alpha: 0.35),
                          width: isColorSelected ? 2.5 : 1,
                        ),
                        boxShadow: isColorSelected
                            ? [
                                BoxShadow(
                                  color: paletteColor.withValues(alpha: 0.55),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: isColorSelected
                          ? const Icon(Icons.check, size: 17, color: Colors.white)
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      );
    });
  }

  void _showCustomHexDialog(
    BuildContext context,
    DynamicReportBuilderController controller,
    String currentHex,
  ) {
    final hexCtrl = TextEditingController(text: currentHex);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'إدخال كود لون مخصص (#HEX)',
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 15),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل كود اللون السداسي (مثال: #1E88E5 أو #D81B60):',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: hexCtrl,
              autofocus: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                hintText: '#1E88E5',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = DynamicReportColorHelper.parseHexColor(hexCtrl.text);
              if (parsed != null) {
                controller.selectedIconColorHex.value =
                    DynamicReportColorHelper.colorToHex(parsed);
                Navigator.of(ctx).pop();
              } else {
                Get.snackbar(
                  'تنبيه',
                  'يرجى إدخال كود لون صحيح مكون من 6 خانات مثل #1E88E5',
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            child: const Text('تطبيق اللون', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }
}

class _ReportIconOption {
  final String key;
  final String label;
  final IconData icon;

  const _ReportIconOption({required this.key, required this.label, required this.icon});
}

const List<_ReportIconOption> _availableIcons = [
  _ReportIconOption(key: 'description', label: 'مستند قياسي', icon: Icons.description_outlined),
  _ReportIconOption(key: 'water_drop', label: 'فحص مياه', icon: Icons.water_drop_outlined),
  _ReportIconOption(key: 'science', label: 'مختبر وتحاليل', icon: Icons.science_outlined),
  _ReportIconOption(key: 'verified', label: 'جودة واعتماد', icon: Icons.verified_outlined),
  _ReportIconOption(key: 'fact_check', label: 'قائمة تفتيش', icon: Icons.fact_check_outlined),
  _ReportIconOption(key: 'assignment', label: 'سجل تدقيق', icon: Icons.assignment_outlined),
  _ReportIconOption(key: 'inventory_2', label: 'مواد ومخزون', icon: Icons.inventory_2_outlined),
  _ReportIconOption(key: 'clean_hands', label: 'نظافة وسلامة', icon: Icons.clean_hands_outlined),
  _ReportIconOption(key: 'health_and_safety', label: 'صحة مهنية', icon: Icons.health_and_safety_outlined),
  _ReportIconOption(key: 'precision_manufacturing', label: 'خط إنتاج', icon: Icons.precision_manufacturing_outlined),
  _ReportIconOption(key: 'biotech', label: 'ميكروبيولوجي', icon: Icons.biotech_outlined),
  _ReportIconOption(key: 'filter_alt', label: 'فلاتر ومعالجة', icon: Icons.filter_alt_outlined),
  _ReportIconOption(key: 'table_chart', label: 'جدول بيانات', icon: Icons.table_chart_outlined),
  _ReportIconOption(key: 'rule', label: 'معايير قياسية', icon: Icons.rule_outlined),
  _ReportIconOption(key: 'assessment', label: 'تقييم ومتابعة', icon: Icons.assessment_outlined),
  _ReportIconOption(key: 'report_problem', label: 'عدم مطابقة / إنذار', icon: Icons.report_problem_outlined),
  _ReportIconOption(key: 'build_circle', label: 'صيانة ومعايرة', icon: Icons.build_circle_outlined),
  _ReportIconOption(key: 'thermostat', label: 'حرارة ورطوبة', icon: Icons.thermostat_outlined),
  _ReportIconOption(key: 'pest_control', label: 'مكافحة آفات', icon: Icons.pest_control_outlined),
  _ReportIconOption(key: 'checkroom', label: 'زي موحد وخزائن', icon: Icons.checkroom_outlined),
  _ReportIconOption(key: 'local_shipping', label: 'شاحنات وتوريد', icon: Icons.local_shipping_outlined),
  _ReportIconOption(key: 'warehouse', label: 'مستودعات وتخزين', icon: Icons.warehouse_outlined),
  _ReportIconOption(key: 'recycling', label: 'مخلفات وبيئة', icon: Icons.recycling_outlined),
  _ReportIconOption(key: 'local_drink', label: 'تعبئة وعبوات', icon: Icons.local_drink_outlined),
  _ReportIconOption(key: 'speed', label: 'عدادات وضغط', icon: Icons.speed_outlined),
  _ReportIconOption(key: 'engineering', label: 'فريق العمل والمهندسين', icon: Icons.engineering_outlined),
  _ReportIconOption(key: 'medical_services', label: 'إسعافات أولية وطبابة', icon: Icons.medical_services_outlined),
  _ReportIconOption(key: 'cleaning_services', label: 'غسيل وتعقيم (CIP)', icon: Icons.cleaning_services_outlined),
  _ReportIconOption(key: 'bolt', label: 'طاقة وكهرباء', icon: Icons.bolt_outlined),
  _ReportIconOption(key: 'qr_code_scanner', label: 'تتبع وباركود', icon: Icons.qr_code_scanner_outlined),
  _ReportIconOption(key: 'wine_bar', label: 'زجاج ومواد قابلة للكسر', icon: Icons.wine_bar_outlined),
  _ReportIconOption(key: 'school', label: 'تدريب وتأهيل', icon: Icons.school_outlined),
];

String _getIconLabel(String key) {
  final cleanKey = DynamicReportColorHelper.extractIconName(key);
  final found = _availableIcons.where((opt) => opt.key == cleanKey);
  return found.isNotEmpty ? found.first.label : 'مستند قياسي';
}
