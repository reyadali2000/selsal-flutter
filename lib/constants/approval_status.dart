import 'package:flutter/material.dart';

/// ثوابت حالة الاعتماد الموحدة لجميع أنواع التقارير في النظام
/// تستخدم في التقارير الثابتة (مياه خام، منتج نهائي، مواد أولية، نظافة)
/// والتقارير الديناميكية على حد سواء
class ApprovalStatus {
  // الحالات الأساسية الحالية
  static const String draft = 'Draft';
  static const String pendingQS = 'Pending_QS';
  static const String pendingQM = 'Pending_QM';
  static const String pendingGM = 'Pending_GM';
  static const String approved = 'Approved';
  static const String rejected = 'Rejected';

  // الحالات الجديدة لدورة الإجراء التصحيحي
  static const String correctiveInProgress = 'Corrective_In_Progress';
  static const String pendingQMDecision = 'Pending_QM_Decision';
  static const String pendingGMDecision = 'Pending_GM_Decision';
  static const String rejectedByGM = 'Rejected_By_GM';
  static const String rejectedFinal = 'Rejected_Final';
  static const String closed = 'Closed';

  // الحالات الجديدة للاعتماد على مرحلتين (نتائج الميكروبيولوجي المتأخرة)
  // المرحلة الأولى اكتملت ويسري التقرير بانتظار إدخال النتائج الميكروبيولوجية
  static const String awaitingMicroResults = 'Awaiting_Micro_Results';
  // المرحلة الثانية: النتائج أُدخلت وبانتظار اعتماد مدير الجودة
  static const String pendingMicroQM = 'Pending_Micro_QM';
  // المرحلة الثانية: اعتمد مدير الجودة وبانتظار الاعتماد النهائي لمدير المصنع
  static const String pendingMicroGM = 'Pending_Micro_GM';
  // الحالات الخاصة برفض الفحص الميكروبيولوجي بشكل مستقل عن التقرير الأولي
  static const String microRejected = 'Micro_Rejected';
  static const String microResamplePending = 'Micro_Resample_Pending';
  static const String microCorrectiveInProgress =
      'Micro_Corrective_In_Progress';

  /// الحالات التي تعتبر "قيد التنفيذ" (لم تُغلق بعد)
  static const List<String> activeStatuses = [
    draft,
    pendingQS,
    pendingQM,
    pendingGM,
    rejected,
    correctiveInProgress,
    pendingQMDecision,
    pendingGMDecision,
    awaitingMicroResults,
    pendingMicroQM,
    pendingMicroGM,
    microRejected,
    microResamplePending,
    microCorrectiveInProgress,
  ];

  /// الحالات التي تستلزم إجراءً من المستخدم
  static const List<String> actionRequiredStatuses = [
    rejected,
    correctiveInProgress,
    pendingQMDecision,
    pendingGMDecision,
    awaitingMicroResults,
    pendingMicroQM,
    pendingMicroGM,
    microRejected,
    microResamplePending,
    microCorrectiveInProgress,
  ];

  /// التسمية العربية المعروضة للحالة
  static String label(String status) {
    switch (status) {
      case draft:
        return 'مسودة';
      case pendingQS:
        return 'بانتظار اعتماد مشرف الجودة';
      case pendingQM:
        return 'بانتظار اعتماد مدير الجودة';
      case pendingGM:
        return 'بانتظار اعتماد مدير المصنع';
      case approved:
        return 'معتمد';
      case rejected:
        return 'مرفوض — تنفيذ إجراء تصحيحي';
      case correctiveInProgress:
        return 'الإجراء التصحيحي قيد التنفيذ';
      case pendingQMDecision:
        return 'بانتظار اعتماد مدير الجودة للإجراء التصحيحي';
      case pendingGMDecision:
        return 'بانتظار القرار النهائي لمدير المصنع على الإجراء التصحيحي';
      case rejectedByGM:
      case rejectedFinal:
        return 'مرفوض نهائياً (انتهاء دورة الاعتماد)';
      case closed:
        return 'معتمد بعد إجراء تصحيحي';
      case awaitingMicroResults:
        return 'معتمد مبدئياً — بانتظار نتائج الفحص الميكروبيولوجي';
      case pendingMicroQM:
        return 'بانتظار اعتماد مدير الجودة لنتائج الفحص الميكروبيولوجي';
      case pendingMicroGM:
        return 'بانتظار اعتماد مدير المصنع لنتائج الفحص الميكروبيولوجي';
      case microRejected:
        return 'نتائج الفحص الميكروبيولوجي مرفوضة — الفحص الأولي معتمد';
      case microResamplePending:
        return 'مرفوض — بانتظار إعادة سحب عينة ميكروبيولوجية جديدة';
      case microCorrectiveInProgress:
        return 'إجراء تصحيحي ميكروبيولوجي قيد التنفيذ';
      default:
        return status;
    }
  }

