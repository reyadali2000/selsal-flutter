class Employee {
  final int? id;
  final int branchId;
  final String fullName;
  final String jobTitle;
  final bool isActive;

  /// معرّف العامل الثابت في سجل [DailyWorkers] (إن وُجد).
  /// يُستخدم لربط سجل HygieneLogs بالهوية الثابتة بدل إدراج صف Employees
  /// جديد مع كل تقرير، مما يمكّن التقييم الشهري بالـ ID.
  /// غير نهائي ليُحدَّث عند إعادة ربط مسودة قديمة بالسجل.
  int? databaseWorkerId;

  Employee({
    this.id,
    required this.branchId,
    required this.fullName,
    required this.jobTitle,
    required this.isActive,
    this.databaseWorkerId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'full_name': fullName,
      'job_title': jobTitle,
      'is_active': isActive ? 1 : 0,
      'database_worker_id': databaseWorkerId,
    };
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as int?,
      branchId: json['branch_id'] as int,
      fullName: json['full_name'] as String,
      jobTitle: json['job_title'] as String,
      isActive: (json['is_active'] as int) == 1,
      databaseWorkerId: json['database_worker_id'] as int?,
    );
  }
}

/// نموذج العامل اليومي المسجّل مسبقاً في النظام.
/// على عكس [Employee] الذي يُدرج صفّاً جديداً مع كل تقرير، يحتفظ هذا
/// النموذج بمعرّف ثابت يربط به سجل [HygieneLogs]، مما يجعل التجميع
/// الشهري والاقتراحات التلقائية ممكنة.
class DailyWorker {
  final int? id;
  final int branchId;
  final String fullName;
  final String jobTitle;
  final bool isActive;
  final DateTime? createdAt;

  DailyWorker({
    this.id,
    required this.branchId,
    required this.fullName,
    this.jobTitle = 'عامل بالأجر اليومي',
    this.isActive = true,
    this.createdAt,
  });

  /// مفتاح تطبيع الاسم: إزالة التشكيل وتوحيد الهمزات والمسافات
  /// بحيث تتطابق "أحمد علي" مع "احمد على" لمنع التكرار وتحسين الاقتراحات.
  static String normalizeName(String name) {
    final text = name.trim();
    if (text.isEmpty) return '';
    final buffer = StringBuffer();
    bool lastWasSpace = false;
    // تقسيم إلى وحدات code points — يكفي للعربية التي ضمن BASIC MULTILINGUAL PLANE
    for (final unit in text.codeUnits) {
      String c = String.fromCharCode(unit);
      switch (c) {
        case 'أ':
        case 'إ':
        case 'آ':
          c = 'ا';
          break;
        case 'ى':
          c = 'ي';
          break;
        case 'ة':
          c = 'ه';
          break;
        case 'ؤ':
          c = 'و';
          break;
        case 'ئ':
          c = 'ي';
          break;
      }
      // إزالة التشكيل (الحركات)
      if ('ًٌٍَُِّْ'.contains(c)) continue;
      final isSpace = c == ' ' || c == '\t';
      if (isSpace) {
        if (lastWasSpace) continue;
        lastWasSpace = true;
        buffer.write(' ');
        continue;
      }
      lastWasSpace = false;
      buffer.write(c);
    }
    return buffer.toString().trim();
  }

  String get nameKey => normalizeName(fullName);

