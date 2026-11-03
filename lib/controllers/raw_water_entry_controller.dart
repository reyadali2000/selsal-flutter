import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/settings_models.dart';
import '../models/standards_models.dart';
import '../models/water_quality_models.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/user_session_service.dart';
import '../services/api/api.dart';
import '../services/sync/sync_manager.dart';

class RawWaterEntryController extends GetxController {
  var shifts = <Shift>[].obs;
  var selectedShiftObj = Rx<Shift?>(null);
  
  // Basic Info Controllers
  final batchNumberController = TextEditingController();
  final notesController = TextEditingController();

  // New Fields Controllers
  final waterSourceController = TextEditingController();
  final wellNumberController = TextEditingController();
  final sampleTakerController = TextEditingController();
  final ncrNumberController = TextEditingController();

  // Compliance Action Booleans
  var managerNotified = false.obs;
  var sourceSuspended = false.obs;

  // Standards and Parameters
  var standards = <QualityStandard>[].obs;
  var testParameters = <TestParameter>[].obs;

  // Categorized Standards for UI
  var sensoryStandards = <QualityStandard>[].obs;
  var physioChemicalStandards = <QualityStandard>[].obs;
  var microbiologicalStandards = <QualityStandard>[].obs;

  var formControllers = <int, TextEditingController>{}.obs;
  var formValidations = <int, Rx<bool?>>{}.obs;
  
  var formNoteControllers = <int, TextEditingController>{}.obs;
  var isNoteVisible = <int, RxBool>{}.obs;

  var isAllCompliant = false.obs;
  var isLoading = false.obs;
  var isSaving = false.obs;

  // Track the current loaded log ID if editing a draft
  int? currentLogId;
  var currentRejectionReason = ''.obs;
  var currentRejectedBy = ''.obs;

  // UI state for Drafts vs Form
  var isFormVisible = false.obs;

  void startNewReport() {
    _resetForm();
    isFormVisible.value = true;
  }

  // List of saved reports for the reports page
  var reportsList = <WaterQualityLog>[].obs;

  Worker? _userWorker;
  Worker? _roleWorker;

  @override
  void onInit() {
    super.onInit();
    _loadReferenceData();
    loadReports();

    if (Get.isRegistered<SyncManager>()) {
      SyncManager.to.registerRefresher('raw_water_reports', () async {
        // تخطي التحديث إذا كان المستخدم يقوم بإدخال تقرير حالياً
        if (isFormVisible.value) return;
        await loadReports(silent: true);
      });
    }

    if (Get.isRegistered<UserSessionService>()) {
      _userWorker = ever(UserSessionService.to.currentUser, (_) {
        if (!isClosed) {
          loadReports();
          _loadReferenceData();
        }
      });
      _roleWorker = ever(UserSessionService.to.currentRole, (_) {
        if (!isClosed) {
          loadReports();
        }
      });
      ever(UserSessionService.to.activeBranchFilter, (_) {
        if (!isClosed) {
          loadReports();
        }
      });
    }
  }

  Future<void> loadReports({bool silent = false}) async {
    if (isClosed) return;
    if (!silent) isLoading.value = true;
    final branchId = Get.isRegistered<UserSessionService>()
        ? UserSessionService.to.effectiveBranchFilter
        : null;

    if (Get.isRegistered<WaterQualityApiService>()) {
      try {
        final apiLogs = await WaterQualityApiService.to.getLogs(
          branchId: branchId,
          category: 'Raw Water',
        );
        if (isClosed) return;
        reportsList.value = apiLogs.map((e) => WaterQualityLog.fromMap(e)).toList();
        if (!silent) isLoading.value = false;
        return;
      } catch (e) {
        debugPrint('API load raw water logs error: $e');
      }
    }

    if (isClosed) return;
    final dbHelper = DatabaseHelper.instance;
    final loaded = await dbHelper.getWaterQualityLogsByCategory('Raw Water', branchId: branchId);
    if (isClosed) return;
    reportsList.value = loaded;
    if (!silent) isLoading.value = false;
  }