  /// التسمية المختصرة للبطاقات
  static String shortLabel(String status) {
    switch (status) {
      case draft:
        return 'مسودة';
      case pendingQS:
        return 'بانتظار مشرف الجودة';
      case pendingQM:
        return 'بانتظار مدير الجودة';
      case pendingGM:
        return 'بانتظار مدير المصنع';
      case approved:
        return 'معتمد';
      case rejected:
        return 'مرفوض';
      case correctiveInProgress:
        return 'تصحيحي قيد التنفيذ';
      case pendingQMDecision:
        return 'بانتظار قرار مدير الجودة';
      case pendingGMDecision:
        return 'بانتظار قرار مدير المصنع';
      case rejectedByGM:
      case rejectedFinal:
        return 'مرفوض نهائياً';
      case closed:
        return 'معتمد بعد إجراء تصحيحي';
      case awaitingMicroResults:
        return 'بانتظار نتائج الميكروبيولوجي';
      case pendingMicroQM:
        return 'الميكروبيولوجي بانتظار مدير الجودة';
      case pendingMicroGM:
        return 'الميكروبيولوجي بانتظار مدير المصنع';
      case microRejected:
        return 'الميكروبيولوجي مرفوض';
      case microResamplePending:
        return 'بانتظار إعادة السحب';
      case microCorrectiveInProgress:
        return 'تصحيحي ميكروبيولوجي';
      default:
        return status;
    }
  }

  /// لون الحالة المستخدم في الشارات والبطاقات
  static Color color(String status) {
    switch (status) {
      case draft:
        return const Color(0xFF607D8B);
      case pendingQS:
        return const Color(0xFFF57F17); // Yellow/Orange for Supervisor
      case pendingQM:
        return const Color(0xFFE65100);
      case pendingGM:
        return const Color(0xFF6A1B9A);
      case approved:
      case closed:
        return const Color(0xFF2E7D32);
      case rejected:
        return const Color(0xFFC62828);
      case rejectedByGM:
      case rejectedFinal:
        return const Color(0xFF8B0000);
      case correctiveInProgress:
        return const Color(0xFF1565C0);
      case pendingQMDecision:
        return const Color(0xFFEF6C00);
      case pendingGMDecision:
        return const Color(0xFFAD6800);
      case awaitingMicroResults:
        return const Color(0xFF00838F);
      case pendingMicroQM:
        return const Color(0xFFE65100);
      case pendingMicroGM:
        return const Color(0xFF6A1B9A);
      case microRejected:
        return const Color(0xFFC62828);
      case microResamplePending:
        return const Color(0xFFD84315);
      case microCorrectiveInProgress:
        return const Color(0xFF1565C0);
      default:
        return Colors.blueGrey;
    }
  }

  /// أيقونة الحالة
  static IconData icon(String status) {
    switch (status) {
      case draft:
        return Icons.edit_note;
      case pendingQS:
        return Icons.person_search;
      case pendingQM:
        return Icons.hourglass_top_rounded;
      case pendingGM:
        return Icons.verified_user;
      case approved:
        return Icons.check_circle;
      case rejected:
        return Icons.cancel;
      case correctiveInProgress:
        return Icons.build_circle;
      case pendingQMDecision:
        return Icons.fact_check_outlined;
      case pendingGMDecision:
        return Icons.pending_actions;
      case rejectedByGM:
        return Icons.block;
      case closed:
        return Icons.task_alt;
      case awaitingMicroResults:
        return Icons.science_outlined;
      case pendingMicroQM:
        return Icons.hourglass_top_rounded;
      case pendingMicroGM:
        return Icons.verified_user;
      default:
        return Icons.info;
    }
  }

  /// هل الحالة نهائية (مغلقة تماماً)؟
  static bool isFinal(String status) =>
      status == approved ||
      status == closed ||
      status == rejectedByGM ||
      status == rejectedFinal;

