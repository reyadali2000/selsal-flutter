import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/dynamic_report_models.dart';
import '../services/api/dynamic_reports_api_service.dart';


class DynamicReportBuilderController extends GetxController {
  final formKey = GlobalKey<FormState>();
  
  var isLoading = false.obs;
  var reportId = RxnInt();
  var categoryId = RxnInt();
  
  final nameController = TextEditingController();
  final descController = TextEditingController();
  final docNumberController = TextEditingController();
  final versionNumberController = TextEditingController(text: '01');
  final issueDateController = TextEditingController(
    text: DateFormat('yyyy/MM/dd').format(DateTime.now()),
  );
  
  var sections = <DynamicReportSection>[].obs;
  var fields = <DynamicReportField>[].obs;
  var categories = <DynamicReportCategory>[].obs;
  var approvalType = 'two_level'.obs;

  var selectedIcon = 'description'.obs;
  var orientation = 'portrait'.obs;

  var showHeaderCreator = true.obs;
  var showHeaderDate = true.obs;
  var showHeaderDay = true.obs;
  var showHeaderLine = true.obs;

  int _fieldKeyCounter = 0;

  /// يولّد مفتاحاً فريداً للحقل باستخدام طابع زمني + عدّاد متزايد
  /// لتفادي تصادم المفاتيح عند إنشاء عدة حقول في نفس المللي ثانية.
  String generateFieldKey() {
    return 'field_${DateTime.now().millisecondsSinceEpoch}_${_fieldKeyCounter++}';
  }

  @override
  void onInit() {
    super.onInit();
    _loadCategories();

    
    // Check if we are editing
    if (Get.arguments != null) {
      if (Get.arguments is int) {
        _loadReport(Get.arguments as int);
      } else if (Get.arguments is Map && (Get.arguments as Map)['reportId'] != null) {
        _loadReport((Get.arguments as Map)['reportId'] as int);
      } else if (Get.arguments is DynamicReport && (Get.arguments as DynamicReport).id != null) {
        _loadReport((Get.arguments as DynamicReport).id!);
      }
    }
  }

  Future<void> _loadCategories() async {
    categories.value = await DynamicReportsApiService.to.getCategories();
    if (categories.isNotEmpty && categoryId.value == null) {
      categoryId.value = categories.first.id;
    }
  }



