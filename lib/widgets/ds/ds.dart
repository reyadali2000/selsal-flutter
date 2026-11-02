/// نقطة استيراد واحدة لنظام التصميم في التطبيق.
///
/// استخدم في الشاشات:
/// ```dart
/// import '../widgets/ds/ds.dart';
/// ```
/// بدل استيراد مسارات `vvk_ui_kit/src/...` مباشرة.
library;

// ===== الأساس =====
export '../../constants/app_colors.dart';
export '../../constants/app_theme.dart';
export '../../utils/responsive_layout/responsive_layout.dart';
// المكتبة تحتوي ResponsiveLayout خاص بها؛ نخفيه لاعتماد نسخة التطبيق.
export '../../utils/vvk_ui_kit/vvk_ui_kit.dart' hide ResponsiveLayout;

// ===== ودجات النظام الموحّدة =====
export '../app_panel.dart';
export 'app_button.dart';
export 'app_card.dart';
export 'app_dialog.dart';
export 'app_scaffold.dart';
export 'app_states.dart';
export 'app_text_field.dart';