  /// هل التقرير تم اعتماده نهائياً (سواء اعتماد مباشر أو بعد إغلاق الإجراء التصحيحي)؟
  static bool isFinalApproved(String status) =>
      status == approved || status == closed;

  /// هل التقرير مغلق ومعتمد بعد إجراء تصحيحي؟
  static bool isClosed(String status) => status == closed;

  /// هل التقرير في حالة رفض قاطع ونهائي (أُغلقت الدورة بالكامل ولا يمكن اتخاذ أي إجراء بعدها)؟
  static bool isFinalRejection(String? status) {
    if (status == null) return false;
    return status == rejectedByGM || status == rejectedFinal;
  }

  /// فحص ما إذا كان نوع التقرير يتضمن مرحلة اعتماد لمدير المصنع
  static bool hasGmApprovalStep(String reportCategory) {
    final cat = reportCategory.trim().toLowerCase();
    if (cat.contains('final') ||
        cat.contains('water') ||
        cat.contains('raw') ||
        cat.contains('مياه') ||
        cat.contains('منتج') ||
        cat.contains('مواد') ||
        cat.contains('hygiene') ||
        cat.contains('نظافة')) {
      return true;
    }
    return false;
  }

  /// هل الحالة تتطلب إجراءً تصحيحياً أو مراجعة إجراء تصحيحي؟
  static bool requiresCorrectiveAction(String status) =>
      status == rejected ||
      status == correctiveInProgress ||
      status == pendingQMDecision ||
      status == pendingGMDecision;

  /// هل التقرير في حالة رفض ساري (مرفوض عاديًا أو رُفض الإجراء التصحيحي)؟
  /// ملاحظة: Corrective_In_Progress تعني أن الرفض حدث وتم تعيين إجراء تصحيحي.
  static bool isRejectedStatus(String status) =>
      status == rejected ||
      status == correctiveInProgress ||
      status == pendingQMDecision ||
      status == rejectedByGM ||
      status == rejectedFinal ||
      status == pendingGMDecision;

  /// استخراج اسم الجهة التي رفضت التقرير
  /// في حالة Rejected_By_GM يكون الرافض هو مدير المصنع (gmDecisionBy)،
  /// وفي باقي حالات الرفض يكون rejectedBy بصيغة "الاسم (المسمى الوظيفي)".
  static String? rejectorName({
    String? rejectedBy,
    String? gmDecisionBy,
    required String status,
  }) {
    if (status == rejectedByGM) {
      return (gmDecisionBy != null && gmDecisionBy.isNotEmpty)
          ? gmDecisionBy
          : rejectedBy;
    }
    return rejectedBy;
  }

  /// هل الرفض صادر من مدير المصنع؟
  static bool rejectedByFactoryManager({
    String? rejectedBy,
    String? gmDecisionBy,
    String? qmApprovedBy,
    required String status,
  }) {
    if (!isRejectedStatus(status)) return false;
    if (status == rejectedByGM) return true;
    if (gmDecisionBy != null && gmDecisionBy.trim().isNotEmpty) return true;
    final name =
        rejectorName(
          rejectedBy: rejectedBy,
          gmDecisionBy: gmDecisionBy,
          status: status,
        ) ??
        '';
    if (name.isNotEmpty) {
      final normalized = name.toLowerCase();
      if (name.contains('مدير المصنع') ||
          name.contains('مدير مصنع') ||
          name.contains('مصنع ') ||
          name.contains('المدير العام') ||
          normalized.contains('factory manager') ||
          normalized.contains('general manager') ||
          normalized.contains('(gm)') ||
          normalized.contains('(gm2)')) {
        return true;
      }
    }
    // إذا كان التقرير قد اعتُمد من مدير الجودة قبل الرفض، فالرفض صادر حتماً من مرحلة مدير المصنع
    final effectiveQm = (qmApprovedBy ?? '').trim();
    if (effectiveQm.isNotEmpty && !effectiveQm.contains('___')) {
      return true;
    }
    return false;
  }

