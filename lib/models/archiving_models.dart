class ArchivedReport {
  final int? id;
  final int logId;
  final String logType;
  final int generatedBy;
  final int approvedBy;
  final String fileUrl;
  final String fileHash;
  final DateTime archivedAt;

  ArchivedReport({
    this.id,
    required this.logId,
    required this.logType,
    required this.generatedBy,
    required this.approvedBy,
    required this.fileUrl,
    required this.fileHash,
    DateTime? archivedAt,
  }) : archivedAt = archivedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'log_id': logId,
      'log_type': logType,
      'generated_by': generatedBy,
      'approved_by': approvedBy,
      'file_url': fileUrl,
      'file_hash': fileHash,
      'archived_at': archivedAt.toIso8601String(),
    };
  }

  factory ArchivedReport.fromJson(Map<String, dynamic> json) {
    return ArchivedReport(
      id: json['id'] as int?,
      logId: json['log_id'] as int,
      logType: json['log_type'] as String,
      generatedBy: json['generated_by'] as int,
      approvedBy: json['approved_by'] as int,
      fileUrl: json['file_url'] as String,
      fileHash: json['file_hash'] as String,
      archivedAt: DateTime.parse(json['archived_at'] as String),
    );
  }
}
