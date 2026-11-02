import 'package:flutter/material.dart';

enum RawMaterialCategoryType {
  petBottles,      // الملحق A: الأمبولات البلاستيكية
  caps,            // الملحق B: الأغطية
  labelsAndRolls,  // الملحق C: الملصقات والروالت
  packaging,       // الملحق D: الكراتين ومواد التغليف
  chemicals,       // الملحق E: المواد الكيميائية
  secondaryPackaging, // الملحق F: مواد التعبئة الثانوية (الشرينك واللاصق)
}

class RawMaterialCategoryInfo {
  final RawMaterialCategoryType type;
  final String key;
  final String title;
  final String subtitle;
  final String annexCode;
  final String annexTitle;
  final IconData icon;
  final Color color;
  final List<ChecklistCriteria> criteria;

  const RawMaterialCategoryInfo({
    required this.type,
    required this.key,
    required this.title,
    required this.subtitle,
    required this.annexCode,
    required this.annexTitle,
    required this.icon,
    required this.color,
    required this.criteria,
  });

  static const List<RawMaterialCategoryInfo> allCategories = [
    RawMaterialCategoryInfo(
      type: RawMaterialCategoryType.petBottles,
      key: 'pet_bottles',
      title: 'أمبولات بلاستيكية (PET)',
      subtitle: 'فحص مقاسات ونقاء وأوزان أمبولات التشكيل',
      annexCode: 'SELSAL-IMSF-19-03A',
      annexTitle: 'الملحق (A): قائمة فحص الأمبولات البلاستيكية (PET Bottles Inspection Checklist)',
      icon: Icons.local_drink_outlined,
      color: Color(0xFF0288D1),
      criteria: [
        ChecklistCriteria(id: 1, name: 'مطابقة المقاس والسعة', acceptanceCriteria: 'حسب المواصفة المعتمدة'),
        ChecklistCriteria(id: 2, name: 'اللون', acceptanceCriteria: 'مطابق'),
        ChecklistCriteria(id: 3, name: 'الشفافية', acceptanceCriteria: 'خالية من العكارة'),
        ChecklistCriteria(id: 4, name: 'خلوها من التشققات', acceptanceCriteria: 'لا يوجد'),
        ChecklistCriteria(id: 5, name: 'خلوها من الانبعاجات', acceptanceCriteria: 'لا يوجد'),
        ChecklistCriteria(id: 6, name: 'انتظام السمك', acceptanceCriteria: 'مطابق'),
        ChecklistCriteria(id: 7, name: 'النظافة', acceptanceCriteria: 'نظيفة وخالية من الأتربة'),
        ChecklistCriteria(id: 8, name: 'خلوها من الأجسام الغريبة', acceptanceCriteria: 'لا يوجد'),
        ChecklistCriteria(id: 9, name: 'مطابقة الوزن (عند الحاجة)', acceptanceCriteria: 'ضمن الحدود'),
        ChecklistCriteria(id: 10, name: 'شهادة المطابقة (إن وجدت)', acceptanceCriteria: 'متوفرة'),
      ],
    ),
    RawMaterialCategoryInfo(
      type: RawMaterialCategoryType.caps,
      key: 'caps',
      title: 'أغطية القوارير (Caps)',
      subtitle: 'فحص المقاس، سالمة الحلقة، النظافة والخامة',
      annexCode: 'SELSAL-IMSF-19-03B',
      annexTitle: 'الملحق (B): قائمة فحص الأغطية (Caps Inspection Checklist)',
      icon: Icons.radio_button_checked,
      color: Color(0xFF00897B),
      criteria: [
        ChecklistCriteria(id: 1, name: 'اللون', acceptanceCriteria: 'مطابق'),
        ChecklistCriteria(id: 2, name: 'المقاس', acceptanceCriteria: 'مطابق'),
        ChecklistCriteria(id: 3, name: 'سلامة الشكل', acceptanceCriteria: 'بدون تشوه'),
        ChecklistCriteria(id: 4, name: 'سلامة الحلقة الأمنية', acceptanceCriteria: 'سليمة'),
        ChecklistCriteria(id: 5, name: 'خلوها من الكسور', acceptanceCriteria: 'لا يوجد'),
        ChecklistCriteria(id: 6, name: 'نظافة الأغطية', acceptanceCriteria: 'نظيفة'),
        ChecklistCriteria(id: 7, name: 'خلوها من الأجسام الغريبة', acceptanceCriteria: 'لا يوجد'),
        ChecklistCriteria(id: 8, name: 'مطابقة الخامة', acceptanceCriteria: 'حسب المواصفة'),
        ChecklistCriteria(id: 9, name: 'شهادة المطابقة (إن وجدت)', acceptanceCriteria: 'متوفرة'),
      ],
    ),
    RawMaterialCategoryInfo(
      type: RawMaterialCategoryType.labelsAndRolls,
      key: 'labels_and_rolls',
      title: 'ملصقات وروالت (Labels)',
      subtitle: 'فحص دقة الطباعة والألوان والباركود والالتصاق',
      annexCode: 'SELSAL-IMSF-19-03C',
      annexTitle: 'الملحق (C): قائمة فحص الملصقات والروالت (Labels & Rolls Inspection Checklist)',
      icon: Icons.label_outline_rounded,
      color: Color(0xFFFB8C00),
      criteria: [
        ChecklistCriteria(id: 1, name: 'التصميم المعتمد', acceptanceCriteria: 'مطابق'),
        ChecklistCriteria(id: 2, name: 'الأبعاد', acceptanceCriteria: 'مطابقة'),
        ChecklistCriteria(id: 3, name: 'جودة الطباعة', acceptanceCriteria: 'واضحة'),
        ChecklistCriteria(id: 4, name: 'الألوان', acceptanceCriteria: 'مطابقة'),
        ChecklistCriteria(id: 5, name: 'الباركود', acceptanceCriteria: 'واضح'),
        ChecklistCriteria(id: 6, name: 'بيانات المنتج', acceptanceCriteria: 'صحيحة'),
        ChecklistCriteria(id: 7, name: 'خلو الرول من التلف', acceptanceCriteria: 'سليم'),
        ChecklistCriteria(id: 8, name: 'جودة الالتصاق (عند الحاجة)', acceptanceCriteria: 'مطابقة'),
      ],
    ),
    RawMaterialCategoryInfo(
      type: RawMaterialCategoryType.packaging,
      key: 'packaging_boxes',
      title: 'كراتين ومواد التغليف',
      subtitle: 'فحص متانة الكرتون، الطباعة، الرطوبة والروائح',
      annexCode: 'SELSAL-IMSF-19-03D',
      annexTitle: 'الملحق (D): قائمة فحص الكراتين ومواد التغليف (Packaging Materials Inspection Checklist)',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF6D4C41),
      criteria: [
        ChecklistCriteria(id: 1, name: 'المقاس', acceptanceCriteria: 'مطابق'),
        ChecklistCriteria(id: 2, name: 'جودة الطباعة', acceptanceCriteria: 'واضحة'),
        ChecklistCriteria(id: 3, name: 'اللون', acceptanceCriteria: 'مطابق'),
        ChecklistCriteria(id: 4, name: 'سلامة الكرتون', acceptanceCriteria: 'بدون تمزق'),
        ChecklistCriteria(id: 5, name: 'قوة التحمل', acceptanceCriteria: 'مناسبة'),
        ChecklistCriteria(id: 6, name: 'نظافة المادة', acceptanceCriteria: 'نظيفة'),
        ChecklistCriteria(id: 7, name: 'خلو المادة من الرطوبة', acceptanceCriteria: 'نعم'),
        ChecklistCriteria(id: 8, name: 'خلو المادة من الروائح', acceptanceCriteria: 'نعم'),
      ],
    ),
    RawMaterialCategoryInfo(
      type: RawMaterialCategoryType.chemicals,
      key: 'chemicals',
      title: 'المواد الكيميائية',
      subtitle: 'فحص بطاقة السلامة SDS وشهادة التحليل COA والتخزين',
      annexCode: 'SELSAL-IMSF-19-03E',
      annexTitle: 'الملحق (E): قائمة فحص المواد الكيميائية (Chemical Inspection Checklist)',
      icon: Icons.science_outlined,
      color: Color(0xFF7B1FA2),
      criteria: [
        ChecklistCriteria(id: 1, name: 'اسم المادة', acceptanceCriteria: 'مطابق لأمر الشراء'),
        ChecklistCriteria(id: 2, name: 'الشركة المصنعة', acceptanceCriteria: 'معتمدة'),
        ChecklistCriteria(id: 3, name: 'رقم التشغيلة', acceptanceCriteria: 'موجود'),
        ChecklistCriteria(id: 4, name: 'تاريخ الإنتاج', acceptanceCriteria: 'واضح'),
        ChecklistCriteria(id: 5, name: 'تاريخ الانتهاء', acceptanceCriteria: 'ساري'),
        ChecklistCriteria(id: 6, name: 'العبوة سليمة', acceptanceCriteria: 'نعم'),
        ChecklistCriteria(id: 7, name: 'بطاقة السلامة (SDS)', acceptanceCriteria: 'متوفرة'),
        ChecklistCriteria(id: 8, name: 'شهادة التحليل (COA)', acceptanceCriteria: 'متوفرة'),
        ChecklistCriteria(id: 9, name: 'شهادة المطابقة (إن وجدت)', acceptanceCriteria: 'متوفرة'),
        ChecklistCriteria(id: 10, name: 'حالة التخزين أثناء الاستلام', acceptanceCriteria: 'مناسبة'),
      ],
    ),
    RawMaterialCategoryInfo(
      type: RawMaterialCategoryType.secondaryPackaging,
      key: 'secondary_packaging',
      title: 'مواد التعبئة الثانوية',
      subtitle: 'فحص أفلام الشرينك (Shrink Film) والشرائط اللاصقة',
      annexCode: 'SELSAL-IMSF-19-03F',
      annexTitle: 'الملحق (F): قائمة فحص مواد التعبئة الثانوية (أفلام الشرينك والشرائط اللاصقة)',
      icon: Icons.all_inclusive_rounded,
      color: Color(0xFF3949AB),
      criteria: [
        ChecklistCriteria(id: 1, name: 'نوع المادة مطابق للمواصفة', acceptanceCriteria: 'نعم'),
        ChecklistCriteria(id: 2, name: 'السمك والأبعاد', acceptanceCriteria: 'ضمن المواصفة'),
        ChecklistCriteria(id: 3, name: 'الشفافية/اللون', acceptanceCriteria: 'مطابق'),
        ChecklistCriteria(id: 4, name: 'خلو الروالت من القطع أو التلف', acceptanceCriteria: 'نعم'),
        ChecklistCriteria(id: 5, name: 'جودة اللحام أو الالتصاق (عند الحاجة)', acceptanceCriteria: 'مطابقة'),
        ChecklistCriteria(id: 6, name: 'نظافة المادة', acceptanceCriteria: 'نظيفة وخالية من التلوث'),
        ChecklistCriteria(id: 7, name: 'بيانات المورد ورقم التشغيلة', acceptanceCriteria: 'متوفرة'),
      ],
    ),
  ];

  static RawMaterialCategoryInfo getByKey(String key) {
    return allCategories.firstWhere(
      (c) => c.key == key,
      orElse: () => allCategories.first,
    );
  }
}