  DailyWorker copyWith({
    int? id,
    int? branchId,
    String? fullName,
    String? jobTitle,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return DailyWorker(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      fullName: fullName ?? this.fullName,
      jobTitle: jobTitle ?? this.jobTitle,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch_id': branchId,
      'full_name': fullName.trim(),
      'name_key': nameKey,
      'job_title': jobTitle.trim(),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory DailyWorker.fromMap(Map<String, dynamic> map) {
    final rawIsActive = map['is_active'] ?? map['isActive'];
    final isActive = rawIsActive == 1 || rawIsActive == true || rawIsActive == '1' || rawIsActive == 'true' || rawIsActive == null;
    final fullName = (map['full_name'] ?? map['fullName'] ?? '').toString().trim();
    final jobTitleRaw = (map['job_title'] ?? map['jobTitle'] ?? '').toString().trim();
    final branchIdRaw = map['branch_id'] ?? map['branchId'] ?? 1;
    final branchId = branchIdRaw is int ? branchIdRaw : (int.tryParse(branchIdRaw.toString()) ?? 1);
    final idRaw = map['id'];
    final id = idRaw != null ? (idRaw is int ? idRaw : int.tryParse(idRaw.toString())) : null;
    final createdAtRaw = map['created_at'] ?? map['createdAt'];

    return DailyWorker(
      id: id,
      branchId: branchId,
      fullName: fullName,
      jobTitle: jobTitleRaw.isNotEmpty ? jobTitleRaw : 'عامل بالأجر اليومي',
      isActive: isActive,
      createdAt: createdAtRaw != null
          ? DateTime.tryParse(createdAtRaw.toString())
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyWorker && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Checklist {
  final int? id;
  final String title;
  final String type;

  Checklist({
    this.id,
    required this.title,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
    };
  }

  factory Checklist.fromJson(Map<String, dynamic> json) {
    return Checklist(
      id: json['id'] as int?,
      title: json['title'] as String,
      type: json['type'] as String,
    );
  }
}

class ChecklistItem {
  final int? id;
  final int checklistId;
  final String itemName;

  ChecklistItem({
    this.id,
    required this.checklistId,
    required this.itemName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'checklist_id': checklistId,
      'item_name': itemName,
    };
  }

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as int?,
      checklistId: json['checklist_id'] as int,
      itemName: json['item_name'] as String,
    );
  }
}

class HygieneLog {
  final int? id;
  final int branchId;
  final int shiftId;
  final int checklistId;
  final int? employeeId;
  final int createdBy;
  final DateTime createdAt;
  
  final String approvalStatus;
  final int? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;

  HygieneLog({
    this.id,
    required this.branchId,
    required this.shiftId,
    required this.checklistId,
    this.employeeId,
    required this.createdBy,
    DateTime? createdAt,
    this.approvalStatus = 'Pending',
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'shift_id': shiftId,
      'checklist_id': checklistId,
      'employee_id': employeeId,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'approval_status': approvalStatus,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
    };
  }

  factory HygieneLog.fromJson(Map<String, dynamic> json) {
    return HygieneLog(
      id: json['id'] as int?,
      branchId: json['branch_id'] as int,
      shiftId: json['shift_id'] as int,
      checklistId: json['checklist_id'] as int,
      employeeId: json['employee_id'] as int?,
      createdBy: json['created_by'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      approvalStatus: json['approval_status'] as String? ?? 'Pending',
      approvedBy: json['approved_by'] as int?,
      approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at'] as String) : null,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }
}

class HygieneLogDetail {
  final int? id;
  final int hygieneLogId;
  final int checklistItemId;
  final bool isCompliant;
  final String? photoUrl;
  final String? notes;

  HygieneLogDetail({
    this.id,
    required this.hygieneLogId,
    required this.checklistItemId,
    required this.isCompliant,
    this.photoUrl,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hygiene_log_id': hygieneLogId,
      'checklist_item_id': checklistItemId,
      'is_compliant': isCompliant ? 1 : 0,
      'photo_url': photoUrl,
      'notes': notes,
    };
  }

  factory HygieneLogDetail.fromJson(Map<String, dynamic> json) {
    return HygieneLogDetail(
      id: json['id'] as int?,
      hygieneLogId: json['hygiene_log_id'] as int,
      checklistItemId: json['checklist_item_id'] as int,
      isCompliant: (json['is_compliant'] as int) == 1,
      photoUrl: json['photo_url'] as String?,
      notes: json['notes'] as String?,
    );
  }
}
