class ProductionLine {
  final int? id;
  final int branchId;
  final String name;
  final bool isActive;

  ProductionLine({
    this.id,
    required this.branchId,
    required this.name,
    required this.isActive,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'name': name,
      'is_active': isActive ? 1 : 0,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  factory ProductionLine.fromMap(Map<String, dynamic> json) {
    return ProductionLine(
      id: (json['id'] as num?)?.toInt(),
      branchId: (json['branch_id'] ?? json['branchId'] as num?)?.toInt() ?? 1,
      name: (json['name'] ?? '') as String,
      isActive: json['is_active'] == 1 || json['is_active'] == true || json['isActive'] == true || json['isActive'] == 1,
    );
  }
}

class Product {
  final int? id;
  final int branchId;
  final String name;
  final double volumeLiters;
  final bool isActive;

  Product({
    this.id,
    required this.branchId,
    required this.name,
    required this.volumeLiters,
    this.isActive = true,
  });

  /// الحجم مع وحدة مناسبة (لتر للقيم ≥ 1، مل لغيرها)
  String get volumeLabel {
    if (volumeLiters >= 1) {
      return volumeLiters % 1 == 0
          ? '${volumeLiters.toInt()} لتر'
          : '$volumeLiters لتر';
    }
    return '${(volumeLiters * 1000).round()} مل';
  }

  /// اسم المصنع المرتبط بالعبوة
  static String branchNameOf(int branchId) {
    return branchId == 2 ? 'مصنع سنحان' : 'مصنع أرتل';
  }

  String get branchName => branchNameOf(branchId);

  Product copyWith({
    int? id,
    int? branchId,
    String? name,
    double? volumeLiters,
    bool? isActive,
  }) {
    return Product(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      name: name ?? this.name,
      volumeLiters: volumeLiters ?? this.volumeLiters,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'name': name,
      'volume_liters': volumeLiters,
      'is_active': isActive ? 1 : 0,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  factory Product.fromJson(Map<String, dynamic> json) => Product.fromMap(json);

  factory Product.fromMap(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] as num?)?.toInt(),
      branchId: (json['branch_id'] ?? json['branchId'] as num?)?.toInt() ?? 1,
      name: (json['name'] ?? json['productName'] ?? '') as String,
      volumeLiters: ((json['volume_liters'] ?? json['volumeLiters']) as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] != null || json['isActive'] != null
          ? (json['is_active'] == 1 || json['is_active'] == true || json['isActive'] == true || json['isActive'] == 1)
          : true,
    );
  }
}
