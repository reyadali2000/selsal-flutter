import 'package:flutter/material.dart';
import '../widgets/branch_filter_selector.dart';
import 'package:get/get.dart';
import '../models/branch_model.dart';
import '../models/hygiene_models.dart';
import '../services/factory_shifts_service.dart';
import '../services/user_session_service.dart';
import '../services/worker_database_service.dart';
import '../widgets/ds/ds.dart';
import 'daily_workers_commitment_view.dart';

class DailyWorkersController extends GetxController {
  final isLoading = true.obs;
  final workers = <DailyWorker>[].obs;
  final branches = <BranchModel>[].obs;
  final searchQuery = ''.obs;
  final selectedBranchFilter = RxnInt(null);

  @override
  void onInit() {
    super.onInit();
    selectedBranchFilter.value = UserSessionService.to.effectiveBranchFilter;
    if (Get.isRegistered<UserSessionService>()) {
      ever(UserSessionService.to.activeBranchFilter, (branchId) {
        selectedBranchFilter.value = branchId;
        loadWorkers();
      });
    }
    loadAll();
  }

  Future<void> loadAll() async {
    isLoading.value = true;
    try {
      final branchList = await FactoryShiftsService.instance.getAllBranches();
      branches.assignAll(branchList);
      await loadWorkers();
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحميل البيانات: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadWorkers() async {
    final branchId = _effectiveBranchFilter;
    final list = await WorkerDatabaseService.instance.getAllWorkers(
      branchId: branchId,
      includeInactive: true,
      searchQuery: searchQuery.value,
    );
    workers.assignAll(list);
  }

  /// فرع العرض الحالي — يستخدم الفلتر المركزي من UserSessionService
  int? get _effectiveBranchFilter => UserSessionService.to.effectiveBranchFilter;

  void setBranchFilter(int? branchId) {
    UserSessionService.to.setActiveBranchFilter(branchId);
    selectedBranchFilter.value = branchId;
    loadWorkers();
  }

  void onSearchChanged(String query) {
    searchQuery.value = query;
    loadWorkers();
  }

  void clearSearch() {
    searchQuery.value = '';
    loadWorkers();
  }

  int get totalWorkersCount => workers.length;
  int get activeWorkersCount => workers.where((w) => w.isActive).length;
  int get inactiveWorkersCount => workers.where((w) => !w.isActive).length;

  String branchNameOf(int? branchId) {
    if (branchId == null) return 'غير محدد';
    final match = branches.where((b) => b.id == branchId);
    if (match.isEmpty) return 'غير محدد';
    return match.first.name;
  }

  Future<void> toggleWorkerStatus(DailyWorker worker) async {
    final newStatus = !worker.isActive;
    try {
      await WorkerDatabaseService.instance
          .toggleWorkerStatus(worker.id!, newStatus);
      await loadWorkers();
      Get.snackbar(
        'تم التحديث',
        newStatus
            ? 'تم تفعيل العامل ${worker.fullName} بنجاح'
            : 'تم إيقاف العامل ${worker.fullName} (يحتفظ بسجلاته السابقة)',
        backgroundColor: newStatus ? const Color(0xFF2E7D32) : Colors.blueGrey,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تغيير حالة العامل: $e');
    }
  }

  Future<bool> saveWorker({
    int? id,
    required String fullName,
    required int branchId,
    String jobTitle = 'عامل بالأجر اليومي',
    bool isActive = true,
  }) async {
    final trimmedName = fullName.trim();
    if (trimmedName.isEmpty) {
      Get.snackbar('تنبيه', 'يرجى إدخال اسم العامل',
          backgroundColor: Colors.orange.shade800, colorText: Colors.white);
      return false;
    }

    final existing = await WorkerDatabaseService.instance
        .findByName(trimmedName, branchId: branchId);
    if (existing != null && existing.id != id) {
      Get.snackbar(
        'تنبيه',
        'يوجد عامل بنفس الاسم في ${branchNameOf(branchId)}: ${existing.fullName}',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
      return false;
    }

    try {
      final worker = DailyWorker(
        id: id,
        branchId: branchId,
        fullName: trimmedName,
        jobTitle: jobTitle.trim().isEmpty ? 'عامل بالأجر اليومي' : jobTitle.trim(),
        isActive: isActive,
      );
      final savedId = await WorkerDatabaseService.instance.saveWorker(worker);
      if (savedId == null) {
        Get.snackbar('خطأ', 'تعذر حفظ بيانات العامل',
            backgroundColor: Colors.redAccent, colorText: Colors.white);
        return false;
      }
      await loadWorkers();
      Get.snackbar(
        'تم الحفظ',
        id == null
            ? 'تمت إضافة العامل $trimmedName إلى سجل العمالة اليومية'
            : 'تم تحديث بيانات العامل $trimmedName',
        backgroundColor: const Color(0xFF2E7D32),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return true;
    } catch (e) {
      Get.snackbar('خطأ', 'فشل حفظ العامل: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return false;
    }
  }

  Future<void> deleteWorker(DailyWorker worker) async {
    final linked = await WorkerDatabaseService.instance
        .countLinkedReports(worker.id!);
    if (linked > 0) {
      Get.snackbar(
        'لا يمكن الحذف',
        'هذا العامل مرتبط بـ $linked سجل فحص سابق. استخدم "إيقاف" بدلاً من الحذف للحفاظ على السجلات.',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    try {
      await WorkerDatabaseService.instance.deleteWorker(worker.id!);
      await loadWorkers();
      Get.snackbar('تم الحذف', 'تم حذف العامل ${worker.fullName} من السجل',
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل حذف العامل: $e');
    }
  }
}

class DailyWorkersManagementView extends StatelessWidget {
  DailyWorkersManagementView({super.key});

  final DailyWorkersController controller = Get.put(DailyWorkersController());

  @override
  Widget build(BuildContext context) {
    final session = UserSessionService.to;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('سجل العمالة اليومية',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          centerTitle: true,
          actions: [
            Obx(() {
              if (!UserSessionService.to.canFilterByBranch) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: BranchFilterSelector(
                  compact: true,
                  onChanged: () => controller.loadWorkers(),
                ),
              );
            }),
            if (session.canViewDailyWorkersCommitment)
              IconButton(
                icon: const Icon(Icons.analytics_outlined),
                tooltip: 'متابعة التزام العمالة والورديات',
                onPressed: () => Get.to(() => DailyWorkersCommitmentView()),
              ),
          ],
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const AppLoading(message: 'جاري تحميل سجلات العمالة...');
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                children: [
                  if (session.canViewDailyWorkersCommitment)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: InkWell(
                        onTap: () => Get.to(() => DailyWorkersCommitmentView()),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1B365D), Color(0xFF0284C7)],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1B365D).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.military_tech_rounded, color: Colors.amber, size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'متابعة التزام العمالة اليومية والورديات',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'تقييم الحضور وتوزيع الورديات ومطابقة النظافة الشخصية شهرياً',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 11,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  _buildStatsOverview(context),
                  _buildBranchFilterChips(),
                  _buildSearchBar(),
                  Expanded(child: _buildWorkersList()),
                ],
              ),
            ),
          );
        }),
        floatingActionButton: session.canManageDailyWorkers
            ? FloatingActionButton.extended(
                onPressed: () => _showWorkerDialog(context),
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('إضافة عامل',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              )
            : null,
      ),
    );
  }

  Widget _buildStatsOverview(BuildContext context) {
    return Obx(() => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _buildStatMiniCard(
                  context,
                  'إجمالي العمال',
                  controller.totalWorkersCount,
                  Icons.groups_rounded,
                  AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatMiniCard(
                  context,
                  'نشط',
                  controller.activeWorkersCount,
                  Icons.check_circle_rounded,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatMiniCard(
                  context,
                  'موقوف',
                  controller.inactiveWorkersCount,
                  Icons.pause_circle_rounded,
                  Colors.blueGrey,
                ),
              ),
            ],
          ),
        ));
  }

  Widget _buildStatMiniCard(BuildContext context,
      String label, int value, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      borderColor: color.withValues(alpha: 0.25),
      borderWidth: 1.2,
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text('$value',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontFamily: 'Tajawal')),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkMuted : AppColors.muted,
                  fontFamily: 'Tajawal')),
        ],
      ),
    );
  }

  Widget _buildBranchFilterChips() {
    final session = UserSessionService.to;
    if (!session.canFilterByBranch) return const SizedBox.shrink();
    return Obx(() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildBranchChip(null, 'كل المصانع'),
                ...controller.branches.map((b) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildBranchChip(b.id, b.name),
                  );
                }),
              ],
            ),
          ),
        ));
  }

  Widget _buildBranchChip(int? branchId, String label) {
    final isSelected = controller.selectedBranchFilter.value == branchId;
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: ChoiceChip(
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
        backgroundColor: Colors.white,
        showCheckmark: false,
        onSelected: (selected) {
          if (selected) controller.setBranchFilter(branchId);
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: controller.onSearchChanged,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  hintText: 'بحث عن عامل بالاسم...',
                  hintStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14),
              ),
            ),
            Obx(() => controller.searchQuery.value.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                    onPressed: controller.clearSearch,
                  )
                : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkersList() {
    return Obx(() {
      if (controller.workers.isEmpty) {
        return _buildEmptyState();
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
        itemCount: controller.workers.length,
        itemBuilder: (context, index) {
          return _buildWorkerCard(context, controller.workers[index]);
        },
      );
    });
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: AppEmptyState(
          icon: Icons.engineering_rounded,
          title: 'لا يوجد عمال في السجل',
          message: 'أضف العمال اليوميين واربطهم بالمصانع لتظهر أسماؤهم كاقتراحات في فحص النظافة.',
        ),
      ),
    );
  }

  Widget _buildWorkerCard(BuildContext context, DailyWorker worker) {
    final session = UserSessionService.to;
    final canManage = session.canManageDailyWorkers;
    final statusColor = worker.isActive ? Colors.green : Colors.blueGrey;
    final statusText = worker.isActive ? 'نشط' : 'موقوف';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        borderColor: statusColor.withValues(alpha: 0.25),
        borderWidth: 1.2,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded,
                  color: AppColors.primaryDark, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(worker.fullName,
                      style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkInk : AppColors.ink)),
                  const SizedBox(height: 3),
                  Text(
                    '${worker.jobTitle} | ${controller.branchNameOf(worker.branchId)}',
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkMuted : AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
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
            if (canManage)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkMuted : AppColors.muted),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showWorkerDialog(context, worker: worker);
                      break;
                    case 'toggle':
                      controller.toggleWorkerStatus(worker);
                      break;
                    case 'delete':
                      controller.deleteWorker(worker);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_note_rounded, color: AppColors.primaryMedium),
                      SizedBox(width: 8),
                      Text('تعديل', style: TextStyle(fontFamily: 'Tajawal')),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(children: [
                      Icon(worker.isActive
                          ? Icons.pause_circle_outline_rounded
                          : Icons.play_circle_outline_rounded),
                      const SizedBox(width: 8),
                      Text(worker.isActive ? 'إيقاف' : 'تفعيل',
                          style: const TextStyle(fontFamily: 'Tajawal')),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded, color: Colors.red),
                      SizedBox(width: 8),
                      Text('حذف', style: TextStyle(fontFamily: 'Tajawal')),
                    ]),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showWorkerDialog(
    BuildContext context, {
    DailyWorker? worker,
  }) async {
    final isEdit = worker != null;
    final isRestricted = UserSessionService.to.isBranchRestricted;
    final userBranchId = UserSessionService.to.assignedBranchId;

    final nameCtrl = TextEditingController(text: worker?.fullName ?? '');
    final jobCtrl = TextEditingController(text: worker?.jobTitle ?? 'عامل بالأجر اليومي');
    final branches = controller.branches;
    int selectedBranchId = isRestricted
        ? (userBranchId ?? 1)
        : (worker?.branchId ??
            (branches.isNotEmpty ? branches.first.id! : 1));
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(
                  isEdit
                      ? Icons.edit_note_rounded
                      : Icons.person_add_alt_1_rounded,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 8),
                Text(
                  isEdit ? 'تعديل بيانات العامل' : 'إضافة عامل جديد',
                  style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        textDirection: TextDirection.rtl,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل *',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'يرجى إدخال الاسم الكامل'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: jobCtrl,
                        textDirection: TextDirection.rtl,
                        decoration: const InputDecoration(
                          labelText: 'المسمى الوظيفي',
                          prefixIcon: Icon(Icons.work_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: selectedBranchId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'المصنع / الفرع *',
                          prefixIcon: Icon(Icons.factory_rounded),
                        ),
                        items: branches.map((b) {
                          return DropdownMenuItem(
                            value: b.id,
                            child: Text(b.name,
                                style: const TextStyle(
                                    fontFamily: 'Tajawal', fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: isRestricted
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => selectedBranchId = value);
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final success = await controller.saveWorker(
                    id: worker?.id,
                    fullName: nameCtrl.text,
                    branchId: selectedBranchId,
                    jobTitle: jobCtrl.text,
                    isActive: worker?.isActive ?? true,
                  );
                  if (success && ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(isEdit ? 'حفظ التعديل' : 'إضافة',
                    style: const TextStyle(fontFamily: 'Tajawal')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
