import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final notifService = NotificationService.to;

    return Obx(() {
      final unread = notifService.unreadCount.value;

      return Tooltip(
        message: 'الإشعارات',
        child: SizedBox(
          width: 44,
          height: 44,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showNotificationsSheet(context),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.2),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                            textAlign: TextAlign.center,
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

  static void showNotificationsSheet(BuildContext context) {
    final notifService = NotificationService.to;
    notifService.loadNotifications();

    if (Get.isBottomSheetOpen == true) {
      Get.back();
    }

    Get.bottomSheet(
      Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          height: Get.height * 0.75,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.notifications_active, color: Color(0xFF0D47A1)),
                        SizedBox(width: 8),
                        Text(
                          'إشعارات النظام',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => notifService.markAllAsRead(),
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text(
                      'تحديد الكل كمقروء',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                    ),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: Obx(() {
                  if (notifService.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final list = notifService.notifications;
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد إشعارات حالياً',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return _buildNotificationItem(item);
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  static Widget _buildNotificationItem(AppNotification item) {
    final timeFormatted = DateFormat('yyyy/MM/dd - hh:mm a', 'en_US').format(item.createdAt);

    Color itemColor;
    IconData itemIcon;
    String badgeText;
    Color badgeColor;

    switch (item.tone) {
      case NotificationTone.approval:
        itemColor = const Color(0xFF2E7D32);
        itemIcon = Icons.check_circle_rounded;
        badgeText = 'معتمد ✓';
        badgeColor = const Color(0xFF2E7D32);
        break;
      case NotificationTone.rejection:
        itemColor = const Color(0xFFC62828);
        itemIcon = Icons.cancel_rounded;
        badgeText = 'مرفوض ✕';
        badgeColor = const Color(0xFFC62828);
        break;
      case NotificationTone.pending:
        itemColor = item.title.contains('مدير المصنع') ? const Color(0xFF6A1B9A) : const Color(0xFF003853);
        itemIcon = Icons.pending_actions_rounded;
        badgeText = 'بانتظار الإجراء';
        badgeColor = Colors.amber.shade800;
        break;
      case NotificationTone.info:
        itemColor = const Color(0xFF0288D1);
        itemIcon = Icons.info_outline;
        badgeText = 'إشعار';
        badgeColor = const Color(0xFF0288D1);
        break;
    }

    return ListTile(
      tileColor: item.isRead ? Colors.transparent : Colors.blue.withValues(alpha: 0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: itemColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(itemIcon, color: itemColor, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                        color: item.isRead ? Colors.black87 : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 0.8),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!item.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              item.body,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeFormatted,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        trailing: item.reportId != null
            ? const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)
            : null,
        onTap: () async {
          if (item.reportId != null) {
            Get.back(); // close bottom sheet
          }
          await NotificationService.to.navigateToReport(item);
        },
      );
  }
}