  /// هل الرفض صادر من مشرف الجودة (مرحلة المراجعة والتدقيق الأولى)؟
  static bool rejectedByQualitySupervisor({
    String? rejectedBy,
    String? qsApprovedBy,
    String? qmApprovedBy,
    required String status,
  }) {
    if (!isRejectedStatus(status)) return false;

    // إذا كان الرفض صادراً من مدير المصنع
    if (rejectedByFactoryManager(rejectedBy: rejectedBy, status: status)) {
      return false;
    }

    // إذا كان التقرير قد اعتُمد من مشرف الجودة قبل الرفض، فالرفض صادر حتماً من مرحلة لاحقة (مدير الجودة أو مدير المصنع)
    final effectiveQs = (qsApprovedBy ?? '').trim();
    if (effectiveQs.isNotEmpty && !effectiveQs.contains('___')) {
      return false;
    }

    final name = (rejectedBy ?? '').toLowerCase();
    if (name.contains('مشرف') ||
        name.contains('supervisor') ||
        name.contains('مشرف الجودة') ||
        name.contains('(qs)') ||
        name.contains('مسؤول المختبر') ||
        name.contains('مسؤول مختبر')) {
      return true;
    }

    return false;
  }

  /// هل الرفض صادر من مدير الجودة (أو في مرحلة مراجعة واعتماد الجودة)؟
  static bool rejectedByQualityManager({
    String? rejectedBy,
    String? gmDecisionBy,
    String? qmApprovedBy,
    String? qsApprovedBy,
    required String status,
  }) {
    if (!isRejectedStatus(status)) return false;
    // إذا كان الرفض صادراً من مدير المصنع فلا يمكن أن يكون من مدير الجودة
    if (rejectedByFactoryManager(
      rejectedBy: rejectedBy,
      gmDecisionBy: gmDecisionBy,
      qmApprovedBy: qmApprovedBy,
      status: status,
    )) {
      return false;
    }
    // إذا كان الرفض صادراً من مشرف الجودة فلا يمكن أن يكون من مدير الجودة
    if (rejectedByQualitySupervisor(
      rejectedBy: rejectedBy,
      qsApprovedBy: qsApprovedBy,
      qmApprovedBy: qmApprovedBy,
      status: status,
    )) {
      return false;
    }
    // في أي حالة رفض أخرى لم تصدر من مدير المصنع أو مشرف الجودة، فهي صادرة في مرحلة اعتماد مدير الجودة
    return true;
  }

  /// هل اعتمد مشرف الجودة التقرير قبل رفضه لاحقاً من مدير الجودة أو مدير المصنع؟
  static bool wasApprovedByQsPriorToRejection({
    String? qsApprovedBy,
    required String status,
  }) {
    if (!isRejectedStatus(status)) return false;
    final effectiveQs = (qsApprovedBy ?? '').trim();
    return effectiveQs.isNotEmpty && !effectiveQs.contains('___');
  }

  /// هل اعتمد مدير الجودة التقرير قبل رفض مدير المصنع؟
  /// يتحقق مما إذا كان هناك اسم اعتماد لمدير الجودة مسجلاً في السجل،
  /// بينما الحالة الحالية مرفوضة بقرار مدير المصنع.
  /// هل رُفض التقرير من مدير الجودة (بطلب إجراء تصحيحي) قبل أو بالتوازي مع رفض مدير المصنع؟
  static bool wasRejectedByQmPriorToGmRejection({
    String? rejectedBy,
    String? gmDecisionBy,
    required String status,
  }) {
    if (!isRejectedStatus(status)) return false;
    final r = (rejectedBy ?? '').trim();
    if (r.isEmpty || r.contains('___')) return false;
    final g = (gmDecisionBy ?? '').trim();
    if (g.isNotEmpty && r == g) return false;
    final rLower = r.toLowerCase();
    if (r.contains('مدير المصنع') ||
        r.contains('المدير العام') ||
        r.contains('مدير مصنع') ||
        rLower.contains('factory manager') ||
        rLower.contains('general manager') ||
        rLower.contains('(gm)')) {
      return false;
    }
    return true;
  }

  static bool wasApprovedByQmPriorToGmRejection({
    String? qmApprovedBy,
    String? microQmApprovedBy,
    String? rejectedBy,
    String? gmDecisionBy,
    required String status,
  }) {
    final effectiveQm = (microQmApprovedBy ?? qmApprovedBy ?? '').trim();
    if (!rejectedByFactoryManager(
      rejectedBy: rejectedBy,
      gmDecisionBy: gmDecisionBy,
      qmApprovedBy: effectiveQm,
      status: status,
    )) {
      return false;
    }
    return effectiveQm.isNotEmpty && !effectiveQm.contains('___');
  }