class ChecklistCriteria {
  final int id;
  final String name;
  final String acceptanceCriteria;

  const ChecklistCriteria({
    required this.id,
    required this.name,
    required this.acceptanceCriteria,
  });
}

// 10 General Checklist items for Page 1 (Common to all raw materials)
class RawMaterialGeneralCriteria {
  static const List<ChecklistCriteria> items = [
    ChecklistCriteria(id: 1, name: 'مطابقة المادة لأمر الشراء', acceptanceCriteria: 'مطابق'),
    ChecklistCriteria(id: 2, name: 'سلامة العبوات', acceptanceCriteria: 'سليمة'),
    ChecklistCriteria(id: 3, name: 'نظافة المادة', acceptanceCriteria: 'نظيفة'),
    ChecklistCriteria(id: 4, name: 'عدم وجود تلف', acceptanceCriteria: 'لا يتجاوز التالف 2%'),
    ChecklistCriteria(id: 5, name: 'بطاقة التعريف', acceptanceCriteria: 'مكتملة'),
    ChecklistCriteria(id: 6, name: 'رقم التشغيلة', acceptanceCriteria: 'مسجل'),
    ChecklistCriteria(id: 7, name: 'تاريخ الإنتاج', acceptanceCriteria: 'ضمن الحد المسموح'),
    ChecklistCriteria(id: 8, name: 'تاريخ الانتهاء', acceptanceCriteria: 'ضمن الحد المسموح'),
    ChecklistCriteria(id: 9, name: 'شهادة المطابقة (COC)', acceptanceCriteria: 'متواجدة'),
    ChecklistCriteria(id: 10, name: 'نتائج التحاليل (إن وجدت)', acceptanceCriteria: 'متواجدة'),
  ];
}

