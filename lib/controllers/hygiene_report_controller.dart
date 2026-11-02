import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/hygiene_models.dart';
import '../services/database_helper.dart';
import '../services/api/hygiene_api_service.dart';
import '../services/factory_shifts_service.dart';
import '../services/notification_service.dart';
import '../services/user_session_service.dart';
import '../services/worker_database_service.dart';

class HygieneDraft {
  const HygieneDraft({required this.id, required this.savedAt, required this.employeeCount});

  final int id;
  final DateTime savedAt;
  final int employeeCount;

  String get employeeNames => 'عدد الموظفين: $employeeCount';
}

class HygieneReportController extends GetxController {
  var isLoading = false.obs;
  final isReportOpen = false.obs;
  final employeeNameController = TextEditingController();
  var _nextEmployeeId = 1;
  int? _activeDraftId;
  final drafts = <HygieneDraft>[].obs;

  // Shifts (تُحتسب تلقائياً من جدول الورديات بالنظام وفق وقت الفحص)
  final selectedShiftId = 1.obs;
  final selectedShiftName = 'وردية أولى (صباحية)'.obs;

  Future<void> _detectActiveShift() async {
    try {
      final branchId = _reportBranchId;
      final activeShift =
          await FactoryShiftsService.instance.getActiveShiftNow(branchId);
      if (activeShift != null) {
        selectedShiftId.value = activeShift.id ?? 1;
        selectedShiftName.value = activeShift.name;
      } else {
        selectedShiftId.value = 1;
        selectedShiftName.value = 'وردية أولى (صباحية)';
      }
    } catch (e) {
      debugPrint('Error detecting active shift: $e');
      selectedShiftId.value = 1;
      selectedShiftName.value = 'وردية أولى (صباحية)';
    }
  }

  // Data
  var employees = <Employee>[].obs;
  var criteria = <ChecklistItem>[].obs;

  /// العمال المختارون من سجل العمالة اليومية (يحملون معرّفات ثابتة).
  /// تُبنى منها [employees] ديناميكياً لضمان التوافق مع منطق الحفظ القائم.
  final selectedWorkers = <DailyWorker>[].obs;

  /// قائمة موحدة بكل الموظفين المعروضين في الجدول: العمال المختارين من
  /// سجل العمالة اليومية (بمعرّفاتهم الثابتة) بالإضافة لموظفي الإدخال الحر
  /// (المسودات القديمة).
  /// على الواجهة وأي عملية شاملة مثل "تحديد الكل" الاعتماد على هذه القائمة
  /// بدل [employees] وحدها، لأن العمال المضافين عبر حقل الاقتراحات لا
  /// يُزامَنون مع [employees] إلا عند الحفظ، فكان زر "تحديد الكل" يمرّ على
  /// قائمة فارغة ولا يفعل شيئاً للتقارير الجديدة.
  List<Employee> get allEmployees {
    final branchId = _reportBranchId;

    final list = selectedWorkers.map((worker) {
      return Employee(
        id: worker.id,
        branchId: branchId,
        fullName: worker.fullName,
        jobTitle: worker.jobTitle,
        isActive: worker.isActive,
        databaseWorkerId: worker.id,
      );
    }).toList();

    // إضافة الموظفين القدامى غير المرتبطين بسجل العمالة (الإدخال الحر)
    for (final emp in employees) {
      final isLinkedToWorker = emp.databaseWorkerId != null &&
          selectedWorkers.any((w) => w.id == emp.databaseWorkerId);
      if (!isLinkedToWorker && !list.any((e) => e.id == emp.id)) {
        list.add(emp);
      }
    }
    return list;
  }

  // State Matrix: Key is "${employeeId}_${criteriaId}", Value is true (Yes), false (No), or null (Unset)
  var complianceMatrix = <String, bool?>{}.obs;

