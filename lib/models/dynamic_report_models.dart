import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class DynamicReportCategory {
  final int? id;
  final String name;
  final String? description;
  final String? icon;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DynamicReportCategory({
    this.id,
    required this.name,
    this.description,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'sort_order': sortOrder,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory DynamicReportCategory.fromMap(Map<String, dynamic> map) {
    return DynamicReportCategory(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      icon: map['icon'],
      sortOrder: map['sort_order'] ?? 0,
      isActive: map['is_active'] == 1 || map['is_active'] == true || map['is_active'] == 'true',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
    );
  }
}


class DynamicReportHeaderConfig {
  final bool showCreator;
  final bool showDate;
  final bool showDay;
  final bool showLine;

  const DynamicReportHeaderConfig({
    this.showCreator = true,
    this.showDate = true,
    this.showDay = true,
    this.showLine = true,
  });

  factory DynamicReportHeaderConfig.fromMap(Map<String, dynamic> map) {
    return DynamicReportHeaderConfig(
      showCreator: map['show_creator'] == true || map['show_creator'] == 1 || (map['show_creator'] == null && map['showCreator'] != false),
      showDate: map['show_date'] == true || map['show_date'] == 1 || (map['show_date'] == null && map['showDate'] != false),
      showDay: map['show_day'] == true || map['show_day'] == 1 || (map['show_day'] == null && map['showDay'] != false),
      showLine: map['show_line'] == true || map['show_line'] == 1 || (map['show_line'] == null && map['showLine'] != false),
    );
  }

  Map<String, dynamic> toMap() => {
    'show_creator': showCreator,
    'show_date': showDate,
    'show_day': showDay,
    'show_line': showLine,
  };

  static DynamicReportHeaderConfig fromJsonString(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return const DynamicReportHeaderConfig();
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return DynamicReportHeaderConfig.fromMap(decoded);
      }
    } catch (_) {}
    return const DynamicReportHeaderConfig();
  }

  String toJsonString() => jsonEncode(toMap());
}

class DynamicReport {
  final int? id;
  final int? categoryId;
  final String name;
  final String? description;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  final String approvalType; // 'none', 'two_level' (للتوافق القديم)
  final String orientation; // 'portrait', 'landscape'
  final String? docNumber; // رقم الوثيقة / كود النموذج (مثال: QA-SOP-01)
  final String? versionNumber; // رقم الإصدار (مثال: 01)
  final String? issueDate; // تاريخ الإصدار (مثال: 2026/07/15)
  final String? headerConfigJson; // إعدادات شريط المعلومات العلوي
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Relation
  List<DynamicReportSection>? sections;