class RawMaterialItemResult {
  final int itemId;
  final String itemName;
  final String acceptanceCriteria;
  final bool? isCompliant;
  final String? resultValue;
  final String? notes;

  RawMaterialItemResult({
    required this.itemId,
    required this.itemName,
    required this.acceptanceCriteria,
    this.isCompliant,
    this.resultValue,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_name': itemName,
      'acceptance_criteria': acceptanceCriteria,
      'is_compliant': isCompliant == null ? null : (isCompliant! ? 1 : 0),
      'result_value': resultValue,
      'notes': notes,
    };
  }

  factory RawMaterialItemResult.fromJson(Map<String, dynamic> json) {
    bool? isComp;
    if (json['is_compliant'] is bool) {
      isComp = json['is_compliant'] as bool;
    } else if (json['is_compliant'] is int) {
      isComp = (json['is_compliant'] as int) == 1;
    } else if (json['isCompliant'] is bool) {
      isComp = json['isCompliant'] as bool;
    } else if (json['isCompliant'] is int) {
      isComp = (json['isCompliant'] as int) == 1;
    }

    return RawMaterialItemResult(
      itemId: json['item_id'] as int? ?? (json['itemId'] as int? ?? 0),
      itemName: json['item_name'] as String? ?? (json['itemName'] as String? ?? ''),
      acceptanceCriteria: json['acceptance_criteria'] as String? ?? (json['acceptanceCriteria'] as String? ?? ''),
      isCompliant: isComp,
      resultValue: json['result_value'] as String? ?? json['resultValue'] as String?,
      notes: json['notes'] as String?,
    );
  }