  // Corrective Actions: Key is employeeId
  var correctiveActions = <int, String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _loadMockData();
    loadDrafts();
  }

  void _loadMockData() {
    isLoading.value = true;
    
    // Daily workers change frequently, so names are entered by the user per report.
    employees.clear();

    // Mock Criteria based on the physical form
    criteria.value = [
      ChecklistItem(id: 1, checklistId: 1, itemName: 'ارتداء ملابس العمل'),
      ChecklistItem(id: 2, checklistId: 1, itemName: 'الملابس نظيفة وفي صورة جيدة'),
      ChecklistItem(id: 3, checklistId: 1, itemName: 'تغطية الشعر والشارب'),
      ChecklistItem(id: 4, checklistId: 1, itemName: 'ارتداء حماية الحذاء'),
      ChecklistItem(id: 5, checklistId: 1, itemName: 'الاظافر مقصوصة ونظيفة'),
      ChecklistItem(id: 6, checklistId: 1, itemName: 'الصحة جيدة (لا أمراض)'),
      ChecklistItem(id: 7, checklistId: 1, itemName: 'لا يرتدي أي اكسسوارات'),
      ChecklistItem(id: 8, checklistId: 1, itemName: 'لا توجد رائحة كريهة'),
      ChecklistItem(id: 9, checklistId: 1, itemName: 'لا روائح عطرية شديدة'),
    ];

    isLoading.value = false;
  }

  /// يُرجع فرع التقرير الحالي (فرع الجلسة أو 1 افتراضياً).
  int get _reportBranchId {
    if (Get.isRegistered<UserSessionService>()) {
      return UserSessionService.to.assignedBranchId ?? 1;
    }
    return 1;
  }

  /// التحقق من عدم تكرار العامل المختار في نفس التقرير.
  bool _isWorkerSelected(DailyWorker worker) {
    return selectedWorkers.any((w) => w.id == worker.id);
  }

  /// إضافة عامل من سجل العمالة اليومية للتقرير الحالي.
  void addSelectedWorker(DailyWorker worker) {
    if (_isWorkerSelected(worker)) {
      Get.snackbar(
        'تنبيه',
        '${worker.fullName} مضاف مسبقاً في هذا التقرير',
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade900,
      );
      return;
    }
    selectedWorkers.add(worker);
    employeeNameController.clear();
  }

  /// إضافة عامل جديد غير موجود في الاقتراحات: يُحفظ تلقائياً في سجل
  /// العمالة اليومية بفرع الجلسة الحالية، ثم يُضاف للتقرير ويرتبط بالـ ID الثابت.
  Future<void> addNewWorker(String fullName) async {
    final name = fullName.trim();
    if (name.isEmpty) {
      Get.snackbar('تنبيه', 'يرجى كتابة اسم العامل أولاً');
      return;
    }

    final branchId = _reportBranchId;

    // إذا وُجد عامل بنفس الاسم المطبَّع في الفرع نربط به مباشرة
    final existing =
        await WorkerDatabaseService.instance.findByName(name, branchId: branchId);
    if (existing != null) {
      addSelectedWorker(existing);
      Get.snackbar(
        'تم الربط',
        'العامل "$name" مسجّل مسبقاً وتمت إضافته من السجل',
        backgroundColor: Colors.blue.shade100,
        colorText: Colors.blue.shade900,
      );
      return;
    }

    final newWorker = DailyWorker(
      branchId: branchId,
      fullName: name,
      jobTitle: 'عامل بالأجر اليومي',
    );
    final savedId =
        await WorkerDatabaseService.instance.saveWorker(newWorker);
    if (savedId == null) {
      Get.snackbar('خطأ', 'تعذر حفظ العامل الجديد في السجل',
          backgroundColor: Colors.red.shade100, colorText: Colors.red.shade900);
      return;
    }
    addSelectedWorker(newWorker.copyWith(id: savedId));
  }

  /// إضافة موظف بالنمط القديم (اسم حر بدون رابط سجل) — يُستخدم فقط
  /// للمسودات القديمة والوضع الاحتياطي.
  void addEmployee() {
    final fullName = employeeNameController.text.trim();
    if (fullName.isEmpty) {
      Get.snackbar('تنبيه', 'يرجى كتابة اسم الموظف أولاً');
      return;
    }

    employees.add(
      Employee(
        id: _nextEmployeeId++,
        branchId: 1,
        fullName: fullName,
        jobTitle: 'عامل بالأجر اليومي',
        isActive: true,
      ),
    );
    employeeNameController.clear();
  }

  Future<void> startNewReport() async {
    employees.clear();
    selectedWorkers.clear();
    complianceMatrix.clear();
    correctiveActions.clear();
    employeeNameController.clear();
    _activeDraftId = null;
    _nextEmployeeId = 1;
    await _detectActiveShift();
    isReportOpen.value = true;
  }

  void removeEmployee(Employee employee) {
    final employeeId = employee.id;
    if (employeeId == null) return;

    employees.remove(employee);
    selectedWorkers.removeWhere((w) => w.id == employee.databaseWorkerId);
    complianceMatrix.removeWhere((key, _) => key.startsWith('${employeeId}_'));
    correctiveActions.remove(employeeId);
  }

  /// حذف عامل مختار من سجل العمالة (مع تنظيف مصفوفة المطابقة).
  void removeSelectedWorker(DailyWorker worker) {
    final employeeId = worker.id;
    selectedWorkers.remove(worker);
    employees.removeWhere((e) => e.databaseWorkerId == worker.id);
    if (employeeId != null) {
      complianceMatrix.removeWhere((key, _) => key.startsWith('${employeeId}_'));
      correctiveActions.remove(employeeId);
    }
  }

  Future<bool> archiveDraft() async {
    await saveReport(isDraft: true);
    return true;
  }

  Future<void> loadDrafts() async {
    final branchId = Get.isRegistered<UserSessionService>()
        ? UserSessionService.to.assignedBranchId
        : null;
    final reports = await DatabaseHelper.instance.getHygieneReports(branchId: branchId);
    final loaded = reports
        .where((item) => item['approval_status'] == 'Draft')
        .map((item) => HygieneDraft(
              id: item['id'] as int,
              savedAt: DateTime.parse(item['created_at'] as String),
              employeeCount: item['employee_count'] as int? ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    drafts.assignAll(loaded);
  }

  Future<void> restoreDraft(HygieneDraft draft) async {
    final details = await DatabaseHelper.instance.getHygieneReportDetails(draft.id);
    if (details == null) return;
    
    final employeeList = details['employees'] as List<dynamic>;
    final restoredEmployees = employeeList.map(
      (item) {
        final employee = Map<String, dynamic>.from(item as Map);
        return Employee(
          id: employee['employee_id'] as int,
          branchId: _reportBranchId,
          fullName: employee['full_name'] as String,
          jobTitle: employee['job_title'] as String,
          isActive: true,
        );
      },
    ).toList();
    employees.assignAll(restoredEmployees);

    // محاولة ربط موظفي المسودة بسجل العمالة اليومية لاستئناف الاقتراحات
    // والحفاظ على المعرّف الثابت عند إعادة الحفظ.
    final restoredWorkers = <DailyWorker>[];
    for (final emp in restoredEmployees) {
      final worker = await WorkerDatabaseService.instance
          .findByName(emp.fullName, branchId: _reportBranchId);
      if (worker != null && !restoredWorkers.contains(worker)) {
        restoredWorkers.add(worker);
        emp.databaseWorkerId = worker.id;
      }
    }
    selectedWorkers.assignAll(restoredWorkers);

    final matrix = <String, bool?>{};
    final actions = <int, String>{};
    final detailsList = details['details'] as List<dynamic>;
    for (final item in detailsList) {
      final detail = Map<String, dynamic>.from(item as Map);
      final empId = detail['employee_id'] as int;
      final critId = detail['checklist_item_id'] as int;
      final isCompliant = detail['is_compliant'] as int;
      final notes = detail['notes'] as String?;
      matrix['${empId}_$critId'] = isCompliant == 1 ? true : (notes != null ? false : null);
      if (isCompliant == 0 && notes != null) {
        actions[empId] = notes;
      }
    }
    complianceMatrix.assignAll(matrix);
    correctiveActions.assignAll(actions);

    final reportMeta = details['report'] as Map<String, dynamic>?;
    if (reportMeta != null) {
      final sId = reportMeta['shift_id'] as int?;
      final sName = reportMeta['shift_name'] as String?;
      if (sId != null) selectedShiftId.value = sId;
      if (sName != null && sName.isNotEmpty) selectedShiftName.value = sName;
    }

    _nextEmployeeId = employees.fold(0, (highestId, employee) => employee.id! > highestId ? employee.id! : highestId) + 1;
    _activeDraftId = draft.id;
    isReportOpen.value = true;
    Get.snackbar('تم الاسترجاع', 'تم فتح الفحص المؤرشف لإكماله');
  }

  Future<void> deleteDraft(int draftId) async {
    await DatabaseHelper.instance.deleteHygieneReport(draftId);
    if (_activeDraftId == draftId) _activeDraftId = null;
    await loadDrafts();
  }

  // Helper to generate matrix key
  String _k(int empId, int critId) => '${empId}_$critId';

  // Check if an employee has any 'false' (non-compliant) criteria
  bool hasViolation(int empId) {
    for (var crit in criteria) {
      if (complianceMatrix[_k(empId, crit.id!)] == false) {
        return true;
      }
    }
    return false;
  }

  // Toggle cell state: null -> true -> false -> null
  void toggleCell(int empId, int critId) {
    final key = _k(empId, critId);
    final current = complianceMatrix[key];

    if (current == null) {
      complianceMatrix[key] = true;
    } else if (current == true) {
      complianceMatrix[key] = false;
    } else {
      complianceMatrix[key] = null;
    }

    // If no violations anymore, clear the corrective action for this employee
    if (!hasViolation(empId)) {
      correctiveActions.remove(empId);
    }
  }

  // Force set a cell (used for "Set All Compliant")
  void setCell(int empId, int critId, bool value) {
    final key = _k(empId, critId);
    complianceMatrix[key] = value;
    if (!hasViolation(empId)) {
      correctiveActions.remove(empId);
    }
  }

  // Set all cells to compliant (true)
  void setAllCompliant() {
    // نمرّ على القائمة الموحّدة [allEmployees] وليس [employees] وحدها، وإلا
    // لظلّت خلايا العمال المضافين حديثاً عبر حقل الاقتراحات دون تحديث
    // (لأنهم لا يُزامَنون مع [employees] إلا عند الحفظ).
    for (var emp in allEmployees) {
      for (var crit in criteria) {
        setCell(emp.id!, crit.id!, true);
      }
    }
  }

  // Save corrective action
  void saveCorrectiveAction(int empId, String action) {
    if (action.trim().isEmpty) {
      correctiveActions.remove(empId);
    } else {
      correctiveActions[empId] = action;
    }
  }

  // Save the entire report
  Future<void> saveReport({bool isDraft = false}) async {
    // مزامنة العمال المختارين (من سجل العمالة اليومية) مع قائمة الموظفين
    // التي يستخدمها منطق الحفظ. كل عامل يحمل معرّفه الثابت في databaseWorkerId
    // ليُربط به سجل HygieneLogs بدل إدراج صف Employees جديد.
    final branchId = Get.isRegistered<UserSessionService>()
        ? (UserSessionService.to.assignedBranchId ?? 1)
        : 1;

    for (final worker in selectedWorkers) {
      final already = employees.any((e) => e.databaseWorkerId == worker.id);
      if (!already) {
        employees.add(Employee(
          id: worker.id,
          branchId: branchId,
          fullName: worker.fullName,
          jobTitle: worker.jobTitle,
          isActive: worker.isActive,
          databaseWorkerId: worker.id,
        ));
      }
    }

    if (employees.isEmpty) {
      Get.snackbar('تنبيه', 'أضف اسم موظف واحد على الأقل قبل حفظ التقرير',
          backgroundColor: Colors.orange.shade100,
          colorText: Colors.orange.shade900);
      return;
    }

    // Basic validation
    bool allAnswered = true;
    for (var emp in employees) {
      for (var crit in criteria) {
        if (complianceMatrix[_k(emp.id!, crit.id!)] == null) {
          allAnswered = false;
          break;
        }
      }
      
      if (hasViolation(emp.id!) && (correctiveActions[emp.id!] == null || correctiveActions[emp.id!]!.trim().isEmpty)) {
        Get.snackbar('تنبيه', 'يجب إدخال الإجراء التصحيحي للمخالفات للموظف: ${emp.fullName}', 
          backgroundColor: Colors.red.shade100, colorText: Colors.red.shade900);
        return;
      }
    }

    if (!allAnswered && !isDraft) {
      Get.snackbar('تنبيه', 'يجب إكمال جميع التقييمات قبل الحفظ كتقرير نهائي', 
        backgroundColor: Colors.orange.shade100, colorText: Colors.orange.shade900);
      return;
    }

    try {
      final branchId = Get.isRegistered<UserSessionService>()
          ? (UserSessionService.to.assignedBranchId ?? 1)
          : 1;
      final branchName = branchId == 2 ? 'مصنع سنحان' : 'مصنع أرتل';

      final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
      final supervisorName = (session != null && session.currentUserName.value.isNotEmpty)
          ? session.currentUserName.value
          : 'أخصائي الجودة';

      int? savedReportId;
      if (Get.isRegistered<HygieneApiService>()) {
        try {
          final detailsList = <Map<String, dynamic>>[];
          for (var emp in employees) {
            for (var crit in criteria) {
              final val = complianceMatrix[_k(emp.id!, crit.id!)];
              detailsList.add({
                'employeeId': emp.id,
                'checklistItemId': crit.id,
                'isCompliant': val == true,
                'notes': val == false ? correctiveActions[emp.id!] : null,
              });
            }
          }
          savedReportId = await HygieneApiService.to.saveReport({
            'id': _activeDraftId ?? 0,
            'branchId': branchId,
            'branchName': branchName,
            'supervisorName': supervisorName,
            'shiftId': selectedShiftId.value,
            'shiftName': selectedShiftName.value,
            'employeeCount': employees.length,
            'approvalStatus': isDraft ? 'Draft' : 'Pending_QM',
            'details': detailsList,
          });
        } catch (e) {
          debugPrint('API save hygiene report error: $e');
        }
      }

      // إذا كانت المسودة المحلية تحمل معرّفاً مختلفاً عن معرّف السيرفر الجديد، نحذف المسودة المحلية القديمة لمنع الازدواجية
      if (_activeDraftId != null && savedReportId != null && savedReportId > 0 && savedReportId != _activeDraftId) {
        await DatabaseHelper.instance.deleteHygieneReport(_activeDraftId!);
      }

      // حفظ نسخة الكاش المحلي دائماً (سواء في حالة الاتصال أو الأوفلاين)
      final effectiveId = (savedReportId != null && savedReportId > 0) ? savedReportId : _activeDraftId;
      final localSavedId = await DatabaseHelper.instance.saveHygieneReport(
        reportId: effectiveId,
        branchId: branchId,
        branchName: branchName,
        shiftId: selectedShiftId.value,
        shiftName: selectedShiftName.value,
        supervisorName: supervisorName,
        employees: employees,
        criteria: criteria,
        complianceMatrix: complianceMatrix,
        correctiveActions: correctiveActions,
        approvalStatus: isDraft ? 'Draft' : 'Pending_QM',
      );
      if (savedReportId == null || savedReportId <= 0) {
        savedReportId = localSavedId;
      }
      
      _activeDraftId = null;
      await loadDrafts();

      if (isDraft) {
        Get.snackbar(
          'تمت الأرشفة',
          'تم حفظ التقرير كمسودة',
          backgroundColor: Colors.blue.shade100,
          colorText: Colors.blue.shade900,
        );
        isReportOpen.value = false;
        return;
      }

      // Trigger notification for Quality Manager
      if (Get.isRegistered<NotificationService>()) {
        try {
          final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
          final creatorName = (session != null && session.currentUserName.value.isNotEmpty)
              ? session.currentUserName.value
              : 'أخصائي الجودة';
          await NotificationService.to.sendNotification(
            title: 'تقرير فحص نظافة شخصية جديد',
            body: 'قام $creatorName برفع تقرير فحص نظافة شخصية جديد (#$savedReportId) وهو بانتظار اعتماد مدير الجودة.',
            reportId: savedReportId,
            reportCategory: 'Hygiene',
            targetRole: 'QualityManager',
          );
        } catch (notifErr) {
          debugPrint('Notification dispatch error: $notifErr');
        }
      }

      Get.snackbar(
        'نجاح',
        'تم حفظ التقرير ورفعه لمدير الجودة للاعتماد',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
      );
      isReportOpen.value = false;
    } catch (error) {
      Get.snackbar(
        'خطأ',
        'تعذر حفظ التقرير: $error',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
    }
  }

  @override
  void onClose() {
    employeeNameController.dispose();
    super.onClose();
  }
}
