import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// ============================================================
/// Arabic PDF Service
/// ============================================================
/// خدمة موحدة وشاملة لإنشاء تقارير PDF باللغة العربية لنظام إدارة المصنع.
///
/// المميزات:
/// - دعم حقيقي لاتجاه النص من اليمين لليسار (RTL) دون تلاعب يدوي بالحروف.
/// - خطوط عربية واضحة ومدمجة (Noto Naskh Arabic / Tajawal).
/// - ترويسة وتذييل احترافيان متوافقان مع الصفحات المتعددة (MultiPage).
/// - معالجة متزامنة (Sync) للترويسة لتجنب أخطاء Future في بناء الصفحات.
/// - جداول تلقائية الترقيم والتقسيم (Paginated Tables).
/// - دعم التوقيعات الرقمية واليدوية.
/// ============================================================

class ArabicPdfService {
  ArabicPdfService._();

  // ============================================================
  // Fonts & Assets Cache
  // ============================================================

  static pw.Font? _regular;
  static pw.Font? _bold;
  static pw.MemoryImage? _cachedLogo;
  static pw.MemoryImage? _cachedBanner;
  static bool _initialized = false;

  /// تهيئة الخطوط والشعار والترويسة مرة واحدة وتخزينها في الذاكرة
  static Future<void> initialize({
    String? defaultLogoPath = 'assets/images/logo.png',
    String? defaultBannerPath = 'assets/images/selsal_pdf_header.png',
  }) async {
    if (_initialized) return;

    // تحميل خط Tajawal المعتمد والمتوافق 100% مع محرك pdf
    try {
      final fontData = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
      _regular = pw.Font.ttf(fontData);
    } catch (e) {
      // محاولة بديلة لـ Noto
      final fontData = await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf');
      _regular = pw.Font.ttf(fontData);
    }

    try {
      final fontBoldData = await rootBundle.load('assets/fonts/Tajawal-Bold.ttf');
      _bold = pw.Font.ttf(fontBoldData);
    } catch (e) {
      final fontBoldData = await rootBundle.load('assets/fonts/NotoNaskhArabic-Bold.ttf');
      _bold = pw.Font.ttf(fontBoldData);
    }

    // تحميل الشعار الافتراضي إن وجد
    if (defaultLogoPath != null && defaultLogoPath.isNotEmpty) {
      try {
        final logoData = await rootBundle.load(defaultLogoPath);
        _cachedLogo = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}
    }

    // تحميل الترويسة العريضة (Official Letterhead) إن وجدت
    if (defaultBannerPath != null && defaultBannerPath.isNotEmpty) {
      try {
        final bannerData = await rootBundle.load(defaultBannerPath);
        _cachedBanner = pw.MemoryImage(bannerData.buffer.asUint8List());
      } catch (_) {}
    }

    _initialized = true;
  }