  factory RawMaterialItemResult.fromMap(Map<String, dynamic> map) =>
      RawMaterialItemResult.fromJson(map);
}

class RawMaterialReport {
  final int? id;
  final String categoryKey;
  final String annexCode;
  final String annexTitle;
  final DateTime createdAt;

  // Receipt Details (Page 1)
  final String dateStr;
  final String timeStr;
  final String supplierName;
  final String poNumber;
  final String materialName;
  final String receiptNumber;
  final String receivedQuantity;
  final String inspectedQuantity;
  final String acceptedQuantity;
  final String rejectedQuantity;
  final String inspectorName;
  final String batchNumber;

  // Quality Decision (Page 1)
  final String qualityDecision; // Accepted, AcceptedWithConditions, Hold, Reject
  final bool actionHold;
  final bool actionReject;
  final bool actionReturnToSupplier;
  final bool actionNcr;
  final String? ncrNumber;

  // Notes
  final String? generalNotes;
  final String? annexNotes;

  // Approvals & Signatures
  final int? branchId;
  final String? branchName;
  String get effectiveBranchName => branchName != null && branchName!.isNotEmpty
      ? branchName!
      : (branchId == 2 ? 'مصنع سنحان' : 'مصنع أرتل');
  final String approvalStatus; // Draft, Pending_QM, Pending_GM, Approved, Rejected
  final String? qmApprovedBy;
  final DateTime? qmApprovedAt;
  final String? gmApprovedBy;
  final DateTime? gmApprovedAt;
  final String? labResponsibleName;
  final DateTime? labResponsibleAt;
  final String? rejectedBy;
  final String? rejectionReason;

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