  /// هل يمكن لمدير الجودة اتخاذ قرار بشأن الإجراء التصحيحي في هذه الحالة؟
  static bool qmCanDecide(String status) => status == pendingQMDecision;

  /// هل يمكن لمدير المصنع اتخاذ قرار على هذه الحالة؟
  static bool gmCanDecide(String status) =>
      status == pendingGM ||
      status == pendingGMDecision ||
      status == pendingMicroGM;

  /// التحقق من صحة انتقال الحالة لمنع الكتابة فوق حالة أحدث بالخطأ
  static bool canTransition(String currentStatus, String nextStatus) {
    if (currentStatus == nextStatus) return true;
    switch (currentStatus) {
      case draft:
      case 'مسودة':
        return nextStatus == pendingQS ||
            nextStatus == pendingQM ||
            nextStatus == approved;
      case pendingQS:
        return nextStatus == pendingQM ||
            nextStatus == rejected ||
            nextStatus == correctiveInProgress;
      case pendingQM:
        return nextStatus == pendingGM ||
            nextStatus == approved ||
            nextStatus == awaitingMicroResults ||
            nextStatus == rejected ||
        nextStatus == correctiveInProgress ||
            nextStatus == pendingGMDecision ||
            nextStatus == rejectedByGM ||
            nextStatus == rejectedFinal;
      case pendingGM:
        return nextStatus == approved ||
            nextStatus == awaitingMicroResults ||
            nextStatus == rejected ||
        nextStatus == correctiveInProgress || nextStatus == rejectedByGM;
      case rejected:
      case correctiveInProgress:
        return nextStatus == pendingQMDecision ||
            nextStatus == pendingGMDecision ||
        nextStatus == correctiveInProgress ||
            nextStatus == rejectedFinal ||
            nextStatus == rejectedByGM;
      case pendingQMDecision:
        return nextStatus == pendingGMDecision ||
            nextStatus == closed ||
            nextStatus == awaitingMicroResults ||
            nextStatus == correctiveInProgress ||
        nextStatus == rejectedByGM || nextStatus == rejectedFinal;
      case pendingGMDecision:
        return nextStatus == closed ||
            nextStatus == awaitingMicroResults ||
            nextStatus == rejectedByGM;
      case rejectedByGM:
      case rejectedFinal:
        // حالات إغلاق نهائية مقفلة تماماً لا يمكن الانتقال منها لأي حالة أخرى
        return false;
      case awaitingMicroResults:
      case microResamplePending:
      case microRejected:
      case microCorrectiveInProgress:
        return nextStatus == pendingMicroQM ||
            nextStatus == pendingQMDecision ||
            nextStatus == microCorrectiveInProgress;
      case pendingMicroQM:
        return nextStatus == pendingMicroGM ||
            nextStatus == microRejected ||
            nextStatus == microResamplePending ||
            nextStatus == microCorrectiveInProgress ||
            nextStatus == rejected ||
            nextStatus == correctiveInProgress;
      case pendingMicroGM:
        return nextStatus == approved ||
            nextStatus == microRejected ||
            nextStatus == microResamplePending ||
            nextStatus == microCorrectiveInProgress ||
            nextStatus == rejected ||
            nextStatus == correctiveInProgress;
      case closed:
        // يُسمح فقط بالانتقال إلى Pending_Micro_QM إذا كانت نتائج الميكروبيولوجي معلقة
        return nextStatus == pendingMicroQM ||
            nextStatus == awaitingMicroResults;
      default:
        return false;
    }
  }

  /// هل الحالة ضمن دورة نتائج الميكروبيولوجي (سواء انتظار أو اعتماد أو رفض ميكرو معزول)؟
  static bool isMicroStage(String status) =>
      status == awaitingMicroResults ||
      status == pendingMicroQM ||
      status == pendingMicroGM ||
      status == microRejected ||
      status == microResamplePending ||
      status == microCorrectiveInProgress;

  /// هل التقرير في حالة رفض ميكروبيولوجي خاص ومعزول؟
  static bool isMicroRejected(String status) =>
      status == microRejected ||
      status == microResamplePending ||
      status == microCorrectiveInProgress;

  /// هل التقرير معتمد مبدئياً وينتظر إدخال نتائج الميكروبيولوجي فقط؟
  static bool isAwaitingMicroResults(String status) =>
      status == awaitingMicroResults;

