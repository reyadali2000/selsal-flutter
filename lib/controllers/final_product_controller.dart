import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/production_models.dart';
import '../models/settings_models.dart';
import '../models/standards_models.dart';
import '../models/water_quality_models.dart';
import '../services/api/api.dart';
import '../services/sync/sync_manager.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/user_session_service.dart';

class FinalProductController extends GetxController {
  var shifts = <Shift>[].obs;
  var products = <Product>[].obs;
  var selectedShiftObj = Rx<Shift?>(null);
  var selectedProductObj = Rx<Product?>(null);

  // 1. Basic / Batch Info Controllers
  final productNameController = TextEditingController(text: 'مياه شرب معبأة سلسال');
  final bottleSizeController = TextEditingController(text: '330 مل');
  var selectedBottleSize = '330 مل'.obs;
  final batchNumberController = TextEditingController();
  final productionDateController = TextEditingController();
  final samplingTimeController = TextEditingController();
  var samplingLocation = 'أثناء التشغيل'.obs; // بداية التشغيل, أثناء التشغيل, نهاية التشغيل
  final producedQuantityController = TextEditingController(text: '5000 كرتون');
  final sampleTakerController = TextEditingController(text: 'صلاح الجابري');
  final notesController = TextEditingController();

  // 2. Non-Compliance Actions
  var isCompliantDecision = true.obs;
  var isIsolated = false.obs;
  var isHoldIssued = false.obs;
  var isRejectIssued = false.obs;
  final ncrNumberController = TextEditingController();

  // 3. Standards and Parameters
  var standards = <QualityStandard>[].obs;
  var testParameters = <TestParameter>[].obs;

  // Categorized Standards for UI (Visual, Physicochemical, Microbiological)
  var visualStandards = <QualityStandard>[].obs;
  var physiochemicalStandards = <QualityStandard>[].obs;
  var microbiologicalStandards = <QualityStandard>[].obs;

  var formControllers = <int, TextEditingController>{}.obs;
  var formValidations = <int, Rx<bool?>>{}.obs;
  var formNoteControllers = <int, TextEditingController>{}.obs;
  var isNoteVisible = <int, RxBool>{}.obs;

  var isAllCompliant = false.obs;
  var isLoading = false.obs;
  var isSaving = false.obs;

  // Track the current loaded log ID if editing a draft or rejected report
  int? currentLogId;
  var currentRejectionReason = ''.obs;
  var currentRejectedBy = ''.obs;

  // UI state for Drafts vs Form
  var isFormVisible = false.obs;

  // List of saved reports for the reports page
  var reportsList = <WaterQualityLog>[].obs;

  @override
  void onInit() {
    super.onInit();
    _initDateTimeDefaults();
    _loadReferenceData();
    loadReports();

    if (Get.isRegistered<SyncManager>()) {
      SyncManager.to.registerRefresher('final_product_reports', () async {
        // تخطي التحديث إذا كان المستخدم يقوم بإدخال تقرير حالياً
        if (isFormVisible.value) return;
        await loadReports(silent: true);
      });
    }

    if (Get.isRegistered<UserSessionService>()) {
      ever(UserSessionService.to.currentUser, (_) {
        loadReports();
        _loadReferenceData();
      });
      ever(UserSessionService.to.currentRole, (_) => loadReports());
      ever(UserSessionService.to.activeBranchFilter, (_) => loadReports());
    }
  }

  void _initDateTimeDefaults() {
    final now = DateTime.now();
    productionDateController.text = DateFormat('yyyy-MM-dd').format(now);
    samplingTimeController.text = DateFormat('HH:mm').format(now);
  }

  void startNewReport() {
    _resetForm();
    isFormVisible.value = true;
  }

  Future<void> loadReports({bool silent = false}) async {
    if (!silent) isLoading.value = true;
    final branchId = Get.isRegistered<UserSessionService>()
        ? UserSessionService.to.effectiveBranchFilter
        : null;

    // الـ API هو المصدر الأساسي للبيانات (SQL Server) — التحميل منه أولاً
    if (Get.isRegistered<WaterQualityApiService>()) {
      try {
        final apiLogs = await WaterQualityApiService.to.getLogs(
          branchId: branchId,
          category: 'Final Product',
        );
        reportsList.value = apiLogs.map((e) => WaterQualityLog.fromMap(e)).toList();
        if (!silent) isLoading.value = false;
        return;
      } catch (e) {
        debugPrint('API load final product logs error: $e');
      }
    }

    // مسار احتياطي: قاعدة البيانات المحلية
    final dbHelper = DatabaseHelper.instance;
    reportsList.value = await dbHelper.getWaterQualityLogsByCategory('Final Product', branchId: branchId);
    if (!silent) isLoading.value = false;
  }