  RawMaterialReport({
    this.id,
    this.branchId,
    this.branchName,
    required this.categoryKey,
    required this.annexCode,
    required this.annexTitle,
    DateTime? createdAt,
    required this.dateStr,
    required this.timeStr,
    required this.supplierName,
    required this.poNumber,
    required this.materialName,
    required this.receiptNumber,
    required this.receivedQuantity,
    required this.inspectedQuantity,
    this.acceptedQuantity = '',
    this.rejectedQuantity = '',
    required this.inspectorName,
    required this.batchNumber,
    required this.qualityDecision,
    this.actionHold = false,
    this.actionReject = false,
    this.actionReturnToSupplier = false,
    this.actionNcr = false,
    this.ncrNumber,
    this.generalNotes,
    this.annexNotes,
    this.approvalStatus = 'Pending_QM',
    this.qmApprovedBy,
    this.qmApprovedAt,
    this.gmApprovedBy,
    this.gmApprovedAt,
    this.labResponsibleName,
    this.labResponsibleAt,
    this.rejectedBy,
    this.rejectionReason,
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
  }) : createdAt = createdAt ?? DateTime.now();

  RawMaterialReport copyWith({
    int? id,
    int? branchId,
    String? branchName,
    String? categoryKey,
    String? annexCode,
    String? annexTitle,
    DateTime? createdAt,
    String? dateStr,
    String? timeStr,
    String? supplierName,
    String? poNumber,
    String? materialName,
    String? receiptNumber,
    String? receivedQuantity,
    String? inspectedQuantity,
    String? acceptedQuantity,
    String? rejectedQuantity,
    String? inspectorName,
    String? batchNumber,
    String? qualityDecision,
    bool? actionHold,
    bool? actionReject,
    bool? actionReturnToSupplier,
    bool? actionNcr,
    String? ncrNumber,
    String? generalNotes,
    String? annexNotes,
    String? approvalStatus,
    String? qmApprovedBy,
    DateTime? qmApprovedAt,
    String? gmApprovedBy,
    DateTime? gmApprovedAt,
    String? labResponsibleName,
    DateTime? labResponsibleAt,
    String? rejectedBy,
    String? rejectionReason,
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
  }) {
    return RawMaterialReport(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      categoryKey: categoryKey ?? this.categoryKey,
      annexCode: annexCode ?? this.annexCode,
      annexTitle: annexTitle ?? this.annexTitle,
      createdAt: createdAt ?? this.createdAt,
      dateStr: dateStr ?? this.dateStr,
      timeStr: timeStr ?? this.timeStr,
      supplierName: supplierName ?? this.supplierName,
      poNumber: poNumber ?? this.poNumber,
      materialName: materialName ?? this.materialName,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      receivedQuantity: receivedQuantity ?? this.receivedQuantity,
      inspectedQuantity: inspectedQuantity ?? this.inspectedQuantity,
      acceptedQuantity: acceptedQuantity ?? this.acceptedQuantity,
      rejectedQuantity: rejectedQuantity ?? this.rejectedQuantity,
      inspectorName: inspectorName ?? this.inspectorName,
      batchNumber: batchNumber ?? this.batchNumber,
      qualityDecision: qualityDecision ?? this.qualityDecision,
      actionHold: actionHold ?? this.actionHold,
      actionReject: actionReject ?? this.actionReject,
      actionReturnToSupplier: actionReturnToSupplier ?? this.actionReturnToSupplier,
      actionNcr: actionNcr ?? this.actionNcr,
      ncrNumber: ncrNumber ?? this.ncrNumber,
      generalNotes: generalNotes ?? this.generalNotes,
      annexNotes: annexNotes ?? this.annexNotes,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      qmApprovedBy: qmApprovedBy ?? this.qmApprovedBy,
      qmApprovedAt: qmApprovedAt ?? this.qmApprovedAt,
      gmApprovedBy: gmApprovedBy ?? this.gmApprovedBy,
      gmApprovedAt: gmApprovedAt ?? this.gmApprovedAt,
      labResponsibleName: labResponsibleName ?? this.labResponsibleName,
      labResponsibleAt: labResponsibleAt ?? this.labResponsibleAt,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'branch_name': branchName,
      'category_key': categoryKey,
      'annex_code': annexCode,
      'annex_title': annexTitle,
      'created_at': createdAt.toIso8601String(),
      'date_str': dateStr,
      'time_str': timeStr,
      'supplier_name': supplierName,
      'po_number': poNumber,
      'material_name': materialName,
      'receipt_number': receiptNumber,
      'received_quantity': receivedQuantity,
      'inspected_quantity': inspectedQuantity,
      'accepted_quantity': acceptedQuantity,
      'rejected_quantity': rejectedQuantity,
      'inspector_name': inspectorName,
      'batch_number': batchNumber,
      'quality_decision': qualityDecision,
      'action_hold': actionHold ? 1 : 0,
      'action_reject': actionReject ? 1 : 0,
      'action_return_to_supplier': actionReturnToSupplier ? 1 : 0,
      'action_ncr': actionNcr ? 1 : 0,
      'ncr_number': ncrNumber,
      'general_notes': generalNotes,
      'annex_notes': annexNotes,
      'approval_status': approvalStatus,
      'qm_approved_by': qmApprovedBy,
      'qm_approved_at': qmApprovedAt?.toIso8601String(),
      'gm_approved_by': gmApprovedBy,
      'gm_approved_at': gmApprovedAt?.toIso8601String(),
      'lab_responsible_name': labResponsibleName,
      'lab_responsible_at': labResponsibleAt?.toIso8601String(),
      'rejected_by': rejectedBy,
      'rejection_reason': rejectionReason,
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
    };
  }

