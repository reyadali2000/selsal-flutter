class TreatmentPlant {
  final int? id;
  final int branchId;
  final String name;

  TreatmentPlant({
    this.id,
    required this.branchId,
    required this.name,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'name': name,
    };
  }

  factory TreatmentPlant.fromJson(Map<String, dynamic> json) {
    return TreatmentPlant(
      id: json['id'] as int?,
      branchId: json['branch_id'] as int,
      name: json['name'] as String,
    );
  }
}

class TreatmentStage {
  final int? id;
  final int plantId;
  final String name;

  TreatmentStage({
    this.id,
    required this.plantId,
    required this.name,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plant_id': plantId,
      'name': name,
    };
  }

  factory TreatmentStage.fromJson(Map<String, dynamic> json) {
    return TreatmentStage(
      id: json['id'] as int?,
      plantId: json['plant_id'] as int,
      name: json['name'] as String,
    );
  }
}

class TreatmentPlantLog {
  final int? id;
  final int stageId;
  final int shiftId;
  final int createdBy;
  final double pressureValue;
  final double tdsValue;
  final String? correctiveAction;
  final DateTime createdAt;
  
  final String approvalStatus;
  final int? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;

  TreatmentPlantLog({
    this.id,
    required this.stageId,
    required this.shiftId,
    required this.createdBy,
    required this.pressureValue,
    required this.tdsValue,
    this.correctiveAction,
    DateTime? createdAt,
    this.approvalStatus = 'Pending',
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stage_id': stageId,
      'shift_id': shiftId,
      'created_by': createdBy,
      'pressure_value': pressureValue,
      'tds_value': tdsValue,
      'corrective_action': correctiveAction,
      'created_at': createdAt.toIso8601String(),
      'approval_status': approvalStatus,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
    };
  }

  factory TreatmentPlantLog.fromJson(Map<String, dynamic> json) {
    return TreatmentPlantLog(
      id: json['id'] as int?,
      stageId: json['stage_id'] as int,
      shiftId: json['shift_id'] as int,
      createdBy: json['created_by'] as int,
      pressureValue: (json['pressure_value'] as num).toDouble(),
      tdsValue: (json['tds_value'] as num).toDouble(),
      correctiveAction: json['corrective_action'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      approvalStatus: json['approval_status'] as String? ?? 'Pending',
      approvedBy: json['approved_by'] as int?,
      approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at'] as String) : null,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }
}
