import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wadialain/models/notification_model.dart';

Widget buildToastCard(AppNotification notif) {
  final Color indicatorColor;
  final IconData iconData;
  final String badgeText;

  switch (notif.tone) {
    case NotificationTone.approval:
      indicatorColor = const Color(0xFF2E7D32);
      iconData = Icons.check_circle_outline_rounded;
      badgeText = 'معتمد';
      break;
    case NotificationTone.rejection:
      indicatorColor = const Color(0xFFC62828);
      iconData = Icons.error_outline_rounded;
      badgeText = 'مرفوض';
      break;
    case NotificationTone.pending:
      indicatorColor = const Color(0xFF1E3A8A);
      iconData = Icons.schedule_rounded;
      badgeText = 'بانتظار الإجراء';
      break;
    case NotificationTone.info:
      indicatorColor = const Color(0xFF0284C7);
      iconData = Icons.notifications_none_rounded;
      badgeText = 'تنبيه';
      break;
  }

  return Directionality(
    textDirection: TextDirection.rtl,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    right: 13,
                    left: 6,
                    top: 8,
                    bottom: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: indicatorColor.withValues(alpha: 0.09),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          iconData,
                          color: indicatorColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notif.title.isNotEmpty ? notif.title : 'إشعار جديد',
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                      height: 1.25,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: indicatorColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: indicatorColor.withValues(alpha: 0.22),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: indicatorColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2.5),
                            Text(
                              notif.body,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                fontWeight: FontWeight.normal,
                                color: Color(0xFF64748B),
                                height: 1.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (notif.reportId != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: indicatorColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: indicatorColor.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'معاينة',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: indicatorColor,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 9.5,
                                color: indicatorColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(width: 2),
                      const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 4.5,
                    color: indicatorColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Executive Toast renders on small screen (320px) without overflow', (tester) async {
    // Set small phone screen size (320px width)
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final notif = AppNotification(
      id: 1,
      title: 'تم اعتماد تقرير فحص المياه الخام رقم 1024 بنجاح من مدير الجودة نبيل مراد',
      body: 'قام مدير الجودة باعتماد التقرير بعد استيفاء جميع الشروط الميكروبيولوجية والكيميائية بدقة',
      reportId: 1024,
      reportCategory: 'RawWater',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: buildToastCard(notif),
          ),
        ),
      ),
    );

    expect(find.text('معاينة'), findsOneWidget);
    expect(find.text('معتمد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Executive Toast renders on PC/Desktop (1920px) without issue', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final notif = AppNotification(
      id: 2,
      title: 'رفض تقرير جودة المنتج النهائي',
      body: 'تم رفض التقرير بسبب عدم مطابقة نسبة العكارة للمواصفة القياسية',
      reportId: 502,
      reportCategory: 'FinalProduct',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildToastCard(notif),
        ),
      ),
    );

    expect(find.text('مرفوض'), findsOneWidget);
    expect(find.text('معاينة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Executive Toast renders on Tablet (768px) for pending status', (tester) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final notif = AppNotification(
      id: 3,
      title: 'تقرير جديد بانتظار الاعتماد',
      body: 'سجل مراقبة النقاط الحرجة CCP بانتظار اعتماد مدير المصنع',
      reportId: 301,
      reportCategory: 'Dynamic',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildToastCard(notif),
        ),
      ),
    );

    expect(find.text('بانتظار الإجراء'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
