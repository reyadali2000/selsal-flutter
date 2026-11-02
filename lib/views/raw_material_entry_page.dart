import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/raw_material_entry_controller.dart';
import '../models/raw_material_models.dart';
import '../services/user_session_service.dart';
import '../widgets/ds/ds.dart';

class RawMaterialEntryPage extends StatelessWidget {
  RawMaterialEntryPage({super.key});

  final controller = Get.put(RawMaterialEntryController());

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
            'فحص واستلام المواد الخام',
            style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 19, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF00695C),
          centerTitle: true,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () {
              if (controller.isFormVisible.value) {
                controller.previousStep();
              } else {
                Get.back();
              }
            },
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const AppLoading(message: 'جاري تحميل البيانات...');
          }

          if (!controller.isFormVisible.value) {
            return _buildStartScreen(context);
          }

          return _buildWizardForm(context);
        }),
      ),
    );
  }

  // ==================== START SCREEN & DRAFTS ====================

  Widget _buildStartScreen(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Banner
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF004D40), Color(0xFF00897B)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00897B).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'نموذج فحص واستلام المواد الخام',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 19,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'وثيقة الجودة المعتمدة: SELSAL-IMSF-19-03',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 12.5,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'يشمل الفحص العام لبيانات الاستلام بالإضافة إلى ملاحق الفحص التخصصية الستة (أمبولات، أغطية، ملصقات، كراتين، مواد كيميائية، وتعبئة ثانوية).',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 13.5, color: Colors.white, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'بدء فحص مادة خام جديدة',
                      icon: Icons.add_circle_outline,
                      color: Colors.white,
                      foregroundColor: const Color(0xFF004D40),
                      onPressed: () => controller.startNewReport(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Drafts Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit_note, color: Color(0xFF00695C), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'المسودات غير المكتملة',
                        style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                    ],
                  ),
                  Obx(() => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00695C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${controller.drafts.length} مسودة',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00695C)),
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 14),

              Obx(() {
                if (controller.drafts.isEmpty) {
                  return const AppCard(
                    padding: EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    child: AppEmptyState(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'لا توجد مسودات معلقة حالياً',
                      message: 'انقر على "بدء فحص مادة خام جديدة" لإنشاء تقرير واستلام جديد',
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.drafts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final draft = controller.drafts[index];
                    final cat = RawMaterialCategoryInfo.getByKey(draft.categoryKey);

                    return AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: cat.color.withValues(alpha: 0.12),
                          child: Icon(cat.icon, color: cat.color, size: 20),
                        ),
                        title: Text(
                          draft.materialName.isNotEmpty ? draft.materialName : cat.title,
                          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          'المورد: ${draft.supplierName.isNotEmpty ? draft.supplierName : "غير محدد"} • التشغيلة: ${draft.batchNumber.isNotEmpty ? draft.batchNumber : "---"}',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade600),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (UserSessionService.to.canDeleteReports)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                tooltip: 'حذف المسودة',
                                onPressed: () => controller.deleteDraft(draft.id!),
                              ),
                            const SizedBox(width: 4),
                            AppButton.primary(
                              label: 'متابعة',
                              color: cat.color,
                              onPressed: () => controller.resumeDraft(draft),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== WIZARD STEPPER FORM ====================

  Widget _buildWizardForm(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            _buildStepperHeader(context),
            Expanded(
              child: Obx(() {
                switch (controller.currentStep.value) {
                  case 0:
                    return _buildCategorySelectionStep(context);
                  case 1:
                    return _buildReceiptAndGeneralChecklistStep(context);
                  case 2:
                    return _buildAnnexChecklistStep(context);
                  case 3:
                    return _buildDecisionAndActionsStep(context);
                  default:
                    return _buildCategorySelectionStep(context);
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final steps = [
      {'title': 'نوع المادة', 'icon': Icons.category_outlined},
      {'title': 'الفحص العام', 'icon': Icons.receipt_long_outlined},
      {'title': 'الملحق التخصصي', 'icon': Icons.fact_check_outlined},
      {'title': 'قرار الجودة', 'icon': Icons.verified_outlined},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isDone = controller.currentStep.value > index;
          final isCurrent = controller.currentStep.value == index;
          final color = isCurrent ? const Color(0xFF00695C) : (isDone ? Colors.green : Colors.grey.shade400);

          return Expanded(
            child: InkWell(
              onTap: () {
                if (controller.selectedCategory.value != null || index == 0) {
                  controller.currentStep.value = index;
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (index > 0)
                        Expanded(
                          child: Container(
                            height: 2.5,
                            color: isDone || isCurrent ? const Color(0xFF00695C) : (isDark ? Colors.white12 : Colors.grey.shade300),
                          ),
                        ),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: color,
                        child: Icon(
                          isDone ? Icons.check : (steps[index]['icon'] as IconData),
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      if (index < steps.length - 1)
                        Expanded(
                          child: Container(
                            height: 2.5,
                            color: isDone ? const Color(0xFF00695C) : (isDark ? Colors.white12 : Colors.grey.shade300),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[index]['title'] as String,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? const Color(0xFF00695C) : (isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==================== STEP 0: CATEGORY SELECTION ====================

  Widget _buildCategorySelectionStep(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الخطوة 1: اختر نوع المادة الخام المطلوب فحصها',
            style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'سيتم ربط الملحق التخصصي التابع للقسم المختار تلقائياً مع النموذج العام.',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 650 ? 3 : 2;
                return GridView.builder(
                  itemCount: RawMaterialCategoryInfo.allCategories.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 180,
                  ),
                  itemBuilder: (context, index) {
                    final cat = RawMaterialCategoryInfo.allCategories[index];
                    final isSelected = controller.selectedCategory.value?.key == cat.key;

                    return InkWell(
                      onTap: () => controller.selectCategory(cat),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? cat.color : Colors.grey.withValues(alpha: 0.2),
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected ? cat.color.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                CircleAvatar(
                                  backgroundColor: cat.color.withValues(alpha: 0.12),
                                  radius: 20,
                                  child: Icon(cat.icon, color: cat.color, size: 22),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cat.color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    cat.annexCode.split('-').last,
                                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 10, color: cat.color),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              cat.title,
                              style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cat.subtitle,
                              style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.grey.shade600, height: 1.3),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '${cat.criteria.length} بنود فحص',
                                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: cat.color, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                Icon(Icons.arrow_forward_ios, size: 12, color: cat.color),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STEP 1: RECEIPT DATA & 10 GENERAL CHECKLIST ====================

  Widget _buildReceiptAndGeneralChecklistStep(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title: Receipt Data
          _buildSectionHeader('أولاً: بيانات الاستلام (الصفحة العامة)', Icons.receipt_outlined),
          const SizedBox(height: 12),
          _buildReceiptFieldsCard(context),
          const SizedBox(height: 24),

          // Section Title: General Checklist (10 items)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildSectionHeader('ثانياً: نتائج الفحص العام (10 بنود)', Icons.checklist_rtl_outlined),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => controller.setAllGeneralCompliant(true),
                icon: const Icon(Icons.done_all, size: 16, color: Color(0xFF00695C)),
                label: const Text(
                  'تحديد الكل كمطابق',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Color(0xFF00695C), fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGeneralChecklistCards(context),
          const SizedBox(height: 24),

          // Navigation Buttons
          _buildStepNavigationButtons(
            onNext: () => controller.nextStep(),
            onPrev: () => controller.previousStep(),
            nextLabel: 'التالي: الملحق التخصصي',
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildReceiptFieldsCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: AppTextField(controller: controller.dateController, label: 'التاريخ', prefixIcon: Icons.calendar_today)),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(controller: controller.timeController, label: 'الوقت', prefixIcon: Icons.access_time)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: AppTextField(controller: controller.supplierController, label: 'اسم المورد *', prefixIcon: Icons.business)),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(controller: controller.poNumberController, label: 'رقم أمر الشراء', prefixIcon: Icons.numbers, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: AppTextField(controller: controller.materialNameController, label: 'اسم المادة *', prefixIcon: Icons.category)),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(controller: controller.receiptNumberController, label: 'رقم إذن الاستلام', prefixIcon: Icons.receipt, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: AppTextField(controller: controller.receivedQuantityController, label: 'الكمية المستلمة', prefixIcon: Icons.inventory, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(controller: controller.inspectedQuantityController, label: 'الكمية المفحوصة', prefixIcon: Icons.fact_check, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: AppTextField(controller: controller.acceptedQuantityController, label: 'الكمية المقبولة', prefixIcon: Icons.check_circle_outline, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(controller: controller.rejectedQuantityController, label: 'الكمية المرفوضة', prefixIcon: Icons.cancel_outlined, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: AppTextField(controller: controller.batchNumberController, label: 'رقم التشغيلة *', prefixIcon: Icons.tag)),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(controller: controller.inspectorNameController, label: 'اسم المفتش', prefixIcon: Icons.person)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralChecklistCards(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: RawMaterialGeneralCriteria.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = RawMaterialGeneralCriteria.items[index];

        return Obx(() {
          final isCompliant = controller.generalCompliance[item.id];

          return AppCard(
            padding: const EdgeInsets.all(14),
            borderColor: isCompliant == true
                ? Colors.green.withValues(alpha: 0.3)
                : (isCompliant == false ? Colors.red.withValues(alpha: 0.4) : null),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFF00695C).withValues(alpha: 0.12),
                      child: Text(
                        '${item.id}',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF00695C)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13.5)),
                          const SizedBox(height: 2),
                          Text('معيار القبول: ${item.acceptanceCriteria}', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    _buildComplianceToggle(
                      isCompliant: isCompliant,
                      onChanged: (val) => controller.generalCompliance[item.id] = val,
                    ),
                  ],
                ),
                if (isCompliant == false) ...[
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: controller.getGeneralNoteController(item.id),
                    hint: 'سبب عدم المطابقة أو الملاحظات...',
                    prefixIcon: Icons.warning_amber_rounded,
                    onChanged: (val) {
                      controller.generalNotes[item.id] = val;
                    },
                  ),
                ],
              ],
            ),
          );
        });
      },
    );
  }

  // ==================== STEP 2: SPECIALIZED ANNEX CHECKLIST ====================

  Widget _buildAnnexChecklistStep(BuildContext context) {
    final cat = controller.selectedCategory.value;
    if (cat == null) {
      return const Center(child: Text('يرجى اختيار نوع المادة أولاً'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Annex Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cat.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cat.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: cat.color,
                  child: Icon(cat.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat.annexTitle, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13.5, color: cat.color)),
                      const SizedBox(height: 2),
                      Text('رقم الملحق: ${cat.annexCode}', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildSectionHeader('بنود الفحص التخصصي (${cat.criteria.length} بنود)', Icons.playlist_add_check_circle_outlined),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => controller.setAllAnnexCompliant(true),
                icon: Icon(Icons.done_all, size: 16, color: cat.color),
                label: Text(
                  'تحديد الكل كمطابق',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: cat.color, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Annex items list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cat.criteria.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = cat.criteria[index];

              return Obx(() {
                final isCompliant = controller.annexCompliance[item.id];

                return AppCard(
                  padding: const EdgeInsets.all(14),
                  borderColor: isCompliant == true
                      ? Colors.green.withValues(alpha: 0.3)
                      : (isCompliant == false ? Colors.red.withValues(alpha: 0.4) : null),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: cat.color.withValues(alpha: 0.12),
                            child: Text('${item.id}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: cat.color)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13.5)),
                                const SizedBox(height: 2),
                                Text('معيار القبول: ${item.acceptanceCriteria}', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          _buildComplianceToggle(
                            isCompliant: isCompliant,
                            onChanged: (val) => controller.annexCompliance[item.id] = val,
                          ),
                        ],
                      ),
                      if (isCompliant == false) ...[
                        const SizedBox(height: 10),
                        AppTextField(
                          controller: controller.getAnnexNoteController(item.id),
                          hint: 'ملاحظات عدم المطابقة...',
                          prefixIcon: Icons.warning_amber_rounded,
                          onChanged: (val) {
                            controller.annexNotes[item.id] = val;
                          },
                        ),
                      ],
                    ],
                  ),
                );
              });
            },
          ),
          const SizedBox(height: 20),

          // Annex specific notes
          _buildSectionHeader('ملاحظات الملحق التخصصي', Icons.note_alt_outlined),
          const SizedBox(height: 8),
          AppTextField(
            controller: controller.annexNotesController,
            hint: 'أدخل أي ملاحظات خاصة بالملحق التخصصي هنا...',
            maxLines: 3,
            prefixIcon: Icons.note_alt_outlined,
          ),
          const SizedBox(height: 24),

          // Navigation Buttons
          _buildStepNavigationButtons(
            onNext: () => controller.nextStep(),
            onPrev: () => controller.previousStep(),
            nextLabel: 'التالي: قرار الجودة والحفظ',
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ==================== STEP 3: DECISION, ACTIONS & SAVE ====================

  Widget _buildDecisionAndActionsStep(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quality Decision
          _buildSectionHeader('قرار الجودة النهائي', Icons.gavel_outlined),
          const SizedBox(height: 10),
          _buildDecisionSelector(),
          const SizedBox(height: 20),

          // Actions Taken
          _buildSectionHeader('الإجراءات المتخذة', Icons.rule_outlined),
          const SizedBox(height: 10),
          _buildActionsTakenCard(),
          const SizedBox(height: 20),

          // General Notes
          _buildSectionHeader('الملاحظات العامة على التقرير', Icons.comment_outlined),
          const SizedBox(height: 8),
          AppTextField(
            controller: controller.generalNotesController,
            hint: 'أدخل أي ملاحظات ختامية للتقرير...',
            maxLines: 3,
            prefixIcon: Icons.comment_outlined,
          ),
          const SizedBox(height: 28),

          // Save Action Buttons
          Row(
            children: [
              Expanded(
                child: AppButton.outlined(
                  label: 'حفظ كمسودة',
                  icon: Icons.save_as_outlined,
                  foregroundColor: Colors.blue.shade700,
                  color: Colors.blue.shade700,
                  onPressed: () => controller.saveReport(isDraft: true),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: AppButton.primary(
                  label: 'إنهاء وحفظ (رفع للاعتماد)',
                  icon: Icons.send_rounded,
                  color: const Color(0xFF00695C),
                  onPressed: () => controller.saveReport(isDraft: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => controller.previousStep(),
              child: const Text('رجوع للملحق التخصصي', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildDecisionSelector() {
    final decisions = [
      {'key': 'Accepted', 'label': 'مقبول للاستخدام', 'color': Colors.green, 'icon': Icons.check_circle_outline},
      {'key': 'AcceptedWithConditions', 'label': 'مقبول بشروط', 'color': Colors.amber.shade800, 'icon': Icons.warning_amber_rounded},
      {'key': 'Hold', 'label': 'حجز (HOLD)', 'color': Colors.orange.shade800, 'icon': Icons.pause_circle_outline},
      {'key': 'Reject', 'label': 'مرفوض (REJECT)', 'color': Colors.red, 'icon': Icons.cancel_outlined},
    ];

    return Obx(() {
      return Column(
        children: decisions.map((d) {
          final isSelected = controller.qualityDecision.value == d['key'];
          final color = d['color'] as Color;

          return InkWell(
            onTap: () => controller.qualityDecision.value = d['key'] as String,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(d['icon'] as IconData, color: color, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    d['label'] as String,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? color : AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected) Icon(Icons.check_circle, color: color, size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _buildActionsTakenCard() {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Obx(() => CheckboxListTile(
            title: const Text('وضع بطاقة HOLD', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold)),
            value: controller.actionHold.value,
            activeColor: Colors.orange.shade800,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => controller.actionHold.value = val ?? false,
          )),
          Obx(() => CheckboxListTile(
            title: const Text('وضع بطاقة REJECT', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold)),
            value: controller.actionReject.value,
            activeColor: Colors.red,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => controller.actionReject.value = val ?? false,
          )),
          Obx(() => CheckboxListTile(
            title: const Text('إعادة للمورد', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold)),
            value: controller.actionReturnToSupplier.value,
            activeColor: Colors.purple,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => controller.actionReturnToSupplier.value = val ?? false,
          )),
          Obx(() => CheckboxListTile(
            title: const Text('تم فتح تقرير عدم مطابقة (NCR)', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold)),
            value: controller.actionNcr.value,
            activeColor: Colors.red.shade800,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => controller.actionNcr.value = val ?? false,
          )),
          Obx(() {
            if (!controller.actionNcr.value) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AppTextField(
                controller: controller.ncrNumberController,
                label: 'رقم تقرير عدم المطابقة (NCR Number)',
                prefixIcon: Icons.tag,
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF00695C)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14.5),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildComplianceToggle({required bool? isCompliant, required Function(bool) onChanged}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => onChanged(true),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isCompliant == true ? Colors.green : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isCompliant == true ? Colors.green : Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 14, color: isCompliant == true ? Colors.white : Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'مطابق',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCompliant == true ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: () => onChanged(false),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isCompliant == false ? Colors.red : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isCompliant == false ? Colors.red : Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.close, size: 14, color: isCompliant == false ? Colors.white : Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'غير مطابق',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCompliant == false ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepNavigationButtons({required VoidCallback onNext, required VoidCallback onPrev, required String nextLabel}) {
    return Row(
      children: [
        AppButton.outlined(
          label: 'السابق',
          onPressed: onPrev,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppButton.primary(
            label: nextLabel,
            icon: Icons.arrow_forward,
            color: const Color(0xFF00695C),
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}
