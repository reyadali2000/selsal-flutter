/// نموذج بيانات قراءة فحص الجودة
/// يمثل قراءة واحدة مكتملة لدفعة إنتاج محددة
class QualityReading {
  final String? id;
  final String batchNumber;
  final String productSize;
  final String shift;
  final double operatingHours;
  final double ph;
  final double tds;
  final double ozone;
  final double uv;
  final bool isCompliant;
  final DateTime createdAt;

  QualityReading({
    this.id,
    required this.batchNumber,
    required this.productSize,
    required this.shift,
    required this.operatingHours,
    required this.ph,
    required this.tds,
    required this.ozone,
    required this.uv,
    required this.isCompliant,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// تحويل النموذج إلى Map لحفظه في قاعدة البيانات
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batchNumber': batchNumber,
      'productSize': productSize,
      'shift': shift,
      'operatingHours': operatingHours,
      'ph': ph,
      'tds': tds,
      'ozone': ozone,
      'uv': uv,
      'isCompliant': isCompliant ? 1 : 0, // SQLite boolean
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// إنشاء نموذج من Map (عند القراءة من قاعدة البيانات)
  factory QualityReading.fromJson(Map<String, dynamic> json) {
    return QualityReading(
      id: json['id']?.toString(), // SQLite might return int for auto-increment PK
      batchNumber: json['batchNumber'] as String,
      productSize: json['productSize'] as String,
      shift: json['shift'] as String,
      operatingHours: (json['operatingHours'] as num).toDouble(),
      ph: (json['ph'] as num).toDouble(),
      tds: (json['tds'] as num).toDouble(),
      ozone: (json['ozone'] as num).toDouble(),
      uv: (json['uv'] as num).toDouble(),
      isCompliant: (json['isCompliant'] as int) == 1, // SQLite boolean
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// نسخة معدلة من النموذج (Immutable Pattern)
  QualityReading copyWith({
    String? id,
    String? batchNumber,
    String? productSize,
    String? shift,
    double? operatingHours,
    double? ph,
    double? tds,
    double? ozone,
    double? uv,
    bool? isCompliant,
    DateTime? createdAt,
  }) {
    return QualityReading(
      id: id ?? this.id,
      batchNumber: batchNumber ?? this.batchNumber,
      productSize: productSize ?? this.productSize,
      shift: shift ?? this.shift,
      operatingHours: operatingHours ?? this.operatingHours,
      ph: ph ?? this.ph,
      tds: tds ?? this.tds,
      ozone: ozone ?? this.ozone,
      uv: uv ?? this.uv,
      isCompliant: isCompliant ?? this.isCompliant,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'QualityReading(batch: $batchNumber, size: $productSize, compliant: $isCompliant)';
  }
}
