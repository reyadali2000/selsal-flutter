import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../models/dynamic_report_models.dart';
import '../services/user_session_service.dart';
import '../services/notification_service.dart';
import '../services/factory_shifts_service.dart';
import '../services/database_helper.dart';
import '../utils/calculated_field_helper.dart';
import '../services/api/dynamic_reports_api_service.dart';


class DynamicReportFormController extends GetxController {
  /// توليد معرّف فريد للتقرير من جهة العميل (RFC 4122 v4 UUID) لمنع التكرار (Idempotency)
  String _generateClientUuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // v4
    values[8] = (values[8] & 0x3f) | 0x80; // variant
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
  final formKey = GlobalKey<FormState>();
  
  var isLoading = true.obs;
  var isSaving = false.obs;
  var isEditMode = false.obs;
  var existingRecord = Rxn<DynamicReportRecord>();
  var isFormOpen = false.obs;
  var isDirectRecordEntry = false.obs;
  var drafts = <DynamicReportRecord>[].obs;
  var isLoadingDrafts = false.obs;
  
  var report = Rxn<DynamicReport>();
  
  // fieldId -> value
  var fieldValues = <int, dynamic>{}.obs;
  
  // Controllers for text fields to manage state cleanly
  var textControllers = <int, TextEditingController>{};

  @override
  void onInit() {
    super.onInit();
    final dynamic args = Get.arguments;
    int? reportId;
    int? recordId;

    if (args is int) {
      reportId = args;
    } else if (args is Map<String, dynamic>) {
      reportId = args['reportId'] as int?;
      recordId = args['recordId'] as int?;
    }

    if (recordId != null) {
      isDirectRecordEntry.value = true;
      isEditMode.value = true;
      isFormOpen.value = true;
      loadRecordAndReport(recordId, reportId);
    } else if (reportId != null) {
      isDirectRecordEntry.value = false;
      isFormOpen.value = false;
      loadReportAndDrafts(reportId);
    } else {
      Get.snackbar('خطأ', 'معرف التقرير غير موجود');
      Get.back();
    }
  }


