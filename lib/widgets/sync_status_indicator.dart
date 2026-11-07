import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../services/sync/sync_manager.dart';
import '../services/sync/sync_queue.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

/// مؤشر وأيقونة حالة المزامنة والاتصال في الشريط العلوي (Sync Status Indicator)
class SyncStatusIndicator extends StatefulWidget {
  final Color? color;
  const SyncStatusIndicator({super.key, this.color});

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();

  /// فتح نافذة تفاصيل المزامنة
  static void showSyncDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _SyncDetailsSheet(),
    );
  }
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<SyncManager>()) return const SizedBox.shrink();
    final syncMgr = SyncManager.to;

    return Obx(() {
      final isOnline = syncMgr.isOnline.value;
      final isSyncing = syncMgr.isSyncing.value;
      final pending = syncMgr.pendingCount.value;

      if (isSyncing) {
        if (!_animController.isAnimating) {
          _animController.repeat();
        }
      } else {
        if (_animController.isAnimating) {
          _animController.stop();
          _animController.reset();
        }
      }

      IconData iconData;
      Color iconColor = widget.color ?? Colors.white;
      String tooltipMsg;

      if (isSyncing) {
        iconData = Icons.sync_rounded;
        tooltipMsg = 'جاري مزامنة البيانات مع الخادم...';
      } else if (!isOnline) {
        iconData = Icons.cloud_off_rounded;
        iconColor = Colors.amber.shade300;
        tooltipMsg = 'العمل بدون اتصال (Offline) - العمليات محفوظة محلياً';
      } else if (pending > 0) {
        iconData = Icons.cloud_upload_outlined;
        iconColor = Colors.orange.shade300;
        tooltipMsg = 'يوجد $pending عملية بانتظار المزامنة';
      } else {
        iconData = Icons.cloud_done_outlined;
        tooltipMsg = 'جميع البيانات متزامنة مع الخادم';
      }

      return Tooltip(
        message: tooltipMsg,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => SyncStatusIndicator.showSyncDetails(context),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isSyncing)
                    RotationTransition(
                      turns: _animController,
                      child: Icon(iconData, color: iconColor, size: 22),
                    )
                  else
                    Icon(iconData, color: iconColor, size: 22),
                  if (pending > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.2),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 17,
                            minHeight: 17,
                          ),
                          child: Center(
                            child: Text(
                              pending > 99 ? '99+' : '$pending',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// نافذة سفلية تعرض تفاصيل حالة المزامنة والاتصال مع إمكانية المزامنة اليدوية
class _SyncDetailsSheet extends StatefulWidget {
  const _SyncDetailsSheet();

  @override
  State<_SyncDetailsSheet> createState() => _SyncDetailsSheetState();
}

class _SyncDetailsSheetState extends State<_SyncDetailsSheet> {
  List<Map<String, dynamic>> _pendingItems = [];
  bool _isLoadingItems = true;

  @override
  void initState() {
    super.initState();
    _loadPendingList();
  }

  Future<void> _loadPendingList() async {
    try {
      final items = await SyncQueue.instance.getPending(limit: 15);
      if (mounted) {
        setState(() {
          _pendingItems = items;
          _isLoadingItems = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingItems = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncMgr = SyncManager.to;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // مقبض السحب
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // العنوان
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMedium.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cloud_sync_outlined,
                        color: AppColors.primaryDark,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'حالة المزامنة والاتصال',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),

              // محتوى الحالة
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  shrinkWrap: true,
                  children: [
                    // بطاقة حالة الشبكة
                    Obx(() {
                      final isOnline = syncMgr.isOnline.value;
                      final lastSync = syncMgr.lastSyncAt.value;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              isOnline
                                  ? Colors.green.shade50.withValues(
                                    alpha: isDark ? 0.12 : 0.7,
                                  )
                                  : Colors.amber.shade50.withValues(
                                    alpha: isDark ? 0.12 : 0.7,
                                  ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                isOnline
                                    ? Colors.green.shade300.withValues(
                                      alpha: 0.5,
                                    )
                                    : Colors.amber.shade400.withValues(
                                      alpha: 0.5,
                                    ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isOnline
                                      ? Icons.wifi_rounded
                                      : Icons.wifi_off_rounded,
                                  color:
                                      isOnline
                                          ? Colors.green.shade700
                                          : Colors.amber.shade800,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isOnline
                                            ? 'متصل بخادم المصنع'
                                            : 'غير متصل (الوضع المحلي)',
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color:
                                              isOnline
                                                  ? Colors.green.shade800
                                                  : Colors.amber.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isOnline
                                            ? 'الاتصال مستقر مع الخادم السحابي'
                                            : 'التقارير تُحفظ محلياً وتُرفع تلقائياً عند عودة الاتصال',
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (lastSync != null) ...[
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'آخر مزامنة ناجحة:',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'yyyy/MM/dd  hh:mm a',
                                    ).format(lastSync),
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // قسم السجلات المعلقة
                    Obx(() {
                      final pending = syncMgr.pendingCount.value;
                      final isSyncing = syncMgr.isSyncing.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'العمليات بانتظار الرفع ($pending)',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (pending > 0 || syncMgr.isOnline.value)
                                ElevatedButton.icon(
                                  onPressed:
                                      isSyncing
                                          ? null
                                          : () async {
                                            await syncMgr.flushOutbox();
                                            await _loadPendingList();
                                          },
                                  icon:
                                      isSyncing
                                          ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : const Icon(
                                            Icons.sync_rounded,
                                            size: 16,
                                          ),
                                  label: Text(
                                    isSyncing ? 'جاري الرفع...' : 'مزامنة الآن',
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryDark,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (_isLoadingItems)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else if (_pendingItems.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? AppColors.darkSurface
                                        : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green.shade600,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'جميع التقارير متزامنة ومحفوظة بالكامل في السيرفر',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _pendingItems.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = _pendingItems[index];
                                final endpoint =
                                    item['endpoint'] as String? ?? '';
                                final attempts = item['attempts'] as int? ?? 0;
                                final createdAt =
                                    item['created_at'] as String? ?? '';

                                String label = 'طلب معلق';
                                if (endpoint.contains(
                                  '/DynamicReports/records',
                                )) {
                                  label = 'تقرير جودة ديناميكي';
                                } else if (endpoint.contains('/approvals')) {
                                  label = 'قرار اعتماد';
                                }

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isDark
                                            ? AppColors.darkSurface
                                            : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.schedule_rounded,
                                          color: Colors.orange.shade800,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              label,
                                              style: const TextStyle(
                                                fontFamily: AppTheme.fontFamily,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              'تاريخ الإدخال: ${createdAt.length >= 16 ? createdAt.substring(0, 16).replaceAll("T", " ") : createdAt}',
                                              style: TextStyle(
                                                fontFamily: AppTheme.fontFamily,
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (attempts > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            '$attempts محاولات',
                                            style: TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: 10,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      );
                    }),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
