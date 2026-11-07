import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/branch_model.dart';
import '../services/factory_shifts_service.dart';
import '../services/user_session_service.dart';
import '../widgets/ds/ds.dart';

/// وحدة التحكم في شاشة الورديات والمصانع
class ShiftsController extends GetxController {
  final isLoading = true.obs;
  final branches = <BranchModel>[].obs;
  final selectedBranchId = 1.obs;
  final shifts = <ShiftModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    isLoading.value = true;
    try {
      final bList = await FactoryShiftsService.instance.getAllBranches();
      branches.value = bList;
      if (bList.isNotEmpty && !bList.any((b) => b.id == selectedBranchId.value)) {
        selectedBranchId.value = bList.first.id ?? 1;
      }
      await loadShiftsForCurrentBranch();
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحميل بيانات المصانع والورديات: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadShiftsForCurrentBranch() async {
    try {
      final list = await FactoryShiftsService.instance.getShiftsForBranch(selectedBranchId.value);
      shifts.value = list;
    } catch (e) {
      debugPrint('Error loading shifts: $e');
    }
  }

  void switchBranch(int branchId) {
    if (selectedBranchId.value == branchId) return;
    selectedBranchId.value = branchId;
    loadShiftsForCurrentBranch();
  }

  BranchModel? get currentBranch {
    try {
      return branches.firstWhere((b) => b.id == selectedBranchId.value);
    } catch (_) {
      return null;
    }
  }

  String get currentSeasonName {
    if (shifts.isNotEmpty) {
      return shifts.first.seasonName;
    }
    return 'التوقيت الصيفي';
  }

  Future<bool> saveShift({
    int? id,
    required String name,
    required String startTime,
    required String endTime,
    required String seasonName,
    bool isActive = true,
  }) async {
    try {
      if (name.trim().isEmpty) {
        Get.snackbar('تنبيه', 'يرجى إدخال اسم الوردية',
            backgroundColor: Colors.amber.shade900, colorText: Colors.white);
        return false;
      }

      final shift = ShiftModel(
        id: id,
        branchId: selectedBranchId.value,
        name: name.trim(),
        startTime: startTime.trim(),
        endTime: endTime.trim(),
        seasonName: seasonName.trim(),
        isActive: isActive,
      );

      if (id == null) {
        await FactoryShiftsService.instance.createShift(shift);
      } else {
        await FactoryShiftsService.instance.updateShift(shift);
      }

      await loadShiftsForCurrentBranch();

      Get.snackbar(
        'تم بنجاح',
        id == null ? 'تمت إضافة الوردية "$name" بنجاح' : 'تم تحديث مواعيد الوردية "$name" بنجاح',
        backgroundColor: const Color(0xFF2E7D32),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
        duration: const Duration(seconds: 3),
      );
      return true;
    } catch (e) {
      Get.snackbar('خطأ', 'فشل حفظ الوردية: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return false;
    }
  }

  Future<void> toggleShift(ShiftModel shift, bool newValue) async {
    if (shift.id == null) return;
    try {
      await FactoryShiftsService.instance.toggleShiftActive(shift.id!, newValue);
      final idx = shifts.indexWhere((s) => s.id == shift.id);
      if (idx != -1) {
        shifts[idx] = shift.copyWith(isActive: newValue);
      }
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر تحديث حالة الوردية',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  Future<void> deleteShift(int id, String name) async {
    try {
      await FactoryShiftsService.instance.deleteShift(id);
      await loadShiftsForCurrentBranch();
      Get.snackbar('تم الحذف', 'تم حذف الوردية "$name" بنجاح',
          backgroundColor: const Color(0xFFC62828), colorText: Colors.white);
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر حذف الوردية: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  Future<void> updateSeason(String newSeason) async {
    try {
      await FactoryShiftsService.instance.updateSeasonForBranch(selectedBranchId.value, newSeason);
      await loadShiftsForCurrentBranch();
      Get.snackbar('تم التحديث', 'تم تغيير الموسم إلى "$newSeason" بنجاح',
          backgroundColor: const Color(0xFF2E7D32), colorText: Colors.white);
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر تحديث الموسم: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }
}

class ShiftsView extends StatelessWidget {
  const ShiftsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ShiftsController());
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content = Obx(() {
      if (controller.isLoading.value) {
        return const AppLoading(message: 'جاري تحميل جدول الورديات...');
      }

      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 18, right: 18, top: 12, bottom: 120),
            children: [
              _buildFactorySelector(context, controller),
              const SizedBox(height: 14),
              _buildSeasonBanner(context, controller),
              const SizedBox(height: 18),
              _buildShiftsHeader(context, controller),
              const SizedBox(height: 12),
              if (controller.shifts.isEmpty)
                _buildEmptyShiftsCard(context, controller)
              else
                ...controller.shifts.map((shift) => _buildShiftCard(context, controller, shift)),
            ],
          ),
        ),
      );
    });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: canPop
            ? (isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF7FAFC))
            : Colors.transparent,
        appBar: canPop
            ? AppBar(
                title: const Text(
                  'جدول ومواعيد الورديات',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                elevation: 0,
              )
            : null,
        body: content,
      ),
    );
  }

  /// محول الفروع / المصانع العلوي
  Widget _buildFactorySelector(BuildContext context, ShiftsController controller) {
    final branches = controller.branches;
    if (branches.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppCard(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: branches.map((b) {
          final isSelected = controller.selectedBranchId.value == b.id;
          final isPlant1 = b.name.contains('1') || b.code.contains('1');

          return Expanded(
            child: InkWell(
              onTap: () => controller.switchBranch(b.id ?? 1),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: isPlant1
                              ? (Theme.of(context).brightness == Brightness.dark ? const [Color(0xFF0369A1), Color(0xFF0EA5E9)] : const [Color(0xFF003853), Color(0xFF007791)])
                              : const [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: (isPlant1 ? const Color(0xFF007791) : const Color(0xFF8E24AA))
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.factory_rounded,
                      size: 18,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        b.name,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.grey.shade700,
                          fontFamily: 'Tajawal',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// شريط الموسم الحالي وخيارات الضبط
  Widget _buildSeasonBanner(BuildContext context, ShiftsController controller) {
    final season = controller.currentSeasonName;
    final activeCount = controller.shifts.where((s) => s.isActive).length;

    IconData seasonIcon = Icons.wb_sunny_rounded;
    Color seasonColor = const Color(0xFFE65100);

    if (season.contains('شتاء') || season.contains('شتوي')) {
      seasonIcon = Icons.ac_unit_rounded;
      seasonColor = const Color(0xFF0277BD);
    } else if (season.contains('رمضان') || season.contains('مبارك')) {
      seasonIcon = Icons.nights_stay_rounded;
      seasonColor = const Color(0xFF6A1B9A);
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderColor: seasonColor.withValues(alpha: 0.25),
      borderWidth: 1.2,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: seasonColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(seasonIcon, color: seasonColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الموسم: $season',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkInk : const Color(0xFF003853),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$activeCount ورديات نشطة بالمصنع حالياً',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (UserSessionService.to.canManageShifts)
            OutlinedButton.icon(
              onPressed: () => _showSeasonSelectionDialog(context, controller),
              icon: const Icon(Icons.tune_rounded, size: 14),
              label: const Text(
                'تغيير',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  /// رأس قائمة الورديات مع زر الإضافة
  Widget _buildShiftsHeader(BuildContext context, ShiftsController controller) {
    final canManage = UserSessionService.to.canManageShifts;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(Icons.schedule_rounded, color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimaryLight : const Color(0xFF003853), size: 19),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'جدول الورديات ومواعيد العمل',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkInk : const Color(0xFF003853),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (canManage)
          ElevatedButton.icon(
            onPressed: () => _showShiftDialog(context, controller),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text(
              'إضافة وردية',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 11.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimary : const Color(0xFF003853),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
      ],
    );
  }

  /// بطاقة الوردية التفاعلية
  Widget _buildShiftCard(BuildContext context, ShiftsController controller, ShiftModel shift) {
    final isLiveNow = shift.isCurrentlyActive();
    final hours = shift.durationHours.toStringAsFixed(shift.durationHours.truncateToDouble() == shift.durationHours ? 0 : 1);

    IconData shiftIcon = Icons.wb_sunny_rounded;
    Color shiftColor = const Color(0xFF007791);

    if (shift.name.contains('مسائية') || shift.name.contains('الثانية')) {
      shiftIcon = Icons.wb_twilight_rounded;
      shiftColor = const Color(0xFFE65100);
    } else if (shift.name.contains('ليلية') || shift.name.contains('الثالثة')) {
      shiftIcon = Icons.nights_stay_rounded;
      shiftColor = const Color(0xFF6A1B9A);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        borderColor: isLiveNow ? const Color(0xFF00A896) : shiftColor.withValues(alpha: 0.25),
        borderWidth: isLiveNow ? 2.0 : 1.2,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            if (isLiveNow)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                color: const Color(0xFF00A896),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.radar_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'الوردية الجارية الآن في المصنع (نشطة لحظياً)',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: shiftColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(shiftIcon, color: shiftColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                shift.name,
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: shift.isActive ? (Theme.of(context).brightness == Brightness.dark ? AppColors.darkInk : const Color(0xFF003853)) : Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time_filled_rounded, size: 13, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  shift.formattedDisplayTime,
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: shift.isActive ? Colors.grey.shade800 : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$hours ساعات',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 10.5,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // الإجراءات
                  if (UserSessionService.to.canManageShifts)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch.adaptive(
                          value: shift.isActive,
                          activeThumbColor: const Color(0xFF007791),
                          onChanged: (val) => controller.toggleShift(shift, val),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade600),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onSelected: (action) {
                            if (action == 'edit') {
                              _showShiftDialog(context, controller, existingShift: shift);
                            } else if (action == 'delete') {
                              _confirmDeleteShift(context, controller, shift);
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_note_rounded, color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkPrimaryLight : const Color(0xFF003853), size: 18),
                                  SizedBox(width: 8),
                                  Text('تعديل المواعيد', style: TextStyle(fontFamily: 'Tajawal')),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                  SizedBox(width: 8),
                                  Text('حذف الوردية', style: TextStyle(fontFamily: 'Tajawal', color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// حالة فارغة للورديات
  Widget _buildEmptyShiftsCard(BuildContext context, ShiftsController controller) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          const AppEmptyState(
            icon: Icons.schedule_rounded,
            title: 'لا توجد ورديات مسجلة لهذا المصنع حالياً',
            message: 'يمكنك إضافة ورديات جديدة للمصنع عبر زر الإضافة بالأعلى',
          ),
          if (UserSessionService.to.canManageShifts) ...[
            const SizedBox(height: 16),
            AppButton.primary(
              label: 'إضافة الوردية الأولى',
              icon: Icons.add_rounded,
              onPressed: () => _showShiftDialog(context, controller),
            ),
          ],
        ],
      ),
    );
  }

  /// نافذة إضافة / تعديل الوردية
  void _showShiftDialog(
    BuildContext context,
    ShiftsController controller, {
    ShiftModel? existingShift,
  }) {
    final isEdit = existingShift != null;
    final nameCtrl = TextEditingController(text: existingShift?.name ?? '');
    var startTime = existingShift?.startTime ?? '06:00';
    var endTime = existingShift?.endTime ?? '14:00';
    var seasonName = existingShift?.seasonName ?? controller.currentSeasonName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(
                  isEdit ? Icons.edit_calendar_rounded : Icons.add_alarm_rounded,
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimaryLight : const Color(0xFF003853),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEdit ? 'تعديل مواعيد الوردية' : 'إضافة وردية جديدة للمصنع',
                    style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'اسم الوردية',
                      hintText: 'مثال: الوردية الأولى (الصباحية)',
                      labelStyle: const TextStyle(fontFamily: 'Tajawal'),
                      hintStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.badge_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimePickerTile(
                          context: ctx,
                          label: 'وقت البداية',
                          timeStr: startTime,
                          onTimeSelected: (t) => setState(() => startTime = t),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTimePickerTile(
                          context: ctx,
                          label: 'وقت النهاية',
                          timeStr: endTime,
                          onTimeSelected: (t) => setState(() => endTime = t),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: seasonName,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'الموسم / التوقيت',
                      labelStyle: const TextStyle(fontFamily: 'Tajawal'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.wb_sunny_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'التوقيت الصيفي',
                        child: Text('التوقيت الصيفي ☀️', style: TextStyle(fontFamily: 'Tajawal')),
                      ),
                      DropdownMenuItem(
                        value: 'التوقيت الشتوي',
                        child: Text('التوقيت الشتوي ❄️', style: TextStyle(fontFamily: 'Tajawal')),
                      ),
                      DropdownMenuItem(
                        value: 'مواعيد شهر رمضان المبارك',
                        child: Text('شهر رمضان المبارك 🌙', style: TextStyle(fontFamily: 'Tajawal')),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => seasonName = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
              ),
              ElevatedButton(
                onPressed: () async {
                  final ok = await controller.saveShift(
                    id: existingShift?.id,
                    name: nameCtrl.text,
                    startTime: startTime,
                    endTime: endTime,
                    seasonName: seasonName,
                    isActive: existingShift?.isActive ?? true,
                  );
                  if (ok && ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimary : const Color(0xFF003853),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  isEdit ? 'حفظ التعديلات' : 'إضافة الوردية',
                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePickerTile({
    required BuildContext context,
    required String label,
    required String timeStr,
    required Function(String) onTimeSelected,
  }) {
    return InkWell(
      onTap: () async {
        final parts = timeStr.split(':');
        final initialHour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 8 : 8;
        final initialMinute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
        );
        if (picked != null) {
          final h = picked.hour.toString().padLeft(2, '0');
          final m = picked.minute.toString().padLeft(2, '0');
          onTimeSelected('$h:$m');
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF131D2E) : Colors.transparent,
          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkMuted : Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 16, color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimaryLight : const Color(0xFF007791)),
                const SizedBox(width: 6),
                Text(
                  ShiftModel.format12h(timeStr),
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkInk : AppColors.ink),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// نافذة تغيير الموسم لجميع ورديات المصنع
  void _showSeasonSelectionDialog(BuildContext context, ShiftsController controller) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(Icons.tune_rounded, color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimaryLight : const Color(0xFF003853)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تغيير موسم ورديات المصنع',
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkInk : const Color(0xFF003853)),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSeasonChoiceTile(
                title: 'التوقيت الصيفي',
                icon: Icons.wb_sunny_rounded,
                color: const Color(0xFFE65100),
                onTap: () {
                  Navigator.pop(ctx);
                  controller.updateSeason('التوقيت الصيفي');
                },
              ),
              const SizedBox(height: 8),
              _buildSeasonChoiceTile(
                title: 'التوقيت الشتوي',
                icon: Icons.ac_unit_rounded,
                color: const Color(0xFF0277BD),
                onTap: () {
                  Navigator.pop(ctx);
                  controller.updateSeason('التوقيت الشتوي');
                },
              ),
              const SizedBox(height: 8),
              _buildSeasonChoiceTile(
                title: 'مواعيد شهر رمضان المبارك',
                icon: Icons.nights_stay_rounded,
                color: const Color(0xFF6A1B9A),
                onTap: () {
                  Navigator.pop(ctx);
                  controller.updateSeason('مواعيد شهر رمضان المبارك');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeasonChoiceTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13.5),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      onTap: onTap,
    );
  }

  /// تأكيد حذف وردية
  void _confirmDeleteShift(BuildContext context, ShiftsController controller, ShiftModel shift) {
    if (shift.id == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('حذف الوردية', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'هل أنت متأكد من حذف "${shift.name}" من هذا المصنع؟',
            style: const TextStyle(fontFamily: 'Tajawal'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                controller.deleteShift(shift.id!, shift.name);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('حذف', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
