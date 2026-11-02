class TestParameter {
  final int? id;
  final String category;
  final String nameAr;
  final String? unit;
  final String inputType;

  TestParameter({
    this.id,
    required this.category,
    required this.nameAr,
    this.unit,
    required this.inputType,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'name_ar': nameAr,
      'unit': unit,
      'input_type': inputType,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  factory TestParameter.fromJson(Map<String, dynamic> json) => TestParameter.fromMap(json);

  factory TestParameter.fromMap(Map<String, dynamic> json) {
    return TestParameter(
      id: (json['id'] as num?)?.toInt(),
      category: (json['category'] ?? 'Sensory') as String,
      nameAr: (json['name_ar'] ?? json['nameAr'] ?? '') as String,
      unit: (json['unit'] as String?),
      inputType: (json['input_type'] ?? json['inputType'] ?? 'Numeric') as String,
    );
  }
}

class QualityStandard {
  final int? id;
  final int? productId; // null if raw water
  final String waterType;
  final int parameterId;
  final double? minValue;
  final double? maxValue;
  final String? expectedText;

  QualityStandard({
    this.id,
    this.productId,
    required this.waterType,
    required this.parameterId,
    this.minValue,
    this.maxValue,
    this.expectedText,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'water_type': waterType,
      'parameter_id': parameterId,
      'min_value': minValue,
      'max_value': maxValue,
      'expected_text': expectedText,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  factory QualityStandard.fromJson(Map<String, dynamic> json) => QualityStandard.fromMap(json);

  factory QualityStandard.fromMap(Map<String, dynamic> json) {
    return QualityStandard(
      id: (json['id'] as num?)?.toInt(),
      productId: (json['product_id'] ?? json['productId'] as num?)?.toInt(),
      waterType: (json['water_type'] ?? json['waterType'] ?? '') as String,
      parameterId: (json['parameter_id'] ?? json['parameterId'] as num?)?.toInt() ?? 0,
      minValue: ((json['min_value'] ?? json['minValue']) as num?)?.toDouble(),
      maxValue: ((json['max_value'] ?? json['maxValue']) as num?)?.toDouble(),
      expectedText: (json['expected_text'] ?? json['expectedText']) as String?,
    );
  }
}
