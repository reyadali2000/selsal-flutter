class WaterQualityLog {
  final int? id;
  final int branchId;
  final int shiftId;
  final int createdBy;
  final String reportCategory;
  final String waterType;
  final String? batchNumber;
  final bool isCompliant;
  final String? generalNotes;
  final DateTime createdAt;
  
  final String approvalStatus; // Draft, Pending_QM, Pending_GM, Approved, Rejected, Corrective_In_Progress, Pending_GM_Decision, Rejected_By_GM, Closed
  final int? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? rejectedBy;

  // Multi-level approval tracking
  final String? qmApprovedBy;
  final DateTime? qmApprovedAt;
  final String? gmApprovedBy;
  final DateTime? gmApprovedAt;

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

  // New fields for Raw Water & Finished Product Inspection
  final String? waterSource;
  final String? wellNumber;
  final String? sampleTaker;
  final bool? managerNotified;
  final bool? sourceSuspended;
  final String? ncrNumber;

  // Finished Product Specific Fields
  final String? productName;
  final String? bottleSize;
  final String? productionDate;
  final String? samplingTime;
  final String? samplingLocation;
  final String? producedQuantity;
  final bool? isIsolated;
  final bool? isHoldIssued;
  final bool? isRejectIssued;

  // ─── الاعتماد على مرحلتين لنتائج الميكروبيولوجي ───
  final bool microResultsPending; // النتائج الميكروبيولوجية لم تُدخل بعد
  final String? microEnteredBy;
  final DateTime? microEnteredAt;
  // تواقيع المرحلة الأولى (الاعتماد المبدئي بدون الميكروبيولوجي)
  final String? stage1QmApprovedBy;
  final DateTime? stage1QmApprovedAt;
  final String? stage1GmApprovedBy;
  final DateTime? stage1GmApprovedAt;
  // تواقيع المرحلة الثانية (اعتماد نتائج الميكروبيولوجي)
  final String? microQmApprovedBy;
  final DateTime? microQmApprovedAt;
  final String? microGmApprovedBy;
  final DateTime? microGmApprovedAt;
  final String? microRejectionReason;
  final String? microRejectedBy;
  final DateTime? microRejectedAt;
  final String? microRejectionAction;

  String get branchName => branchId == 2 ? 'مصنع سنحان' : 'مصنع أرتل';

  WaterQualityLog({
    this.id,
    required this.branchId,
    required this.shiftId,
    required this.createdBy,
    required this.reportCategory,
    required this.waterType,
    this.batchNumber,
    required this.isCompliant,
    this.generalNotes,
    DateTime? createdAt,
    this.approvalStatus = 'Pending_QM',
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.rejectedBy,
    this.qmApprovedBy,
    this.qmApprovedAt,
    this.gmApprovedBy,
    this.gmApprovedAt,
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
    this.waterSource,
    this.wellNumber,
    this.sampleTaker,
    this.managerNotified,
    this.sourceSuspended,
    this.ncrNumber,
    this.productName,
    this.bottleSize,
    this.productionDate,
    this.samplingTime,
    this.samplingLocation,
    this.producedQuantity,
    this.isIsolated,
    this.isHoldIssued,
    this.isRejectIssued,
    this.microResultsPending = false,
    this.microEnteredBy,
    this.microEnteredAt,
    this.stage1QmApprovedBy,
    this.stage1QmApprovedAt,
    this.stage1GmApprovedBy,
    this.stage1GmApprovedAt,
    this.microQmApprovedBy,
    this.microQmApprovedAt,
    this.microGmApprovedBy,
    this.microGmApprovedAt,
    this.microRejectionReason,
    this.microRejectedBy,
    this.microRejectedAt,
    this.microRejectionAction,
  }) : createdAt = createdAt ?? DateTime.now();

  WaterQualityLog copyWith({
    int? id,
    int? branchId,
    int? shiftId,
    int? createdBy,
    String? reportCategory,
    String? waterType,
    String? batchNumber,
    bool? isCompliant,
    String? generalNotes,
    DateTime? createdAt,
    String? approvalStatus,
    int? approvedBy,
    DateTime? approvedAt,
    String? rejectionReason,
    String? rejectedBy,
    String? qmApprovedBy,
    DateTime? qmApprovedAt,
    String? gmApprovedBy,
    DateTime? gmApprovedAt,
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
    String? waterSource,
    String? wellNumber,
    String? sampleTaker,
    bool? managerNotified,
    bool? sourceSuspended,
    String? ncrNumber,
    String? productName,
    String? bottleSize,
    String? productionDate,
    String? samplingTime,
    String? samplingLocation,
    String? producedQuantity,
    bool? isIsolated,
    bool? isHoldIssued,
    bool? isRejectIssued,
    bool? microResultsPending,
    String? microEnteredBy,
    DateTime? microEnteredAt,
    String? stage1QmApprovedBy,
    DateTime? stage1QmApprovedAt,
    String? stage1GmApprovedBy,
    DateTime? stage1GmApprovedAt,
    String? microQmApprovedBy,
    DateTime? microQmApprovedAt,
    String? microGmApprovedBy,
    DateTime? microGmApprovedAt,
    String? microRejectionReason,
    String? microRejectedBy,
    DateTime? microRejectedAt,
    String? microRejectionAction,
  }) {
    return WaterQualityLog(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      shiftId: shiftId ?? this.shiftId,
      createdBy: createdBy ?? this.createdBy,
      reportCategory: reportCategory ?? this.reportCategory,
      waterType: waterType ?? this.waterType,
      batchNumber: batchNumber ?? this.batchNumber,
      isCompliant: isCompliant ?? this.isCompliant,
      generalNotes: generalNotes ?? this.generalNotes,
      createdAt: createdAt ?? this.createdAt,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      qmApprovedBy: qmApprovedBy ?? this.qmApprovedBy,
      qmApprovedAt: qmApprovedAt ?? this.qmApprovedAt,
      gmApprovedBy: gmApprovedBy ?? this.gmApprovedBy,
      gmApprovedAt: gmApprovedAt ?? this.gmApprovedAt,
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
      waterSource: waterSource ?? this.waterSource,
      wellNumber: wellNumber ?? this.wellNumber,
      sampleTaker: sampleTaker ?? this.sampleTaker,
      managerNotified: managerNotified ?? this.managerNotified,
      sourceSuspended: sourceSuspended ?? this.sourceSuspended,
      ncrNumber: ncrNumber ?? this.ncrNumber,
      productName: productName ?? this.productName,
      bottleSize: bottleSize ?? this.bottleSize,
      productionDate: productionDate ?? this.productionDate,
      samplingTime: samplingTime ?? this.samplingTime,
      samplingLocation: samplingLocation ?? this.samplingLocation,
      producedQuantity: producedQuantity ?? this.producedQuantity,
      isIsolated: isIsolated ?? this.isIsolated,
      isHoldIssued: isHoldIssued ?? this.isHoldIssued,
      isRejectIssued: isRejectIssued ?? this.isRejectIssued,
      microResultsPending: microResultsPending ?? this.microResultsPending,
      microEnteredBy: microEnteredBy ?? this.microEnteredBy,
      microEnteredAt: microEnteredAt ?? this.microEnteredAt,
      stage1QmApprovedBy: stage1QmApprovedBy ?? this.stage1QmApprovedBy,
      stage1QmApprovedAt: stage1QmApprovedAt ?? this.stage1QmApprovedAt,
      stage1GmApprovedBy: stage1GmApprovedBy ?? this.stage1GmApprovedBy,
      stage1GmApprovedAt: stage1GmApprovedAt ?? this.stage1GmApprovedAt,
      microQmApprovedBy: microQmApprovedBy ?? this.microQmApprovedBy,
      microQmApprovedAt: microQmApprovedAt ?? this.microQmApprovedAt,
      microGmApprovedBy: microGmApprovedBy ?? this.microGmApprovedBy,
      microGmApprovedAt: microGmApprovedAt ?? this.microGmApprovedAt,
      microRejectionReason: microRejectionReason ?? this.microRejectionReason,
      microRejectedBy: microRejectedBy ?? this.microRejectedBy,
      microRejectedAt: microRejectedAt ?? this.microRejectedAt,
      microRejectionAction: microRejectionAction ?? this.microRejectionAction,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'shift_id': shiftId,
      'created_by': createdBy,
      'report_category': reportCategory,
      'water_type': waterType,
      'batch_number': batchNumber,
      'is_compliant': isCompliant ? 1 : 0,
      'general_notes': generalNotes,
      'created_at': createdAt.toIso8601String(),
      'approval_status': approvalStatus,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'rejected_by': rejectedBy,
      'qm_approved_by': qmApprovedBy,
      'qm_approved_at': qmApprovedAt?.toIso8601String(),
      'gm_approved_by': gmApprovedBy,
      'gm_approved_at': gmApprovedAt?.toIso8601String(),
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
      'water_source': waterSource,
      'well_number': wellNumber,
      'sample_taker': sampleTaker,
      'manager_notified': managerNotified == true ? 1 : (managerNotified == false ? 0 : null),
      'source_suspended': sourceSuspended == true ? 1 : (sourceSuspended == false ? 0 : null),
      'ncr_number': ncrNumber,
      'product_name': productName,
      'bottle_size': bottleSize,
      'production_date': productionDate,
      'sampling_time': samplingTime,
      'sampling_location': samplingLocation,
      'produced_quantity': producedQuantity,
      'is_isolated': isIsolated == true ? 1 : (isIsolated == false ? 0 : null),
      'is_hold_issued': isHoldIssued == true ? 1 : (isHoldIssued == false ? 0 : null),
      'is_reject_issued': isRejectIssued == true ? 1 : (isRejectIssued == false ? 0 : null),
      'micro_results_pending': microResultsPending ? 1 : 0,
      'micro_entered_by': microEnteredBy,
      'micro_entered_at': microEnteredAt?.toIso8601String(),
      'stage1_qm_approved_by': stage1QmApprovedBy,
      'stage1_qm_approved_at': stage1QmApprovedAt?.toIso8601String(),
      'stage1_gm_approved_by': stage1GmApprovedBy,
      'stage1_gm_approved_at': stage1GmApprovedAt?.toIso8601String(),
      'micro_qm_approved_by': microQmApprovedBy,
      'micro_qm_approved_at': microQmApprovedAt?.toIso8601String(),
      'micro_gm_approved_by': microGmApprovedBy,
      'micro_gm_approved_at': microGmApprovedAt?.toIso8601String(),
      'micro_rejection_reason': microRejectionReason,
      'micro_rejected_by': microRejectedBy,
      'micro_rejected_at': microRejectedAt?.toIso8601String(),
      'micro_rejection_action': microRejectionAction,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  static bool _parseBool(dynamic val, [bool defaultVal = false]) {
    if (val == null) return defaultVal;
    if (val is bool) return val;
    if (val is num) return val == 1;
    if (val is String) return val == '1' || val.toLowerCase() == 'true';
    return defaultVal;
  }

  static bool? _parseNullableBool(dynamic val) {
    if (val == null) return null;
    if (val is bool) return val;
    if (val is num) return val == 1;
    if (val is String) return val == '1' || val.toLowerCase() == 'true';
    return null;
  }

  static int _parseInt(dynamic val, [int defaultVal = 0]) {
    if (val == null) return defaultVal;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? defaultVal;
    return defaultVal;
  }

  static DateTime _parseDate(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is DateTime) return val;
    return DateTime.tryParse(val.toString()) ?? DateTime.now();
  }

  static DateTime? _parseNullableDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    return DateTime.tryParse(val.toString());
  }

  factory WaterQualityLog.fromJson(Map<String, dynamic> json) => WaterQualityLog.fromMap(json);

  factory WaterQualityLog.fromMap(Map<String, dynamic> rawJson) {
    final json = (rawJson['log'] is Map)
        ? Map<String, dynamic>.from(rawJson['log'])
        : ((rawJson['Log'] is Map)
            ? Map<String, dynamic>.from(rawJson['Log'])
            : rawJson);
    return WaterQualityLog(
      id: json['id'] as int?,
      branchId: _parseInt(json['branch_id'] ?? json['branchId'], 1),
      shiftId: _parseInt(json['shift_id'] ?? json['shiftId'], 1),
      createdBy: _parseInt(json['created_by'] ?? json['createdBy'], 1),
      reportCategory: (json['report_category'] ?? json['reportCategory'] ?? 'Final Product') as String,
      waterType: (json['water_type'] ?? json['waterType'] ?? 'Final Product') as String,
      batchNumber: (json['batch_number'] ?? json['batchNumber']) as String?,
      isCompliant: _parseBool(json['is_compliant'] ?? json['isCompliant'], true),
      generalNotes: (json['general_notes'] ?? json['generalNotes']) as String?,
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
      approvalStatus: (json['approval_status'] ?? json['approvalStatus'] ?? 'Pending_QM') as String,
      approvedBy: json['approved_by'] != null || json['approvedBy'] != null
          ? _parseInt(json['approved_by'] ?? json['approvedBy'])
          : null,
      approvedAt: _parseNullableDate(json['approved_at'] ?? json['approvedAt']),
      rejectionReason: (json['rejection_reason'] ?? json['rejectionReason']) as String?,
      rejectedBy: (json['rejected_by'] ?? json['rejectedBy']) as String?,
      qmApprovedBy: (json['qm_approved_by'] ?? json['qmApprovedBy']) as String?,
      qmApprovedAt: _parseNullableDate(json['qm_approved_at'] ?? json['qmApprovedAt']),
      gmApprovedBy: (json['gm_approved_by'] ?? json['gmApprovedBy']) as String?,
      gmApprovedAt: _parseNullableDate(json['gm_approved_at'] ?? json['gmApprovedAt']),
      rejectionCategory: (json['rejection_category'] ?? json['rejectionCategory']) as String?,
      severityLevel: (json['severity_level'] ?? json['severityLevel']) as String?,
      rejectionNotes: (json['rejection_notes'] ?? json['rejectionNotes']) as String?,
      affectedProducts: (json['affected_products'] ?? json['affectedProducts']) as String?,
      immediateAction: (json['immediate_action'] ?? json['immediateAction']) as String?,
      correctiveAction: (json['corrective_action'] ?? json['correctiveAction']) as String?,
      correctiveOwner: (json['corrective_owner'] ?? json['correctiveOwner']) as String?,
      correctiveDueDate: _parseNullableDate(json['corrective_due_date'] ?? json['correctiveDueDate']),
      gmDecision: (json['gm_decision'] ?? json['gmDecision']) as String?,
      gmDecisionBy: (json['gm_decision_by'] ?? json['gmDecisionBy']) as String?,
      gmDecisionAt: _parseNullableDate(json['gm_decision_at'] ?? json['gmDecisionAt']),
      gmDecisionNotes: (json['gm_decision_notes'] ?? json['gmDecisionNotes']) as String?,
      rejectionCount: _parseInt(json['rejection_count'] ?? json['rejectionCount'], 0),
      waterSource: (json['water_source'] ?? json['waterSource']) as String?,
      wellNumber: (json['well_number'] ?? json['wellNumber']) as String?,
      sampleTaker: (json['sample_taker'] ?? json['sampleTaker']) as String?,
      managerNotified: _parseNullableBool(json['manager_notified'] ?? json['managerNotified']),
      sourceSuspended: _parseNullableBool(json['source_suspended'] ?? json['sourceSuspended']),
      ncrNumber: (json['ncr_number'] ?? json['ncrNumber']) as String?,
      productName: (json['product_name'] ?? json['productName']) as String?,
      bottleSize: (json['bottle_size'] ?? json['bottleSize']) as String?,
      productionDate: (json['production_date'] ?? json['productionDate']) as String?,
      samplingTime: (json['sampling_time'] ?? json['samplingTime']) as String?,
      samplingLocation: (json['sampling_location'] ?? json['samplingLocation']) as String?,
      producedQuantity: (json['produced_quantity'] ?? json['producedQuantity']) as String?,
      isIsolated: _parseNullableBool(json['is_isolated'] ?? json['isIsolated']),
      isHoldIssued: _parseNullableBool(json['is_hold_issued'] ?? json['isHoldIssued']),
      isRejectIssued: _parseNullableBool(json['is_reject_issued'] ?? json['isRejectIssued']),
      microResultsPending: _parseBool(json['micro_results_pending'] ?? json['microResultsPending']),
      microEnteredBy: (json['micro_entered_by'] ?? json['microEnteredBy']) as String?,
      microEnteredAt: _parseNullableDate(json['micro_entered_at'] ?? json['microEnteredAt']),
      stage1QmApprovedBy: (json['stage1_qm_approved_by'] ?? json['stage1QmApprovedBy']) as String?,
      stage1QmApprovedAt: _parseNullableDate(json['stage1_qm_approved_at'] ?? json['stage1QmApprovedAt']),
      stage1GmApprovedBy: (json['stage1_gm_approved_by'] ?? json['stage1GmApprovedBy']) as String?,
      stage1GmApprovedAt: _parseNullableDate(json['stage1_gm_approved_at'] ?? json['stage1GmApprovedAt']),
      microQmApprovedBy: (json['micro_qm_approved_by'] ?? json['microQmApprovedBy']) as String?,
      microQmApprovedAt: _parseNullableDate(json['micro_qm_approved_at'] ?? json['microQmApprovedAt']),
      microGmApprovedBy: (json['micro_gm_approved_by'] ?? json['microGmApprovedBy']) as String?,
      microGmApprovedAt: _parseNullableDate(json['micro_gm_approved_at'] ?? json['microGmApprovedAt']),
    );
  }
}

