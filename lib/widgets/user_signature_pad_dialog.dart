import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../services/user_signature_service.dart';

/// مربع حوار تفاعلي لإدخال وتعديل توقيع المستخدم
/// يدعم:
/// 1. رفع صورة توقيع معزولة الخلفية جاهزة بصيغة PNG من ملفات أو معرض الجهاز.
/// 2. رسم التوقيع باليد أو القلم مباشرة على شاشة لمسية مع تصديره كـ PNG شفاف عالي الدقة.
class UserSignaturePadDialog extends StatefulWidget {
  final String title;
  final String? signerName;
  final Uint8List? initialSignature;

  const UserSignaturePadDialog({
    super.key,
    this.title = 'إدارة وتعيين التوقيع الرقمي',
    this.signerName,
    this.initialSignature,
  });

  static Future<Uint8List?> show(
    BuildContext context, {
    String? title,
    String? signerName,
    Uint8List? initialSignature,
  }) {
    return showDialog<Uint8List?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UserSignaturePadDialog(
        title: title ?? 'إدارة وتعيين التوقيع الرقمي',
        signerName: signerName,
        initialSignature: initialSignature,
      ),
    );
  }

  @override
  State<UserSignaturePadDialog> createState() => _UserSignaturePadDialogState();
}

class _UserSignaturePadDialogState extends State<UserSignaturePadDialog> {
  // مسارات الرسم اليدوي
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;

  // صورة توقيع تم رفعها كملف PNG
  Uint8List? _uploadedPngBytes;

