import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/raw_material_models.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/user_session_service.dart';
import '../services/api/api.dart';
import '../views/raw_material_reports_page.dart';

class RawMaterialEntryController extends GetxController {
  // State
  final currentStep = 0.obs; // 0: Select Material, 1: General Info & Checklist, 2: Annex Checklist, 3: Decision & Actions
  final selectedCategory = Rx<RawMaterialCategoryInfo?>(null);
  final isFormVisible = false.obs;
  final isLoading = false.obs;
  final drafts = <RawMaterialReport>[].obs;
  int? activeDraftId;

  // Controllers for Receipt Data (Page 1)
  final dateController = TextEditingController();
  final timeController = TextEditingController();
  final supplierController = TextEditingController();
  final poNumberController = TextEditingController();
  final materialNameController = TextEditingController();
  final receiptNumberController = TextEditingController();
  final receivedQuantityController = TextEditingController();
  final inspectedQuantityController = TextEditingController();
  final acceptedQuantityController = TextEditingController();
  final rejectedQuantityController = TextEditingController();
  final batchNumberController = TextEditingController();
  final inspectorNameController = TextEditingController();

  // General Checklist Results (Page 1 - 10 items)
  final generalCompliance = <int, bool?>{}.obs;
  final generalResults = <int, String>{}.obs;
  final generalNotes = <int, String>{}.obs;

  // Specialized Annex Results (Page 2)
  final annexCompliance = <int, bool?>{}.obs;
  final annexResults = <int, String>{}.obs;
  final annexNotes = <int, String>{}.obs;

  // Quality Decision & Actions (Page 1)
  final qualityDecision = 'Accepted'.obs; // Accepted, AcceptedWithConditions, Hold, Reject
  final actionHold = false.obs;
  final actionReject = false.obs;
  final actionReturnToSupplier = false.obs;
  final actionNcr = false.obs;
  final ncrNumberController = TextEditingController();

  // Overall Notes
  final generalNotesController = TextEditingController();
  final annexNotesController = TextEditingController();

  // Per-item note controllers (cached by item id and created lazily).
  // NOTE: creating a TextEditingController inside build()/Obx resets the
  // caret position and can lose typed text on every keystroke, so we keep a
  // stable controller per checklist item instead.
  final Map<int, TextEditingController> generalNoteControllers = {};
  final Map<int, TextEditingController> annexNoteControllers = {};

  TextEditingController getGeneralNoteController(int id) {
    return generalNoteControllers.putIfAbsent(
      id,
      () => TextEditingController(text: generalNotes[id] ?? ''),
    );
  }

  TextEditingController getAnnexNoteController(int id) {
    return annexNoteControllers.putIfAbsent(
      id,
      () => TextEditingController(text: annexNotes[id] ?? ''),
    );
  }

  /// Pushes the current note-map values into any already-created controllers.
  /// Used when a draft is restored or a category is (re)selected so the
  // on-screen text fields match the restored data without recreating
  // controllers (which would reset the caret).
  void _syncNoteControllers() {
    for (final id in generalNoteControllers.keys) {
      generalNoteControllers[id]!.text = generalNotes[id] ?? '';
    }
    for (final id in annexNoteControllers.keys) {
      annexNoteControllers[id]!.text = annexNotes[id] ?? '';
    }
  }

  @override
  void onInit() {
    super.onInit();
    _initDefaults();
    loadDrafts();
    
    receivedQuantityController.addListener(_calculateRejectedQuantity);
    acceptedQuantityController.addListener(_calculateRejectedQuantity);
  }

  void _calculateRejectedQuantity() {
    final receivedStr = receivedQuantityController.text.trim();
    final acceptedStr = acceptedQuantityController.text.trim();
    
    if (receivedStr.isNotEmpty && acceptedStr.isNotEmpty) {
      final received = double.tryParse(receivedStr);
      final accepted = double.tryParse(acceptedStr);
      if (received != null && accepted != null) {
        final rejected = received - accepted;
        if (rejected >= 0) {
           rejectedQuantityController.text = rejected == rejected.toInt() ? rejected.toInt().toString() : rejected.toStringAsFixed(2).replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
        } else {
           rejectedQuantityController.text = '0';
        }
      }
    } else {
      rejectedQuantityController.text = '';
    }
  }

  void _initDefaults() {
    final now = DateTime.now();
    dateController.text = DateFormat('yyyy/MM/dd').format(now);
    timeController.text = DateFormat('hh:mm a').format(now);
    
    if (Get.isRegistered<UserSessionService>()) {
      inspectorNameController.text = UserSessionService.to.currentUserName.value;
    } else {
      inspectorNameController.text = 'صلاح الجابري (مهندس الجودة)';
    }

    // Default general compliance to true
    for (final item in RawMaterialGeneralCriteria.items) {
      generalCompliance[item.id] = true;
    }
  }

