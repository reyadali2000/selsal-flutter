import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// مكوّن موحَّد واحترافي لعرض مستندات التقارير في شاشات الهواتف والأجهزة اللوحية والكمبيوتر.
///
/// المميزات:
/// * ملاءمة تلقائية لعرض الشاشة عند الفتح (Fit-to-Width / Fit-to-Screen)
/// * تكبير وتصغير سلس باللمس (Pinch-to-Zoom) من 0.3x إلى 4.0x
/// * سحب وتحريك المستند في جميع الاتجاهات (Pan / 2D Scroll)
/// * نقر مزدوج ذكي (Double Tap): للتبديل السريع بين ملء الشاشة والتكبير التفصيلي
/// * شريط تحكم عائم مريح في الأسفل (تكبير +، تصغير -، نسبة التكبير %، وزر إعادة الضبط للشاشة)
class ZoomableDocumentView extends StatefulWidget {
  const ZoomableDocumentView({
    super.key,
    required this.child,
    required this.documentWidth,
    this.minScale,
    this.maxScale = 4.0,
    this.doubleTapScale,
    this.alignment = Alignment.topCenter,
    this.showControls = true,
    this.scrollController,
    this.storageKey,
  });

  /// محتوى المستند (الجدول/النموذج/الصفحة).
  final Widget child;

  /// العرض الطبيعي للمستند عند scale = 1.0 (مثل 794 لصفحة A4 أو 1140 للجداول العريضة).
  final double documentWidth;

  /// أقل نسبة تكبير مسموحة.
  final double? minScale;

  /// أعلى نسبة تكبير مسموحة.
  final double maxScale;

  /// نسبة تكبير النقر المزدوج (إذا كانت null يتم احتسابها تلقائياً).
  final double? doubleTapScale;

  /// محاذاة المستند داخل النافذة.
  final Alignment alignment;

  /// إظهار شريط أدوات التكبير والتصغير العائم في الأسفل.
  final bool showControls;

  /// متحكم التمرير الخارجي للحفاظ على الموضع عند التحديث
  final ScrollController? scrollController;

  /// مفتاح تخزين موضع التمرير في الذاكرة
  final PageStorageKey? storageKey;

  @override
  State<ZoomableDocumentView> createState() => _ZoomableDocumentViewState();
}

