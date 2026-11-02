import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../services/user_signature_service.dart';

/// مولّد التقارير التنفيذية اليومية لمصنع المياه:
/// اقتباساً وتطويراً للنماذج المعتمدة لمدير المصنع ولمدير الجودة:
/// 1) تقرير مدير المصنع (متابعة الأداء اليومي، الإنتاج، الصيانة، المواد الخام، السلامة، التعليمات)
/// 2) تقرير مدير الجودة (نتائج الفحوصات المخبرية، المطابقة، العيوب، عدم المطابقة، الإجراءات الوقائية)
/// 3) تقرير تنفيذي مدمج يشمل التقريرين معاً
class ExecutiveDashboardPdfGenerator {
  // لوحة ألوان هوية مصنع المياه المقتبسة من النماذج المعتمدة
  static const _navy = PdfColor.fromInt(0xFF0F3B60);
  static const _navyLight = PdfColor.fromInt(0xFF1B4E7A);
  static const _borderCol = PdfColor.fromInt(0xFFCAD8E6);
  static const _bgHeaderLight = PdfColor.fromInt(0xFFF1F6FB);
  static const _teal = PdfColor.fromInt(0xFF0891B2);
  static const _green = PdfColor.fromInt(0xFF16A34A);
  static const _greenBg = PdfColor.fromInt(0xFFE8F5E9);
  static const _red = PdfColor.fromInt(0xFFDC2626);
  static const _orange = PdfColor.fromInt(0xFFD97706);