  Future<void> loadReportAndDrafts(int reportId) async {
    isLoading.value = true;
    try {
      final loadedReport = await DynamicReportsApiService.to.getTemplateDetails(reportId);
      if (loadedReport != null) {
        if (!UserSessionService.to.canFillDynamicReport(loadedReport.id, loadedReport.categoryId)) {
          Get.snackbar('غير مصرح', 'لا تملك صلاحية تعبئة هذا التقرير');
          Get.back();
          return;
        }
        report.value = loadedReport;
        _initFields(loadedReport);
        await loadDrafts(reportId);
      } else {
        Get.snackbar('خطأ', 'تعذر العثور على التقرير');
        Get.back();
      }
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء جلب التقرير: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadDrafts([int? repId]) async {
    final targetId = repId ?? report.value?.id;
    if (targetId == null) return;
    isLoadingDrafts.value = true;
    try {
      final allRecords = await DynamicReportsApiService.to.getRecords(reportId: targetId);
      drafts.value = allRecords.where((r) => r.approvalStatus == 'Draft').toList();
    } catch (e) {
      debugPrint('Error loading drafts: $e');
    } finally {
      isLoadingDrafts.value = false;
    }
  }

  void startNewReport() {
    isEditMode.value = false;
    existingRecord.value = null;
    fieldValues.clear();
    for (var controller in textControllers.values) {
      controller.clear();
    }
    if (report.value != null) {
      _initFields(report.value!);
    }
    isFormOpen.value = true;
  }

  Future<void> resumeDraft(DynamicReportRecord draft) async {
    if (draft.id == null) return;
    isEditMode.value = true;
    await loadRecordAndReport(draft.id!, draft.reportId);
    isFormOpen.value = true;
  }

  Future<void> deleteDraft(DynamicReportRecord draft) async {
    if (draft.id == null) return;
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد حذف المسودة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('هل أنت متأكد من حذف هذه المسودة المؤرشفة (#${draft.id})؟\nلا يمكن التراجع عن هذا الإجراء.', style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Get.back(result: true),
            child: const Text('حذف', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await DynamicReportsApiService.to.deleteRecord(draft.id!);
        drafts.removeWhere((d) => d.id == draft.id);
        Get.snackbar(
          'تم الحذف',
          'تم حذف المسودة بنجاح.',
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(12),
        );
      } catch (e) {
        Get.snackbar('خطأ', 'حدث خطأ أثناء حذف المسودة: $e');
      }
    }
  }

  Future<void> loadReport(int reportId) async {
    isLoading.value = true;
    try {
      final loadedReport = await DynamicReportsApiService.to.getTemplateDetails(reportId);
      if (loadedReport != null) {
        if (!UserSessionService.to.canFillDynamicReport(loadedReport.id, loadedReport.categoryId)) {
          Get.snackbar('غير مصرح', 'لا تملك صلاحية تعبئة هذا التقرير');
          Get.back();
          return;
        }
        report.value = loadedReport;
        _initFields(loadedReport);
      } else {
        Get.snackbar('خطأ', 'تعذر العثور على التقرير');
        Get.back();
      }
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء جلب التقرير: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadRecordAndReport(int recId, int? repId) async {
    isLoading.value = true;
    try {
      final recordData = await DynamicReportsApiService.to.getRecordDetailsWithValues(recId);
      final rec = recordData?['record'] as DynamicReportRecord?;
      if (rec != null) {
        // يُسمح فقط بتعديل المسودات؛ أي تقرير دخل دورة الاعتماد أو اعتُمد أو رُفض يكون مقفلاً
        if (rec.approvalStatus != 'Draft' && rec.approvalStatus != 'مسودة') {
          isLoading.value = false;
          Get.snackbar(
            'التقرير مقفل للتعديل',
            'لا يمكن تعديل التقرير بعد رفعه لدورة الاعتماد أو إغلاقه.${(rec.rejectionReason ?? '').isNotEmpty ? '\nسبب الرفض: ${rec.rejectionReason}' : ''}'
            '${(rec.correctiveAction ?? '').isNotEmpty ? '\nالإجراء التصحيحي: ${rec.correctiveAction}' : ''}',
            backgroundColor: Colors.redAccent,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 4),
          );
          Get.back();
          return;
        }
        existingRecord.value = rec;
        final targetReportId = repId ?? rec.reportId;
        final loadedReport = await DynamicReportsApiService.to.getTemplateDetails(targetReportId);
        if (loadedReport != null) {
          if (!UserSessionService.to.canFillDynamicReport(loadedReport.id, loadedReport.categoryId)) {
            Get.snackbar('غير مصرح', 'لا تملك صلاحية تعديل هذا التقرير');
            Get.back();
            return;
          }
          report.value = loadedReport;
          _initFields(loadedReport);

          // Load existing values for record
          final loadedValues = recordData!['values'] as List<DynamicReportValue>;
          for (var v in loadedValues) {
            fieldValues[v.fieldId] = v.value;
            if (textControllers.containsKey(v.fieldId)) {
              textControllers[v.fieldId]!.text = v.value ?? '';
            }
          }

          // إعادة اشتقاق الحقول المحسوبة من القيم المُحمَّلة
          _recalculateFields();
        } else {
          Get.snackbar('خطأ', 'تعذر العثور على نموذج التقرير المرتبط');
          Get.back();
        }
      } else {
        Get.snackbar('خطأ', 'تعذر العثور على السجل المطلوب');
        Get.back();
      }
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل السجل: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _initFields(DynamicReport r) {
    if (r.sections == null) return;
    
    for (var section in r.sections!) {
      if (section.fields == null) continue;
      
      for (var field in section.fields!) {
        // تحديد القيمة الافتراضية الذكية إن لم تكن محددة مسبقاً
        String? initialDefault = field.defaultValue;
        if ((initialDefault == null || initialDefault.trim().isEmpty) && field.fieldType != 'instructions') {
          final key = field.fieldKey.toLowerCase();
          final lbl = field.label.toLowerCase();
          if (field.fieldType == 'date' || key.contains('date') || lbl.contains('تاريخ')) {
            initialDefault = DateFormat('yyyy/MM/dd').format(DateTime.now());
          } else if (key.contains('day') || lbl.contains('اليوم')) {
            const arDays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
            final currentDay = arDays[DateTime.now().weekday - 1];
            if (field.options.isNotEmpty) {
              initialDefault = field.options.firstWhere(
                (o) => o == currentDay || o.replaceAll('إ', 'ا') == currentDay.replaceAll('إ', 'ا'),
                orElse: () => currentDay,
              );
            } else {
              initialDefault = currentDay;
            }
          } else if (key.contains('line') || lbl.contains('خط')) {
            initialDefault = 'خط الإنتاج 1';
          } else if (key.contains('shift') || lbl.contains('وردية')) {
            initialDefault = 'الوردية الأولى';
          }
        }

        // Initialize default values
        // ملاحظة: حقل "تعليمات" لا يُحفظ كقيمة (نصه ثابت توجيهي)
        if (initialDefault != null && field.fieldType != 'instructions') {
          fieldValues[field.id!] = initialDefault;
        }

        // Initialize table default rows if not set
        if (field.fieldType == 'table') {
          final cfg = field.tableConfig;
          if (cfg != null && cfg.defaultRows.isNotEmpty) {
            fieldValues[field.id!] = jsonEncode(cfg.defaultRows);
          }
        }

        // Initialize TextControllers for text-based fields
        final normalizedType = field.fieldType.toLowerCase().trim();
        if (['text', 'multiline_text', 'textarea', 'multiline', 'number', 'int', 'integer', 'decimal', 'float', 'double', 'note', 'date'].contains(normalizedType)) {
          textControllers[field.id!] = TextEditingController(text: initialDefault ?? '');
        }
      }
    }

    // حساب الحقول المحسوبة انطلاقاً من القيم الافتراضية
    _recalculateFields();
  }

  /// يعيد حساب كل الحقول المحسوبة بناءً على القيم الحالية.
  ///
  /// يُستدعى عند كل تغيير لأي حقل وعند الحفظ، لأن الحقل المحسوب
  /// يُشتق من غيره ولا يُدخل يدوياً.
  void _recalculateFields() {
    final sections = report.value?.sections;
    if (sections == null) return;

    final valuesByKey = _currentValuesByKey();
    for (var section in sections) {
      final fields = section.fields;
      if (fields == null) continue;
      for (var field in fields) {
        if (field.fieldType != 'calculated' || field.id == null) continue;
        final result = CalculatedFieldHelper.evaluateField(field, valuesByKey);
        if (result != null) {
          fieldValues[field.id!] = result;
        } else {
          fieldValues.remove(field.id);
        }
      }
    }
  }

  /// يجمع القيم الحالية لكل الحقول في خريطة (field_key -> قيمة نصية).
  Map<String, String> _currentValuesByKey() {
    final map = <String, String>{};
    final sections = report.value?.sections;
    if (sections == null) return map;

    for (var section in sections) {
      final fields = section.fields;
      if (fields == null) continue;
      for (var field in fields) {
        final fId = field.id;
        if (fId == null) continue;
        dynamic val = fieldValues[fId];
        if (textControllers.containsKey(fId)) {
          val = textControllers[fId]!.text;
        }
        if (val != null && val.toString().isNotEmpty) {
          map[field.fieldKey] = val.toString();
        }
      }
    }
    return map;
  }

  void updateFieldValue(int fieldId, dynamic value) {
    fieldValues[fieldId] = value;
    // أي إدخال جديد قد تُشتق منه الحقول المحسوبة
    _recalculateFields();
  }

  String get currentInspectorName {
    final existing = existingRecord.value?.createdBy?.trim();
    if (existing != null &&
        existing.isNotEmpty &&
        existing.toLowerCase() != 'current_user' &&
        existing.toLowerCase() != 'current user' &&
        existing.toLowerCase() != 'currentuser') {
      return DynamicReportRecord.sanitizeCreatorName(existing);
    }
    final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
    final userFullName = session?.currentUser.value?.fullName.trim();
    if (userFullName != null && userFullName.isNotEmpty && !userFullName.toLowerCase().contains('current_user')) {
      return DynamicReportRecord.sanitizeCreatorName(userFullName);
    }
    final name = session?.currentUserName.value.trim() ?? '';
    if (name.isEmpty ||
        name.toLowerCase() == 'current_user' ||
        name.toLowerCase() == 'current user' ||
        name.toLowerCase() == 'currentuser') {
      return 'صلاح الجابري (مهندس الجودة)';
    }
    return DynamicReportRecord.sanitizeCreatorName(name);
  }

  /// بناء خريطة data_json من القيم الحالية للحقول
  Map<String, dynamic> _buildDataJsonMap() {
    final Map<String, dynamic> dataJson = {};
    final reportSections = report.value?.sections ?? [];

    for (var section in reportSections) {
      if (section.fields == null) continue;
      for (var field in section.fields!) {
        final fId = field.id!;
        dynamic val = fieldValues[fId];
        if (textControllers.containsKey(fId)) {
          val = textControllers[fId]!.text;
        }
        if (val != null && val.toString().isNotEmpty) {
          dataJson[field.fieldKey] = {
            'field_id': fId,
            'value': val.toString(),
            'label': field.label,
            'field_type': field.fieldType,
            'unit': field.unit,
            'min_value': field.minValue,
            'max_value': field.maxValue,
          };
        }
      }
    }
    return dataJson;
  }

  /// بناء قائمة القيم التقليدية (dr_values) للتوافق العكسي
  List<DynamicReportValue> _buildValuesList() {
    final List<DynamicReportValue> values = [];
    fieldValues.forEach((fieldId, value) {
      if (textControllers.containsKey(fieldId)) {
        value = textControllers[fieldId]!.text;
      }
      if (value != null && value.toString().isNotEmpty) {
        values.add(DynamicReportValue(
          recordId: existingRecord.value?.id ?? 0,
          fieldId: fieldId,
          value: value.toString(),
        ));
      }
    });
    return values;
  }

  Future<void> saveDraft() async {
    isSaving.value = true;
    try {
      final userName = currentInspectorName;

      final currentUser = UserSessionService.to.currentUser.value;
      final int userBranchId = currentUser?.branchId ?? 1;
      final String userBranchName = userBranchId == 2
          ? 'مصنع سنحان'
          : 'مصنع أرتل';
      final activeShift = await FactoryShiftsService.instance.getActiveShiftNow(userBranchId);
      final String activeShiftName = activeShift?.name ?? 'الوردية الأولى';

      final String recordClientUuid = existingRecord.value?.clientUuid ?? _generateClientUuid();

      final record = DynamicReportRecord(
        id: existingRecord.value?.id,
        clientUuid: recordClientUuid,
        reportId: report.value!.id!,
        createdBy: userName,
        createdAt: existingRecord.value?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'Draft',
        approvalStatus: 'Draft',
        branchId: existingRecord.value?.branchId ?? userBranchId,
        branchName: existingRecord.value?.branchName ?? userBranchName,
        shiftName: existingRecord.value?.shiftName ?? activeShiftName,
        rejectionReason: existingRecord.value?.rejectionReason,
        rejectedBy: existingRecord.value?.rejectedBy,
        rejectedAt: existingRecord.value?.rejectedAt,
      );

      // إعادة حساب الحقول المحسوبة قبل بناء البيانات
      _recalculateFields();

      final values = _buildValuesList();
      final dataJsonMap = _buildDataJsonMap();
      
      final recordWithDataJson = DynamicReportRecord(
        id: record.id,
        clientUuid: record.clientUuid,
        reportId: record.reportId,
        createdBy: record.createdBy,
        createdAt: record.createdAt,
        updatedAt: record.updatedAt,
        status: record.status,
        approvalStatus: record.approvalStatus,
        branchId: record.branchId,
        branchName: record.branchName,
        shiftName: record.shiftName,
        rejectionReason: record.rejectionReason,
        rejectedBy: record.rejectedBy,
        rejectedAt: record.rejectedAt,
        dataJson: jsonEncode(dataJsonMap),
      );

      final int? previousLocalId = existingRecord.value?.id;
      final int savedDraftId = await DynamicReportsApiService.to.saveRecord(recordWithDataJson, values);
      final recordToCache = savedDraftId > 0
          ? recordWithDataJson.copyWith(id: savedDraftId)
          : (recordWithDataJson.id != null && recordWithDataJson.id! < 0
              ? recordWithDataJson
              : recordWithDataJson.copyWith(id: -DateTime.now().millisecondsSinceEpoch));
      await DatabaseHelper.instance.saveDynamicReportRecordLocal(
        recordToCache,
        values,
        previousLocalId: previousLocalId,
      );

      await loadDrafts();
      if (!isDirectRecordEntry.value) {
        isFormOpen.value = false;
      } else {
        Get.back(result: true);
      }
      Get.snackbar(
        'تم الحفظ كمسودة',
        'تم حفظ مسودة التقرير بنجاح في الأرشيف. يمكنك استكمال تعبئتها وإرسالها للاعتماد في أي وقت.',
        backgroundColor: const Color(0xFF37474F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        icon: const Icon(Icons.drafts_rounded, color: Colors.amber),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء حفظ المسودة: $e');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> saveRecord({bool isDraft = false}) async {
    if (isDraft) {
      await saveDraft();
      return;
    }

    final form = formKey.currentState;
    if (form == null || !form.validate()) {
      Get.snackbar(
        'تنبيه',
        'يرجى تعبئة جميع الحقول المطلوبة بشكل صحيح قبل الإرسال للاعتماد',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
      return;
    }

    isSaving.value = true;
    try {
      final userName = currentInspectorName;

      final bool requiresApproval = report.value?.approvalType != 'none';
      final bool isThreeLevel = report.value?.approvalType == 'three_level';
        
      String initialApprovalStatus = requiresApproval 
          ? (isThreeLevel ? 'Pending_QS' : 'Pending_QM') 
          : 'Approved';
      String initialStatus = initialApprovalStatus;
      bool isAutoApproved = !requiresApproval;
      String pendingLabel = requiresApproval 
          ? (isThreeLevel ? 'اعتماد مشرف الجودة' : 'اعتماد مدير الجودة') 
          : '';
      int currentStepOrder = 1;

      // Prepare Factory & Shift info
      final currentUser = UserSessionService.to.currentUser.value;
      final int userBranchId = currentUser?.branchId ?? 1;
      final String userBranchName = userBranchId == 2
          ? 'مصنع سنحان'
          : 'مصنع أرتل';
      final activeShift = await FactoryShiftsService.instance.getActiveShiftNow(userBranchId);
      final String activeShiftName = activeShift?.name ?? 'الوردية الأولى';

      final String recordClientUuid = existingRecord.value?.clientUuid ?? _generateClientUuid();

      // Prepare Record
      final record = DynamicReportRecord(
        id: existingRecord.value?.id,
        clientUuid: recordClientUuid,
        reportId: report.value!.id!,
        createdBy: userName,
        createdAt: existingRecord.value?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        status: initialStatus,
        approvalStatus: initialApprovalStatus,
        branchId: existingRecord.value?.branchId ?? userBranchId,
        branchName: existingRecord.value?.branchName ?? userBranchName,
        shiftName: existingRecord.value?.shiftName ?? activeShiftName,
        // Reset rejection history on fresh submission
        rejectionReason: null,
        rejectedBy: null,
        rejectedAt: null,
        currentStepOrder: currentStepOrder,
        pendingLabel: pendingLabel,
      );

      // إعادة حساب الحقول المحسوبة قبل بناء البيانات
      _recalculateFields();

      // Prepare Values + data_json (المحرك الهجين)
      final values = _buildValuesList();
      final dataJsonMap = _buildDataJsonMap();

      final recordWithDataJson = DynamicReportRecord(
        id: record.id,
        clientUuid: record.clientUuid,
        reportId: record.reportId,
        createdBy: record.createdBy,
        createdAt: record.createdAt,
        updatedAt: record.updatedAt,
        status: record.status,
        approvalStatus: record.approvalStatus,
        branchId: record.branchId,
        branchName: record.branchName,
        shiftName: record.shiftName,
        rejectionReason: record.rejectionReason,
        rejectedBy: record.rejectedBy,
        rejectedAt: record.rejectedAt,
        currentStepOrder: record.currentStepOrder,
        pendingLabel: record.pendingLabel,
        dataJson: jsonEncode(dataJsonMap),
      );

      final int? previousLocalId = existingRecord.value?.id;
      int savedId = await DynamicReportsApiService.to.saveRecord(recordWithDataJson, values);
      final bool isQueuedOffline = savedId <= 0;
      final recordToCache = savedId > 0
          ? recordWithDataJson.copyWith(id: savedId)
          : (recordWithDataJson.id != null && recordWithDataJson.id! < 0
              ? recordWithDataJson
              : recordWithDataJson.copyWith(id: -DateTime.now().millisecondsSinceEpoch));
      final localSavedId = await DatabaseHelper.instance.saveDynamicReportRecordLocal(
        recordToCache,
        values,
        previousLocalId: previousLocalId,
      );
      if (savedId <= 0) {
        savedId = localSavedId;
      }

      // تسجيل عملية الاعتماد في سجل التدقيق
      // Note: Auditing is now handled server-side by the SQL Server API.

      if (Get.isRegistered<NotificationService>() && !isAutoApproved && !isQueuedOffline) {
        final actionWord = isEditMode.value ? 'إعادة إرسال' : 'إرسال';
        await NotificationService.to.sendNotification(
          title: 'تقرير ديناميكي بانتظار $pendingLabel',
          body: 'تم $actionWord تقرير (${report.value?.name ?? "جديد"}) سجل (#$savedId) من قِبل ($userName) وهو بانتظار الاعتماد.',
          reportId: savedId,
          reportCategory: 'Dynamic Report',
          targetRole: isThreeLevel ? 'QualitySupervisor' : 'QualityManager',
          branchId: recordWithDataJson.branchId,
        );
      }
      
      if (!isDirectRecordEntry.value) {
        await loadDrafts();
        isFormOpen.value = false;
      } else {
        Get.back(result: true);
      }
      Get.snackbar(
        'نجاح',
        isQueuedOffline
            ? 'تم حفظ التقرير محلياً وسيتم مزامنته تلقائياً عند عودة الاتصال'
            : (!isAutoApproved
                ? 'تم إرسال التقرير بنجاح وهو الآن بانتظار $pendingLabel'
                : 'تم حفظ التقرير واعتماده بنجاح'),
        backgroundColor: isQueuedOffline ? Colors.blue.shade700 : Colors.green.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        icon: Icon(isQueuedOffline ? Icons.cloud_off_rounded : Icons.check_circle_rounded, color: Colors.white),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء الحفظ: $e');
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    for (var controller in textControllers.values) {
      controller.dispose();
    }
    super.onClose();
  }
}