  Future<void> _loadReferenceData() async {
    if (isClosed) return;
    isLoading.value = true;
    final dbHelper = DatabaseHelper.instance;
    final userBranchId = Get.isRegistered<UserSessionService>() ? UserSessionService.to.assignedBranchId : null;

    if (Get.isRegistered<MasterDataApiService>()) {
      try {
        final apiShifts = await MasterDataApiService.to.getShifts(branchId: userBranchId);
        if (isClosed) return;
        if (apiShifts.isNotEmpty) {
          shifts.value = apiShifts.map((e) => Shift.fromMap(e)).toList();
        }
        final apiParams = await MasterDataApiService.to.getTestParameters();
        if (isClosed) return;
        if (apiParams.isNotEmpty) {
          final mappedParams = apiParams.map((e) => TestParameter.fromMap(e)).toList();
          testParameters.value = mappedParams;
          dbHelper.syncTestParameters(mappedParams).catchError((_) {});
        }
        final apiStandards = await MasterDataApiService.to.getQualityStandards(waterType: 'Raw Water');
        if (isClosed) return;
        if (apiStandards.isNotEmpty) {
          final mappedStandards = apiStandards.map((e) => QualityStandard.fromMap(e)).toList();
          standards.value = mappedStandards;
          dbHelper.syncQualityStandards(mappedStandards, waterType: 'Raw Water').catchError((_) {});
        }
      } catch (e) {
        debugPrint('API load raw water reference data error: $e');
      }
    }

    if (isClosed) return;

    if (shifts.isEmpty) {
      shifts.value = await dbHelper.getShiftsForBranch(userBranchId);
    }
    if (isClosed) return;
    if (shifts.isNotEmpty && selectedShiftObj.value == null) {
      selectedShiftObj.value = shifts.first;
    }

    if (testParameters.isEmpty) {
      testParameters.value = await dbHelper.getTestParameters();
    }
    if (isClosed) return;
    if (standards.isEmpty) {
      standards.value = await dbHelper.getQualityStandards(null, 'Raw Water');
    }
    if (isClosed) return;
    
    // Categorize Standards
    sensoryStandards.clear();
    physioChemicalStandards.clear();
    microbiologicalStandards.clear();

    final Map<int, QualityStandard> uniqueStandards = {};
    for (var std in standards) {
      uniqueStandards.putIfAbsent(std.parameterId, () => std);
    }

    for (var std in uniqueStandards.values) {
      final param = getParameterDetails(std.parameterId);
      if (param != null) {
        if (param.category == 'Sensory') {
          sensoryStandards.add(std);
        } else if (param.category == 'Physical' || param.category == 'Chemical' || param.category == 'Physiochemical') {
          physioChemicalStandards.add(std);
        } else if (param.category == 'Microbiological') {
          microbiologicalStandards.add(std);
        }
      }
      
      if (!formControllers.containsKey(std.parameterId)) {
        var textCtrl = TextEditingController();
        textCtrl.addListener(() => _validateField(std));
        
        formControllers[std.parameterId] = textCtrl;
        formValidations[std.parameterId] = Rx<bool?>(null);
        formNoteControllers[std.parameterId] = TextEditingController();
        isNoteVisible[std.parameterId] = false.obs;
      }
    }
    
    isLoading.value = false;
  }

  void selectShift(Shift shift) {
    selectedShiftObj.value = shift;
  }

  void generateBatchNumber() {
    final now = DateTime.now();
    batchNumberController.text =
        'RW${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  TestParameter? getParameterDetails(int parameterId) {
    try {
      return testParameters.firstWhere((p) => p.id == parameterId);
    } catch (e) {
      return null;
    }
  }

  void _validateField(QualityStandard std) {
    final pId = std.parameterId;
    final text = formControllers[pId]?.text.trim() ?? '';
    final param = getParameterDetails(pId);
    
    if (text.isEmpty) {
      formValidations[pId]?.value = null;
    } else {
      if (param?.inputType == 'Numeric') {
        final val = double.tryParse(text);
        if (val == null) {
          formValidations[pId]?.value = false;
        } else {
          bool ok = true;
          if (std.minValue != null && val < std.minValue!) ok = false;
          if (std.maxValue != null && val > std.maxValue!) ok = false;
          formValidations[pId]?.value = ok;
        }
      } else {
        if (std.expectedText != null && std.expectedText!.isNotEmpty) {
          if (std.expectedText == '<100 CFU') {
            final val = double.tryParse(text);
            formValidations[pId]?.value = (val != null && val < 100);
          } else if (text == 'غير مطابق') {
            formValidations[pId]?.value = false;
          } else {
            formValidations[pId]?.value = (text.toLowerCase() == std.expectedText!.toLowerCase());
          }
        } else {
          if (text == 'غير مطابق') {
            formValidations[pId]?.value = false;
          } else {
            formValidations[pId]?.value = true;
          }
        }
      }
    }
    _updateCompliance();
  }