  Future<void> loadDrafts() async {
    try {
      isLoading.value = true;
      final branchId = Get.isRegistered<UserSessionService>()
          ? UserSessionService.to.assignedBranchId
          : null;
      final reports = await DatabaseHelper.instance.getRawMaterialReports(branchId: branchId);
      drafts.value = reports.where((r) => r.approvalStatus == 'Draft').toList();
    } catch (e) {
      debugPrint('Error loading raw material drafts: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void startNewReport() {
    _resetForm();
    isFormVisible.value = true;
    currentStep.value = 0;
  }

  void selectCategory(RawMaterialCategoryInfo category) {
    selectedCategory.value = category;
    materialNameController.text = category.title;
    
    // Initialize annex compliance to true
    annexCompliance.clear();
    annexResults.clear();
    annexNotes.clear();
    for (final item in category.criteria) {
      annexCompliance[item.id] = true;
    }

    // Keep any already-created annex note fields in sync with the cleared map
    // (e.g. when the user switches category after typing notes).
    _syncNoteControllers();

    currentStep.value = 1; // Move to common info & checklist
  }

  void setAllGeneralCompliant(bool compliant) {
    for (final item in RawMaterialGeneralCriteria.items) {
      generalCompliance[item.id] = compliant;
    }
  }

  void setAllAnnexCompliant(bool compliant) {
    if (selectedCategory.value == null) return;
    for (final item in selectedCategory.value!.criteria) {
      annexCompliance[item.id] = compliant;
    }
  }

  void nextStep() {
    if (currentStep.value == 0 && selectedCategory.value == null) {
      Get.snackbar('تنبيه', 'يرجى اختيار نوع المادة الخام أولاً',
          backgroundColor: Colors.orange.shade100, colorText: Colors.orange.shade900);
      return;
    }
    if (currentStep.value == 1) {
      if (supplierController.text.trim().isEmpty || batchNumberController.text.trim().isEmpty) {
        Get.snackbar('تنبيه', 'يرجى ملء اسم المورد ورقم التشغيلة',
            backgroundColor: Colors.orange.shade100, colorText: Colors.orange.shade900);
        return;
      }
    }
    if (currentStep.value < 3) {
      currentStep.value++;
    }
  }

  void previousStep() {
    if (currentStep.value > 0) {
      currentStep.value--;
    } else {
      isFormVisible.value = false;
    }
  }

  Future<void> saveReport({bool isDraft = false}) async {
    if (selectedCategory.value == null) {
      Get.snackbar('تنبيه', 'يرجى اختيار نوع المادة الخام',
          backgroundColor: Colors.orange.shade100, colorText: Colors.orange.shade900);
      return;
    }

    if (!isDraft) {
      if (supplierController.text.trim().isEmpty || batchNumberController.text.trim().isEmpty) {
        Get.snackbar('تنبيه', 'يرجى إكمال بيانات الاستلام (اسم المورد ورقم التشغيلة مطلوبان)',
            backgroundColor: Colors.orange.shade100, colorText: Colors.orange.shade900);
        return;
      }
    }

    try {
      final category = selectedCategory.value!;

      // Build General Results
      final generalItems = RawMaterialGeneralCriteria.items.map((c) {
        return RawMaterialItemResult(
          itemId: c.id,
          itemName: c.name,
          acceptanceCriteria: c.acceptanceCriteria,
          isCompliant: generalCompliance[c.id],
          resultValue: generalResults[c.id],
          notes: generalNotes[c.id],
        );
      }).toList();

      // Build Annex Results
      final annexItems = category.criteria.map((c) {
        return RawMaterialItemResult(
          itemId: c.id,
          itemName: c.name,
          acceptanceCriteria: c.acceptanceCriteria,
          isCompliant: annexCompliance[c.id],
          resultValue: annexResults[c.id],
          notes: annexNotes[c.id],
        );
      }).toList();

      final branchId = Get.isRegistered<UserSessionService>() ? (UserSessionService.to.assignedBranchId ?? 1) : 1;
      final branchName = branchId == 2 ? 'مصنع سنحان' : 'مصنع أرتل';
      final report = RawMaterialReport(
        id: activeDraftId,
        branchId: branchId,
        branchName: branchName,
        categoryKey: category.key,
        annexCode: category.annexCode,
        annexTitle: category.annexTitle,
        dateStr: dateController.text.trim(),
        timeStr: timeController.text.trim(),
        supplierName: supplierController.text.trim(),
        poNumber: poNumberController.text.trim(),
        materialName: materialNameController.text.trim(),
        receiptNumber: receiptNumberController.text.trim(),
        receivedQuantity: receivedQuantityController.text.trim(),
        inspectedQuantity: inspectedQuantityController.text.trim(),
        acceptedQuantity: acceptedQuantityController.text.trim(),
        rejectedQuantity: rejectedQuantityController.text.trim(),
        inspectorName: inspectorNameController.text.trim(),
        batchNumber: batchNumberController.text.trim(),
        qualityDecision: qualityDecision.value,
        actionHold: actionHold.value,
        actionReject: actionReject.value,
        actionReturnToSupplier: actionReturnToSupplier.value,
        actionNcr: actionNcr.value,
        ncrNumber: actionNcr.value ? ncrNumberController.text.trim() : null,
        generalNotes: generalNotesController.text.trim().isNotEmpty ? generalNotesController.text.trim() : null,
        annexNotes: annexNotesController.text.trim().isNotEmpty ? annexNotesController.text.trim() : null,
        approvalStatus: isDraft ? 'Draft' : 'Pending_QS',
      );

      int? effectiveReportId = activeDraftId;
      RawMaterialReport effectiveReport = report;

      if (Get.isRegistered<RawMaterialsApiService>()) {
        try {
          final generalWithTypes = generalItems.map((i) {
            final map = i.toJson();
            map['item_type'] = 'general';
            return map;
          }).toList();
          final annexWithTypes = annexItems.map((i) {
            final map = i.toJson();
            map['item_type'] = 'annex';
            return map;
          }).toList();
          final allItems = [...generalWithTypes, ...annexWithTypes];
          final apiReportId = await RawMaterialsApiService.to.saveTest(report.toJson(), allItems);
          if (apiReportId != null && apiReportId > 0) {
            if (activeDraftId != null && activeDraftId != apiReportId) {
              await DatabaseHelper.instance.deleteRawMaterialReport(activeDraftId!);
            }
            effectiveReportId = apiReportId;
            effectiveReport = report.copyWith(id: apiReportId);
          }
        } catch (e) {
          debugPrint('API save raw material error: $e');
        }
      }

      // حفظ نسخة الكاش المحلي متطابقة مع معرف السيرفر
      final savedId = await DatabaseHelper.instance.saveRawMaterialReport(
        reportId: effectiveReportId,
        report: effectiveReport,
        generalResults: generalItems,
        annexResults: annexItems,
      );

      activeDraftId = null;
      await loadDrafts();
      if (Get.isRegistered<RawMaterialReportsController>()) {
        Get.find<RawMaterialReportsController>().loadReports();
      }

      if (isDraft) {
        Get.snackbar(
          'تم الحفظ كمسودة',
          'تم حفظ بيانات الفحص بنجاح في قائمة المسودات',
          backgroundColor: Colors.blue.shade700,
          colorText: Colors.white,
        );
        isFormVisible.value = false;
        return;
      }

      // Send Notification to Quality Supervisor (Stage 1 of 3-level cycle)
      if (Get.isRegistered<NotificationService>()) {
        final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
        final creatorName = (session != null && session.currentUserName.value.isNotEmpty)
            ? session.currentUserName.value
            : inspectorNameController.text.trim();
        await NotificationService.to.sendNotification(
          title: 'تقرير فحص مادة خام جديد',
          body: 'قام $creatorName برفع تقرير فحص (${category.title}) للتشغيلة (${report.batchNumber}) للاعتماد.',
          reportId: savedId,
          reportCategory: 'Raw Material',
          targetRole: 'QualitySupervisor',
          branchId: branchId,
        );
      }

      Get.snackbar(
        'تم الحفظ والرفع بنجاح',
        'تم حفظ تقرير فحص المواد الخام ورفعه لمشرف الجودة للاعتماد',
        backgroundColor: Colors.green.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );

      isFormVisible.value = false;
      _resetForm();
    } catch (e) {
      Get.snackbar('خطأ', 'فشل حفظ التقرير: $e',
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
    }
  }

  Future<void> resumeDraft(RawMaterialReport report) async {
    if (report.approvalStatus != 'Draft' && report.approvalStatus != 'مسودة') {
      Get.snackbar(
        'التقرير مقفل للتعديل',
        'لا يمكن تعديل التقرير بعد رفعه لدورة الاعتماد أو إغلاقه.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }
    try {
      isLoading.value = true;
      activeDraftId = report.id;
      final details = await DatabaseHelper.instance.getRawMaterialReportDetails(report.id!);
      if (details == null) return;

      selectedCategory.value = RawMaterialCategoryInfo.getByKey(report.categoryKey);
      dateController.text = report.dateStr;
      timeController.text = report.timeStr;
      supplierController.text = report.supplierName;
      poNumberController.text = report.poNumber;
      materialNameController.text = report.materialName;
      receiptNumberController.text = report.receiptNumber;
      receivedQuantityController.text = report.receivedQuantity;
      inspectedQuantityController.text = report.inspectedQuantity;
      acceptedQuantityController.text = report.acceptedQuantity;
      rejectedQuantityController.text = report.rejectedQuantity;
      inspectorNameController.text = report.inspectorName;
      batchNumberController.text = report.batchNumber;

      qualityDecision.value = report.qualityDecision;
      actionHold.value = report.actionHold;
      actionReject.value = report.actionReject;
      actionReturnToSupplier.value = report.actionReturnToSupplier;
      actionNcr.value = report.actionNcr;
      ncrNumberController.text = report.ncrNumber ?? '';
      generalNotesController.text = report.generalNotes ?? '';
      annexNotesController.text = report.annexNotes ?? '';

      // Restore General Results
      generalCompliance.clear();
      generalResults.clear();
      generalNotes.clear();
      final generalItems = details['generalResults'] as List<RawMaterialItemResult>;
      for (final item in generalItems) {
        generalCompliance[item.itemId] = item.isCompliant;
        if (item.resultValue != null) generalResults[item.itemId] = item.resultValue!;
        if (item.notes != null) generalNotes[item.itemId] = item.notes!;
      }

      // Restore Annex Results
      annexCompliance.clear();
      annexResults.clear();
      annexNotes.clear();
      final annexItems = details['annexResults'] as List<RawMaterialItemResult>;
      for (final item in annexItems) {
        annexCompliance[item.itemId] = item.isCompliant;
        if (item.resultValue != null) annexResults[item.itemId] = item.resultValue!;
        if (item.notes != null) annexNotes[item.itemId] = item.notes!;
      }

      // Sync the per-item note controllers (if already created) with the
      // restored draft data so the text fields show the draft text.
      _syncNoteControllers();

      isFormVisible.value = true;
      currentStep.value = 1;
    } catch (e) {
      Get.snackbar('خطأ', 'فشل استرجاع المسودة: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteDraft(int id) async {
    try {
      await DatabaseHelper.instance.deleteRawMaterialReport(id);
      await loadDrafts();
      Get.snackbar('تم الحذف', 'تم حذف المسودة بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل حذف المسودة: $e');
    }
  }

  void _resetForm() {
    activeDraftId = null;
    selectedCategory.value = null;
    supplierController.clear();
    poNumberController.clear();
    materialNameController.clear();
    receiptNumberController.clear();
    receivedQuantityController.clear();
    inspectedQuantityController.clear();
    acceptedQuantityController.clear();
    rejectedQuantityController.clear();
    batchNumberController.clear();
    ncrNumberController.clear();
    generalNotesController.clear();
    annexNotesController.clear();

    // Reset per-item checklist state so a new report starts completely fresh.
    generalCompliance.clear();
    generalResults.clear();
    generalNotes.clear();
    annexCompliance.clear();
    annexResults.clear();
    annexNotes.clear();
    for (final controller in generalNoteControllers.values) {
      controller.dispose();
    }
    generalNoteControllers.clear();
    for (final controller in annexNoteControllers.values) {
      controller.dispose();
    }
    annexNoteControllers.clear();

    qualityDecision.value = 'Accepted';
    actionHold.value = false;
    actionReject.value = false;
    actionReturnToSupplier.value = false;
    actionNcr.value = false;
    _initDefaults();
  }

  @override
  void onClose() {
    dateController.dispose();
    timeController.dispose();
    supplierController.dispose();
    poNumberController.dispose();
    materialNameController.dispose();
    receiptNumberController.dispose();
    receivedQuantityController.dispose();
    inspectedQuantityController.dispose();
    acceptedQuantityController.dispose();
    rejectedQuantityController.dispose();
    batchNumberController.dispose();
    inspectorNameController.dispose();
    ncrNumberController.dispose();
    generalNotesController.dispose();
    annexNotesController.dispose();
    for (final controller in generalNoteControllers.values) {
      controller.dispose();
    }
    generalNoteControllers.clear();
    for (final controller in annexNoteControllers.values) {
      controller.dispose();
    }
    annexNoteControllers.clear();
    super.onClose();
  }
}