  // لون الحبر المختار
  Color _selectedInkColor = const Color(0xFF003853); // Navy

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _uploadedPngBytes = widget.initialSignature;
  }

  bool get _hasDrawing => _strokes.isNotEmpty;
  bool get _hasSignature => _uploadedPngBytes != null || _hasDrawing;

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
      _uploadedPngBytes = null;
    });
  }

  /// التقاط الرسم وتصديره كصورة PNG شفافة عالية الدقة مع تحجيم وتوسيط تلقائي (Auto-Crop & Center Scaling)
  Future<Uint8List?> _exportDrawingToPng() async {
    const double exportWidth = 400;
    const double exportHeight = 160;
    const double safePadding = 14.0;

    // 1. حساب المستطيل المحيط بجميع نقاط التوقيع المرسومة (Bounding Box)
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final stroke in _strokes) {
      for (final pt in stroke) {
        if (pt.dx < minX) minX = pt.dx;
        if (pt.dy < minY) minY = pt.dy;
        if (pt.dx > maxX) maxX = pt.dx;
        if (pt.dy > maxY) maxY = pt.dy;
      }
    }

    if (!minX.isFinite || !minY.isFinite) return null;

    final double drawnWidth = math.max(maxX - minX, 1.0);
    final double drawnHeight = math.max(maxY - minY, 1.0);
    final double availWidth = exportWidth - safePadding * 2;
    final double availHeight = exportHeight - safePadding * 2;

    // 2. حساب معامل التحجيم المتناسب وإزاحة التوسيط لمنع القصّ في الشاشات العريضة
    final double rawScale = math.min(availWidth / drawnWidth, availHeight / drawnHeight);
    final double scale = rawScale.clamp(0.25, 1.85);
    final double offsetX = (exportWidth - drawnWidth * scale) / 2.0 - minX * scale;
    final double offsetY = (exportHeight - drawnHeight * scale) / 2.0 - minY * scale;

    Offset transformPoint(Offset p) => Offset(p.dx * scale + offsetX, p.dy * scale + offsetY);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, exportWidth, exportHeight));

    // رسم الخطوط المنعمة على قماش شفاف
    final paint = Paint()
      ..color = _selectedInkColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in _strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        final pt = transformPoint(stroke.first);
        canvas.drawCircle(pt, 1.8, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
      } else {
        final path = Path();
        final firstPt = transformPoint(stroke.first);
        path.moveTo(firstPt.dx, firstPt.dy);
        for (int i = 1; i < stroke.length; i++) {
          final prevPt = transformPoint(stroke[i - 1]);
          final currPt = transformPoint(stroke[i]);
          final midPt = Offset((prevPt.dx + currPt.dx) / 2, (prevPt.dy + currPt.dy) / 2);
          path.quadraticBezierTo(prevPt.dx, prevPt.dy, midPt.dx, midPt.dy);
        }
        final lastPt = transformPoint(stroke.last);
        path.lineTo(lastPt.dx, lastPt.dy);
        canvas.drawPath(path, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(exportWidth.toInt(), exportHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _pickPngFile() async {
    setState(() => _isProcessing = true);
    try {
      final bytes = await UserSignatureService.instance.pickSignaturePngFromDevice();
      if (bytes != null && mounted) {
        setState(() {
          _uploadedPngBytes = bytes;
          _strokes.clear(); // إذا رفع صورة يتم إخلاء الرسم اليدوي لتفضيل الصورة المرفوعة
        });
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'خطأ',
          'فشل اختيار الصورة: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(12),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isProcessing = true);
    try {
      final bytes = await UserSignatureService.instance.pickSignatureImageFromGallery();
      if (bytes != null && mounted) {
        setState(() {
          _uploadedPngBytes = bytes;
          _strokes.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'خطأ',
          'فشل اختيار الصورة: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(12),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveAndReturn() async {
    if (!_hasSignature) {
      Get.snackbar(
        'تنبيه',
        'يرجى رفع صورة PNG أو رسم التوقيع أولاً',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      Uint8List? resultBytes;
      if (_uploadedPngBytes != null) {
        resultBytes = _uploadedPngBytes;
      } else if (_hasDrawing) {
        resultBytes = await _exportDrawingToPng();
      }

      if (resultBytes != null && mounted) {
        Navigator.pop(context, resultBytes);
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'خطأ',
          'حدث خطأ أثناء معالجة التوقيع: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(12),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.draw_rounded, color: AppColors.primaryDark, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (widget.signerName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'المعتمد: ${widget.signerName}',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.88,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // شريط التوجيه التوضيحي
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ارفع صورة PNG شفافة (معزولة الخلفية) أو ارسم توقيعك مباشرة بالقلم/الإصبع في المربع أدناه.',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // أزرار الاختيار السريع لرفع صورة
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _pickPngFile,
                        icon: const Icon(Icons.upload_file_rounded, size: 17),
                        label: const Text('رفع ملف PNG', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF007791),
                          side: const BorderSide(color: Color(0xFF007791)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _pickFromGallery,
                        icon: const Icon(Icons.photo_library_rounded, size: 17),
                        label: const Text('من المعرض', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blueGrey.shade700,
                          side: BorderSide(color: Colors.blueGrey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // لوحة الرسم / المعاينة
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hasSignature ? const Color(0xFF007791) : Colors.grey.shade300,
                      width: _hasSignature ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Stack(
                      children: [
                        // نمط رقعة الشطرنج الخفيف للتأكيد على شفافية الخلفية
                        Positioned.fill(
                          child: CustomPaint(
                            painter: CheckerboardPainter(),
                          ),
                        ),

                        // في حال تم رفع صورة PNG جاهزة
                        if (_uploadedPngBytes != null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Image.memory(
                                _uploadedPngBytes!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          )
                        // أو لوحة الرسم اليدوي المقيدة بحدود الصندوق
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              Offset clampPoint(Offset p) => Offset(
                                    p.dx.clamp(4.0, math.max(4.0, constraints.maxWidth - 4.0)),
                                    p.dy.clamp(4.0, math.max(4.0, constraints.maxHeight - 4.0)),
                                  );
                              return GestureDetector(
                                onPanStart: (details) {
                                  setState(() {
                                    _currentStroke = [clampPoint(details.localPosition)];
                                    _strokes.add(_currentStroke!);
                                  });
                                },
                                onPanUpdate: (details) {
                                  setState(() {
                                    _currentStroke?.add(clampPoint(details.localPosition));
                                  });
                                },
                                onPanEnd: (_) {
                                  _currentStroke = null;
                                },
                                child: CustomPaint(
                                  painter: _SignaturePainter(
                                    strokes: _strokes,
                                    color: _selectedInkColor,
                                  ),
                                  size: Size.infinite,
                                ),
                              );
                            },
                          ),

                        // نص الإرشاد التوضيحي عندما تكون اللوحة فارغة
                        if (!_hasSignature)
                          IgnorePointer(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.gesture_rounded, size: 28, color: Colors.grey.shade400),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ارسم توقيعك هنا باليد أو القلم',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 12,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // زر مسح المحتوى أعلى اليسار
                        if (_hasSignature)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Material(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _clear,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'مسح',
                                        style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // شارة توضح نوع التوقيع الحالي
                        if (_hasSignature)
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111111).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _uploadedPngBytes != null ? 'صورة PNG مرفوعة' : 'رسم يدوي رقمي',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // خيارات ألوان الحبر عند الرسم اليدوي
                if (_uploadedPngBytes == null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لون الحبر:',
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          _buildColorDot(const Color(0xFF003853)), // Navy
                          _buildColorDot(const Color(0xFF007791)), // Teal
                          _buildColorDot(const Color(0xFF1E293B)), // Dark Slate
                          _buildColorDot(const Color(0xFF1565C0)), // Royal Blue
                          _buildColorDot(const Color(0xFF111111)), // أسود غامق
                          _buildColorDot(const Color(0xFF8B0000)), // أحمر غامق
                          _buildColorDot(const Color(0xFF1B5E20)), // أخضر غامق
                          _buildColorDot(const Color(0xFF0D47A1)), // أزرق غامق
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
          ),
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _saveAndReturn,
            icon: _isProcessing
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 18),
            label: const Text(
              'اعتماد التوقيع',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    final isSelected = _selectedInkColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedInkColor = color),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.white,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
                spreadRadius: 1,
              ),
          ],
        ),
      ),
    );
  }
}

/// رسام خطوط التوقيع اليدوي الانسيابي
class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;

  _SignaturePainter({required this.strokes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.6, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
      } else {
        final path = Path();
        path.moveTo(stroke.first.dx, stroke.first.dy);
        for (int i = 1; i < stroke.length; i++) {
          final prev = stroke[i - 1];
          final curr = stroke[i];
          final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
          path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
        }
        path.lineTo(stroke.last.dx, stroke.last.dy);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

/// خلفية شطرنجية خفيفة جداً تبرز شفافية الـ PNG
class CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double cellSize = 10;
    final paint1 = Paint()..color = const Color(0xFFFAFAFA);
    final paint2 = Paint()..color = const Color(0xFFF0F2F5);

    for (double x = 0; x < size.width; x += cellSize) {
      for (double y = 0; y < size.height; y += cellSize) {
        final isEven = ((x / cellSize).floor() + (y / cellSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          isEven ? paint1 : paint2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