  Future<void> _loadReport(int id) async {
    isLoading.value = true;
    try {
      final report = await DynamicReportsApiService.to.getTemplateDetails(id);
      if (report != null) {
        reportId.value = report.id;
        categoryId.value = report.categoryId;
        nameController.text = report.name;
        descController.text = report.description ?? '';
        docNumberController.text = report.docNumber ?? '';
        versionNumberController.text = report.versionNumber ?? '01';
        issueDateController.text = report.issueDate ?? DateFormat('yyyy/MM/dd').format(DateTime.now());
        approvalType.value = report.approvalType;

        final cfg = report.headerConfig;
        showHeaderCreator.value = cfg.showCreator;
        showHeaderDate.value = cfg.showDate;
        showHeaderDay.value = cfg.showDay;
        showHeaderLine.value = cfg.showLine;

        selectedIcon.value = report.icon ?? 'description';
        orientation.value = report.orientation;
        if (report.orientation == 'portrait' &&
            (report.sections?.any((s) => s.fields?.any((f) => f.fieldType == 'table' && f.tableConfig?.isLandscape == true) ?? false) ?? false)) {
          orientation.value = 'landscape';
        }
        
        sections.value = report.sections ?? [];
        
        List<DynamicReportField> allFields = [];
        for (var s in sections) {
          if (s.fields != null) {
            allFields.addAll(s.fields!);
          }
        }
        fields.value = allFields;
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// إضافة قسم "بيانات التشغيل" القياسية بحقوله المجهزة تلقائياً (تاريخ، يوم، خط، وردية)
  void addOperatingInfoSection() {
    final repId = reportId.value ?? 0;

    // 1. إنشاء القسم
    int sectionTempId = -DateTime.now().millisecondsSinceEpoch;
    final section = DynamicReportSection(
      id: sectionTempId,
      reportId: repId,
      title: 'بيانات التشغيل',
      description: 'المعلومات التشغيلية الخاصة بتاريخ الفحص والخط والوردية',
      isCollapsible: false,
      sortOrder: 0,
    );
    
    // إزاحة الأقسام الأخرى في الترتيب
    for (int i = 0; i < sections.length; i++) {
      sections[i] = sections[i].copyWith(sortOrder: i + 1);
    }
    sections.insert(0, section);
    sections.refresh();

    // 2. إضافة الحقول الأساسية
    final dateField = DynamicReportField(
      reportId: repId,
      sectionId: sectionTempId,
      fieldKey: 'report_date',
      label: 'تاريخ التقرير',
      fieldType: 'date',
      isRequired: true,
      hint: 'اختر تاريخ التقرير',
      sortOrder: 0,
    );

    final dayField = DynamicReportField(
      reportId: repId,
      sectionId: sectionTempId,
      fieldKey: 'day_name',
      label: 'اليوم',
      fieldType: 'dropdown',
      isRequired: true,
      hint: 'اختر يوم الفحص',
      optionsJson: jsonEncode(['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة']),
      sortOrder: 1,
    );

    final lineField = DynamicReportField(
      reportId: repId,
      sectionId: sectionTempId,
      fieldKey: 'line_number',
      label: 'رقم خط الإنتاج',
      fieldType: 'dropdown',
      isRequired: true,
      hint: 'اختر خط الإنتاج',
      optionsJson: jsonEncode(['خط الإنتاج 1', 'خط الإنتاج 2', 'خط الإنتاج 3', 'خط الإنتاج 4', 'خط الإنتاج 5']),
      sortOrder: 2,
    );

    final shiftField = DynamicReportField(
      reportId: repId,
      sectionId: sectionTempId,
      fieldKey: 'shift',
      label: 'الوردية',
      fieldType: 'dropdown',
      isRequired: false,
      hint: 'اختر الوردية',
      optionsJson: jsonEncode(['الوردية الأولى', 'الوردية الثانية', 'الوردية الثالثة']),
      sortOrder: 3,
    );

    fields.addAll([dateField, dayField, lineField, shiftField]);
    fields.refresh();

    Get.snackbar(
      'تمت الإضافة',
      'تمت إضافة قسم "بيانات التشغيل" مع حقول: التاريخ، اليوم، رقم الخط، الوردية',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.shade700,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
    );
  }

  void addSection(String title, {String? description, bool isCollapsible = true}) {
    // Generate a unique temporary negative ID so it never collides
    int tempId = -DateTime.now().millisecondsSinceEpoch;
    sections.add(DynamicReportSection(
      id: tempId,
      reportId: reportId.value ?? 0,
      title: title,
      description: (description == null || description.trim().isEmpty) ? null : description.trim(),
      isCollapsible: isCollapsible,
      sortOrder: sections.length,
    ));
    sections.refresh();
  }

  void updateSection(int sectionId, {required String title, String? description, required bool isCollapsible}) {
    final index = sections.indexWhere((s) => s.id == sectionId);
    if (index != -1) {
      sections[index] = sections[index].copyWith(
        title: title,
        description: (description == null || description.trim().isEmpty) ? null : description.trim(),
        isCollapsible: isCollapsible,
      );
      sections.refresh();
    }
  }

  void deleteSection(int sectionId) {
    sections.removeWhere((s) => s.id == sectionId);
    fields.removeWhere((f) => f.sectionId == sectionId);
    // Update sort order
    for (int i = 0; i < sections.length; i++) {
      sections[i] = sections[i].copyWith(sortOrder: i);
    }
    sections.refresh();
  }

  void reorderSection(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final section = sections.removeAt(oldIndex);
    sections.insert(newIndex, section);
    // Update sortOrder for all
    for (int i = 0; i < sections.length; i++) {
      sections[i] = sections[i].copyWith(sortOrder: i);
    }
    sections.refresh();
  }

  void addField(DynamicReportField field) {
    fields.add(field);
    fields.refresh();
  }

  void updateField(DynamicReportField updatedField) {
    // المطابقة بـ fieldKey (الفريد دائماً) وليس id،
    // لأن الحقول الجديدة غير المحفوظة بعد يكون id فيها null.
    final index = fields.indexWhere((f) => f.fieldKey == updatedField.fieldKey);
    if (index != -1) {
      fields[index] = updatedField;
      fields.refresh();
    }
  }

  void reorderFields(int sectionId, int oldIndex, int newIndex) {
    final sectionFields = fields.where((f) => f.sectionId == sectionId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final field = sectionFields.removeAt(oldIndex);
    sectionFields.insert(newIndex, field);

    for (int i = 0; i < sectionFields.length; i++) {
      final f = sectionFields[i];
      final idx = fields.indexOf(f);
      if (idx != -1) {
        fields[idx] = f.copyWith(sortOrder: i);
      }
    }
    fields.refresh();
  }

  void deleteField(DynamicReportField field) {
    fields.remove(field);
    fields.refresh();
  }

  List<DynamicReportField> getFieldsForSection(int sectionId) {
    return fields.where((f) => f.sectionId == sectionId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<void> saveReport() async {
    if (!formKey.currentState!.validate()) return;
    if (sections.isEmpty) {
      Get.snackbar('خطأ', 'يجب إضافة قسم واحد على الأقل');
      return;
    }

    isLoading.value = true;
    try {
      // تسوية الاتجاه: إذا كان التقرير طولياً ويحوي جدولاً عرضياً نحوّله لعرضي
      if (orientation.value == 'portrait') {
        final hasLandscapeTable = fields.any(
          (f) => f.fieldType == 'table' && f.tableConfig?.isLandscape == true,
        );
        if (hasLandscapeTable) {
          orientation.value = 'landscape';
        }
      }

      final headerConfig = DynamicReportHeaderConfig(
        showCreator: showHeaderCreator.value,
        showDate: showHeaderDate.value,
        showDay: showHeaderDay.value,
        showLine: showHeaderLine.value,
      );

      final report = DynamicReport(
        id: reportId.value,
        categoryId: categoryId.value,
        name: nameController.text.trim(),
        description: descController.text.trim(),
        docNumber: docNumberController.text.trim().isEmpty ? null : docNumberController.text.trim(),
        versionNumber: versionNumberController.text.trim().isEmpty ? '01' : versionNumberController.text.trim(),
        issueDate: issueDateController.text.trim().isEmpty ? DateFormat('yyyy/MM/dd').format(DateTime.now()) : issueDateController.text.trim(),
        headerConfigJson: headerConfig.toJsonString(),
        icon: selectedIcon.value,
        orientation: orientation.value,
        isActive: true,

        approvalType: approvalType.value,
        createdAt: reportId.value == null ? DateTime.now() : null,
        updatedAt: DateTime.now(),
      );

      await DynamicReportsApiService.to.saveOrUpdateTemplate(
        report,
        sections.toList(),
        fields.toList(),
      );

      Get.back(result: true);
      Get.snackbar('نجاح', 'تم حفظ التقرير بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء الحفظ: $e');
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    descController.dispose();
    docNumberController.dispose();
    versionNumberController.dispose();
    issueDateController.dispose();
    super.onClose();
  }
}


