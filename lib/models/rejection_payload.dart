import 'package:flutter/material.dart';

/// حزمة بيانات الرفض الموحدة
/// تجمع كل المعلومات التي يُدخلها مدير الجودة (أي معتمد يرفض) عند رفض التقرير،
/// بالإضافة إلى بيانات الإجراء التصحيحي المطلوب تنفيذه.
///
/// تُستخدم عبر جميع أنواع التقارير (مياه خام، منتج نهائي، مواد أولية، نظافة، ديناميكي)
/// لضمان اتساق دورة الرفض والإصلاح في كامل النظام.
class RejectionPayload {
  /// سبب الرفض (إلزامي)
  final String reason;

  /// تصنيف سبب الرفض (اختياري — قائمة منسدلة)
  final String? category;

  /// مستوى الخطورة (اختياري)
  final String? severity;

  /// ملاحظات إضافية / أدلة / مرفقات نصية
  final String? notes;

  /// المنتجات أو الكميات المتأثرة (تأثير على الإنتاج)
  final String? affectedProducts;

  /// الإجراء الفوري المتخذ (عزل، إيقاف، إشعار...)
  final String? immediateAction;

  /// الإجراء التصحيحي المطلوب تنفيذه
  final String? correctiveAction;

  /// المسؤول عن تنفيذ الإجراء التصحيحي
  final String? correctiveOwner;

  /// الموعد المستهدف للإغلاق
  final DateTime? dueDate;

  const RejectionPayload({
    required this.reason,
    this.category,
    this.severity,
    this.notes,
    this.affectedProducts,
    this.immediateAction,
    this.correctiveAction,
    this.correctiveOwner,
    this.dueDate,
  });

  /// إنشاء نسخة محدثة من الحزمة
  RejectionPayload copyWith({
    String? reason,
    String? category,
    String? severity,
    String? notes,
    String? affectedProducts,
    String? immediateAction,
    String? correctiveAction,
    String? correctiveOwner,
    DateTime? dueDate,
  }) {
    return RejectionPayload(
      reason: reason ?? this.reason,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      notes: notes ?? this.notes,
      affectedProducts: affectedProducts ?? this.affectedProducts,
      immediateAction: immediateAction ?? this.immediateAction,
      correctiveAction: correctiveAction ?? this.correctiveAction,
      correctiveOwner: correctiveOwner ?? this.correctiveOwner,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  /// التحقق من صحة الحزمة — سبب الرفض إلزامي
  bool get isValid => reason.trim().isNotEmpty;

  /// هل توجد بيانات إجراء تصحيحي كافية لإرساله لمدير المصنع؟
  bool get hasCorrectiveAction =>
      (correctiveAction ?? '').trim().isNotEmpty &&
      (correctiveOwner ?? '').trim().isNotEmpty;

  /// تحويل الحزمة إلى Map لحفظها في قاعدة البيانات
  /// الحقول الفارغة تُحفظ كـ null لتجنب الكتابة فوق بيانات سابقة
  Map<String, dynamic> toDbMap() {
    final map = <String, dynamic>{};
    void put(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        map[key] = value.trim();
      }
    }

    put('rejection_reason', reason);
    put('rejection_category', category);
    put('severity_level', severity);
    put('rejection_notes', notes);
    put('affected_products', affectedProducts);
    put('immediate_action', immediateAction);
    put('corrective_action', correctiveAction);
    put('corrective_owner', correctiveOwner);
    if (dueDate != null) {
      map['corrective_due_date'] = dueDate!.toIso8601String();
    }
    return map;
  }

  /// ملخص نصي مختصر للعرض في البطاقات والقوائم
  String get summary {
    final parts = <String>[];
    if (category != null && category!.isNotEmpty) parts.add(category!);
    if (severity != null && severity!.isNotEmpty) parts.add('خطورة $severity');
    return parts.isEmpty ? reason : '${parts.join(' • ')} — $reason';
  }

  /// وصف تأثير التقرير على الإنتاج والجودة
  String get impactDescription {
    final buffer = StringBuffer();
    if ((affectedProducts ?? '').isNotEmpty) {
      buffer.write('الكميات/المنتجات المتأثرة: $affectedProducts');
    }
    if ((immediateAction ?? '').isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' | ');
      buffer.write('الإجراء الفوري: $immediateAction');
    }
    if ((severity ?? '').isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' | ');
      buffer.write('مستوى الخطورة: $severity');
    }
    return buffer.toString();
  }

  /// القرار المطلوب من مدير المصنع
  String get gmDecisionRequest {
    if (hasCorrectiveAction) {
      return 'اعتماد الإجراء التصحيحي: "$correctiveAction" المناط بـ $correctiveOwner';
    }
    return 'مراجعة سبب الرفض واتخاذ القرار المناسب';
  }

  /// لون مستوى الخطورة الحالي
  Color get severityColor => severity != null
      ? _severityColor(severity!)
      : Colors.grey;

  Color _severityColor(String level) {
    switch (level) {
      case 'منخفضة':
        return Colors.green.shade700;
      case 'متوسطة':
        return Colors.orange.shade700;
      case 'عالية':
        return Colors.deepOrange.shade700;
      case 'حرجة':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }
}