  Future<void> _loadReferenceData() async {
    isLoading.value = true;
    final dbHelper = DatabaseHelper.instance;
    final userBranchId = Get.isRegistered<UserSessionService>() ? UserSessionService.to.effectiveBranchFilter : null;

    // الـ API هو المصدر الأساسي للبيانات المرجعية (الورديات، العبوات، البارامترات، المواصفات)
    if (Get.isRegistered<MasterDataApiService>()) {
      try {
        final apiShifts = await MasterDataApiService.to.getShifts(branchId: userBranchId);
        if (apiShifts.isNotEmpty) {
          shifts.value = apiShifts.map((e) => Shift.fromMap(e)).toList();
        }
        final apiProducts = await MasterDataApiService.to.getProducts(branchId: userBranchId);
        if (apiProducts.isNotEmpty) {
          products.value = apiProducts.map((e) => Product.fromMap(e)).toList();
        }
        final apiParams = await MasterDataApiService.to.getTestParameters();
        if (apiParams.isNotEmpty) {
          final mappedParams = apiParams.map((e) => TestParameter.fromMap(e)).toList();
          testParameters.value = mappedParams;
          dbHelper.syncTestParameters(mappedParams).catchError((_) {});
        }
        final apiStandards = await MasterDataApiService.to.getQualityStandards(waterType: 'Final Product');
        if (apiStandards.isNotEmpty) {
          final mappedStandards = apiStandards.map((e) => QualityStandard.fromMap(e)).toList();
          standards.value = mappedStandards;
          dbHelper.syncQualityStandards(mappedStandards).catchError((_) {});
        }
      } catch (e) {
        debugPrint('API load final product reference data error: $e');
      }
    }

    // مسار احتياطي: تعبئة ما لم يُجلب من الـ API من قاعدة البيانات المحلية
    if (shifts.isEmpty) {
      // ورديات مصنع المستخدم الحالي فقط — لكل مصنع وردياته الخاصة
      shifts.value = await dbHelper.getShiftsForBranch(userBranchId);
    }
    if (products.isEmpty) {
      // العبوات النشطة المرئية لهذا المستخدم حسب مصنعهم (مصفاة بالفرع)
      products.value = await dbHelper.getActiveProducts(branchId: userBranchId);
    }
    if (testParameters.isEmpty) {
      testParameters.value = await dbHelper.getTestParameters();
    }
    if (standards.isEmpty) {
      // Load standards for Final Product
      standards.value = await dbHelper.getQualityStandards(null, 'Final Product');
    }

    if (shifts.isNotEmpty) {
      selectedShiftObj.value ??= shifts.first;
    }
    if (products.isNotEmpty) {
      // العبوة المختارة يجب أن تنتمي لمصنع المستخدم المقيّد
      final belongsToBranch = selectedProductObj.value == null ||
          (userBranchId != null && userBranchId > 0 && selectedProductObj.value!.branchId != userBranchId);
      if (selectedProductObj.value == null || belongsToBranch) {
        selectedProductObj.value = products.first;
      }
      productNameController.text = selectedProductObj.value!.name;
      selectedBottleSize.value = selectedProductObj.value!.name;
      bottleSizeController.text = selectedProductObj.value!.name;
    } else {
      // لا توجد عبوات مخصصة لمصنع هذا المستخدم — إعادة الضبط
      selectedProductObj.value = null;
      selectedBottleSize.value = '';
      bottleSizeController.text = '';
    }

    _categorizeStandards();
    isLoading.value = false;
  }