  factory RawMaterialReport.fromJson(Map<String, dynamic> json) {
    return RawMaterialReport(
      id: json['id'] as int?,
      branchId: json['branch_id'] as int? ?? (json['branchId'] as int?),
      branchName: json['branch_name'] as String? ?? (json['branchName'] as String?),
      categoryKey: json['category_key'] as String? ?? (json['categoryKey'] as String? ?? 'pet_bottles'),
      annexCode: json['annex_code'] as String? ?? (json['annexCode'] as String? ?? 'SELSAL-IMSF-19-03A'),
      annexTitle: json['annex_title'] as String? ?? (json['annexTitle'] as String? ?? ''),
      createdAt: json['created_at'] != null 
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()) 
          : (json['createdAt'] != null ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()) : DateTime.now()),
      dateStr: json['date_str'] as String? ?? (json['dateStr'] as String? ?? ''),
      timeStr: json['time_str'] as String? ?? (json['timeStr'] as String? ?? ''),
      supplierName: json['supplier_name'] as String? ?? (json['supplierName'] as String? ?? ''),
      poNumber: json['po_number'] as String? ?? (json['poNumber'] as String? ?? ''),
      materialName: json['material_name'] as String? ?? (json['materialName'] as String? ?? (json['material_type'] as String? ?? '')),
      receiptNumber: json['receipt_number'] as String? ?? (json['receiptNumber'] as String? ?? (json['invoice_number'] as String? ?? '')),
      receivedQuantity: json['received_quantity'] as String? ?? (json['receivedQuantity'] as String? ?? ''),
      inspectedQuantity: json['inspected_quantity'] as String? ?? (json['inspectedQuantity'] as String? ?? (json['sample_size'] as String? ?? '')),
      acceptedQuantity: json['accepted_quantity'] as String? ?? (json['acceptedQuantity'] as String? ?? ''),
      rejectedQuantity: json['rejected_quantity'] as String? ?? (json['rejectedQuantity'] as String? ?? ''),
      inspectorName: json['inspector_name'] as String? ?? (json['inspectorName'] as String? ?? ''),
      batchNumber: json['batch_number'] as String? ?? (json['batchNumber'] as String? ?? (json['lot_number'] as String? ?? '')),
      qualityDecision: json['quality_decision'] as String? ?? (json['qualityDecision'] as String? ?? 'Accepted'),
      actionHold: json['action_hold'] == true || json['action_hold'] == 1 || json['actionHold'] == true || json['actionHold'] == 1,
      actionReject: json['action_reject'] == true || json['action_reject'] == 1 || json['actionReject'] == true || json['actionReject'] == 1,
      actionReturnToSupplier: json['action_return_to_supplier'] == true || json['action_return_to_supplier'] == 1 || json['actionReturnToSupplier'] == true || json['actionReturnToSupplier'] == 1,
      actionNcr: json['action_ncr'] == true || json['action_ncr'] == 1 || json['actionNcr'] == true || json['actionNcr'] == 1,
      ncrNumber: json['ncr_number'] as String? ?? (json['ncrNumber'] as String?),
      generalNotes: json['general_notes'] as String? ?? (json['generalNotes'] as String?),
      annexNotes: json['annex_notes'] as String? ?? (json['annexNotes'] as String?),
      approvalStatus: json['approval_status'] as String? ?? (json['approvalStatus'] as String? ?? 'Pending_QM'),
      qmApprovedBy: json['qm_approved_by'] as String? ?? (json['qmApprovedBy'] as String?),
      qmApprovedAt: json['qm_approved_at'] != null ? DateTime.tryParse(json['qm_approved_at'].toString()) : (json['qmApprovedAt'] != null ? DateTime.tryParse(json['qmApprovedAt'].toString()) : null),
      gmApprovedBy: json['gm_approved_by'] as String? ?? (json['gmApprovedBy'] as String?),
      gmApprovedAt: json['gm_approved_at'] != null ? DateTime.tryParse(json['gm_approved_at'].toString()) : (json['gmApprovedAt'] != null ? DateTime.tryParse(json['gmApprovedAt'].toString()) : null),
      labResponsibleName: json['lab_responsible_name'] as String? ?? (json['labResponsibleName'] as String?),
      labResponsibleAt: json['lab_responsible_at'] != null ? DateTime.tryParse(json['lab_responsible_at'].toString()) : (json['labResponsibleAt'] != null ? DateTime.tryParse(json['labResponsibleAt'].toString()) : null),
      rejectedBy: json['rejected_by'] as String? ?? (json['rejectedBy'] as String?),
      rejectionReason: json['rejection_reason'] as String? ?? (json['rejectionReason'] as String?),
      rejectionCategory: json['rejection_category'] as String? ?? (json['rejectionCategory'] as String?),
      severityLevel: json['severity_level'] as String? ?? (json['severityLevel'] as String?),
      rejectionNotes: json['rejection_notes'] as String? ?? (json['rejectionNotes'] as String?),
      affectedProducts: json['affected_products'] as String? ?? (json['affectedProducts'] as String?),
      immediateAction: json['immediate_action'] as String? ?? (json['immediateAction'] as String?),
      correctiveAction: json['corrective_action'] as String? ?? (json['correctiveAction'] as String?),
      correctiveOwner: json['corrective_owner'] as String? ?? (json['correctiveOwner'] as String?),
      correctiveDueDate: json['corrective_due_date'] != null
          ? DateTime.tryParse(json['corrective_due_date'].toString())
          : (json['correctiveDueDate'] != null ? DateTime.tryParse(json['correctiveDueDate'].toString()) : null),
      gmDecision: json['gm_decision'] as String? ?? (json['gmDecision'] as String?),
      gmDecisionBy: json['gm_decision_by'] as String? ?? (json['gmDecisionBy'] as String?),
      gmDecisionAt: json['gm_decision_at'] != null
          ? DateTime.tryParse(json['gm_decision_at'].toString())
          : (json['gmDecisionAt'] != null ? DateTime.tryParse(json['gmDecisionAt'].toString()) : null),
      gmDecisionNotes: json['gm_decision_notes'] as String? ?? (json['gmDecisionNotes'] as String?),
    );
  }

  factory RawMaterialReport.fromMap(Map<String, dynamic> map) =>
      RawMaterialReport.fromJson(map);
}