  DynamicReport({
    this.id,
    this.categoryId,
    required this.name,
    this.description,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,

    this.approvalType = 'two_level',
    this.orientation = 'portrait',
    this.docNumber,
    this.versionNumber,
    this.issueDate,
    this.headerConfigJson,
    this.createdAt,
    this.updatedAt,
    this.sections,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'icon': icon,
      'sort_order': sortOrder,
      'is_active': isActive ? 1 : 0,

      'approval_type': approvalType,
      'orientation': orientation,
      'doc_number': docNumber,
      'version_number': versionNumber,
      'issue_date': issueDate,
      'header_config_json': headerConfigJson,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory DynamicReport.fromMap(Map<String, dynamic> map) {
    return DynamicReport(
      id: map['id'],
      categoryId: map['category_id'] ?? map['categoryId'],
      name: map['name'] ?? '',
      description: map['description'],
      icon: map['icon'] ?? map['icon_name'],
      sortOrder: map['sort_order'] ?? map['sortOrder'] ?? 0,
      isActive: map['is_active'] == 1 || map['is_active'] == true || map['is_active'] == 'true' || map['isActive'] == 1 || map['isActive'] == true,

      approvalType: map['approval_type'] ?? map['approvalType'] ?? 'two_level',
      orientation: map['orientation'] ?? 'portrait',
      docNumber: map['doc_number'] ?? map['docNumber'] ?? map['code'],
      versionNumber: map['version_number'] ?? map['versionNumber'] ?? map['issue_number'],
      issueDate: map['issue_date'] ?? map['issueDate'] ?? map['version_date'],
      headerConfigJson: map['header_config_json'] ?? map['headerConfigJson'],
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  DynamicReport copyWith({
    int? id,
    int? categoryId,
    String? name,
    String? description,
    String? icon,
    int? sortOrder,
    bool? isActive,

    String? approvalType,
    String? orientation,
    String? docNumber,
    String? versionNumber,
    String? issueDate,
    String? headerConfigJson,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<DynamicReportSection>? sections,
  }) {
    return DynamicReport(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,

      approvalType: approvalType ?? this.approvalType,
      orientation: orientation ?? this.orientation,
      docNumber: docNumber ?? this.docNumber,
      versionNumber: versionNumber ?? this.versionNumber,
      issueDate: issueDate ?? this.issueDate,
      headerConfigJson: headerConfigJson ?? this.headerConfigJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sections: sections ?? this.sections,
    );
  }

  /// Helper to convert icon key to IconData
  static IconData getIconData(String? iconKey) {
    if (iconKey == null || iconKey.isEmpty) return Icons.description_outlined;
    final key = iconKey.contains('|') ? iconKey.split('|').first.trim() : iconKey.trim();
    switch (key) {
      case 'water_drop':
      case 'water':
        return Icons.water_drop_outlined;
      case 'science':
      case 'lab':
        return Icons.science_outlined;
      case 'verified':
      case 'quality':
        return Icons.verified_outlined;
      case 'fact_check':
      case 'checklist':
        return Icons.fact_check_outlined;
      case 'assignment':
      case 'task':
        return Icons.assignment_outlined;
      case 'inventory_2':
      case 'inventory':
        return Icons.inventory_2_outlined;
      case 'clean_hands':
      case 'sanitizer':
      case 'hygiene':
        return Icons.clean_hands_outlined;
      case 'health_and_safety':
      case 'shield':
        return Icons.health_and_safety_outlined;
      case 'precision_manufacturing':
      case 'factory':
        return Icons.precision_manufacturing_outlined;
      case 'biotech':
        return Icons.biotech_outlined;
      case 'filter_alt':
      case 'filter':
        return Icons.filter_alt_outlined;
      case 'table_chart':
        return Icons.table_chart_outlined;
      case 'rule':
        return Icons.rule_outlined;
      case 'assessment':
        return Icons.assessment_outlined;
      case 'description':
      default:
        return Icons.description_outlined;
    }
  }

  IconData get iconData => getIconData(icon);
  DynamicReportHeaderConfig get headerConfig => DynamicReportHeaderConfig.fromJsonString(headerConfigJson);
}

class DynamicReportSection {
  final int? id;
  final int reportId;
  final String title;
  final String? description;
  final int sortOrder;
  final bool isCollapsible;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Relation
  List<DynamicReportField>? fields;

  DynamicReportSection({
    this.id,
    required this.reportId,
    required this.title,
    this.description,
    this.sortOrder = 0,
    this.isCollapsible = true,
    this.createdAt,
    this.updatedAt,
    this.fields,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'report_id': reportId,
      'title': title,
      'description': description,
      'sort_order': sortOrder,
      'is_collapsible': isCollapsible ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  DynamicReportSection copyWith({
    int? id,
    int? reportId,
    String? title,
    String? description,
    int? sortOrder,
    bool? isCollapsible,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<DynamicReportField>? fields,
  }) {
    return DynamicReportSection(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      title: title ?? this.title,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      isCollapsible: isCollapsible ?? this.isCollapsible,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fields: fields ?? this.fields,
    );
  }

  factory DynamicReportSection.fromMap(Map<String, dynamic> map) {
    return DynamicReportSection(
      id: map['id'],
      reportId: map['report_id'] ?? map['reportId'] ?? 0,
      title: map['title'] ?? '',
      description: map['description'],
      sortOrder: map['sort_order'] ?? map['sortOrder'] ?? 0,
      isCollapsible: map['is_collapsible'] == 1 || map['is_collapsible'] == true || map['is_collapsible'] == 'true' || map['isCollapsible'] == 1 || map['isCollapsible'] == true,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }
}

class DynamicReportField {
  final int? id;
  final int reportId;
  final int sectionId;
  final String fieldKey;
  final String label;
  final String? hint;
  final String fieldType;
  final bool isRequired;
  final int sortOrder;
  final String? defaultValue;
  final String? optionsJson; // For Dropdowns, Radios, etc. Example: ["Op1", "Op2"]
  final String? validationJson; // Example: {"min": 1, "max": 10}
  final double? minValue;
  final double? maxValue;
  final String? unit;
  final bool isVisible;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DynamicReportField({
    this.id,
    required this.reportId,
    required this.sectionId,
    required this.fieldKey,
    required this.label,
    this.hint,
    required this.fieldType,
    this.isRequired = false,
    this.sortOrder = 0,
    this.defaultValue,
    this.optionsJson,
    this.validationJson,
    this.minValue,
    this.maxValue,
    this.unit,
    this.isVisible = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'report_id': reportId,
      'section_id': sectionId,
      'field_key': fieldKey,
      'label': label,
      'hint': hint,
      'field_type': fieldType,
      'is_required': isRequired ? 1 : 0,
      'sort_order': sortOrder,
      'default_value': defaultValue,
      'options_json': optionsJson,
      'validation_json': validationJson,
      'min_value': minValue,
      'max_value': maxValue,
      'unit': unit,
      'is_visible': isVisible ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  DynamicReportField copyWith({
    int? id,
    int? reportId,
    int? sectionId,
    String? fieldKey,
    String? label,
    String? hint,
    String? fieldType,
    bool? isRequired,
    int? sortOrder,
    String? defaultValue,
    String? optionsJson,
    String? validationJson,
    double? minValue,
    double? maxValue,
    String? unit,
    bool? isVisible,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DynamicReportField(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      sectionId: sectionId ?? this.sectionId,
      fieldKey: fieldKey ?? this.fieldKey,
      label: label ?? this.label,
      hint: hint ?? this.hint,
      fieldType: fieldType ?? this.fieldType,
      isRequired: isRequired ?? this.isRequired,
      sortOrder: sortOrder ?? this.sortOrder,
      defaultValue: defaultValue ?? this.defaultValue,
      optionsJson: optionsJson ?? this.optionsJson,
      validationJson: validationJson ?? this.validationJson,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      unit: unit ?? this.unit,
      isVisible: isVisible ?? this.isVisible,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory DynamicReportField.fromMap(Map<String, dynamic> map) {
    return DynamicReportField(
      id: map['id'],
      reportId: map['report_id'] ?? map['reportId'] ?? 0,
      sectionId: map['section_id'] ?? map['sectionId'] ?? 0,
      fieldKey: map['field_key'] ?? map['fieldKey'] ?? '',
      label: map['label'] ?? '',
      hint: map['hint'],
      fieldType: map['field_type'] ?? map['fieldType'] ?? 'Text',
      isRequired: map['is_required'] == 1 || map['is_required'] == true || map['is_required'] == 'true' || map['isRequired'] == 1 || map['isRequired'] == true,
      sortOrder: map['sort_order'] ?? map['sortOrder'] ?? 0,
      defaultValue: map['default_value'] ?? map['defaultValue'],
      optionsJson: map['options_json'] ?? map['optionsJson'],
      validationJson: map['validation_json'] ?? map['validationJson'],
      minValue: map['min_value'] != null ? (map['min_value'] as num).toDouble() : (map['minValue'] != null ? (map['minValue'] as num).toDouble() : null),
      maxValue: map['max_value'] != null ? (map['max_value'] as num).toDouble() : (map['maxValue'] != null ? (map['maxValue'] as num).toDouble() : null),
      unit: map['unit'],
      isVisible: map['is_visible'] == 1 || map['is_visible'] == true || map['is_visible'] == 'true' || map['isVisible'] == 1 || map['isVisible'] == true,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  List<String> get options {
    if (optionsJson == null || optionsJson!.isEmpty) return [];
    try {
      final decoded = jsonDecode(optionsJson!);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  /// لون خلفية عنوان الحقل (البند) بصيغة Hex (مثل #BDD7EE)
  String? get headerBgColor {
    if (validationJson != null && validationJson!.isNotEmpty) {
      try {
        final d = jsonDecode(validationJson!);
        if (d is Map && d['header_bg_color'] != null) {
          final s = d['header_bg_color'].toString().trim();
          if (s.isNotEmpty) return s;
        }
      } catch (_) {}
    }
    return null;
  }

  /// لون خلفية محتوى الحقل (التفاصيل) بصيغة Hex (مثل #FFFFFF)
  String? get valueBgColor {
    if (validationJson != null && validationJson!.isNotEmpty) {
      try {
        final d = jsonDecode(validationJson!);
        if (d is Map && d['value_bg_color'] != null) {
          final s = d['value_bg_color'].toString().trim();
          if (s.isNotEmpty) return s;
        }
      } catch (_) {}
    }
    return null;
  }

  /// لون رأس الحقل كـ Flutter Color
  Color? get headerColor {
    final hex = headerBgColor;
    if (hex == null || hex.isEmpty) return null;
    var c = hex.replaceAll('#', '').trim();
    if (c.length == 6) c = 'FF$c';
    final val = int.tryParse(c, radix: 16);
    return val != null ? Color(val) : null;
  }

  /// لون تفاصيل الحقل كـ Flutter Color
  Color? get valueColor {
    final hex = valueBgColor;
    if (hex == null || hex.isEmpty) return null;
    var c = hex.replaceAll('#', '').trim();
    if (c.length == 6) c = 'FF$c';
    final val = int.tryParse(c, radix: 16);
    return val != null ? Color(val) : null;
  }

  /// يحوّل نص الخيارات إلى قائمة.
  /// الفاصل الأساسي هو السطر الجديد (يدعم الخيارات التي تحتوي فاصلة).
  /// لأسباب التوافق مع البيانات القديمة: إذا كان السطر مفرداً ويحوي فاصلة
  /// نعتمدها كفاصل.
  static List<String> parseOptionsText(String? text) {
    if (text == null) return [];
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length == 1 && lines.first.contains(',')) {
      return lines.first
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return lines;
  }

  /// يحوّل قائمة الخيارات إلى نص قابل للتعديل (سطر لكل خيار).
  static String optionsToText(List<String> options) {
    return options.join('\n');
  }

  DynamicTableConfig? get tableConfig {
    if (fieldType != 'table') return null;
    return DynamicTableConfig.fromJsonString(optionsJson);
  }
}

class DynamicTableColumn {
  final String key;
  final String title;
  final String type; // 'label', 'text', 'number', 'decimal', 'date', 'time', 'radio', 'checkbox'
  final List<String> options; // for radio/select
  final double widthRatio;

  DynamicTableColumn({
    required this.key,
    required this.title,
    this.type = 'text',
    this.options = const [],
    this.widthRatio = 1.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'title': title,
      'type': type,
      'options': options,
      'widthRatio': widthRatio,
    };
  }

  factory DynamicTableColumn.fromMap(Map<String, dynamic> map) {
    return DynamicTableColumn(
      key: map['key'] ?? '',
      title: map['title'] ?? '',
      type: map['type'] ?? 'text',
      options: (map['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
      widthRatio: (map['widthRatio'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class DynamicTableConfig {
  final List<DynamicTableColumn> columns;
  final List<Map<String, dynamic>> defaultRows;
  final bool allowAddRows;
  final bool isLandscape;
  final int rowCount;

  DynamicTableConfig({
    required this.columns,
    this.defaultRows = const [],
    this.allowAddRows = true,
    this.isLandscape = false,
    this.rowCount = 10,
  });

  Map<String, dynamic> toMap() {
    return {
      'columns': columns.map((c) => c.toMap()).toList(),
      'defaultRows': defaultRows,
      'allowAddRows': allowAddRows,
      'isLandscape': isLandscape,
      'rowCount': rowCount,
    };
  }

  factory DynamicTableConfig.fromMap(Map<String, dynamic> map) {
    return DynamicTableConfig(
      columns: (map['columns'] as List?)
              ?.map((c) => DynamicTableColumn.fromMap(c is Map<String, dynamic> ? c : Map<String, dynamic>.from(c)))
              .toList() ??
          [],
      defaultRows: (map['defaultRows'] as List?)
              ?.map((r) => r is Map<String, dynamic> ? r : Map<String, dynamic>.from(r))
              .toList() ??
          [],
      allowAddRows: map['allowAddRows'] == true,
      isLandscape: map['isLandscape'] == true,
      rowCount: (map['rowCount'] as num?)?.toInt() ?? 10,
    );
  }

  String toJsonString() => jsonEncode(toMap());

  static DynamicTableConfig? fromJsonString(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return DynamicTableConfig.fromMap(decoded);
      }
    } catch (_) {}
    return null;
  }

  /// قالب الفحص والمطابقة الرسمي
  static DynamicTableConfig inspectionChecklistTemplate() {
    return DynamicTableConfig(
      isLandscape: false,
      columns: [
        DynamicTableColumn(key: 'item', title: 'بند الفحص', type: 'label', widthRatio: 2.5),
        DynamicTableColumn(key: 'criteria', title: 'معيار القبول', type: 'label', widthRatio: 2.0),
        DynamicTableColumn(key: 'result', title: 'النتيجة', type: 'text', widthRatio: 1.5),
        DynamicTableColumn(key: 'status', title: 'المطابقة', type: 'match', options: ['مطابق', 'غير مطابق'], widthRatio: 2.0),
        DynamicTableColumn(key: 'notes', title: 'الملاحظات', type: 'text', widthRatio: 2.0),
      ],
      defaultRows: [
        {'item': 'مطابقة المادة لأمر الشراء', 'criteria': 'مطابق', 'status': 'مطابق'},
        {'item': 'سلامة العبوات', 'criteria': 'سليمه', 'status': 'مطابق'},
        {'item': 'نظافة المادة', 'criteria': 'نظيفة', 'status': 'مطابق'},
        {'item': 'عدم وجود تلف', 'criteria': 'لا يتجاوز التالف 2%', 'status': 'مطابق'},
        {'item': 'بطاقة التعريف', 'criteria': 'مكتملة', 'status': 'مطابق'},
        {'item': 'رقم التشغيلة', 'criteria': 'مسجل', 'status': 'مطابق'},
        {'item': 'تاريخ الإنتاج', 'criteria': 'ضمن الحد المسموح', 'status': 'مطابق'},
        {'item': 'تاريخ الانتهاء', 'criteria': 'ضمن الحد المسموح', 'status': 'مطابق'},
        {'item': 'شهادة المطابقة (COC)', 'criteria': 'متواجدة', 'status': 'مطابق'},
        {'item': 'نتائج التحاليل (إن وجدت)', 'criteria': 'متواجدة', 'status': 'مطابق'},
      ],
      allowAddRows: true,
      rowCount: 10,
    );
  }

  /// قالب مراقبة تركيز الأوزون - نقطة التحكم الحرجة 1 (24 ساعة)
  static DynamicTableConfig ccpOzoneTemplate() {
    final List<Map<String, String>> shiftsHours = [
      {'shift': 'الوردية الأولى', 'time': '08:00'},
      {'shift': 'الوردية الأولى', 'time': '09:00'},
      {'shift': 'الوردية الأولى', 'time': '10:00'},
      {'shift': 'الوردية الأولى', 'time': '11:00'},
      {'shift': 'الوردية الأولى', 'time': '12:00'},
      {'shift': 'الوردية الأولى', 'time': '01:00'},
      {'shift': 'الوردية الأولى', 'time': '02:00'},
      {'shift': 'الوردية الأولى', 'time': '03:00'},
      {'shift': 'الوردية الثانية', 'time': '04:00'},
      {'shift': 'الوردية الثانية', 'time': '05:00'},
      {'shift': 'الوردية الثانية', 'time': '06:00'},
      {'shift': 'الوردية الثانية', 'time': '07:00'},
      {'shift': 'الوردية الثانية', 'time': '08:00'},
      {'shift': 'الوردية الثانية', 'time': '09:00'},
      {'shift': 'الوردية الثانية', 'time': '10:00'},
      {'shift': 'الوردية الثانية', 'time': '11:00'},
      {'shift': 'الوردية الثالثة', 'time': '12:00'},
      {'shift': 'الوردية الثالثة', 'time': '01:00'},
      {'shift': 'الوردية الثالثة', 'time': '02:00'},
      {'shift': 'الوردية الثالثة', 'time': '03:00'},
      {'shift': 'الوردية الثالثة', 'time': '04:00'},
      {'shift': 'الوردية الثالثة', 'time': '05:00'},
      {'shift': 'الوردية الثالثة', 'time': '06:00'},
      {'shift': 'الوردية الثالثة', 'time': '07:00'},
    ];

    return DynamicTableConfig(
      isLandscape: true,
      rowCount: 24,
      allowAddRows: true,
      columns: [
        DynamicTableColumn(key: 'shift', title: 'الوردية', type: 'label', widthRatio: 1.2),
        DynamicTableColumn(key: 'time', title: 'الوقت', type: 'label', widthRatio: 0.9),
        DynamicTableColumn(key: 'ozone_conc', title: 'تركيز الأوزون (0.10 - 0.30 ملغم/لتر)', type: 'decimal', widthRatio: 1.5),
        DynamicTableColumn(key: 'status', title: 'المطابقة', type: 'match', options: ['مطابق', 'غير مطابق'], widthRatio: 1.2),
        DynamicTableColumn(key: 'corrective_action', title: 'الإجراء التصحيحي في حال الانحراف', type: 'text', widthRatio: 2.2),
        DynamicTableColumn(key: 'inspector', title: 'المسؤول عن المراقبة', type: 'inspector', widthRatio: 1.4),
        DynamicTableColumn(key: 'signature', title: 'التوقيع', type: 'signature', widthRatio: 1.2),
      ],
      defaultRows: shiftsHours.map((sh) => {
        'shift': sh['shift'],
        'time': sh['time'],
        'ozone_conc': '',
        'status': '',
        'corrective_action': '',
        'inspector': '',
        'signature': '',
      }).toList(),
    );
  }

  /// قالب مراقبة سلامة الأغطية وعزم الفتح والتسريب - نقطة التحكم الحرجة 2 (24 ساعة)
  static DynamicTableConfig ccpCappingTemplate() {
    final List<Map<String, String>> shiftsHours = [
      {'shift': 'الوردية الأولى', 'time': '08:00'},
      {'shift': 'الوردية الأولى', 'time': '09:00'},
      {'shift': 'الوردية الأولى', 'time': '10:00'},
      {'shift': 'الوردية الأولى', 'time': '11:00'},
      {'shift': 'الوردية الأولى', 'time': '12:00'},
      {'shift': 'الوردية الأولى', 'time': '01:00'},
      {'shift': 'الوردية الأولى', 'time': '02:00'},
      {'shift': 'الوردية الأولى', 'time': '03:00'},
      {'shift': 'الوردية الثانية', 'time': '04:00'},
      {'shift': 'الوردية الثانية', 'time': '05:00'},
      {'shift': 'الوردية الثانية', 'time': '06:00'},
      {'shift': 'الوردية الثانية', 'time': '07:00'},
      {'shift': 'الوردية الثانية', 'time': '08:00'},
      {'shift': 'الوردية الثانية', 'time': '09:00'},
      {'shift': 'الوردية الثانية', 'time': '10:00'},
      {'shift': 'الوردية الثانية', 'time': '11:00'},
      {'shift': 'الوردية الثالثة', 'time': '12:00'},
      {'shift': 'الوردية الثالثة', 'time': '01:00'},
      {'shift': 'الوردية الثالثة', 'time': '02:00'},
      {'shift': 'الوردية الثالثة', 'time': '03:00'},
      {'shift': 'الوردية الثالثة', 'time': '04:00'},
      {'shift': 'الوردية الثالثة', 'time': '05:00'},
      {'shift': 'الوردية الثالثة', 'time': '06:00'},
      {'shift': 'الوردية الثالثة', 'time': '07:00'},
    ];

    return DynamicTableConfig(
      isLandscape: true,
      rowCount: 24,
      allowAddRows: true,
      columns: [
        DynamicTableColumn(key: 'shift', title: 'الوردية', type: 'label', widthRatio: 1.1),
        DynamicTableColumn(key: 'time', title: 'الوقت', type: 'label', widthRatio: 0.9),
        DynamicTableColumn(key: 'visual_check', title: 'الفحص البصري للغطاء', type: 'match', options: ['مطابق', 'غير مطابق'], widthRatio: 1.1),
        DynamicTableColumn(key: 'torque', title: 'عزم الفتح (lbf.in)', type: 'decimal', widthRatio: 1.2),
        DynamicTableColumn(key: 'leak_test', title: 'فحص التسريب تحت الضغط', type: 'match', options: ['مطابق', 'غير مطابق'], widthRatio: 1.2),
        DynamicTableColumn(key: 'status', title: 'المطابقة', type: 'match', options: ['مطابق', 'غير مطابق'], widthRatio: 1.1),
        DynamicTableColumn(key: 'corrective_action', title: 'الإجراء التصحيحي في حال الانحراف', type: 'text', widthRatio: 2.0),
        DynamicTableColumn(key: 'inspector', title: 'المسؤول عن المراقبة', type: 'inspector', widthRatio: 1.3),
        DynamicTableColumn(key: 'signature', title: 'التوقيع', type: 'signature', widthRatio: 1.1),
      ],
      defaultRows: shiftsHours.map((sh) => {
        'shift': sh['shift'],
        'time': sh['time'],
        'visual_check': '',
        'torque': '',
        'leak_test': '',
        'status': '',
        'corrective_action': '',
        'inspector': '',
        'signature': '',
      }).toList(),
    );
  }

  /// قالب عام للمراقبة الدورية على مدار 24 ساعة (3 ورديات)
  static DynamicTableConfig daily24HourShiftTemplate() {
    final List<Map<String, String>> shiftsHours = [
      {'shift': 'الوردية الأولى', 'time': '08:00'},
      {'shift': 'الوردية الأولى', 'time': '09:00'},
      {'shift': 'الوردية الأولى', 'time': '10:00'},
      {'shift': 'الوردية الأولى', 'time': '11:00'},
      {'shift': 'الوردية الأولى', 'time': '12:00'},
      {'shift': 'الوردية الأولى', 'time': '01:00'},
      {'shift': 'الوردية الأولى', 'time': '02:00'},
      {'shift': 'الوردية الأولى', 'time': '03:00'},
      {'shift': 'الوردية الثانية', 'time': '04:00'},
      {'shift': 'الوردية الثانية', 'time': '05:00'},
      {'shift': 'الوردية الثانية', 'time': '06:00'},
      {'shift': 'الوردية الثانية', 'time': '07:00'},
      {'shift': 'الوردية الثانية', 'time': '08:00'},
      {'shift': 'الوردية الثانية', 'time': '09:00'},
      {'shift': 'الوردية الثانية', 'time': '10:00'},
      {'shift': 'الوردية الثانية', 'time': '11:00'},
      {'shift': 'الوردية الثالثة', 'time': '12:00'},
      {'shift': 'الوردية الثالثة', 'time': '01:00'},
      {'shift': 'الوردية الثالثة', 'time': '02:00'},
      {'shift': 'الوردية الثالثة', 'time': '03:00'},
      {'shift': 'الوردية الثالثة', 'time': '04:00'},
      {'shift': 'الوردية الثالثة', 'time': '05:00'},
      {'shift': 'الوردية الثالثة', 'time': '06:00'},
      {'shift': 'الوردية الثالثة', 'time': '07:00'},
    ];

    return DynamicTableConfig(
      isLandscape: true,
      rowCount: 24,
      allowAddRows: true,
      columns: [
        DynamicTableColumn(key: 'shift', title: 'الوردية', type: 'label', widthRatio: 1.2),
        DynamicTableColumn(key: 'time', title: 'الوقت', type: 'label', widthRatio: 0.9),
        DynamicTableColumn(key: 'reading_val', title: 'القراءة / القيمة', type: 'decimal', widthRatio: 1.4),
        DynamicTableColumn(key: 'status', title: 'المطابقة', type: 'match', options: ['مطابق', 'غير مطابق'], widthRatio: 1.2),
        DynamicTableColumn(key: 'corrective_action', title: 'الإجراء التصحيحي', type: 'text', widthRatio: 2.2),
        DynamicTableColumn(key: 'inspector', title: 'المسؤول عن المراقبة', type: 'inspector', widthRatio: 1.4),
        DynamicTableColumn(key: 'signature', title: 'التوقيع', type: 'signature', widthRatio: 1.2),
      ],
      defaultRows: shiftsHours.map((sh) => {
        'shift': sh['shift'],
        'time': sh['time'],
        'reading_val': '',
        'status': '',
        'corrective_action': '',
        'inspector': '',
        'signature': '',
      }).toList(),
    );
  }

  /// قالب قائمة التفتيش على النظافة الشخصية (مطابق للمستند الرسمي)
  static DynamicTableConfig hygieneInspectionTemplate() {
    return DynamicTableConfig(
      isLandscape: true,
      rowCount: 15,
      allowAddRows: true,
      columns: [
        DynamicTableColumn(key: 'employee', title: 'اسم الموظف', type: 'text', widthRatio: 2.2),
        DynamicTableColumn(key: 'work_clothes', title: 'ارتداء ملابس العمل', type: 'yes_no', options: ['نعم', 'لا'], widthRatio: 1.1),
        DynamicTableColumn(key: 'clean_clothes', title: 'الملابس نظيفة وفي صورة جيدة', type: 'yes_no', options: ['نعم', 'لا'], widthRatio: 1.2),
        DynamicTableColumn(key: 'head_cover', title: 'تغطية الشعر والشارب بغطاء الرأس والكمامة', type: 'yes_no', options: ['نعم', 'لا'], widthRatio: 1.3),
        DynamicTableColumn(key: 'shoe_protection', title: 'ارتداء حماية الحذاء', type: 'yes_no', options: ['نعم', 'لا'], widthRatio: 1.1),
        DynamicTableColumn(key: 'clean_nails', title: 'الأظافر مقصوصة ونظيفة', type: 'yes_no', options: ['نعم', 'لا'], widthRatio: 1.1),
        DynamicTableColumn(key: 'good_health', title: 'الصحة جيدة (لا يوجد أي أمراض)', type: 'yes_no', options: ['نعم', 'لا'], widthRatio: 1.2),
        DynamicTableColumn(key: 'no_accessories', title: 'لا يرتدي أي اكسسوارات', type: 'yes_no', options: ['نعم', 'لا'], widthRatio: 1.1),
        DynamicTableColumn(key: 'no_bad_smell', title: 'لا توجد رائحة كريهة من الجسم', type: 'yes_no', options: ['نعم', 'لا'], widthRatio: 1.2),
        DynamicTableColumn(key: 'no_perfume', title: 'لا توجد روائح عطرية شديدة', type: 'yes_no', options: ['نعم', 'لا'], widthRatio: 1.1),
        DynamicTableColumn(key: 'corrective_action', title: 'إذا أجبت بـ لا ما التصرف الذي قمت به لتصحيح الوضع', type: 'text', widthRatio: 2.8),
      ],
      defaultRows: List.generate(15, (index) => {
        'work_clothes': 'نعم',
        'clean_clothes': 'نعم',
        'head_cover': 'نعم',
        'shoe_protection': 'نعم',
        'clean_nails': 'نعم',
        'good_health': 'نعم',
        'no_accessories': 'نعم',
        'no_bad_smell': 'نعم',
        'no_perfume': 'نعم',
      }),
    );
  }
}

class DynamicReportRecord {
  final int? id;
  final int reportId;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? status;
  final String approvalStatus; // 'Draft', 'Pending_QM', 'Pending_GM', 'Approved', 'Rejected'
  final int? currentStepOrder; // ترتيب الخطوة الحالية المنتظرة في المسار المرن
  final String? pendingLabel; // وصف نصي للخطوة المنتظرة (مثال: "بانتظار مدير الجودة")
  final String? qsApprovedBy;
  final DateTime? qsApprovedAt;
  final String? qmApprovedBy;
  final DateTime? qmApprovedAt;
  final String? gmApprovedBy;
  final DateTime? gmApprovedAt;
  final String? rejectionReason;
  final String? rejectedBy;
  final DateTime? rejectedAt;

  // ─── دورة الرفض والإجراء التصحيحي ───
  final String? rejectionCategory;
  final String? severityLevel;
  final String? rejectionNotes;
  final String? affectedProducts;
  final String? immediateAction;
  final String? correctiveAction;
  final String? correctiveOwner;
  final DateTime? correctiveDueDate;
  final String? gmDecision; // Approved / Rejected
  final String? gmDecisionBy;
  final DateTime? gmDecisionAt;
  final String? gmDecisionNotes;
  final int rejectionCount;

  final int? branchId;
  final String? branchName;
  final String? shiftName;

  // ─── Enterprise Fields (v8) ───
  final int? reportVersionId;
  final int? departmentId;
  final int? positionId;
  final int? productId;
  final DateTime? samplingDatetime;
  final bool? isCompliant;
  final int? currentStepId;
  final String? currentStepName;
  final String? summaryNotes;
  final String? dataJson; // المحرك الهجين: حقل JSON لحفظ كل بيانات التقرير
  final String? clientUuid; // معرّف فريد للتقرير من جهة العميل لمنع التكرار (Idempotency)

  String get effectiveBranchName => branchName != null && branchName!.isNotEmpty
      ? branchName!
      : (branchId == 2 ? 'مصنع سنحان' : 'مصنع أرتل');

  /// تحويل data_json إلى Map
  Map<String, dynamic>? get dataMap {
    if (dataJson == null || dataJson!.isEmpty) return null;
    try {
      return jsonDecode(dataJson!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// استخراج قيمة حقل معين من data_json
  String? getFieldValue(String fieldKey) {
    final map = dataMap;
    if (map == null) return null;
    final fieldData = map[fieldKey];
    if (fieldData is Map) {
      return fieldData['value']?.toString();
    }
    return fieldData?.toString();
  }

  DynamicReportRecord({
    this.id,
    required this.reportId,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.status,
    this.approvalStatus = 'Pending_QM',
    this.currentStepOrder,
    this.pendingLabel,
    this.qsApprovedBy,
    this.qsApprovedAt,
    this.qmApprovedBy,
    this.qmApprovedAt,
    this.gmApprovedBy,
    this.gmApprovedAt,
    this.rejectionReason,
    this.rejectedBy,
    this.rejectedAt,
    this.rejectionCategory,
    this.severityLevel,
    this.rejectionNotes,
    this.affectedProducts,
    this.immediateAction,
    this.correctiveAction,
    this.correctiveOwner,
    this.correctiveDueDate,
    this.gmDecision,
    this.gmDecisionBy,
    this.gmDecisionAt,
    this.gmDecisionNotes,
    this.rejectionCount = 0,
    this.branchId,
    this.branchName,
    this.shiftName,
    // Enterprise
    this.reportVersionId,
    this.departmentId,
    this.positionId,
    this.productId,
    this.samplingDatetime,
    this.isCompliant,
    this.currentStepId,
    this.currentStepName,
    this.summaryNotes,
    this.dataJson,
    this.clientUuid,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'report_id': reportId,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'status': status,
      'approval_status': approvalStatus,
      'current_step_order': currentStepOrder,
      'pending_label': pendingLabel,
      'qs_approved_by': qsApprovedBy,
      'qs_approved_at': qsApprovedAt?.toIso8601String(),
      'qm_approved_by': qmApprovedBy,
      'qm_approved_at': qmApprovedAt?.toIso8601String(),
      'gm_approved_by': gmApprovedBy,
      'gm_approved_at': gmApprovedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'rejected_by': rejectedBy,
      'rejected_at': rejectedAt?.toIso8601String(),
      'rejection_category': rejectionCategory,
      'severity_level': severityLevel,
      'rejection_notes': rejectionNotes,
      'affected_products': affectedProducts,
      'immediate_action': immediateAction,
      'corrective_action': correctiveAction,
      'corrective_owner': correctiveOwner,
      'corrective_due_date': correctiveDueDate?.toIso8601String(),
      'gm_decision': gmDecision,
      'gm_decision_by': gmDecisionBy,
      'gm_decision_at': gmDecisionAt?.toIso8601String(),
      'gm_decision_notes': gmDecisionNotes,
      'rejection_count': rejectionCount,
      'branch_id': branchId,
      'branch_name': branchName,
      'shift_name': shiftName,
      // Enterprise
      'report_version_id': reportVersionId,
      'department_id': departmentId,
      'position_id': positionId,
      'product_id': productId,
      'sampling_datetime': samplingDatetime?.toIso8601String(),
      'is_compliant': isCompliant == null ? null : (isCompliant! ? 1 : 0),
      'current_step_id': currentStepId,
      'current_step_name': currentStepName,
      'summary_notes': summaryNotes,
      'data_json': dataJson,
      'client_uuid': clientUuid,
    };
  }

  static String sanitizeCreatorName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'صلاح الجابري (مهندس الجودة)';
    final clean = raw.trim();
    final lower = clean.toLowerCase();
    if (lower == 'current_user' || lower == 'current user' || lower == 'currentuser' || lower == 'user' || lower == 'null') {
      return 'صلاح الجابري (مهندس الجودة)';
    }
    const usernameMap = {
      'basheer_fs': 'م. بشير القدسي',
      'salah': 'م. صلاح الجابري',
      'osama': 'م. أسامة الشجاع',
      'mohammed_r': 'م. محمد الرجامي',
      'amjad_fs': 'م. أمجد الخدشي',
      'ali': 'علي محمد',
      'sam': 'د/سام',
      'mohm': 'محمد احمد',
      'qm': 'أ. حمود يسر',
      'nabil': 'نبيل مراد',
      'gm2': 'أ. محمد الحاج',
      'gm': 'د. خالد العمري',
      'gmanager': 'أ. مازن الجلال',
      'admin': 'مسؤول النظام (المدير التقني)',
    };
    if (usernameMap.containsKey(lower)) {
      return usernameMap[lower]!;
    }
    return clean;
  }

  factory DynamicReportRecord.fromMap(Map<String, dynamic> map) {
    final rawIsCompliant = map['is_compliant'] ?? map['isCompliant'];
    return DynamicReportRecord(
      id: map['id'],
      reportId: map['report_id'] ?? map['reportId'],
      createdBy: sanitizeCreatorName((map['created_by'] ?? map['createdBy'])?.toString()),
      createdAt: (map['created_at'] ?? map['createdAt']) != null ? DateTime.tryParse((map['created_at'] ?? map['createdAt']).toString()) : null,
      updatedAt: (map['updated_at'] ?? map['updatedAt']) != null ? DateTime.tryParse((map['updated_at'] ?? map['updatedAt']).toString()) : null,
      status: map['status']?.toString(),
      approvalStatus: (map['approval_status'] ?? map['approvalStatus'])?.toString() ?? (map['status'] == 'مكتمل' ? 'Approved' : 'Pending_QM'),
      currentStepOrder: map['current_step_order'] ?? map['currentStepOrder'],
      pendingLabel: (map['pending_label'] ?? map['pendingLabel'])?.toString(),
      qsApprovedBy: (map['qs_approved_by'] ?? map['qsApprovedBy'])?.toString(),
      qsApprovedAt: (map['qs_approved_at'] ?? map['qsApprovedAt']) != null ? DateTime.tryParse((map['qs_approved_at'] ?? map['qsApprovedAt']).toString()) : null,
      qmApprovedBy: (map['qm_approved_by'] ?? map['qmApprovedBy'])?.toString(),
      qmApprovedAt: (map['qm_approved_at'] ?? map['qmApprovedAt']) != null ? DateTime.tryParse((map['qm_approved_at'] ?? map['qmApprovedAt']).toString()) : null,
      gmApprovedBy: (map['gm_approved_by'] ?? map['gmApprovedBy'])?.toString(),
      gmApprovedAt: (map['gm_approved_at'] ?? map['gmApprovedAt']) != null ? DateTime.tryParse((map['gm_approved_at'] ?? map['gmApprovedAt']).toString()) : null,
      rejectionReason: (map['rejection_reason'] ?? map['rejectionReason'])?.toString(),
      rejectedBy: (map['rejected_by'] ?? map['rejectedBy'])?.toString(),
      rejectedAt: (map['rejected_at'] ?? map['rejectedAt']) != null ? DateTime.tryParse((map['rejected_at'] ?? map['rejectedAt']).toString()) : null,
      rejectionCategory: (map['rejection_category'] ?? map['rejectionCategory'])?.toString(),
      severityLevel: (map['severity_level'] ?? map['severityLevel'])?.toString(),
      rejectionNotes: (map['rejection_notes'] ?? map['rejectionNotes'])?.toString(),
      affectedProducts: (map['affected_products'] ?? map['affectedProducts'])?.toString(),
      immediateAction: (map['immediate_action'] ?? map['immediateAction'])?.toString(),
      correctiveAction: (map['corrective_action'] ?? map['correctiveAction'])?.toString(),
      correctiveOwner: (map['corrective_owner'] ?? map['correctiveOwner'])?.toString(),
      correctiveDueDate: (map['corrective_due_date'] ?? map['correctiveDueDate']) != null
          ? DateTime.tryParse((map['corrective_due_date'] ?? map['correctiveDueDate']).toString())
          : null,
      gmDecision: (map['gm_decision'] ?? map['gmDecision'])?.toString(),
      gmDecisionBy: (map['gm_decision_by'] ?? map['gmDecisionBy'])?.toString(),
      gmDecisionAt: (map['gm_decision_at'] ?? map['gmDecisionAt']) != null
          ? DateTime.tryParse((map['gm_decision_at'] ?? map['gmDecisionAt']).toString())
          : null,
      gmDecisionNotes: (map['gm_decision_notes'] ?? map['gmDecisionNotes'])?.toString(),
      rejectionCount: (map['rejection_count'] ?? map['rejectionCount']) is int
          ? (map['rejection_count'] ?? map['rejectionCount']) as int
          : int.tryParse((map['rejection_count'] ?? map['rejectionCount'] ?? '0').toString()) ?? 0,
      branchId: map['branch_id'] ?? map['branchId'],
      branchName: (map['branch_name'] ?? map['branchName'])?.toString(),
      shiftName: (map['shift_name'] ?? map['shiftName'])?.toString(),
      // Enterprise
      reportVersionId: map['report_version_id'] ?? map['reportVersionId'],
      departmentId: map['department_id'] ?? map['departmentId'],
      positionId: map['position_id'] ?? map['positionId'],
      productId: map['product_id'] ?? map['productId'],
      samplingDatetime: (map['sampling_datetime'] ?? map['samplingDatetime']) != null ? DateTime.tryParse((map['sampling_datetime'] ?? map['samplingDatetime']).toString()) : null,
      isCompliant: rawIsCompliant != null ? (rawIsCompliant == 1 || rawIsCompliant == true || rawIsCompliant == '1' || rawIsCompliant == 'true') : null,
      currentStepId: map['current_step_id'] ?? map['currentStepId'],
      currentStepName: (map['current_step_name'] ?? map['currentStepName'])?.toString(),
      summaryNotes: (map['summary_notes'] ?? map['summaryNotes'])?.toString(),
      dataJson: (map['data_json'] ?? map['dataJson'])?.toString(),
      clientUuid: (map['client_uuid'] ?? map['clientUuid'])?.toString(),
    );
  }

  DynamicReportRecord copyWith({
    int? id,
    int? reportId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? approvalStatus,
    int? currentStepOrder,
    String? pendingLabel,
    String? qsApprovedBy,
    DateTime? qsApprovedAt,
    String? qmApprovedBy,
    DateTime? qmApprovedAt,
    String? gmApprovedBy,
    DateTime? gmApprovedAt,
    String? rejectionReason,
    String? rejectedBy,
    DateTime? rejectedAt,
    String? rejectionCategory,
    String? severityLevel,
    String? rejectionNotes,
    String? affectedProducts,
    String? immediateAction,
    String? correctiveAction,
    String? correctiveOwner,
    DateTime? correctiveDueDate,
    String? gmDecision,
    String? gmDecisionBy,
    DateTime? gmDecisionAt,
    String? gmDecisionNotes,
    int? rejectionCount,
    int? branchId,
    String? branchName,
    String? shiftName,
    // Enterprise
    int? reportVersionId,
    int? departmentId,
    int? positionId,
    int? productId,
    DateTime? samplingDatetime,
    bool? isCompliant,
    int? currentStepId,
    String? currentStepName,
    String? summaryNotes,
    String? dataJson,
    String? clientUuid,
  }) {
    return DynamicReportRecord(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      currentStepOrder: currentStepOrder ?? this.currentStepOrder,
      pendingLabel: pendingLabel ?? this.pendingLabel,
      qsApprovedBy: qsApprovedBy ?? this.qsApprovedBy,
      qsApprovedAt: qsApprovedAt ?? this.qsApprovedAt,
      qmApprovedBy: qmApprovedBy ?? this.qmApprovedBy,
      qmApprovedAt: qmApprovedAt ?? this.qmApprovedAt,
      gmApprovedBy: gmApprovedBy ?? this.gmApprovedBy,
      gmApprovedAt: gmApprovedAt ?? this.gmApprovedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectionCategory: rejectionCategory ?? this.rejectionCategory,
      severityLevel: severityLevel ?? this.severityLevel,
      rejectionNotes: rejectionNotes ?? this.rejectionNotes,
      affectedProducts: affectedProducts ?? this.affectedProducts,
      immediateAction: immediateAction ?? this.immediateAction,
      correctiveAction: correctiveAction ?? this.correctiveAction,
      correctiveOwner: correctiveOwner ?? this.correctiveOwner,
      correctiveDueDate: correctiveDueDate ?? this.correctiveDueDate,
      gmDecision: gmDecision ?? this.gmDecision,
      gmDecisionBy: gmDecisionBy ?? this.gmDecisionBy,
      gmDecisionAt: gmDecisionAt ?? this.gmDecisionAt,
      gmDecisionNotes: gmDecisionNotes ?? this.gmDecisionNotes,
      rejectionCount: rejectionCount ?? this.rejectionCount,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      shiftName: shiftName ?? this.shiftName,
      // Enterprise
      reportVersionId: reportVersionId ?? this.reportVersionId,
      departmentId: departmentId ?? this.departmentId,
      positionId: positionId ?? this.positionId,
      productId: productId ?? this.productId,
      samplingDatetime: samplingDatetime ?? this.samplingDatetime,
      isCompliant: isCompliant ?? this.isCompliant,
      currentStepId: currentStepId ?? this.currentStepId,
      currentStepName: currentStepName ?? this.currentStepName,
      summaryNotes: summaryNotes ?? this.summaryNotes,
      dataJson: dataJson ?? this.dataJson,
      clientUuid: clientUuid ?? this.clientUuid,
    );
  }
}

class DynamicReportValue {
  final int? id;
  final int recordId;
  final int fieldId;
  final String? value;

  DynamicReportValue({
    this.id,
    required this.recordId,
    required this.fieldId,
    this.value,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'record_id': recordId,
      'field_id': fieldId,
      'value': value,
    };
  }

  factory DynamicReportValue.fromMap(Map<String, dynamic> map) {
    return DynamicReportValue(
      id: map['id'],
      recordId: map['record_id'],
      fieldId: map['field_id'],
      value: map['value']?.toString(), // Handle both string and numerical DB returns
    );
  }
}

// =====================================
// النماذج المؤسسية (Enterprise Models v8)
// =====================================

/// نموذج القسم الإداري
class Department {
  final int? id;
  final String name;
  final String? code;
  final String? description;
  final int? parentId;
  final int? branchId;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Department({
    this.id,
    required this.name,
    this.code,
    this.description,
    this.parentId,
    this.branchId,
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'code': code,
    'description': description,
    'parent_id': parentId,
    'branch_id': branchId,
    'is_active': isActive ? 1 : 0,
    'sort_order': sortOrder,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory Department.fromMap(Map<String, dynamic> map) => Department(
    id: map['id'],
    name: map['name'] ?? '',
    code: map['code'],
    description: map['description'],
    parentId: map['parent_id'],
    branchId: map['branch_id'],
    isActive: map['is_active'] == 1 || map['is_active'] == true || map['is_active'] == 'true',
    sortOrder: map['sort_order'] ?? 0,
    createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
    updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
  );
}

/// نموذج المنصب الوظيفي
class Position {
  final int? id;
  final String name;
  final String? code;
  final int? departmentId;
  final int level;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Position({
    this.id,
    required this.name,
    this.code,
    this.departmentId,
    this.level = 0,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'code': code,
    'department_id': departmentId,
    'level': level,
    'description': description,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory Position.fromMap(Map<String, dynamic> map) => Position(
    id: map['id'],
    name: map['name'] ?? '',
    code: map['code'],
    departmentId: map['department_id'],
    level: map['level'] ?? 0,
    description: map['description'],
    isActive: map['is_active'] == 1 || map['is_active'] == true || map['is_active'] == 'true',
    createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
    updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
  );
}



/// نموذج إصدار التقرير
class DynamicReportVersion {
  final int? id;
  final int reportId;
  final int versionNumber;
  final String? versionLabel;
  final String? schemaSnapshotJson;
  final DateTime? publishedAt;
  final String? publishedBy;
  final String? changeNotes;
  final bool isCurrent;
  final DateTime? createdAt;

  DynamicReportVersion({
    this.id,
    required this.reportId,
    this.versionNumber = 1,
    this.versionLabel,
    this.schemaSnapshotJson,
    this.publishedAt,
    this.publishedBy,
    this.changeNotes,
    this.isCurrent = true,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'report_id': reportId,
    'version_number': versionNumber,
    'version_label': versionLabel,
    'schema_snapshot_json': schemaSnapshotJson,
    'published_at': publishedAt?.toIso8601String(),
    'published_by': publishedBy,
    'change_notes': changeNotes,
    'is_current': isCurrent ? 1 : 0,
    'created_at': createdAt?.toIso8601String(),
  };

  factory DynamicReportVersion.fromMap(Map<String, dynamic> map) => DynamicReportVersion(
    id: map['id'],
    reportId: map['report_id'] ?? 0,
    versionNumber: map['version_number'] ?? 1,
    versionLabel: map['version_label'],
    schemaSnapshotJson: map['schema_snapshot_json'],
    publishedAt: map['published_at'] != null ? DateTime.tryParse(map['published_at']) : null,
    publishedBy: map['published_by'],
    changeNotes: map['change_notes'],
    isCurrent: map['is_current'] == 1 || map['is_current'] == true || map['is_current'] == 'true',
    createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
  );
}

/// نموذج سجل الاعتماد
class ReportApproval {
  final int? id;
  final int recordId;
  final int? stepId;
  final String? stepName;
  final String action;
  final String? actedBy;
  final int? actedByUserId;
  final String? actionByPosition;
  final DateTime? actedAt;
  final String? comments;
  final String? previousStatus;
  final String? newStatus;

  // ─── حقول التوقيع المرئي المجمد لحظة الاعتماد ───
  final dynamic signatureSnapshotBlob;
  final String? signatureSnapshotPath;
  final String? signatureHash;
  final String? signatureType;
  final String? documentHash;

  ReportApproval({
    this.id,
    required this.recordId,
    this.stepId,
    this.stepName,
    required this.action,
    this.actedBy,
    this.actedByUserId,
    this.actionByPosition,
    this.actedAt,
    this.comments,
    this.previousStatus,
    this.newStatus,
    this.signatureSnapshotBlob,
    this.signatureSnapshotPath,
    this.signatureHash,
    this.signatureType = 'drawn_png',
    this.documentHash,
  });

  /// استخراج بايتات صورة التوقيع الشفافة
  Uint8List? get signatureBytes {
    if (signatureSnapshotBlob == null) return null;
    if (signatureSnapshotBlob is Uint8List) return signatureSnapshotBlob as Uint8List;
    if (signatureSnapshotBlob is List<int>) return Uint8List.fromList(signatureSnapshotBlob as List<int>);
    if (signatureSnapshotBlob is String) {
      try {
        final str = signatureSnapshotBlob as String;
        final clean = str.contains(',') ? str.split(',').last : str;
        return base64Decode(clean);
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'record_id': recordId,
    'step_id': stepId,
    'step_name': stepName,
    'action': action,
    'acted_by': actedBy,
    'acted_by_user_id': actedByUserId,
    'action_by_position': actionByPosition,
    'acted_at': actedAt?.toIso8601String(),
    'comments': comments,
    'previous_status': previousStatus,
    'new_status': newStatus,
    'signature_snapshot_blob': signatureSnapshotBlob,
    'signature_snapshot_path': signatureSnapshotPath,
    'signature_hash': signatureHash,
    'signature_type': signatureType,
    'document_hash': documentHash,
  };

  factory ReportApproval.fromMap(Map<String, dynamic> map) => ReportApproval(
    id: map['id'],
    recordId: map['record_id'] ?? 0,
    stepId: map['step_id'],
    stepName: map['step_name'],
    action: map['action'] ?? '',
    actedBy: map['acted_by'],
    actedByUserId: map['acted_by_user_id'],
    actionByPosition: map['action_by_position'],
    actedAt: map['acted_at'] != null ? DateTime.tryParse(map['acted_at']) : null,
    comments: map['comments'],
    previousStatus: map['previous_status'],
    newStatus: map['new_status'],
    signatureSnapshotBlob: map['signature_snapshot_blob'],
    signatureSnapshotPath: map['signature_snapshot_path'],
    signatureHash: map['signature_hash'],
    signatureType: map['signature_type'] ?? 'drawn_png',
    documentHash: map['document_hash'],
  );
}

/// نموذج توقيع المستخدم المعتمد في حسابه
class UserSignature {
  final int? id;
  final int userId;
  final String signatureType; // 'drawn_png', 'uploaded_image'
  final String signatureData; // Base64 string
  final String signatureHash; // SHA-256
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserSignature({
    this.id,
    required this.userId,
    this.signatureType = 'drawn_png',
    required this.signatureData,
    required this.signatureHash,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Uint8List? get bytes {
    try {
      final clean = signatureData.contains(',') ? signatureData.split(',').last : signatureData;
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'signature_type': signatureType,
    'signature_data': signatureData,
    'signature_hash': signatureHash,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory UserSignature.fromMap(Map<String, dynamic> map) => UserSignature(
    id: map['id'],
    userId: map['user_id'] ?? 0,
    signatureType: map['signature_type'] ?? 'drawn_png',
    signatureData: map['signature_data'] ?? '',
    signatureHash: map['signature_hash'] ?? '',
    isActive: map['is_active'] == 1 || map['is_active'] == true || map['is_active'] == 'true',
    createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
    updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
  );
}

/// نموذج سجل التدقيق
class AuditLog {
  final int? id;
  final String entityType;
  final int entityId;
  final String action;
  final int? userId;
  final String? userName;
  final String? oldValueJson;
  final String? newValueJson;
  final String? ipAddress;
  final String? deviceInfo;
  final DateTime? createdAt;

  AuditLog({
    this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.userId,
    this.userName,
    this.oldValueJson,
    this.newValueJson,
    this.ipAddress,
    this.deviceInfo,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'entity_type': entityType,
    'entity_id': entityId,
    'action': action,
    'user_id': userId,
    'user_name': userName,
    'old_value_json': oldValueJson,
    'new_value_json': newValueJson,
    'ip_address': ipAddress,
    'device_info': deviceInfo,
    'created_at': createdAt?.toIso8601String(),
  };

  factory AuditLog.fromMap(Map<String, dynamic> map) => AuditLog(
    id: map['id'],
    entityType: map['entity_type'] ?? '',
    entityId: map['entity_id'] ?? 0,
    action: map['action'] ?? '',
    userId: map['user_id'],
    userName: map['user_name'],
    oldValueJson: map['old_value_json'],
    newValueJson: map['new_value_json'],
    ipAddress: map['ip_address'],
    deviceInfo: map['device_info'],
    createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
  );
}