  void _categorizeStandards() {
    visualStandards.clear();
    physiochemicalStandards.clear();
    microbiologicalStandards.clear();

    for (var std in standards) {
      final param = getParameterDetails(std.parameterId);
      if (param != null) {
        if (param.category == 'Sensory') {
          visualStandards.add(std);
        } else if (param.category == 'Physical' ||
            param.category == 'Chemical' ||
            param.category == 'Physiochemical') {
          physiochemicalStandards.add(std);
        } else if (param.category == 'Microbiological') {
          microbiologicalStandards.add(std);
        }
      }

      if (!formControllers.containsKey(std.parameterId)) {
        var textCtrl = TextEditingController();
        // Set smart default for text tests
        if (std.expectedText != null && std.expectedText!.isNotEmpty) {
          textCtrl.text = std.expectedText!;
        }
        textCtrl.addListener(() => _validateField(std));

        formControllers[std.parameterId] = textCtrl;
        formValidations[std.parameterId] = Rx<bool?>(null);
        formNoteControllers[std.parameterId] = TextEditingController();
        isNoteVisible[std.parameterId] = false.obs;

        // Trigger initial validation
        _validateField(std);
      }
    }
  }

  void selectBottleSize(String size) {
    selectedBottleSize.value = size;
    bottleSizeController.text = size;
    // مزامنة العبوة المختارة لتطبيق ارتباطها بالمصنع
    final match = products.firstWhereOrNull((p) => p.name == size);
    if (match != null) {
      selectedProductObj.value = match;
      productNameController.text = match.name;
    }
  }

  void selectSamplingLocation(String loc) {
    samplingLocation.value = loc;
  }

  void selectShift(Shift shift) {
    selectedShiftObj.value = shift;
  }

  void selectProduct(Product prod) {
    selectedProductObj.value = prod;
    productNameController.text = prod.name;
  }