  void setParamValue(int parameterId, String val) {
    if (formControllers.containsKey(parameterId)) {
      formControllers[parameterId]!.text = val;
      formControllers.refresh(); // Trigger Obx rebuilds
    }
  }

  void toggleParamNote(int parameterId) {
    if (isNoteVisible.containsKey(parameterId)) {
      isNoteVisible[parameterId]!.toggle();
    }
  }

  void _updateCompliance() {
    if (standards.isEmpty) {
      isAllCompliant.value = false;
      return;
    }
    bool allOk = true;
    for (var std in standards) {
      // If a field is not validated properly or is empty, it's not compliant yet
      if (formValidations[std.parameterId]?.value != true) {
        allOk = false;
        break;
      }
    }
    isAllCompliant.value = allOk;
  }

  Future<void> loadReport(WaterQualityLog log) async {
    // يُسمح فقط بتعديل المسودات؛ أي تقرير دخل دورة الاعتماد أو اعتُمد أو رُفض يكون مقفلاً
    if (log.approvalStatus != 'Draft' && log.approvalStatus != 'مسودة') {
      Get.snackbar(
        'التقرير مقفل للتعديل',
        'لا يمكن تعديل التقرير بعد رفعه لدورة الاعتماد أو إغلاقه.${(log.rejectionReason ?? '').isNotEmpty ? '\nسبب الرفض: ${log.rejectionReason}' : ''}'
        '${(log.correctiveAction ?? '').isNotEmpty ? '\nالإجراء التصحيحي: ${log.correctiveAction}' : ''}',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
      );
      return;
    }
    isLoading.value = true;
    _resetForm();
    await _loadReferenceData(); // ensure parameters are loaded

    currentLogId = log.id;
    currentRejectionReason.value = log.rejectionReason ?? '';
    currentRejectedBy.value = log.rejectedBy ?? '';
    isFormVisible.value = true;
    
    // Set Shift
    try {
      selectedShiftObj.value = shifts.firstWhere((s) => s.id == log.shiftId);
    } catch (_) {}

    batchNumberController.text = log.batchNumber ?? '';
    notesController.text = log.generalNotes ?? '';
    waterSourceController.text = log.waterSource ?? '';
    wellNumberController.text = log.wellNumber ?? '';
    sampleTakerController.text = log.sampleTaker ?? '';
    ncrNumberController.text = log.ncrNumber ?? '';
    managerNotified.value = log.managerNotified ?? false;
    sourceSuspended.value = log.sourceSuspended ?? false;

    // Load results: محاولة القراءة من الـ API أولاً لضمان أحدث النتائج
    List<WaterQualityResult> results = [];
    if (Get.isRegistered<WaterQualityApiService>() && log.id != null) {
      try {
        final logDetails = await WaterQualityApiService.to.getLogById(log.id!);
        if (logDetails != null && logDetails['results'] is List) {
          results = (logDetails['results'] as List)
              .map((r) => WaterQualityResult.fromMap(Map<String, dynamic>.from(r)))
              .toList();
        }
      } catch (e) {
        debugPrint('API getLogById error in loadReport: $e');
      }
    }
    if (results.isEmpty && log.id != null) {
      final dbHelper = DatabaseHelper.instance;
      results = await dbHelper.getWaterQualityResultsByLogId(log.id!);
    }
    
    for (var res in results) {
      final textCtrl = formControllers[res.parameterId];
      if (textCtrl != null) {
        final param = getParameterDetails(res.parameterId);
        if (param?.inputType == 'Numeric') {
          textCtrl.text = res.numericResult?.toString() ?? '';
        } else {
          textCtrl.text = res.textResult ?? '';
        }
      }
      final noteCtrl = formNoteControllers[res.parameterId];
      if (noteCtrl != null) {
        noteCtrl.text = res.notes ?? '';
        if (noteCtrl.text.isNotEmpty) {
          isNoteVisible[res.parameterId]?.value = true;
        }
      }
    }

    isLoading.value = false;
  }

