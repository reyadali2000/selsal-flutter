import 'dart:math' as math;
import '../controllers/raw_water_report_display_controller.dart';
import '../controllers/final_product_report_display_controller.dart';
import '../services/api/water_quality_api_service.dart';
import '../models/water_quality_models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../constants/approval_status.dart';
import '../routes/app_routes.dart';
import '../services/database_helper.dart';
import '../services/pending_approvals_service.dart';
import '../services/user_session_service.dart';
import '../views/dynamic_report_display_view.dart';
import '../views/final_product_report_display_view.dart';
import '../views/hygiene_report_display_view.dart';
import '../views/raw_material_report_display_view.dart';
import '../views/raw_water_report_display_view.dart';

/// إشعار منبثق يظهر للشخص المخول بالاعتماد فور فتحه للنظام.
/// يُعلِمه بوجود تقارير بحاجة لاعتماده، ويتيح له فتح أي تقرير مباشرةً منه.
class PendingApprovalsPopup extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const PendingApprovalsPopup({super.key, required this.items});

  /// يتحقق أولاً من أن المستخدم الحالي مخوّل بالاعتماد، ثم يجلب التقارير
  /// المعلقة لدوره ويُظهر الإشعار المنبثق فقط عند وجود تقارير بحاجة للاعتماد.
  /// يُستدعى هذا التابع بعد تسجيل الدخول (يدوياً أو بالبصمة) مباشرةً.
  static Future<void> showIfAny() async {
    if (!Get.isRegistered<PendingApprovalsService>()) return;
    final service = PendingApprovalsService.to;
    if (!service.currentUserCanApprove) return;

    final pendingItems = await service.fetchPendingApprovalsForCurrentRole();
    if (pendingItems.isEmpty) return;

    await Get.dialog(
      PendingApprovalsPopup(items: pendingItems),
      barrierDismissible: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    final roleTitle = Get.isRegistered<UserSessionService>()
        ? UserSessionService.to.roleTitle
        : 'المعتمد';

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = math.min(screenWidth - 32, 480.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SizedBox(
          width: dialogWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(count, roleTitle),
                  const SizedBox(height: 14),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: count,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _buildItem(context, items[index]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildActions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// رأس الإشعار: أيقونة دائرية + عنوان + رسالة عداد التقارير
  Widget _buildHeader(int count, String roleTitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.fact_check_rounded,
            color: AppColors.primary,
            size: 30,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تقارير بحاجة للاعتماد',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'مرحباً $roleTitle، يوجد $count ${_pendingWord(count)} بانتظار اعتمادك.',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// عنصر تقرير معلق: أيقونة حسب النوع + العنوان + الحالة + التاريخ
  Widget _buildItem(BuildContext context, Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? 'water_log';
    final category = item['category']?.toString();
    final title = item['title']?.toString() ?? 'تقرير #${item['id']}';
    final status = item['approval_status']?.toString() ?? '';
    final createdRaw = item['created_at']?.toString();

    final (icon, color) = _iconForItem(type, category);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openItem(item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _buildSubtitle(status, createdRaw),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: AppColors.muted, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  /// أزرار الإجراءات: عرض الكل (لوحة التحكم) وإغلاق الإشعار
  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        TextButton.icon(
          onPressed: () => Get.back(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text(
            'إغلاق',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const Spacer(),
        Flexible(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Get.back(),
            icon: const Icon(Icons.dashboard_rounded, size: 18),
            label: const Text(
              'عرض لوحة التحكم',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  /// اختيار الأيقونة واللون حسب نوع/فئة التقرير
  (IconData, Color) _iconForItem(String type, String? category) {
    switch (type) {
      case 'dynamic':
        return (Icons.description_rounded, const Color(0xFF1565C0));
      case 'hygiene':
        return (Icons.cleaning_services_rounded, const Color(0xFF00897B));
      default:
        if (category == 'Final Product') {
          return (Icons.inventory_2_rounded, const Color(0xFF6A1B9A));
        }
        if (category == 'Raw Material') {
          return (Icons.science_outlined, const Color(0xFFE65100));
        }
        return (Icons.water_drop_rounded, const Color(0xFF0277BD));
    }
  }

  /// سطر فرعي يجمع حالة الاعتماد مع التاريخ
  String _buildSubtitle(String status, String? createdRaw) {
    final label = ApprovalStatus.label(status);
    final date = _formatDate(createdRaw);
    if (date.isEmpty) return label;
    return '$label • $date';
  }

  /// تنسيق التاريخ بصيغة قصيرة (YYYY-MM-DD HH:MM)
  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw.length > 16 ? raw.substring(0, 16) : raw;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  /// كلمة "تقرير" معدودة بشكل صحيح (تقرير / تقريران / تقارير)
  String _pendingWord(int count) {
    if (count == 1) return 'تقرير';
    if (count == 2) return 'تقريران';
    return 'تقارير';
  }

  /// فتح التقرير المحدد مباشرةً من الإشعار ثم إغلاق النافذة المنبثقة.
  /// منطق التنقل متطابق مع بطاقة الاعتمادات المعلقة في لوحة التحكم.
  Future<void> _openItem(Map<String, dynamic> item) async {
    Get.back(); // إغلاق الإشعار المنبثق أولاً

    final type = item['type'];
    final id = item['id'] as int;

    if (type == 'dynamic') {
      if (Get.isRegistered<DynamicReportDisplayController>()) {
        Get.delete<DynamicReportDisplayController>();
      }
      await Get.toNamed(AppRoutes.dynamicReportDisplay, arguments: {
        'reportId': item['report_id'],
        'recordId': id,
      });
      return;
    }

    if (type == 'hygiene') {
      await Get.to(() => HygieneReportDisplayView(reportId: id));
      return;
    }

    if (type == 'raw_material') {
      await Get.to(() => RawMaterialReportDisplayView(reportId: id));
      return;
    }

    // السجلات الثابتة (مياه خام / منتج نهائي)
    WaterQualityLog? log;
    if (Get.isRegistered<WaterQualityApiService>()) {
      try {
        final apiData = await WaterQualityApiService.to.getLogById(id);
        if (apiData != null) {
          final logData = apiData['log'] is Map ? Map<String, dynamic>.from(apiData['log']) : apiData;
          log = WaterQualityLog.fromMap(logData);
        }
      } catch (_) {}
    }
    log ??= await DatabaseHelper.instance.getWaterQualityLogById(id);
    if (log == null) return;
    final cat = item['category'];
    if (cat == 'Final Product') {
      if (Get.isRegistered<FinalProductReportDisplayController>()) {
        Get.delete<FinalProductReportDisplayController>();
      }
      await Get.to(() => FinalProductReportDisplayView(), arguments: log);
    } else if (cat == 'Raw Material') {
      await Get.to(() => RawMaterialReportDisplayView(reportId: id));
    } else {
      if (Get.isRegistered<RawWaterReportDisplayController>()) {
        Get.delete<RawWaterReportDisplayController>();
      }
      await Get.to(() => RawWaterReportDisplayView(), arguments: log);
    }
  }
}