  void generateBatchNumber() {
    final now = DateTime.now();
    final dateStr = DateFormat('yyMMdd').format(now);
    final timeStr = DateFormat('HHmm').format(now);
    batchNumberController.text = 'FP-$dateStr-$timeStr';
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
          formValidations[pId]?.value =
              (text.toLowerCase() == std.expectedText!.toLowerCase());
        } else {
          formValidations[pId]?.value = true;
        }
      }
    }

    _updateCompliance();
  }

  void _updateCompliance() {
    if (standards.isEmpty) {
      isAllCompliant.value = false;
      return;
    }

    bool allOk = true;
    for (var std in standards) {
      final val = formValidations[std.parameterId]?.value;
      if (val == false) {
        allOk = false;
        break;
      }
    }
    isAllCompliant.value = allOk;
    isCompliantDecision.value = allOk;
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

  Future<void> submitForm({bool isDraft = false}) async {
    if (Get.isRegistered<UserSessionService>() && !UserSessionService.to.canCreateWaterReports) {
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية إدخال أو حفظ تقارير المياه في حسابك الحالي',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    if (batchNumberController.text.trim().isEmpty) {
      Get.snackbar('تنبيه', 'الرجاء إدخال رقم التشغيلة (Batch Number)',
          backgroundColor: Colors.orange.shade800, colorText: Colors.white);
      return;
    }

    if (selectedBottleSize.value.trim().isEmpty) {
      Get.snackbar(
        'لا توجد عبوة مخصصة',
        'لا يمكن حفظ التقرير لأنه لم يتم تحديد عبوة. تواصل مع مسؤول النظام لربط عبوات بمصنعكم.',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
      return;
    }

    if (!isDraft) {
      // For final submission, ensure required parameters have values
      for (var std in standards) {
        final text = formControllers[std.parameterId]?.text.trim() ?? '';
        final param = getParameterDetails(std.parameterId);
        // Ozone and chlorine can be optional if not applicable
        if (param != null &&
            (param.nameAr.contains('الأوزون') ||
                param.nameAr.contains('الكلور') ||
                param.nameAr.contains('درجة الحرارة') ||
                param.nameAr.contains('التوصيلية'))) {
          continue;
        }
        // نتائج الميكروبيولوجي تصل بعد 24 ساعة — تُدخل لاحقاً في مرحلة منفصلة
        if (param != null && param.category == 'Microbiological') {
          continue;
        }
        if (text.isEmpty) {
          Get.snackbar('تنبيه', 'الرجاء إكمال الفحص لجميع المعايير الإلزامية',
              backgroundColor: Colors.orange.shade800, colorText: Colors.white);
          return;
        }
      }
    }

    final status = isDraft ? 'Draft' : 'Pending_QM';
    final isCompliant = isCompliantDecision.value;

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
      reportCategory: 'Final Product',
      waterType: 'Final Product',
      batchNumber: batchNumberController.text.trim(),
      isCompliant: isCompliant,
      generalNotes: notesController.text.trim(),
      approvalStatus: status,
      sampleTaker: sampleTakerController.text.trim().isNotEmpty
          ? sampleTakerController.text.trim()
          : (session?.currentUserName.value.isNotEmpty == true
              ? session!.currentUserName.value
              : 'أخصائي الجودة'),
      ncrNumber: ncrNumberController.text.trim(),
      productName: productNameController.text.trim(),
      bottleSize: selectedBottleSize.value,
      productionDate: productionDateController.text.trim(),
      samplingTime: samplingTimeController.text.trim(),
      samplingLocation: samplingLocation.value,
      producedQuantity: producedQuantityController.text.trim(),
      isIsolated: isIsolated.value,
      isHoldIssued: isHoldIssued.value,
      isRejectIssued: isRejectIssued.value,
      microResultsPending: hasPendingMicro,
      rejectionReason: null,
      rejectedBy: null,
    );

    List<WaterQualityResult> results = [];
    for (var std in standards) {
      final pId = std.parameterId;
      final text = formControllers[pId]?.text.trim() ?? '';
      final note = formNoteControllers[pId]?.text.trim();
      final param = getParameterDetails(pId);

      double? numVal;
      String? textVal;

      if (param?.inputType == 'Numeric') {
        numVal = double.tryParse(text);
      } else {
        textVal = text;
      }

      results.add(
        WaterQualityResult(
          logId: currentLogId ?? 0,
          parameterId: pId,
          numericResult: numVal,
          textResult: textVal,
          isCompliant: formValidations[pId]?.value ?? true,
          notes: note != null && note.isNotEmpty ? note : null,
        ),
      );
    }

    try {
      WaterQualityLog effectiveLog = log;
      List<WaterQualityResult> effectiveResults = results;

      final int? previousLocalId = currentLogId;
      // المزامنة مع الـ API أولاً (المصدر الأساسي للبيانات)، ثم الحفظ في الكاش المحلي
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
          debugPrint('API saveLog final product error: $e');
        }
      }

      // حفظ نسخة الكاش المحلي متطابقة مع معرّف السيرفر
      await DatabaseHelper.instance.saveWaterQualityReport(effectiveLog, effectiveResults);
      await loadReports();

      // Trigger notification if submitted for approval
      if (!isDraft && Get.isRegistered<NotificationService>()) {
        final creatorName = sampleTakerController.text.trim();
        NotificationService.to.sendNotification(
          title: 'تقرير فحص منتج نهائي جديد',
          body:
              'قام $creatorName برفع تقرير فحص منتج نهائي للتشغيلة (${batchNumberController.text.trim()}) للاعتماد.',
          reportId: currentLogId,
          reportCategory: 'Final Product',
          targetRole: 'QualityManager',
        );
      }

      Get.snackbar(
        'نجاح',
        isDraft
            ? 'تم حفظ المسودة بنجاح'
            : (hasPendingMicro
                ? 'تم رفع التقرير وهو بانتظار اعتماد مدير الجودة. ملاحظة: الفحوصات الميكروبيولوجية تُكمل لاحقاً وستتطلب جولة اعتماد ثانية.'
                : 'تم رفع تقرير فحص المنتج النهائي بنجاح وهو بانتظار اعتماد مدير الجودة (حمود يسر)'),
        backgroundColor: isDraft ? Colors.blue.shade700 : Colors.green.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );

      _resetForm();
      isFormVisible.value = false;
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء الحفظ: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  Future<void> initForEdit(WaterQualityLog log) async {
    // يُسمح فقط بتعديل المسودات؛ أي تقرير دخل دورة الاعتماد أو اعتُمد أو رُفض يكون مقفلاً
    if (log.approvalStatus != 'Draft' && log.approvalStatus != 'مسودة') {
      Get.snackbar(
        'التقرير مقفل للتعديل',
        'لا يمكن تعديل التقرير بعد رفعه لدورة الاعتماد أو إغلاقه.${(log.rejectionReason ?? '').isNotEmpty ? '\nسبب الرفض: ${log.rejectionReason}' : ''}',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
      );
      return;
    }
    isLoading.value = true;
    currentLogId = log.id;
    currentRejectionReason.value = log.rejectionReason ?? '';
    currentRejectedBy.value = log.rejectedBy ?? '';

    batchNumberController.text = log.batchNumber ?? '';
    notesController.text = log.generalNotes ?? '';
    sampleTakerController.text = log.sampleTaker ?? 'صلاح الجابري';
    productNameController.text = log.productName ?? 'مياه شرب معبأة سلسال';
    selectedBottleSize.value = log.bottleSize ?? '';
    bottleSizeController.text = selectedBottleSize.value;
    // مزامنة العبوة المحفوظة مع كائن المنتج المرتبط (لتطبيق ارتباط المصنع)
    final savedProduct = products.firstWhereOrNull((p) => p.name == selectedBottleSize.value);
    selectedProductObj.value = savedProduct;
    productionDateController.text = log.productionDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    samplingTimeController.text = log.samplingTime ?? DateFormat('HH:mm').format(DateTime.now());
    samplingLocation.value = log.samplingLocation ?? 'أثناء التشغيل';
    producedQuantityController.text = log.producedQuantity ?? '5000 كرتون';
    ncrNumberController.text = log.ncrNumber ?? '';
    isIsolated.value = log.isIsolated ?? false;
    isHoldIssued.value = log.isHoldIssued ?? false;
    isRejectIssued.value = log.isRejectIssued ?? false;
    isCompliantDecision.value = log.isCompliant;

    if (shifts.isNotEmpty) {
      selectedShiftObj.value = shifts.firstWhereOrNull((s) => s.id == log.shiftId) ?? shifts.first;
    }

    if (standards.isEmpty) {
      await _loadReferenceData();
    }

    // تحميل نتائج الفحص من الـ API (المصدر الأساسي) إن أمكن
    List<WaterQualityResult> results = [];
    if (Get.isRegistered<WaterQualityApiService>()) {
      try {
        final apiLog = await WaterQualityApiService.to.getLogById(log.id!);
        if (apiLog != null && apiLog['results'] is List) {
          results = (apiLog['results'] as List)
              .map((r) => WaterQualityResult.fromMap(Map<String, dynamic>.from(r)))
              .toList();
        }
      } catch (e) {
        debugPrint('API load final product edit results error: $e');
      }
    }

    // مسار احتياطي: قاعدة البيانات المحلية
    if (results.isEmpty) {
      final dbHelper = DatabaseHelper.instance;
      results = await dbHelper.getWaterQualityResultsByLogId(log.id!);
    }

    for (var res in results) {
      final pId = res.parameterId;
      if (formControllers.containsKey(pId)) {
        if (res.numericResult != null) {
          formControllers[pId]!.text = res.numericResult.toString();
        } else if (res.textResult != null) {
          formControllers[pId]!.text = res.textResult!;
        }
      }
      if (formNoteControllers.containsKey(pId) && res.notes != null) {
        formNoteControllers[pId]!.text = res.notes!;
        isNoteVisible[pId]?.value = true;
      }
    }

    for (var std in standards) {
      _validateField(std);
    }

    isFormVisible.value = true;
    isLoading.value = false;
  }

  void _resetForm() {
    currentLogId = null;
    currentRejectionReason.value = '';
    currentRejectedBy.value = '';
    _initDateTimeDefaults();
    notesController.clear();
    ncrNumberController.clear();
    isIsolated.value = false;
    isHoldIssued.value = false;
    isRejectIssued.value = false;
    isCompliantDecision.value = true;
    sampleTakerController.text = UserSessionService.to.currentUserName.value.isNotEmpty
        ? UserSessionService.to.currentUserName.value
        : 'صلاح الجابري';

    for (var std in standards) {
      final pId = std.parameterId;
      if (std.expectedText != null && std.expectedText!.isNotEmpty) {
        formControllers[pId]?.text = std.expectedText!;
      } else {
        formControllers[pId]?.clear();
      }
      formNoteControllers[pId]?.clear();
      isNoteVisible[pId]?.value = false;
      _validateField(std);
    }
  }

  @override
  void onClose() {
    if (Get.isRegistered<SyncManager>()) {
      SyncManager.to.unregisterRefresher('final_product_reports');
    }
    productNameController.dispose();
    bottleSizeController.dispose();
    batchNumberController.dispose();
    productionDateController.dispose();
    samplingTimeController.dispose();
    producedQuantityController.dispose();
    sampleTakerController.dispose();
    notesController.dispose();
    ncrNumberController.dispose();

    for (var ctrl in formControllers.values) {
      ctrl.dispose();
    }
    for (var ctrl in formNoteControllers.values) {
      ctrl.dispose();
    }
    super.onClose();
  }
}