  Future<void> saveAsDraft() async {
    await _saveData(isDraft: true);
  }

  Future<void> submitForm() async {
    // 1. Basic validation
    if (selectedShiftObj.value == null) {
      Get.snackbar('تنبيه', 'الرجاء تحديد الوردية', backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }
    if (batchNumberController.text.trim().isEmpty) {
      Get.snackbar('تنبيه', 'الرجاء إدخال رقم العينة/الدفعة', backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    // 2. Ensure all fields are filled for final submit
    for (var std in standards) {
      // نتائج الميكروبيولوجي تصل بعد 24 ساعة — تُدخل لاحقاً في مرحلة منفصلة
      final param = getParameterDetails(std.parameterId);
      if (param != null && param.category == 'Microbiological') {
        continue;
      }
      if ((formControllers[std.parameterId]?.text.trim() ?? '').isEmpty) {
        Get.snackbar('تنبيه', 'الرجاء إكمال جميع الفحوصات قبل رفع التقرير للاعتماد', backgroundColor: Colors.redAccent, colorText: Colors.white);
        return;
      }
    }

    await _saveData(isDraft: false);
  }

  Future<void> _saveData({required bool isDraft}) async {
    if (isSaving.value) return;
    isSaving.value = true;
    if (Get.isRegistered<UserSessionService>() && !UserSessionService.to.canCreateWaterReports) {
      isSaving.value = false;
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية إدخال أو حفظ تقارير المياه في حسابك الحالي',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    final takerName = sampleTakerController.text.trim().isNotEmpty
        ? sampleTakerController.text.trim()
        : (Get.isRegistered<UserSessionService>() ? UserSessionService.to.currentUserName.value : 'أخصائي الجودة');

    // هل توجد معايير ميكروبيولوجية غير مُعبَّأة؟ → تُكمل لاحقاً (مرحلة ثانية)
    bool hasPendingMicro = false;
    for (var std in standards) {
      final param = getParameterDetails(std.parameterId);
      if (param != null && param.category == 'Microbiological') {
        final text = formControllers[std.parameterId]?.text.trim() ?? '';
        if (text.isEmpty) {
          hasPendingMicro = true;
          break;
        }
      }
    }

    final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
    final currentUserId = session?.currentUser.value?.id ?? 1;

    final log = WaterQualityLog(
      id: currentLogId,
      branchId: selectedShiftObj.value?.branchId ?? (session?.assignedBranchId ?? 1),
      shiftId: selectedShiftObj.value?.id ?? 1,
      createdBy: currentUserId,
      reportCategory: 'Raw Water',
      waterType: 'Raw Water',
      batchNumber: batchNumberController.text.trim(),
      isCompliant: isAllCompliant.value,
      generalNotes: notesController.text.trim(),
      approvalStatus: isDraft ? 'Draft' : 'Pending_QM', // Pending Quality Manager
      waterSource: waterSourceController.text.trim(),
      wellNumber: wellNumberController.text.trim(),
      sampleTaker: takerName,
      managerNotified: managerNotified.value,
      sourceSuspended: sourceSuspended.value,
      ncrNumber: ncrNumberController.text.trim(),
      microResultsPending: hasPendingMicro,
    );

    List<WaterQualityResult> results = [];
    for (var std in standards) {
      final pId = std.parameterId;
      final text = formControllers[pId]?.text.trim() ?? '';
      final noteText = formNoteControllers[pId]?.text.trim() ?? '';
      
      if (text.isEmpty && noteText.isEmpty) continue; // Skip empty fields, allowed for drafts

      final param = getParameterDetails(pId);
      
      double? numericVal;
      String? textVal;
      
      if (param?.inputType == 'Numeric') {
        numericVal = double.tryParse(text);
      } else {
        textVal = text;
      }

      results.add(
        WaterQualityResult(
          logId: log.id ?? 0,
          parameterId: pId,
          numericResult: numericVal,
          textResult: textVal,
          isCompliant: formValidations[pId]?.value ?? false,
          notes: noteText.isNotEmpty ? noteText : null,
        ),
      );
    }

    try {
      WaterQualityLog effectiveLog = log;
      List<WaterQualityResult> effectiveResults = results;

      final int? previousLocalId = currentLogId;
      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          final savedId = await WaterQualityApiService.to.saveLog(
            log.toMap(),
            results.map((r) => r.toMap()).toList(),
          );
          if (savedId != null && savedId > 0) {
            if (previousLocalId != null && previousLocalId != savedId) {
              await DatabaseHelper.instance.deleteWaterQualityReport(previousLocalId);
            }
            currentLogId = savedId;
            effectiveLog = log.copyWith(id: savedId);
            effectiveResults = results.map((r) => WaterQualityResult(
              id: r.id,
              logId: savedId,
              parameterId: r.parameterId,
              numericResult: r.numericResult,
              textResult: r.textResult,
              isCompliant: r.isCompliant,
              notes: r.notes,
            )).toList();
          }
        } catch (e) {
          debugPrint('API saveLog raw water error: $e');
        }
      }

      // حفظ نسخة الكاش المحلي متطابقة مع معرّف السيرفر
      await DatabaseHelper.instance.saveWaterQualityReport(effectiveLog, effectiveResults);
      await loadReports();

      if (!isDraft) {
        // Send in-app notification to Quality Manager
        if (Get.isRegistered<NotificationService>()) {
          await NotificationService.to.sendNotification(
            title: 'تقرير فحص مياه خام بانتظار الاعتماد',
            body: 'تم رفع تقرير عينة رقم (${log.batchNumber}) بواسطة $takerName وبانتظار اعتماد مدير الجودة.',
            reportId: currentLogId ?? log.id,
            reportCategory: 'Raw Water',
            targetRole: 'QualityManager',
            branchId: log.branchId,
          );
        }
      }

      Get.snackbar(
        'نجاح',
        isDraft
            ? 'تم حفظ التقرير كمسودة'
            : (hasPendingMicro
                ? 'تم رفع التقرير للاعتماد. ملاحظة: الفحوصات الميكروبيولوجية تُكمل لاحقاً وستتطلب جولة اعتماد ثانية.'
                : 'تم رفع التقرير للاعتماد بنجاح إلى مدير الجودة'),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      _resetForm();
      isFormVisible.value = false; // Hide form and show drafts
      loadReports();
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء الحفظ: $e', backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isSaving.value = false;
    }
  }

  void _clearDynamicForm() {
    for (var ctrl in formControllers.values) {
      ctrl.dispose();
    }
    for (var ctrl in formNoteControllers.values) {
      ctrl.dispose();
    }
    formControllers.clear();
    formValidations.clear();
    formNoteControllers.clear();
    isNoteVisible.clear();
  }

  void _resetForm() {
    currentLogId = null;
    currentRejectionReason.value = '';
    currentRejectedBy.value = '';
    selectedShiftObj.value = null;
    batchNumberController.clear();
    notesController.clear();
    waterSourceController.clear();
    wellNumberController.clear();
    sampleTakerController.text = Get.isRegistered<UserSessionService>() &&
            UserSessionService.to.currentRole.value == UserRole.qualitySpecialist
        ? UserSessionService.to.currentUserName.value
        : 'صلاح الجابري';
    ncrNumberController.clear();
    managerNotified.value = false;
    sourceSuspended.value = false;
    _clearDynamicForm();
    _loadReferenceData();
  }

  @override
  void onClose() {
    if (Get.isRegistered<SyncManager>()) {
      SyncManager.to.unregisterRefresher('raw_water_reports');
    }
    _userWorker?.dispose();
    _roleWorker?.dispose();
    _clearDynamicForm();
    batchNumberController.dispose();
    notesController.dispose();
    waterSourceController.dispose();
    wellNumberController.dispose();
    sampleTakerController.dispose();
    ncrNumberController.dispose();
    super.onClose();
  }
}
