class AppNotification {
  final int? id;
  final int? branchId;
  final String title;
  final String body;
  final int? reportId;
  final String? reportCategory;
  final String targetRole; // QualitySpecialist, QualityManager, FactoryManager, All
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    this.id,
    this.branchId,
    required this.title,
    required this.body,
    this.reportId,
    this.reportCategory,
    this.targetRole = 'All',
    this.isRead = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'title': title,
      'body': body,
      'report_id': reportId,
      'report_category': reportCategory,
      'target_role': targetRole,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int?,
      branchId: (json['branch_id'] ?? json['branchId']) as int?,
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      reportId: (json['report_id'] ?? json['reportId']) as int?,
      reportCategory: (json['report_category'] ?? json['reportCategory']) as String?,
      targetRole: (json['target_role'] ?? json['targetRole']) as String? ?? 'All',
      isRead: json['is_read'] == 1 || json['is_read'] == true || json['isRead'] == true,
      createdAt: (json['created_at'] ?? json['createdAt']) != null
          ? DateTime.tryParse((json['created_at'] ?? json['createdAt']).toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification.fromJson(map);

  NotificationTone get tone {
    final t = title.trim();
    final b = body.trim();
    if (t.contains('رفض') || t.contains('مرفوض') || b.contains('رفض') || b.contains('مرفوض') || t.contains('تصحيحي')) {
      return NotificationTone.rejection;
    }
    if ((t.contains('تم اعتماد') || t.contains('معتمد') || t.contains('موافقة') || (t.contains('اعتماد') && !t.contains('بانتظار'))) &&
        !t.contains('بانتظار') && !b.contains('بانتظار الاعتماد') && !b.contains('بانتظار اعتمادك') && !b.contains('بانتظار إدخال')) {
      return NotificationTone.approval;
    }
    if (t.contains('بانتظار') || b.contains('بانتظار') || t.contains('جديد')) {
      return NotificationTone.pending;
    }
    return NotificationTone.info;
  }
}

enum NotificationTone {
  approval,
  rejection,
  pending,
  info,
}