class WaterQualityResult {
  final int? id;
  final int logId;
  final int parameterId;
  final double? numericResult;
  final String? textResult;
  final bool isCompliant;
  final String? notes;

  WaterQualityResult({
    this.id,
    required this.logId,
    required this.parameterId,
    this.numericResult,
    this.textResult,
    required this.isCompliant,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'log_id': logId,
      'parameter_id': parameterId,
      'numeric_result': numericResult,
      'text_result': textResult,
      'is_compliant': isCompliant ? 1 : 0,
      'notes': notes,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  factory WaterQualityResult.fromJson(Map<String, dynamic> json) => WaterQualityResult.fromMap(json);

  factory WaterQualityResult.fromMap(Map<String, dynamic> json) {
    return WaterQualityResult(
      id: json['id'] as int?,
      logId: WaterQualityLog._parseInt(json['log_id'] ?? json['logId'], 0),
      parameterId: WaterQualityLog._parseInt(json['parameter_id'] ?? json['parameterId'], 0),
      numericResult: (json['numeric_result'] ?? json['numericResult']) != null
          ? ((json['numeric_result'] ?? json['numericResult']) as num).toDouble()
          : null,
      textResult: (json['text_result'] ?? json['textResult']) as String?,
      isCompliant: WaterQualityLog._parseBool(json['is_compliant'] ?? json['isCompliant'], true),
      notes: (json['notes'] ?? json['Notes']) as String?,
    );
  }
}
