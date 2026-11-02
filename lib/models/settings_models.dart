class Branch {
  final int? id;
  final String name;
  final String location;
  final bool isActive;

  Branch({
    this.id,
    required this.name,
    required this.location,
    required this.isActive,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] as int?,
      name: json['name'] as String,
      location: json['location'] as String,
      isActive: (json['is_active'] as int) == 1,
    );
  }
}

class User {
  final int? id;
  final int branchId;
  final String fullName;
  final String role;
  final String email;
  final String passwordHash;

  User({
    this.id,
    required this.branchId,
    required this.fullName,
    required this.role,
    required this.email,
    required this.passwordHash,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'full_name': fullName,
      'role': role,
      'email': email,
      'password_hash': passwordHash,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int?,
      branchId: json['branch_id'] as int,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      email: json['email'] as String,
      passwordHash: json['password_hash'] as String,
    );
  }
}

class Shift {
  final int? id;
  final int branchId;
  final String name;
  final String startTime;
  final String endTime;

  Shift({
    this.id,
    required this.branchId,
    required this.name,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'name': name,
      'start_time': startTime,
      'end_time': endTime,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  factory Shift.fromJson(Map<String, dynamic> json) => Shift.fromMap(json);

  factory Shift.fromMap(Map<String, dynamic> json) {
    return Shift(
      id: (json['id'] as num?)?.toInt(),
      branchId: (json['branch_id'] ?? json['branchId'] as num?)?.toInt() ?? 1,
      name: (json['name'] ?? '') as String,
      startTime: (json['start_time'] ?? json['startTime'] ?? '') as String,
      endTime: (json['end_time'] ?? json['endTime'] ?? '') as String,
    );
  }
}
