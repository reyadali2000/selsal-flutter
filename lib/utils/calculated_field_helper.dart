import 'dart:convert';
import '../models/dynamic_report_models.dart';

/// مساعد حساب الحقول المحسوبة وحدود التقييم.
///
/// يُخزَّن كل من صيغة الحقل المحسوب وحدود التقييم داخل حقل
/// [DynamicReportField.validationJson] على الصورة:
///   - محسوب: {"formula": "{field_a} * 2 + {field_b}"}
///   - تقييم: {"min": 1, "max": 5}
class CalculatedFieldHelper {
  CalculatedFieldHelper._();

  /// يستخرج صيغة الحقل المحسوب من validationJson، أو null إن لم توجد.
  static String? extractFormula(DynamicReportField field) {
    if (field.fieldType != 'calculated') return null;
    return _readStringKey(field.validationJson, 'formula');
  }

  /// يستخرج حدود التقييم (min, max) من validationJson مع قيم افتراضية 1..5.
  static ({int min, int max}) ratingBounds(DynamicReportField field) {
    final rawMin = _readNumKey(field.validationJson, 'min');
    final rawMax = _readNumKey(field.validationJson, 'max');
    int min = rawMin?.toInt() ?? 1;
    int max = rawMax?.toInt() ?? 5;
    if (max <= min) max = min + 1;
    return (min: min, max: max);
  }

  /// يحسب قيمة حقل محسوب بناءً على قيم الحقول الأخرى.
  ///
  /// [fieldKeyToValue]: خريطة من مفتاح الحقل (field_key) إلى قيمته النصية الحالية.
  /// يُرجع النتيجة كنص، أو null إذا تعذّر الحساب (نقص في المدخلات أو صيغة غير صالحة).
  static String? evaluateField(
    DynamicReportField field,
    Map<String, String> fieldKeyToValue,
  ) {
    final formula = extractFormula(field);
    if (formula == null) return null;
    return evaluateFormula(formula, fieldKeyToValue);
  }

  /// يحسب صيغة نصية بعد استبدال مفاتيح الحقول {key} بقيمها.
  static String? evaluateFormula(
    String formula,
    Map<String, String> fieldKeyToValue,
  ) {
    final placeholderRegex = RegExp(r'\{([^{}]+)\}');
    final placeholders = placeholderRegex
        .allMatches(formula)
        .map((m) => m.group(1)!.trim())
        .toSet();

    // استبدال كل مفتاح بقيمته العددية، وأي مدخل ناقص يُفشل الحساب
    final substitutions = <String, double>{};
    for (final key in placeholders) {
      final raw = fieldKeyToValue[key];
      if (raw == null || raw.trim().isEmpty) return null;
      final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
      if (parsed == null) return null;
      substitutions[key] = parsed;
    }

    String expr = formula.replaceAllMapped(placeholderRegex, (m) {
      return _numberToExpr(substitutions[m.group(1)!.trim()]!);
    });

    final result = _evaluateExpression(expr);
    if (result == null) return null;
    return _formatResult(result);
  }

  // ───────── أدوات قراءة validationJson ─────────

  static String? _readStringKey(String? json, String key) {
    if (json == null || json.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        final value = decoded[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    } catch (_) {}
    return null;
  }

  static num? _readNumKey(String? json, String key) {
    if (json == null || json.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        final value = decoded[key];
        if (value is num) return value;
        if (value is String) return double.tryParse(value.trim().replaceAll(',', '.'));
      }
    } catch (_) {}
    return null;
  }

  // ───────── أدوات تنسيق الأرقام ─────────

  /// صياغة عدد للاستخدام داخل التعبير الحسابي (بدون التدوين العلمي).
  static String _numberToExpr(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    var s = v.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  /// تنسيق نتيجة العرض: أعداد صحيحة بدون كسور، وإلا حتى 4 خانات عشرية.
  static String formatNumber(double v) => _formatResult(v);

  static String _formatResult(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    var s = v.toStringAsFixed(4);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  // ───────── محلل التعبيرات الحسابية الآمن ─────────
  // يدعم: الأعداد العشرية، و + - * /، والأقواس ( )، والإشارة السالبة.

  static double? _evaluateExpression(String expr) {
    try {
      final tokens = _tokenize(expr);
      if (tokens.isEmpty) return null;
      final parser = _ExprParser(tokens);
      final result = parser.parse();
      if (!parser.fullyConsumed) return null;
      if (result.isNaN || result.isInfinite) return null;
      return result;
    } catch (_) {
      return null;
    }
  }

  static final _tokenRegex = RegExp(r'\d+(?:\.\d+)?|\.\d+|[+\-*/()]');

  static List<String> _tokenize(String expr) {
    final tokens = _tokenRegex.allMatches(expr).map((m) => m.group(0)!).toList();
    // اكتشاف أي أحرف غير مسموح بها (مثل الحروف أو الرموز الغريبة)
    final leftover = expr.replaceAll(_tokenRegex, '').replaceAll(RegExp(r'\s'), '');
    if (leftover.isNotEmpty) {
      throw FormatException('رموز غير مدعومة في الصيغة: "$leftover"');
    }
    return tokens;
  }
}

/// محلل تعبيرات نازل-تعاودي (recursive descent) آمن وبدون تقييم ديناميكي.
class _ExprParser {
  _ExprParser(this.tokens);

  final List<String> tokens;
  int _pos = 0;
  bool fullyConsumed = false;

  String _peek() => _pos < tokens.length ? tokens[_pos] : '';
  String _next() => _pos < tokens.length ? tokens[_pos++] : '';

  double parse() {
    final value = _expr();
    fullyConsumed = _pos == tokens.length;
    return value;
  }

  // expr := term (('+' | '-') term)*
  double _expr() {
    var value = _term();
    while (_peek() == '+' || _peek() == '-') {
      final op = _next();
      final right = _term();
      value = op == '+' ? value + right : value - right;
    }
    return value;
  }

  // term := unary (('*' | '/') unary)*
  double _term() {
    var value = _unary();
    while (_peek() == '*' || _peek() == '/') {
      final op = _next();
      final right = _unary();
      if (op == '*') {
        value = value * right;
      } else {
        if (right == 0) throw const _FormulaError('القسمة على صفر');
        value = value / right;
      }
    }
    return value;
  }

  // unary := ('-' | '+')? factor
  double _unary() {
    if (_peek() == '-') {
      _next();
      return -_factor();
    }
    if (_peek() == '+') {
      _next();
    }
    return _factor();
  }

  // factor := number | '(' expr ')'
  double _factor() {
    final token = _next();
    if (token == '(') {
      final value = _expr();
      if (_next() != ')') {
        throw const _FormulaError('قوس إغلاق مفقود');
      }
      return value;
    }
    if (token.isEmpty) {
      throw const _FormulaError('صيغة غير مكتملة');
    }
    return double.parse(token);
  }
}

class _FormulaError implements Exception {
  final String message;
  const _FormulaError(this.message);

  @override
  String toString() => 'خطأ في الصيغة الحسابية: $message';
}