  /// تحميل صورة شعار مخصصة لاستخدامها كـ MemoryImage
  static Future<pw.MemoryImage?> loadLogo(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // Theme & Validation
  // ============================================================

  static pw.ThemeData get theme {
    _ensureInitialized();
    return pw.ThemeData.withFont(
      base: _regular!,
      bold: _bold!,
    );
  }

  static void _ensureInitialized() {
    if (!_initialized || _regular == null || _bold == null) {
      throw StateError(
        'ArabicPdfService is not initialized. '
        'Call await ArabicPdfService.initialize() before creating the PDF.',
      );
    }
  }

  // ============================================================
  // Text Styles
  // ============================================================

  static pw.TextStyle regular({
    double fontSize = 9,
    PdfColor color = PdfColors.black,
  }) {
    _ensureInitialized();
    return pw.TextStyle(
      font: _regular,
      fontSize: fontSize,
      color: color,
    );
  }

  static pw.TextStyle bold({
    double fontSize = 10,
    PdfColor color = PdfColors.black,
  }) {
    _ensureInitialized();
    return pw.TextStyle(
      font: _bold,
      fontSize: fontSize,
      color: color,
    );
  }

  // ============================================================
  // Header Variations (ترويسات متزامنة خالية من أخطاء Future)
  // ============================================================

  /// ترويسة رسمية عريضة (Letterhead Banner Image)
  static pw.Widget bannerHeader({
    pw.MemoryImage? bannerImage,
    double height = 76,
    double? width,
  }) {
    final image = bannerImage ?? _cachedBanner;
    if (image == null) return pw.SizedBox(height: height);
    return pw.Image(
      image,
      width: width,
      height: height,
      fit: pw.BoxFit.fill,
    );
  }

  /// عنوان تقرير داخل شارة بارزة ومؤطرة (Badge Title)
  static pw.Widget badgeTitle(
    String title, {
    PdfColor bgColor = const PdfColor.fromInt(0xFFD6E6F5),
    PdfColor borderColor = const PdfColor.fromInt(0xFF173A5E),
    double fontSize = 15,
  }) {
    return pw.Center(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 5),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: borderColor, width: 1.2),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          color: bgColor,
        ),
        child: pw.Text(
          title,
          style: bold(fontSize: fontSize),
        ),
      ),
    );
  }

  /// شارة حالة الاعتماد (Status Badge)
  static pw.Widget statusBadge({
    required String text,
    bool isApproved = false,
    bool isRejected = false,
    double fontSize = 8,
  }) {
    PdfColor bgColor;
    PdfColor borderColor;
    PdfColor textColor;

    if (isRejected) {
      bgColor = const PdfColor.fromInt(0xFFFFEBEE); // أحمر فاتح
      borderColor = const PdfColor.fromInt(0xFFC62828); // أحمر داكن
      textColor = const PdfColor.fromInt(0xFFB71C1C); // نص أحمر
    } else if (isApproved) {
      bgColor = const PdfColor.fromInt(0xFFE8F5E9); // أخضر فاتح
      borderColor = const PdfColor.fromInt(0xFF2E7D32);
      textColor = const PdfColor.fromInt(0xFF1B5E20);
    } else {
      bgColor = const PdfColor.fromInt(0xFFFFF8E1); // أصفر فاتح للانتظار
      borderColor = const PdfColor.fromInt(0xFFF57F17);
      textColor = const PdfColor.fromInt(0xFFE65100);
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color: bgColor,
        border: pw.Border.all(color: borderColor, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Text(
        text,
        style: bold(fontSize: fontSize, color: textColor),
      ),
    );
  }

  static pw.Widget factoryHeader({
    String factoryName = 'مصنع وادي العين للمياه المعدنية',
    String? factorySubtitle,
    pw.MemoryImage? logo,
    String? reportTitle,
    String? reportNumber,
    String? date,
    bool showDivider = true,
  }) {
    final effectiveLogo = logo ?? _cachedLogo;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: showDivider
              ? const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(
                      width: 1,
                      color: PdfColors.grey400,
                    ),
                  ),
                )
              : null,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // معلومات المصنع
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    factoryName,
                    style: bold(fontSize: 14),
                  ),
                  if (factorySubtitle != null) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      factorySubtitle,
                      style: regular(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ],
              ),

              // الشعار
              if (effectiveLogo != null)
                pw.Container(
                  width: 50,
                  height: 50,
                  child: pw.Image(
                    effectiveLogo,
                    fit: pw.BoxFit.contain,
                  ),
                ),
            ],
          ),
        ),

        // عنوان التقرير الرئيسي
        if (reportTitle != null) ...[
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              reportTitle,
              style: bold(fontSize: 15),
            ),
          ),
        ],

        // بيانات رقم التقرير والتاريخ
        if (reportNumber != null || date != null) ...[
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (reportNumber != null)
                pw.Text(
                  'رقم التقرير: $reportNumber',
                  style: regular(fontSize: 8),
                ),
              if (date != null)
                pw.Text(
                  'التاريخ: $date',
                  style: regular(fontSize: 8),
                ),
            ],
          ),
        ],

        pw.SizedBox(height: 10),
      ],
    );
  }

  // ============================================================
  // Factory Footer
  // ============================================================

  static pw.Widget footer({
    String systemName = 'نظام إدارة المصنع - وادي العين',
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            width: 0.5,
            color: PdfColors.grey400,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            systemName,
            style: regular(
              fontSize: 7,
              color: PdfColors.grey700,
            ),
          ),
          pw.Builder(
            builder: (context) {
              return pw.Text(
                'الصفحة ${context.pageNumber} من ${context.pagesCount}',
                style: regular(
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Section Title
  // ============================================================

  static pw.Widget sectionTitle(
    String title, {
    double fontSize = 11,
    PdfColor backgroundColor = PdfColors.grey200,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(
        vertical: 5,
        horizontal: 8,
      ),
      margin: const pw.EdgeInsets.only(bottom: 8, top: 4),
      decoration: pw.BoxDecoration(
        color: backgroundColor,
        borderRadius: const pw.BorderRadius.all(
          pw.Radius.circular(3),
        ),
      ),
      child: pw.Text(
        title,
        style: bold(fontSize: fontSize),
      ),
    );
  }

  // ============================================================
  // Information Row
  // ============================================================

  static pw.Widget infoRow({
    required String label,
    required String value,
    double labelWidth = 90,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: labelWidth,
            child: pw.Text(
              label,
              style: bold(fontSize: 8.5),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Text(
              value,
              style: regular(fontSize: 8.5),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Paragraph
  // ============================================================

  static pw.Widget paragraph(
    String text, {
    double fontSize = 9,
    pw.TextAlign textAlign = pw.TextAlign.right,
  }) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text,
        textAlign: textAlign,
        style: regular(fontSize: fontSize),
      ),
    );
  }

  // ============================================================
  // Highlight / Metric Card
  // ============================================================

  static pw.Widget highlightCard({
    required String title,
    required String value,
    String? subtitle,
    double valueFontSize = 14,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(
          pw.Radius.circular(4),
        ),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        children: [
          pw.Text(
            title,
            textAlign: pw.TextAlign.center,
            style: regular(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            textAlign: pw.TextAlign.center,
            style: bold(fontSize: valueFontSize),
          ),
          if (subtitle != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              subtitle,
              textAlign: pw.TextAlign.center,
              style: regular(fontSize: 7, color: PdfColors.grey600),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // Standard Arabic Table (تلقائي التقسيم عبر الصفحات)
  // ============================================================

  static pw.Widget table({
    required List<String> headers,
    required List<List<dynamic>> rows,
    Map<int, pw.TableColumnWidth>? columnWidths,
    double fontSize = 8,
    PdfColor headerColor = PdfColors.grey200,
    pw.Alignment cellAlignment = pw.Alignment.center,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      columnWidths: columnWidths,
      border: pw.TableBorder.all(
        color: PdfColors.grey400,
        width: 0.5,
      ),
      headerStyle: bold(fontSize: fontSize),
      headerDecoration: pw.BoxDecoration(color: headerColor),
      headerAlignment: pw.Alignment.center,
      cellStyle: regular(fontSize: fontSize),
      cellAlignment: cellAlignment,
      cellPadding: const pw.EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 5,
      ),
    );
  }

  // ============================================================
  // Signatures Section
  // ============================================================

  static pw.Widget signatures({
    required List<SignatureData> signatures,
    double topMargin = 20,
  }) {
    return pw.Container(
      margin: pw.EdgeInsets.only(top: topMargin),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: signatures.map((sig) {
          return pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 6),
              child: pw.Column(
                children: [
                  pw.Text(
                    sig.title,
                    textAlign: pw.TextAlign.center,
                    style: bold(fontSize: 8.5),
                  ),
                  pw.SizedBox(height: 6),

                  // صورة التوقيع إن وجدت، وإلا خط توقيع
                  if (sig.signatureImage != null)
                    pw.Container(
                      height: 35,
                      child: pw.Image(
                        pw.MemoryImage(sig.signatureImage!),
                        fit: pw.BoxFit.contain,
                      ),
                    )
                  else
                    pw.SizedBox(height: 25),

                  pw.Container(
                    width: 100,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                          color: PdfColors.black,
                          width: 0.7,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),

                  pw.Builder(
                    builder: (context) {
                      final parsed = splitNameAndRole(sig.name ?? '.......................');
                      return pw.Column(
                        children: [
                          pw.Text(
                            parsed.name,
                            textAlign: pw.TextAlign.center,
                            style: regular(fontSize: 7.5),
                          ),
                          if (parsed.role != null) ...[
                            pw.SizedBox(height: 1),
                            pw.Text(
                              parsed.role!,
                              textAlign: pw.TextAlign.center,
                              style: regular(fontSize: 6.5, color: PdfColors.grey700),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // Generate Document
  // ============================================================

  static Future<Uint8List> generate({
    required String title,
    required List<pw.Widget> Function(pw.Context) build,
    pw.Widget Function(pw.Context)? header,
    pw.Widget Function(pw.Context)? footer,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    pw.EdgeInsets margin = const pw.EdgeInsets.fromLTRB(28, 28, 28, 30),
    String author = 'نظام إدارة المصنع',
  }) async {
    await initialize();

    final pdf = pw.Document(
      title: title,
      author: author,
      creator: 'نظام إدارة المصنع - وادي العين',
      subject: title,
      theme: theme,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: margin,
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        header: header,
        footer: footer ?? (context) => ArabicPdfService.footer(),
        build: build,
      ),
    );

    return pdf.save();
  }

  // ============================================================
  // Print & Share Helpers
  // ============================================================

  static Future<void> printPdf(Uint8List pdfBytes) async {
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
    );
  }

  static Future<void> sharePdf({
    required Uint8List pdfBytes,
    String filename = 'factory_report.pdf',
  }) async {
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );
  }

  // ============================================================
  // Date & Status Formatters
  // ============================================================

  /// تنسيق التواريخ بشكل عربي نظيف ومقروء
  static String formatArabicDate(DateTime? dt) {
    if (dt == null) return 'تاريخ غير متوفر';
    final date = DateFormat('yyyy/MM/dd').format(dt);
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'م' : 'ص';
    return '$date - $hour:$minute $period';
  }

  /// تحويل حالات الاعتماد إلى مسميات عربية موحدة
  static String formatArabicStatus(String? status) {
    if (status == null || status.trim().isEmpty) return 'مكتمل';
    switch (status.toLowerCase().trim()) {
      case 'approved':
      case 'معتمد':
        return 'معتمد';
      case 'pending_qm':
        return 'بانتظار اعتماد الجودة';
      case 'pending_gm':
        return 'بانتظار اعتماد المدير';
      case 'rejected':
      case 'مرفوض':
        return 'مرفوض';
      case 'draft':
      case 'مسودة':
        return 'مسودة';
      default:
        return status;
    }
  }

  /// تنظيف ومعالجة النصوص والأسماء العربية لمنع مشاكل BiDi وتداخل الحروف
  static String cleanArabicText(String text) {
    if (text.isEmpty) return text;
    var res = text;

    // 1. إزالة أي محارف تحكم غير مرئية أو مسافات صفرية قديمة
    res = res.replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E\uFEFF]'), '');

    // 2. تصحيح الألقاب ذات النقطة التي تكسر اتجاه BiDi في محرك الـ PDF
    res = res.replaceAllMapped(RegExp(r'(^|\s)أ\.\s*'), (m) => '${m[1]}أ/ ');
    res = res.replaceAllMapped(RegExp(r'(^|\s)د\.\s*'), (m) => '${m[1]}د/ ');
    res = res.replaceAllMapped(RegExp(r'(^|\s)م\.\s*'), (m) => '${m[1]}م/ ');

    // 3. ضبط المسافات حول الأقواس لمنع التصاق الأقواس بالكلمات العربية
    res = res.replaceAllMapped(RegExp(r'(\S)\('), (m) => '${m[1]} (');
    res = res.replaceAllMapped(RegExp(r'\)(\S)'), (m) => ') ${m[1]}');

    // 4. دمج المسافات المتكررة
    res = res.replaceAll(RegExp(r'\s+'), ' ').trim();

    return res;
  }

  /// تقسيم الاسم والمسمى الوظيفي إذا كان مدمجاً في نفس النص (مثل: خالد العمري (مدير المصنع))
  /// لتجنب تداخل الأقواس وعكس الكلمات في سطر واحد
  static ({String name, String? role}) splitNameAndRole(String raw) {
    final cleaned = cleanArabicText(raw);
    final match = RegExp(r'^(.*?)\s*(\(.*\))\s*$').firstMatch(cleaned);
    if (match != null && match.group(1)!.trim().isNotEmpty) {
      return (
        name: match.group(1)!.trim(),
        role: match.group(2)!.trim(),
      );
    }
    return (name: cleaned, role: null);
  }
}

// ============================================================
// Signature Model
// ============================================================

class SignatureData {
  final String title;
  final String? name;
  final Uint8List? signatureImage;

  const SignatureData({
    required this.title,
    this.name,
    this.signatureImage,
  });
}