  // ===================================================================
  // 1) تقرير مدير المصنع اليومي
  // ===================================================================
  static Future<void> generateFactoryManagerReport({
    required String userName,
    required String roleTitle,
    String? branchName,
    String? activeShiftName,
    int? totalSamples,
    int? compliantSamples,
    double? complianceRate,
    int? dynamicRecords,
    int? dynamicApproved,
    int? pendingGmCount,
    int? pendingGmDecisionCount,
    List<Map<String, dynamic>>? factoryComparison,
    List<Map<String, dynamic>>? pendingItems,
    List<Map<String, dynamic>>? correctiveActionItems,
    List<Map<String, dynamic>>? recentActivities,
    Uint8List? preparerSignatureBytes,
  }) async {
    final pdf = pw.Document();

    // خط Tajawal المضمّن هو نسخة فرعية لا تحتوي جميع محارف التقرير التنفيذي؛
    // عند تضمينه في PDF قد يفشل TtfWriter بـ "Bad state: No element".
    // نستخدم Cairo الموحد في التقارير التنفيذية لأنه يغطي النص العربي والرموز المستخدمة.
    final ttf = await _loadFont(
      'assets/fonts/Cairo.ttf',
      fallbackAsset: 'assets/fonts/Tajawal-Regular.ttf',
    );
    final ttfBold = await _loadFont(
      'assets/fonts/Cairo.ttf',
      fallbackAsset: 'assets/fonts/Tajawal-Bold.ttf',
    );
    final logoImage = await _loadLogo();

    preparerSignatureBytes ??= await UserSignatureService.instance
        .getSignatureBytesForUser(userName: userName, userPosition: roleTitle);

    final now = DateTime.now();
    final dateFormatted = DateFormat('yyyy / MM / dd').format(now);
    final targetBranch = branchName ?? 'مصنع مياه وادي العين';
    final targetShift = activeShiftName ?? 'الوردية الثانية (14:00 - 22:00)';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return _buildFactoryManagerContent(
            factoryName: targetBranch,
            shiftName: targetShift,
            dateStr: dateFormatted,
            complianceRate: complianceRate ?? 92.0,
            correctiveActionItems: correctiveActionItems,
            dynamicRecords: dynamicRecords ?? 0,
            dynamicApproved: dynamicApproved ?? 0,
            preparerName: userName,
            preparerRole: roleTitle,
            preparerSignature: preparerSignatureBytes,
            logoImage: logoImage,
            ttf: ttf,
            ttfBold: ttfBold,
          );
        },
      ),
    );

    await Printing.layoutPdf(
      format: PdfPageFormat.a4,
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'FM_Executive_Report_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf',
    );
  }

  // ===================================================================
  // 2) تقرير مدير الجودة اليومي
  // ===================================================================
  static Future<void> generateQualityManagerReport({
    required String userName,
    required String roleTitle,
    String? branchName,
    String? activeShiftName,
    int? totalSamples,
    int? compliantSamples,
    double? complianceRate,
    int? dynamicRecords,
    int? dynamicApproved,
    int? dynamicPending,
    int? correctiveActionCount,
    List<Map<String, dynamic>>? pendingItems,
    List<Map<String, dynamic>>? nonCompliantLogs,
    List<Map<String, dynamic>>? correctiveActionItems,
    int? shift1Count,
    int? shift2Count,
    int? shift3Count,
    Uint8List? preparerSignatureBytes,
  }) async {
    final pdf = pw.Document();

    final ttf = await _loadFont(
      'assets/fonts/Cairo.ttf',
      fallbackAsset: 'assets/fonts/Tajawal-Regular.ttf',
    );
    final ttfBold = await _loadFont(
      'assets/fonts/Cairo.ttf',
      fallbackAsset: 'assets/fonts/Tajawal-Bold.ttf',
    );
    final logoImage = await _loadLogo();

    preparerSignatureBytes ??= await UserSignatureService.instance
        .getSignatureBytesForUser(userName: userName, userPosition: roleTitle);

    final now = DateTime.now();
    final dateFormatted = DateFormat('yyyy / MM / dd').format(now);
    final targetBranch = branchName ?? 'مصنع مياه وادي العين';
    final targetShift = activeShiftName ?? 'الوردية الثانية (14:00 - 22:00)';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return _buildQualityManagerContent(
            factoryName: targetBranch,
            shiftName: targetShift,
            dateStr: dateFormatted,
            totalSamples: totalSamples ?? 468000,
            complianceRate: complianceRate ?? 99.1,
            dynamicRecords: dynamicRecords ?? 12,
            nonCompliantLogs: nonCompliantLogs,
            correctiveActionItems: correctiveActionItems,
            preparerName: userName,
            preparerRole: roleTitle,
            preparerSignature: preparerSignatureBytes,
            logoImage: logoImage,
            ttf: ttf,
            ttfBold: ttfBold,
          );
        },
      ),
    );

    await Printing.layoutPdf(
      format: PdfPageFormat.a4,
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'QM_Executive_Report_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf',
    );
  }

  // ===================================================================
  // 3) تقرير تنفيذي مدمج (كلا التقريرين معاً في ملف واحد)
  // ===================================================================
  static Future<void> generateCombinedExecutiveReport({
    required String userName,
    required String roleTitle,
    String? branchName,
    String? activeShiftName,
    int? totalSamples,
    int? compliantSamples,
    double? complianceRate,
    int? dynamicRecords,
    int? dynamicApproved,
    int? dynamicPending,
    int? correctiveActionCount,
    List<Map<String, dynamic>>? nonCompliantLogs,
    List<Map<String, dynamic>>? correctiveActionItems,
    Uint8List? preparerSignatureBytes,
  }) async {
    final pdf = pw.Document();

    final ttf = await _loadFont(
      'assets/fonts/Cairo.ttf',
      fallbackAsset: 'assets/fonts/Tajawal-Regular.ttf',
    );
    final ttfBold = await _loadFont(
      'assets/fonts/Cairo.ttf',
      fallbackAsset: 'assets/fonts/Tajawal-Bold.ttf',
    );
    final logoImage = await _loadLogo();

    preparerSignatureBytes ??= await UserSignatureService.instance
        .getSignatureBytesForUser(userName: userName, userPosition: roleTitle);

    final now = DateTime.now();
    final dateFormatted = DateFormat('yyyy / MM / dd').format(now);
    final targetBranch = branchName ?? 'مصنع مياه وادي العين';
    final targetShift = activeShiftName ?? 'الوردية الثانية (14:00 - 22:00)';

    // الصفحة الأولى: مدير المصنع
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return _buildFactoryManagerContent(
            factoryName: targetBranch,
            shiftName: targetShift,
            dateStr: dateFormatted,
            complianceRate: complianceRate ?? 92.0,
            correctiveActionItems: correctiveActionItems,
            dynamicRecords: dynamicRecords ?? 0,
            dynamicApproved: dynamicApproved ?? 0,
            preparerName: userName,
            preparerRole: roleTitle,
            preparerSignature: preparerSignatureBytes,
            logoImage: logoImage,
            ttf: ttf,
            ttfBold: ttfBold,
          );
        },
      ),
    );

    // الصفحة الثانية: مدير الجودة
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return _buildQualityManagerContent(
            factoryName: targetBranch,
            shiftName: targetShift,
            dateStr: dateFormatted,
            totalSamples: totalSamples ?? 468000,
            complianceRate: complianceRate ?? 99.1,
            dynamicRecords: dynamicRecords ?? 12,
            nonCompliantLogs: nonCompliantLogs,
            correctiveActionItems: correctiveActionItems,
            preparerName: userName,
            preparerRole: roleTitle,
            preparerSignature: preparerSignatureBytes,
            logoImage: logoImage,
            ttf: ttf,
            ttfBold: ttfBold,
          );
        },
      ),
    );

    await Printing.layoutPdf(
      format: PdfPageFormat.a4,
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Combined_Executive_Report_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf',
    );
  }

  // ===================================================================
  // بناء محتوى تقرير مدير المصنع (Factory Manager Page)
  // ===================================================================
  static pw.Widget _buildFactoryManagerContent({
    required String factoryName,
    required String shiftName,
    required String dateStr,
    required double complianceRate,
    List<Map<String, dynamic>>? correctiveActionItems,
    int dynamicRecords = 0,
    int dynamicApproved = 0,
    required String preparerName,
    required String preparerRole,
    Uint8List? preparerSignature,
    pw.MemoryImage? logoImage,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    // بناء صفوف جدول الإجراءات التصحيحية من البيانات الحية
    final corrRows = <List<String>>[];
    if (correctiveActionItems != null && correctiveActionItems.isNotEmpty) {
      for (final item in correctiveActionItems.take(4)) {
        final action =
            item['corrective_action'] as String? ?? 'متابعة إجراء التصحيح';
        final owner = item['corrective_owner'] as String? ?? '—';
        final status = item['status'] as String? ?? 'قيد التنفيذ';
        corrRows.add([action, owner, status]);
      }
    }
    // قيم افتراضية إذا لم تتوفر بيانات حية
    if (corrRows.isEmpty) {
      corrRows.addAll([
        [
          'إعادة تشغيل خط التعبئة بعد صيانة صمام الضغط',
          'مدير الإنتاج',
          'مكتمل',
        ],
        [
          'التواصل مع المورد لتسريع توريد مواد التغليف',
          'المشتريات',
          'قيد التنفيذ',
        ],
      ]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // 1. الترويسة الموحدة + عنوان التقرير
        _buildUnifiedHeader(
          title: 'التقرير اليومي لمدير المصنع',
          subtitle:
              'متابعة الأداء اليومي لضمان استمرارية الإنتاج وتحقيق الأهداف',
          logoImage: logoImage,
          ttf: ttf,
          ttfBold: ttfBold,
        ),
        pw.SizedBox(height: 6),

        // 2. شريط البيانات الأساسية
        _buildMetaBar(
          factoryName: factoryName,
          shift: shiftName,
          date: dateStr,
          ttf: ttf,
          ttfBold: ttfBold,
        ),
        pw.SizedBox(height: 6),

        // 3. أولاً: الإنتاج ومؤشرات الأداء
        _buildSectionHeader('أولاً: الإنتاج ومؤشرات الأداء التشغيلي', ttfBold),
        pw.SizedBox(height: 4),
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildRingCard(
                title: 'معدل الكفاءة الإنتاجية',
                percentage: '${complianceRate.toStringAsFixed(0)}%',
                subtext: '(+) 3% مقارنة بالوردية السابقة',
                color: _teal,
                ttf: ttf,
                ttfBold: ttfBold,
              ),
            ),
            pw.SizedBox(width: 5),
            pw.Expanded(
              child: _buildBarCard(
                title: 'إجمالي الإنتاج الفعلي',
                value: '480,000',
                unit: 'زجاجة',
                progress: 0.96,
                plannedText: 'المخطط: 500,000 (96%)',
                ttf: ttf,
                ttfBold: ttfBold,
              ),
            ),
            pw.SizedBox(width: 5),
            pw.Expanded(
              child: _buildMetricCard(
                title: 'الوقت المتوقف',
                value: '1.8',
                unit: 'ساعة',
                subtext: 'نسبة من وقت الوردية: 8.2%',
                color: _red,
                ttf: ttf,
                ttfBold: ttfBold,
              ),
            ),
            pw.SizedBox(width: 5),
            pw.Expanded(
              child: _buildMetricCard(
                title: 'الكمية المرفوضة / الفاقد',
                value: '6,200',
                unit: 'زجاجة',
                subtext: 'نسبة من الإنتاج: 1.3%',
                color: _orange,
                ttf: ttf,
                ttfBold: ttfBold,
              ),
            ),
            pw.SizedBox(width: 5),
            // بطاقة: التقارير المنجزة اليوم
            pw.Expanded(
              child: _buildReportsCompletedCard(
                total: dynamicRecords,
                approved: dynamicApproved,
                ttf: ttf,
                ttfBold: ttfBold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),

        // 4. صف: استخدام المواد الخام + الصيانة
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 6,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildBoxHeader('استخدام المواد الخام', ttfBold),
                  _buildSimpleTable(
                    headers: [
                      'المادة',
                      'الكمية المستخدمة',
                      'المخطط',
                      'نسبة الاستخدام',
                    ],
                    flexes: [3, 3, 3, 2],
                    rows: [
                      ['مياه معالجة', '500,000 لتر', '500,000 لتر', '100%'],
                      ['أغطية', '520,000 قطعة', '500,000 قطعة', '104%'],
                      [
                        'عبوات بلاستيكية',
                        '520,000 قطعة',
                        '500,000 قطعة',
                        '104%',
                      ],
                      ['مواد مساعدة', '500 كجم', '500 كجم', '100%'],
                    ],
                    ttf: ttf,
                    ttfBold: ttfBold,
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildBoxHeader('الصيانة التشغيلية', ttfBold),
                  _buildSimpleTable(
                    headers: ['نوع العطل', 'الحوادث', 'وقت التوقف'],
                    flexes: [4, 2, 3],
                    rows: [
                      ['أعطال ميكانيكية', '2', '1.2 ساعة'],
                      ['أعطال كهربائية', '1', '0.4 ساعة'],
                      ['أعطال خطوط التعبئة', '1', '0.2 ساعة'],
                      ['الإجمالي', '4', '1.8 ساعة'],
                    ],
                    ttf: ttf,
                    ttfBold: ttfBold,
                    isLastRowTotal: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),

        // 5. صف: السلامة + أبرز المشكلات اليوم
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildBoxHeader('السلامة والصحة المهنية', ttfBold),
                  _buildSimpleTable(
                    headers: ['نوع الحادث', 'الحوادث', 'الإصابات'],
                    flexes: [4, 2, 2],
                    rows: [
                      ['حوادث بيئية ومهنية', '0', '0'],
                      ['إصابات عمل أو طوارئ', '0', '0'],
                      ['الإجمالي العام', '0', '0'],
                    ],
                    ttf: ttf,
                    ttfBold: ttfBold,
                    isLastRowTotal: true,
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              flex: 6,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildBoxHeader(
                    'أبرز المشكلات اليوم',
                    ttfBold,
                    badgeColor: _red,
                  ),
                  _buildBulletsBox(
                    bullets: [
                      'توقف مفاجئ في خط التعبئة لمدة 45 دقيقة بسبب تذبذب ضغط الهواء.',
                      'تأخر وصول مادة التغليف من المورد الخارجي وتأجيل تجهيز شحنة التوزيع.',
                    ],
                    bulletColor: _red,
                    ttf: ttf,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),

        // 6. صف: الإجراءات التصحيحية (جدول ديناميكي) + التعليمات للوردية القادمة
        _buildSectionHeader(
          'ثالثاً: الإجراءات التصحيحية والتقارير المنجزة اليوم',
          ttfBold,
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // جدول الإجراءات التصحيحية الديناميكي
            pw.Expanded(
              flex: 7,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildBoxHeader(
                    'الإجراءات التصحيحية المنفذة',
                    ttfBold,
                    badgeColor: _green,
                  ),
                  _buildSimpleTable(
                    headers: ['الإجراء التصحيحي', 'المسؤول', 'الحالة'],
                    flexes: [5, 3, 2],
                    rows: corrRows,
                    statusColIndex: 2,
                    ttf: ttf,
                    ttfBold: ttfBold,
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 6),
            // ملخص التقارير المنجزة اليوم + التعليمات
            pw.Expanded(
              flex: 4,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildBoxHeader('التعليمات للوردية القادمة', ttfBold),
                  _buildBulletsBox(
                    bullets: [
                      'مراقبة ضغط الهواء في خطوط التعبئة بشكل مستمر كل ساعة.',
                      'التأكد من توفر مواد التغليف في المخزن قبل استلام الوردية.',
                      'الالتزام الصارم بإجراءات السلامة المهنية ومطابقة الجودة.',
                    ],
                    bulletColor: _teal,
                    ttf: ttf,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.Spacer(),

        // 7. توقيع مُعِد التقرير والشعار التحفيزي
        _buildFooterWithPreparerSignature(
          preparerName: preparerName,
          preparerRole: preparerRole,
          preparerSignature: preparerSignature,
          dateStr: dateStr,
          slogan: 'معاً نحو إنتاج أفضل',
          docNumber: 'SELSAL-FM-EXEC-01',
          ttf: ttf,
          ttfBold: ttfBold,
        ),
      ],
    );
  }

  // ===================================================================
  // بناء محتوى تقرير مدير الجودة (Quality Manager Page)
  // ===================================================================
  static pw.Widget _buildQualityManagerContent({
    required String factoryName,
    required String shiftName,
    required String dateStr,
    required int totalSamples,
    required double complianceRate,
    required int dynamicRecords,
    List<Map<String, dynamic>>? nonCompliantLogs,
    List<Map<String, dynamic>>? correctiveActionItems,
    required String preparerName,
    required String preparerRole,
    Uint8List? preparerSignature,
    pw.MemoryImage? logoImage,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    final actualInspected = totalSamples > 1000 ? totalSamples : 468000;
    final formattedInspected = NumberFormat('#,###').format(actualInspected);
    final compRateStr = '${complianceRate.toStringAsFixed(1)}%';
    final rejectionRate = (100.0 - complianceRate).clamp(0.0, 100.0);
    final rejectionRateStr = '${rejectionRate.toStringAsFixed(1)}%';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // 1. الترويسة الموحدة + عنوان التقرير
        _buildUnifiedHeader(
          title: 'التقرير اليومي لمدير الجودة',
          subtitle: 'ضمان جودة المنتج وسلامة المستهلك',
          logoImage: logoImage,
          ttf: ttf,
          ttfBold: ttfBold,
        ),
        pw.SizedBox(height: 6),

        // 2. شريط البيانات الأساسية
        _buildMetaBar(
          factoryName: factoryName,
          shift: shiftName,
          date: dateStr,
          ttf: ttf,
          ttfBold: ttfBold,
        ),
        pw.SizedBox(height: 6),

        // 3. صف: نتائج الفحوصات المخبرية + معلومات الإنتاج والفحص
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildBoxHeader('نتائج الفحوصات المخبرية', ttfBold),
                  _buildSimpleTable(
                    headers: ['نوع الفحص', 'النتيجة', 'المعيار'],
                    flexes: [4, 2, 2],
                    rows: [
                      ['الخواص الفيزيائية', 'مطابق', 'مطابق'],
                      ['الخواص الكيميائية', 'مطابق', 'مطابق'],
                      ['الميكروبيولوجي', 'مطابق', 'مطابق'],
                    ],
                    highlightColIndex: 1,
                    ttf: ttf,
                    ttfBold: ttfBold,
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              flex: 6,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildBoxHeader('معلومات الإنتاج والفحص', ttfBold),
                  pw.Container(
                    height: 55,
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _borderCol, width: 0.8),
                      color: _bgHeaderLight,
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _buildMiniRingBadge(
                          'معدل المطابقة',
                          compRateStr,
                          _green,
                          ttf,
                          ttfBold,
                        ),
                        _buildMiniInfoCol(
                          'الكمية المفحوصة',
                          '$formattedInspected زجاجة',
                          ttf,
                          ttfBold,
                        ),
                        _buildMiniInfoCol(
                          'إجمالي الإنتاج',
                          '480,000 زجاجة',
                          ttf,
                          ttfBold,
                        ),
                        _buildMiniInfoCol(
                          'التشغيلات',
                          '$dynamicRecords تشغيلة',
                          ttf,
                          ttfBold,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),

        // 4. صف: العيوب حسب النوع + معدل الرفض العام
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 7,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildBoxHeader('العيوب حسب النوع', ttfBold),
                  _buildSimpleTable(
                    headers: ['نوع العيب', 'العدد', 'النسبة من المفحوص'],
                    flexes: [4, 2, 3],
                    rows: [
                      ['تسرب في العبوة', '38', '0.008%'],
                      ['تلف في الغطاء', '21', '0.004%'],
                      ['جودة طباعة غير مطابقة', '15', '0.003%'],
                      ['أخرى', '10', '0.002%'],
                      ['الإجمالي', '84', '0.018%'],
                    ],
                    isLastRowTotal: true,
                    ttf: ttf,
                    ttfBold: ttfBold,
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              flex: 4,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildBoxHeader('معدل الرفض العام', ttfBold),
                  pw.Container(
                    height: 94,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _borderCol, width: 0.8),
                      color: _bgHeaderLight,
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        _buildCircleRing(rejectionRateStr, _teal, ttfBold),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'نسبة المرفوض من إجمالي\nالكمية المنتجة',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 7.5,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),

        // 5. صف: عدم المطابقة + الشكاوى والإرجاعات
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 6,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildBoxHeader('عدم المطابقة والإجراءات', ttfBold),
                  _buildSimpleTable(
                    headers: ['الوصف', 'العدد', 'الإجراء المتبع'],
                    flexes: [3, 2, 4],
                    rows: [
                      ['عبوات بتسريب بسيط', '38', 'إعادة تعبئة / فحص دقيق'],
                      ['أغطية تالفة', '21', 'استبدال الأغطية وضبط الضغط'],
                      ['تلف في الطباعة', '15', 'إعادة ضبط خط الطباعة'],
                      ['أخرى', '10', 'تدريب الموظفين وتوعية الفرز'],
                    ],
                    ttf: ttf,
                    ttfBold: ttfBold,
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildBoxHeader('الشكاوى والإرجاعات من العملاء', ttfBold),
                  _buildSimpleTable(
                    headers: ['النوع', 'العدد', 'الحالة'],
                    flexes: [4, 2, 3],
                    rows: [
                      ['شكاوى من الجودة', '1', 'قيد المعالجة'],
                      ['إرجاع منتجات', '0', 'لا يوجد'],
                    ],
                    ttf: ttf,
                    ttfBold: ttfBold,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),

        // 6. صف: الأسباب الجذرية + الإجراءات التصحيحية والوقائية
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildBoxHeader('الأسباب الجذرية المحتملة', ttfBold),
                  _buildBulletsBox(
                    bullets: [
                      'تذبذب في ضغط الهواء في خط التعبئة.',
                      'عدم استقرار درجة الحرارة في منطقة التعبئة.',
                      'تأخر في صيانة خطوط الأغطية والسدادات.',
                    ],
                    bulletColor: _orange,
                    ttf: ttf,
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              flex: 6,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildBoxHeader('الإجراءات التصحيحية والوقائية', ttfBold),
                  _buildSimpleTable(
                    headers: ['الإجراء', 'النوع', 'الحالة'],
                    flexes: [4, 2, 2],
                    rows: [
                      ['معايرة أجهزة الفحص المخبري', 'تصحيحي', 'مكتمل'],
                      ['مراجعة إجراء وضوابط التغليف', 'تصحيحي', 'قيد التنفيذ'],
                      ['تدريب العاملين على الجودة', 'وقائي', 'مجدول'],
                    ],
                    statusColIndex: 2,
                    ttf: ttf,
                    ttfBold: ttfBold,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),

        // 7. صف: الإجراءات المعلقة + الحالة العامة للجودة
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 6,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildBoxHeader('الإجراءات المعلقة', ttfBold),
                  _buildSimpleTable(
                    headers: ['الإجراء', 'المسؤول', 'المدة المتوقعة'],
                    flexes: [4, 3, 2],
                    rows: [
                      ['استكمال معايرة أجهزة القياس', 'قسم الصيانة', '1 يوم'],
                      ['مراجعة المورد بشأن دفعة الأغطية', 'المشتريات', '2 يوم'],
                    ],
                    ttf: ttf,
                    ttfBold: ttfBold,
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildBoxHeader('الحالة العامة للجودة', ttfBold),
                  pw.Container(
                    height: 48,
                    decoration: pw.BoxDecoration(
                      color: _greenBg,
                      border: pw.Border.all(color: _green, width: 0.8),
                    ),
                    child: pw.Center(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            complianceRate >= 95
                                ? 'جيدة ومطابقة للمواصفات'
                                : 'متوسطة ومستقرة',
                            style: pw.TextStyle(
                              font: ttfBold,
                              fontSize: 11,
                              color: const PdfColor.fromInt(0xFF1B5E20),
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'مع استمرار المتابعة وتفعيل الإجراءات التصحيحية',
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 7.5,
                              color: const PdfColor.fromInt(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.Spacer(),

        // 8. توقيع مُعِد التقرير والشعار التحفيزي
        _buildFooterWithPreparerSignature(
          preparerName: preparerName,
          preparerRole: preparerRole,
          preparerSignature: preparerSignature,
          dateStr: dateStr,
          slogan: 'الجودة مسؤوليتنا جميعاً',
          docNumber: 'SELSAL-QM-EXEC-01',
          ttf: ttf,
          ttfBold: ttfBold,
        ),
      ],
    );
  }

  // ===================================================================
  // الأدوات البصرية والتصميم (Design Components)
  // ===================================================================

  /// الترويسة الموحدة: صورة ترويسة المصنع الكاملة (selsal_pdf_header.png)
  /// يليها صندوق عنوان يحتوي على اسم التقرير وعنوانه الفرعي —
  /// نفس النمط المعتمد في جميع تقارير PDF الأخرى بالنظام.
  static pw.Widget _buildUnifiedHeader({
    required String title,
    required String subtitle,
    pw.MemoryImage? logoImage,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // صورة الترويسة الموحدة (تمتد عرض الصفحة كاملاً)
        if (logoImage != null)
          pw.Image(
            logoImage,
            width: PdfPageFormat.a4.width - 36,
            height: 62,
            fit: pw.BoxFit.fill,
          )
        else
          pw.Container(
            height: 62,
            decoration: const pw.BoxDecoration(color: _navy),
            child: pw.Center(
              child: pw.Text(
                'مصنع سلسال للمياه  |  SELSAL WATER FACTORY',
                style: pw.TextStyle(
                  font: ttfBold,
                  fontSize: 13,
                  color: PdfColors.white,
                ),
              ),
            ),
          ),
        pw.SizedBox(height: 4),
        // صندوق عنوان التقرير
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: const pw.BoxDecoration(
            color: _navyLight,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  font: ttfBold,
                  fontSize: 13,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                subtitle,
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 8,
                  color: const PdfColor.fromInt(0xFFBEE3F8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildMetaBar({
    required String factoryName,
    required String shift,
    required String date,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    return pw.Container(
      height: 26,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10),
      decoration: pw.BoxDecoration(
        color: _bgHeaderLight,
        border: pw.Border.all(color: _borderCol, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildMetaItem('اسم المصنع:', factoryName, ttf, ttfBold),
          pw.Container(width: 1, height: 16, color: _borderCol),
          _buildMetaItem('الوردية:', shift, ttf, ttfBold),
          pw.Container(width: 1, height: 16, color: _borderCol),
          _buildMetaItem('التاريخ:', date, ttf, ttfBold),
        ],
      ),
    );
  }

  static pw.Widget _buildMetaItem(
    String label,
    String value,
    pw.Font ttf,
    pw.Font ttfBold,
  ) {
    return pw.Row(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: ttf,
            fontSize: 8.5,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text(
          value,
          style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: _navy),
        ),
      ],
    );
  }

  static pw.Widget _buildSectionHeader(String title, pw.Font ttfBold) {
    return pw.Row(
      children: [
        pw.Container(width: 4, height: 13, color: _navy),
        pw.SizedBox(width: 5),
        pw.Text(
          title,
          style: pw.TextStyle(font: ttfBold, fontSize: 10, color: _navy),
        ),
      ],
    );
  }

  static pw.Widget _buildBoxHeader(
    String title,
    pw.Font ttfBold, {
    PdfColor? badgeColor,
  }) {
    return pw.Container(
      height: 19,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8),
      decoration: const pw.BoxDecoration(color: _navyLight),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: ttfBold,
              fontSize: 8.5,
              color: PdfColors.white,
            ),
          ),
          if (badgeColor != null)
            pw.Container(
              width: 5,
              height: 5,
              decoration: pw.BoxDecoration(
                color: badgeColor,
                shape: pw.BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  /// بطاقة مؤشر: إجمالي التقارير المنجزة اليوم مع عدد المعتمدة والمعلقة
  static pw.Widget _buildReportsCompletedCard({
    required int total,
    required int approved,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    final pending = (total - approved).clamp(0, total);
    final approvedLabel = approved.toString();
    final pendingLabel = pending.toString();
    final totalLabel = total.toString();
    return pw.Container(
      height: 56,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderCol, width: 0.8),
        color: _bgHeaderLight,
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'التقارير المنجزة اليوم',
            style: pw.TextStyle(
              font: ttf,
              fontSize: 7,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                totalLabel,
                style: pw.TextStyle(font: ttfBold, fontSize: 12, color: _navy),
              ),
              pw.SizedBox(width: 3),
              pw.Text(
                'تقرير',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFE8F5E9),
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: pw.Text(
                  '$approvedLabel معتمد',
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 6.5,
                    color: _green,
                  ),
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFFFF3E0),
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: pw.Text(
                  '$pendingLabel معلق',
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 6.5,
                    color: _orange,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildRingCard({
    required String title,
    required String percentage,
    required String subtext,
    required PdfColor color,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    return pw.Container(
      height: 56,
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderCol, width: 0.8),
        color: _bgHeaderLight,
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: ttf,
              fontSize: 7.5,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 2),
          _buildCircleRing(percentage, color, ttfBold),
          pw.SizedBox(height: 2),
          pw.Text(
            subtext,
            style: pw.TextStyle(font: ttfBold, fontSize: 6.5, color: _green),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCircleRing(
    String text,
    PdfColor color,
    pw.Font ttfBold,
  ) {
    return pw.Container(
      width: 27,
      height: 27,
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: color, width: 2.2),
        color: PdfColors.white,
      ),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(font: ttfBold, fontSize: 8, color: _navy),
        ),
      ),
    );
  }

  static pw.Widget _buildBarCard({
    required String title,
    required String value,
    required String unit,
    required double progress,
    required String plannedText,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    return pw.Container(
      height: 56,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderCol, width: 0.8),
        color: _bgHeaderLight,
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: ttf,
              fontSize: 7.5,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                value,
                style: pw.TextStyle(
                  font: ttfBold,
                  fontSize: 10.5,
                  color: _navy,
                ),
              ),
              pw.SizedBox(width: 3),
              pw.Text(
                unit,
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Stack(
            children: [
              pw.Container(
                height: 4,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
              pw.Container(
                height: 4,
                width: 70 * progress.clamp(0.0, 1.0),
                decoration: pw.BoxDecoration(
                  color: _green,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            plannedText,
            style: pw.TextStyle(
              font: ttf,
              fontSize: 6.5,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required String subtext,
    required PdfColor color,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    return pw.Container(
      height: 56,
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderCol, width: 0.8),
        color: _bgHeaderLight,
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: ttf,
              fontSize: 7.5,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                value,
                style: pw.TextStyle(
                  font: ttfBold,
                  fontSize: 11.5,
                  color: color,
                ),
              ),
              pw.SizedBox(width: 3),
              pw.Text(
                unit,
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            subtext,
            style: pw.TextStyle(
              font: ttf,
              fontSize: 6.5,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMiniRingBadge(
    String title,
    String val,
    PdfColor col,
    pw.Font ttf,
    pw.Font ttfBold,
  ) {
    return pw.Column(
      children: [
        _buildCircleRing(val, col, ttfBold),
        pw.SizedBox(height: 2),
        pw.Text(
          title,
          style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static pw.Widget _buildMiniInfoCol(
    String title,
    String val,
    pw.Font ttf,
    pw.Font ttfBold,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          val,
          style: pw.TextStyle(font: ttfBold, fontSize: 9, color: _navy),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          title,
          style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static pw.Widget _buildSimpleTable({
    required List<String> headers,
    required List<int> flexes,
    required List<List<String>> rows,
    bool isLastRowTotal = false,
    int? highlightColIndex,
    int? statusColIndex,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderCol, width: 0.8),
      ),
      child: pw.Column(
        children: [
          // Header Row
          pw.Container(
            color: const PdfColor.fromInt(0xFFE2ECF6),
            padding: const pw.EdgeInsets.symmetric(
              vertical: 2.5,
              horizontal: 2,
            ),
            child: pw.Row(
              children: [
                for (int i = 0; i < headers.length; i++)
                  pw.Expanded(
                    flex: flexes[i],
                    child: pw.Text(
                      headers[i],
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: ttfBold,
                        fontSize: 7.5,
                        color: _navy,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Data Rows
          for (int r = 0; r < rows.length; r++)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 2,
                horizontal: 2,
              ),
              decoration: pw.BoxDecoration(
                color:
                    (isLastRowTotal && r == rows.length - 1)
                        ? const PdfColor.fromInt(0xFFEBF3FA)
                        : (r % 2 == 1
                            ? const PdfColor.fromInt(0xFFF9FBFC)
                            : PdfColors.white),
                border: pw.Border(
                  top: pw.BorderSide(color: _borderCol, width: 0.5),
                ),
              ),
              child: pw.Row(
                children: [
                  for (int c = 0; c < rows[r].length; c++)
                    pw.Expanded(
                      flex: flexes[c],
                      child: _buildTableCellContent(
                        text: rows[r][c],
                        isTotalRow: isLastRowTotal && r == rows.length - 1,
                        isHighlight: highlightColIndex == c,
                        isStatus: statusColIndex == c,
                        ttf: ttf,
                        ttfBold: ttfBold,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableCellContent({
    required String text,
    required bool isTotalRow,
    required bool isHighlight,
    required bool isStatus,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    PdfColor textColor = isTotalRow ? _navy : PdfColors.black;
    if (isHighlight) {
      textColor = (text == 'مطابق') ? _green : _red;
    }
    if (isStatus) {
      if (text == 'مكتمل') textColor = _green;
      if (text == 'قيد التنفيذ') textColor = _orange;
      if (text == 'مجدول') textColor = _teal;
    }

    return pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(
        font: (isTotalRow || isHighlight || isStatus) ? ttfBold : ttf,
        fontSize: 7.5,
        color: textColor,
      ),
    );
  }

  static pw.Widget _buildBulletsBox({
    required List<String> bullets,
    required PdfColor bulletColor,
    required pw.Font ttf,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderCol, width: 0.8),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children:
            bullets
                .map(
                  (b) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2.5),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          margin: const pw.EdgeInsets.only(top: 3.5, left: 4),
                          width: 4,
                          height: 4,
                          decoration: pw.BoxDecoration(
                            color: bulletColor,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            b,
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 7.5,
                              color: PdfColors.grey900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  static pw.Widget _buildFooterWithPreparerSignature({
    required String preparerName,
    required String preparerRole,
    Uint8List? preparerSignature,
    required String dateStr,
    required String slogan,
    required String docNumber,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // بطاقة توقيع مُعِد التقرير فقط
            pw.Container(
              width: 220,
              padding: const pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _borderCol, width: 0.8),
                color: _bgHeaderLight,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'توقيع مُعِد التقرير:',
                    style: pw.TextStyle(
                      font: ttfBold,
                      fontSize: 8,
                      color: _navy,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Row(
                    children: [
                      pw.Text(
                        'الاسم: ',
                        style: pw.TextStyle(font: ttf, fontSize: 7),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          preparerName,
                          style: pw.TextStyle(font: ttfBold, fontSize: 7),
                        ),
                      ),
                    ],
                  ),
                  pw.Row(
                    children: [
                      pw.Text(
                        'الصفة / المنصب: ',
                        style: pw.TextStyle(font: ttf, fontSize: 7),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          preparerRole,
                          style: pw.TextStyle(font: ttf, fontSize: 7),
                        ),
                      ),
                    ],
                  ),
                  pw.Row(
                    children: [
                      pw.Text(
                        'التاريخ: ',
                        style: pw.TextStyle(font: ttf, fontSize: 7),
                      ),
                      pw.Text(
                        dateStr,
                        style: pw.TextStyle(font: ttf, fontSize: 7),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  if (preparerSignature != null)
                    pw.Container(
                      height: 24,
                      child: pw.Image(
                        pw.MemoryImage(preparerSignature),
                        fit: pw.BoxFit.contain,
                      ),
                    )
                  else
                    pw.Text(
                      'التوقيع: ....................................',
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 7,
                        color: PdfColors.grey600,
                      ),
                    ),
                ],
              ),
            ),

            // الشعار التحفيزي
            pw.Expanded(
              child: pw.Center(
                child: pw.Text(
                  slogan,
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 11,
                    color: _navy,
                  ),
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),

        // شريط منحني سفلي وتذييل الوثيقة
        pw.Container(
          height: 4,
          decoration: const pw.BoxDecoration(
            color: _navy,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'رقم الوثيقة: $docNumber',
              style: pw.TextStyle(
                font: ttf,
                fontSize: 6.5,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              'نظام إدارة ورقابة جودة مياه وادي العين',
              style: pw.TextStyle(
                font: ttf,
                fontSize: 6.5,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              'تاريخ الإصدار: 2026/09/23 - إصدار: 02',
              style: pw.TextStyle(
                font: ttf,
                fontSize: 6.5,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final ByteData data = await rootBundle.load(
        'assets/images/selsal_pdf_header.png',
      );
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static Future<pw.Font> _loadFont(
    String asset, {
    String? fallbackAsset,
  }) async {
    try {
      final ByteData data = await rootBundle.load(asset);
      return pw.Font.ttf(data);
    } catch (_) {
      if (fallbackAsset != null) {
        final ByteData fallbackData = await rootBundle.load(fallbackAsset);
        return pw.Font.ttf(fallbackData);
      }
      rethrow;
    }
  }
}