class _ZoomableDocumentViewState extends State<ZoomableDocumentView>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late final AnimationController _animController;
  Animation<Matrix4>? _zoomAnimation;

  double _scale = 1.0;
  double _fitScale = 1.0;
  bool _initializedScale = false;
  double _lastAvailableWidth = 0.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _controller.value = _zoomAnimation!.value;
        }
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _animateToMatrix(Matrix4 target) {
    _zoomAnimation = Matrix4Tween(
      begin: _controller.value,
      end: target,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward(from: 0.0);
  }

  Matrix4 _getMatrixForScale(double scale, double availableWidth, double docWidth) {
    final scaledWidth = docWidth * scale;
    final dx = availableWidth > scaledWidth ? (availableWidth - scaledWidth) / 2.0 : 0.0;
    return Matrix4.diagonal3Values(scale, scale, 1.0)
      ..setTranslationRaw(dx, 0.0, 0.0);
  }

  void _animateToScale(double targetScale, double availableWidth, double docWidth) {
    final double clampedScale = targetScale.clamp(
      widget.minScale ?? math.min(0.2, _fitScale * 0.6),
      widget.maxScale,
    ).toDouble();
    final target = _getMatrixForScale(clampedScale, availableWidth, docWidth);
    _animateToMatrix(target);
    setState(() => _scale = clampedScale);
  }

  void _onDoubleTap(double availableWidth, double docWidth) {
    final isFitted = (_scale - _fitScale).abs() < 0.08;
    final targetScale = isFitted
        ? (widget.doubleTapScale ?? math.max(1.0, _fitScale * 2.2))
        : _fitScale;

    _animateToScale(targetScale, availableWidth, docWidth);
  }

  void _onInteractionUpdate(ScaleUpdateDetails _) => _syncScale();
  void _onInteractionEnd(ScaleEndDetails _) => _syncScale();

  void _syncScale() {
    final scale = _controller.value.getMaxScaleOnAxis();
    if ((scale - _scale).abs() > 0.01) {
      setState(() => _scale = scale);
    }
  }

  void _zoomIn(double availableWidth, double docWidth) {
    _animateToScale(_scale * 1.3, availableWidth, docWidth);
  }

  void _zoomOut(double availableWidth, double docWidth) {
    _animateToScale(_scale / 1.3, availableWidth, docWidth);
  }

  void _resetToFit(double availableWidth, double docWidth) {
    _animateToScale(_fitScale, availableWidth, docWidth);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final docWidth = widget.documentWidth;
        final availableWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : docWidth;

        // احتساب مقياس ملاءمة الشاشة تلقائياً
        final calculatedFitScale = availableWidth < docWidth
            ? (availableWidth / docWidth)
            : 1.0;

        _fitScale = calculatedFitScale;

        // تهيئة التكبير الأولي ومصفوفة التمركز لملء الشاشة بالكامل
        if (!_initializedScale || (availableWidth - _lastAvailableWidth).abs() > 20) {
          _lastAvailableWidth = availableWidth;
          _initializedScale = true;
          _scale = calculatedFitScale;
          _controller.value = _getMatrixForScale(calculatedFitScale, availableWidth, docWidth);
        }

        final minScaleValue = widget.minScale ?? math.min(0.2, _fitScale * 0.6);

        // إذا كان المكوّن داخل ScrollView عمودي غير مقيد الارتفاع
        if (constraints.maxHeight.isInfinite) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: math.max(availableWidth, docWidth),
              child: widget.child,
            ),
          );
        }

        // على أجهزة سطح المكتب (Windows/Linux/macOS): لا حاجة للتكبير والتصغير
        // عند التمرير. نعرض المستند بعرضه الطبيعي (أو مُلبَّياً لعرض النافذة إذا كانت
        // أضيق منه) مع تمرير عمودي عادي فقط — بدون InteractiveViewer.
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          return SingleChildScrollView(
            key: widget.storageKey ?? const PageStorageKey('zoomable_doc_scroll'),
            controller: widget.scrollController,
            child: Center(
              child: availableWidth < docWidth
                  ? FittedBox(
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      child: SizedBox(width: docWidth, child: widget.child),
                    )
                  : SizedBox(width: docWidth, child: widget.child),
            ),
          );
        }

        final isZoomed = (_scale - _fitScale).abs() > 0.05;

        return Stack(
          children: [
            InteractiveViewer(
              transformationController: _controller,
              constrained: false,
              alignment: Alignment.topLeft,
              boundaryMargin: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
              minScale: minScaleValue,
              maxScale: widget.maxScale,
              onInteractionUpdate: _onInteractionUpdate,
              onInteractionEnd: _onInteractionEnd,
              child: GestureDetector(
                onDoubleTap: () => _onDoubleTap(availableWidth, docWidth),
                child: SizedBox(
                  width: docWidth,
                  child: widget.child,
                ),
              ),
            ),

            // شريط الأدوات العائم للتحكم بالتكبير
            if (widget.showControls)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xE61E293B), // Dark Slate with opacity
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // زر تصغير
                        InkWell(
                          onTap: () => _zoomOut(availableWidth, docWidth),
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.remove, color: Colors.white, size: 18),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // نسبة التكبير
                        GestureDetector(
                          onTap: () => _resetToFit(availableWidth, docWidth),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isZoomed ? const Color(0xFF0284C7) : Colors.white12,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isZoomed ? '${(_scale * 100).round()}%' : 'ملاءمة الشاشة',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // زر تكبير
                        InkWell(
                          onTap: () => _zoomIn(availableWidth, docWidth),
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.add, color: Colors.white, size: 18),
                          ),
                        ),

                        // زر العودة للحجم المناسب للشاشة عند التكبير
                        if (isZoomed) ...[
                          Container(
                            height: 16,
                            width: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            color: Colors.white24,
                          ),
                          InkWell(
                            onTap: () => _resetToFit(availableWidth, docWidth),
                            borderRadius: BorderRadius.circular(16),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fit_screen_rounded, color: Colors.tealAccent, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'إعادة ضبط',
                                    style: TextStyle(
                                      color: Colors.tealAccent,
                                      fontSize: 11.5,
                                      fontFamily: 'Tajawal',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