  /// وصف موجز للحالة يصلح لبطاقة الإجراء التصحيحي
  static String description(String status) {
    switch (status) {
      case draft:
        return 'التقرير لم يُرفع للاعتماد بعد.';
      case pendingQS:
        return 'تم إرسال التقرير وهو بانتظار مراجعة واعتماد مشرف الجودة.';
      case pendingQM:
        return 'تم إرسال التقرير وهو بانتظار مراجعة واعتماد مدير الجودة.';
      case pendingGM:
        return 'تم اعتماد التقرير من مدير الجودة وبانتظار الاعتماد النهائي لمدير المصنع.';
      case approved:
        return 'تم اعتماد التقرير رسمياً من جميع المستويات وهو مقفل.';
      case rejected:
        return 'تم رفض التقرير وتعيين إجراء تصحيحي للمسؤول المختص.';
      case correctiveInProgress:
        return 'المسؤول المختص يعمل على تنفيذ الإجراء التصحيحي المطلوب.';
      case pendingQMDecision:
        return 'تم توثيق الإجراء التصحيحي وبانتظار مراجعة واعتماد مدير الجودة.';
      case pendingGMDecision:
        return 'اعتمد مدير الجودة الإجراء التصحيحي وبانتظار القرار النهائي لمدير المصنع.';
      case rejectedByGM:
        return 'تم الرفض النهائي للإجراء التصحيحي، وانتهت دورة الاعتماد بإغلاق التقرير بالرفض القاطع.';
      case closed:
        return 'تم اعتماد الإجراء التصحيحي وإغلاق التقرير نهائياً بالاعتماد.';
      case awaitingMicroResults:
        return 'اعتُمد التقرير مبدئياً من مدير الجودة ومدير المصنع، وهو بانتظار إدخال نتائج الفحص الميكروبيولوجي (تتطلب 24 ساعة) ثم جولة اعتماد ثانية.';
      case pendingMicroQM:
        return 'أُدخلت نتائج الفحص الميكروبيولوجي وبانتظار مراجعة واعتماد مدير الجودة.';
      case pendingMicroGM:
        return 'اعتمد مدير الجودة نتائج الفحص الميكروبيولوجي وبانتظار الاعتماد النهائي لمدير المصنع.';
      case microRejected:
        return 'تم رفض نتائج الفحص الميكروبيولوجي مع الحفاظ على التوقيعات والاعتماد الفيزيوكيميائي الأولي سارياً.';
      case microResamplePending:
        return 'تم رفض نتائج العينة الميكروبيولوجية وبانتظار قيام أخصائي الجودة بإعادة سحب عينة جديدة وفحصها.';
      case microCorrectiveInProgress:
        return 'تم تسجيل عدم مطابقة ميكروبيولوجية والإجراء التصحيحي الخاص بالتعقيم أو الفلاتر قيد التنفيذ.';
      default:
        return '';
    }
  }
}

/// تصنيفات أسباب الرفض الافتراضية لتسهيل الاختيار
class RejectionCategory {
  static const String dataError = 'خطأ في إدخال البيانات';
  static const String missingData = 'بيانات ناقصة أو غير مكتملة';
  static const String nonCompliance = 'عدم مطابقة للمعايير المعتمدة';
  static const String documentation = 'مشكلة في التوثيق أو المرفقات';
  static const String procedural = 'مخالفة إجرائية';
  static const String other = 'سبب آخر';

  static const List<String> all = [
    dataError,
    missingData,
    nonCompliance,
    documentation,
    procedural,
    other,
  ];
}

/// مستويات الخطورة للتقرير المرفوض
class SeverityLevel {
  static const String low = 'منخفضة';
  static const String medium = 'متوسطة';
  static const String high = 'عالية';
  static const String critical = 'حرجة';

  static const List<String> all = [low, medium, high, critical];

  /// لون مميز لكل مستوى خطورة
  static Color color(String level) {
    switch (level) {
      case low:
        return Colors.green.shade700;
      case medium:
        return Colors.orange.shade700;
      case high:
        return Colors.deepOrange.shade700;
      case critical:
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  /// ترتيب أولوية المعالجة (الأعلى = أولوية أكبر)
  static int weight(String level) {
    switch (level) {
      case low:
        return 1;
      case medium:
        return 2;
      case high:
        return 3;
      case critical:
        return 4;
      default:
        return 0;
    }
  }
}
