/// نموذج بيانات المصنع / الفرع
class BranchModel {
  final int? id;
  final String name;
  final String code;
  final String? location;
  final bool isActive;

  const BranchModel({
    this.id,
    required this.name,
    required this.code,
    this.location,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name.trim(),
      'code': code.trim().toLowerCase(),
      'location': location?.trim(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory BranchModel.fromMap(Map<String, dynamic> map) {
    return BranchModel(
      id: map['id'],
      name: map['name'] ?? 'مصنع غير مسمى',
      code: map['code'] ?? 'plant_${map['id'] ?? 1}',
      location: map['location'],
      isActive: (map['is_active'] ?? 1) == 1,
    );
  }

  BranchModel copyWith({
    int? id,
    String? name,
    String? code,
    String? location,
    bool? isActive,
  }) {
    return BranchModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      location: location ?? this.location,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BranchModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// نموذج بيانات الوردية المرتبطة بمصنع وموسم
class ShiftModel {
  final int? id;
  final int branchId;
  final String name;
  final String startTime; // صيغة HH:mm بنظام 24 ساعة (مثال: '06:00')
  final String endTime;   // صيغة HH:mm بنظام 24 ساعة (مثال: '14:00')
  final String seasonName;// التوقيت الصيفي، التوقيت الشتوي، مواعيد رمضان
  final bool isActive;

  const ShiftModel({
    this.id,
    required this.branchId,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.seasonName = 'التوقيت الصيفي',
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch_id': branchId,
      'name': name.trim(),
      'start_time': startTime.trim(),
      'end_time': endTime.trim(),
      'season_name': seasonName.trim(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      id: map['id'],
      branchId: map['branch_id'] ?? 1,
      name: map['name'] ?? 'وردية',
      startTime: map['start_time'] ?? '08:00',
      endTime: map['end_time'] ?? '16:00',
      seasonName: map['season_name'] ?? 'التوقيت الصيفي',
      isActive: (map['is_active'] ?? 1) == 1,
    );
  }

  ShiftModel copyWith({
    int? id,
    int? branchId,
    String? name,
    String? startTime,
    String? endTime,
    String? seasonName,
    bool? isActive,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      seasonName: seasonName ?? this.seasonName,
      isActive: isActive ?? this.isActive,
    );
  }

  /// التحقق مما إذا كانت هذه الوردية نشطة الآن بناءً على ساعة الجهاز الفعلية
  bool isCurrentlyActive([DateTime? now]) {
    if (!isActive) return false;
    final current = now ?? DateTime.now();
    final currentMinutes = current.hour * 60 + current.minute;

    final startMinutes = _timeToMinutes(startTime);
    final endMinutes = _timeToMinutes(endTime);

    if (startMinutes == null || endMinutes == null) return false;

    // حالة 1: الوردية في نفس اليوم (مثلاً 06:00 إلى 14:00)
    if (startMinutes < endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
    // حالة 2: الوردية تمتد لليوم التالي عبر منتصف الليل (مثلاً 22:00 إلى 06:00)
    else {
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    }
  }

  /// حساب عدد ساعات الوردية
  double get durationHours {
    final startMinutes = _timeToMinutes(startTime);
    final endMinutes = _timeToMinutes(endTime);
    if (startMinutes == null || endMinutes == null) return 8.0;

    int diff;
    if (endMinutes >= startMinutes) {
      diff = endMinutes - startMinutes;
    } else {
      diff = (24 * 60 - startMinutes) + endMinutes;
    }
    return diff / 60.0;
  }

  /// تحويل الوقت من 'HH:mm' إلى دقائق
  static int? _timeToMinutes(String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length >= 2) {
        final h = int.parse(parts[0].trim());
        final m = int.parse(parts[1].trim());
        return h * 60 + m;
      }
    } catch (_) {}
    return null;
  }

  /// عرض توقيت الوردية بتنسيق 12 ساعة مقروء بالعربية
  String get formattedDisplayTime {
    return '${format12h(startTime)} - ${format12h(endTime)}';
  }

  static String format12h(String time24) {
    try {
      final parts = time24.split(':');
      final h = int.parse(parts[0]);
      final m = parts[1].padLeft(2, '0');
      final period = h >= 12 ? 'م' : 'ص';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$h12:$m $period';
    } catch (_) {
      return time24;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
