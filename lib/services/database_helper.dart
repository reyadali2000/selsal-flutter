import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/settings_models.dart';
import '../models/production_models.dart';
import '../models/standards_models.dart';
import '../models/water_quality_models.dart';
import '../models/notification_model.dart';
import '../models/hygiene_models.dart';
import '../models/raw_material_models.dart';
import '../models/dynamic_report_models.dart';
import '../models/role_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('wadialain_quality_v18.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onConfigure: _onConfigure,
      onCreate: _createDB,
      onOpen: (db) async {
        // ضمان وجود الجداول الأساسية وتحديث الأعمدة المضافة
        await _ensureWaterQualityColumns(db);
        await _ensureHygieneReportTables(db);
        await _ensureRawMaterialTables(db);
        await _ensureDailyWorkersTable(db);
        await _ensureSyncQueueTable(db);
        await _ensureSignaturesAndApprovalColumns(db);
        await _ensureDynamicReportTables(db);
      },
    );
  }

  Future _onConfigure(Database db) async {
    // تفعيل المفاتيح الأجنبية
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// إنشاء جدول طابور المزامنة (sync_queue) إن لم يكن موجوداً.
  /// يخزّن عمليات الكتابة التي فشلت بسبب انقطاع الشبكة لإعادة إرسالها.
  Future<void> _ensureSyncQueueTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        method TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        body_json TEXT,
        entity_type TEXT,
        entity_id INTEGER,
        status TEXT NOT NULL DEFAULT 'pending',
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        next_retry_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue (status, next_retry_at)',
    );
  }

  /// إنشاء جدول سجل العمالة اليومية إن لم يكن موجوداً.
  /// يتميز عن جدول Employees بأنه يحتفظ بمعرّف ثابت لكل عامل ومفتاح
  /// اسم مطبَّع لمنع التكرار وتمكين الاقتراحات التلقائية.
  /// يقبل [DatabaseExecutor] ليعمل داخل الترانزاكشن وخارجها على حد سواء.
  Future<void> _ensureDailyWorkersTable(DatabaseExecutor db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS DailyWorkers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          branch_id INTEGER NOT NULL DEFAULT 1,
          full_name TEXT NOT NULL,
          name_key TEXT NOT NULL,
          job_title TEXT,
          is_active INTEGER DEFAULT 1,
          created_at TEXT,
          UNIQUE(branch_id, name_key),
          FOREIGN KEY (branch_id) REFERENCES Branches(id)
        )
      ''');
      final info = await db.rawQuery("PRAGMA table_info(DailyWorkers)");
      final existingCols = info.map((r) => r['name'].toString()).toSet();
      for (final column in <String>[
        'name_key TEXT',
        'job_title TEXT',
        'is_active INTEGER DEFAULT 1',
        'created_at TEXT',
      ]) {
        final parts = column.split(' ');
        final colName = parts.first;
        final colType = column.substring(colName.length).trim();
        if (!existingCols.contains(colName)) {
          try {
            await db.execute(
              'ALTER TABLE DailyWorkers ADD COLUMN $colName $colType',
            );
          } catch (_) {
            // العمود موجود مسبقاً
          }
        }
      }
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_daily_workers_name_key ON DailyWorkers(name_key)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_daily_workers_branch ON DailyWorkers(branch_id)',
      );
    } catch (e) {
      debugPrint('Error ensuring DailyWorkers table: $e');
    }
  }

  /// نسخة عامة من ضمان وجود الجدول تُستدعى من الخدمات الخارجية
  /// (تأخذ قاعدة البيانات من المثيل المُدار مركزياً).
  Future<void> ensureDailyWorkersTable() async {
    final db = await instance.database;
    await _ensureDailyWorkersTable(db);
  }

  // =====================================
  // إنشاء جداول قاعدة البيانات المحلية (cache)
  // =====================================

  Future _createDB(Database db, int version) async {
    // 1. الإعدادات العامة والثوابت (Settings)
    await db.execute('''
      CREATE TABLE Branches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        code TEXT UNIQUE,
        location TEXT,
        is_active INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE Users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER,
        full_name TEXT,
        username TEXT UNIQUE,
        role TEXT,
        email TEXT,
        password_hash TEXT,
        phone TEXT,
        job_title TEXT,
        is_active INTEGER DEFAULT 1,
        avatar_color INTEGER,
        created_at TEXT,
        last_login TEXT,
        FOREIGN KEY (branch_id) REFERENCES Branches(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE Shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER,
        name TEXT,
        start_time TEXT,
        end_time TEXT,
        season_name TEXT DEFAULT 'التوقيت الصيفي',
        is_active INTEGER DEFAULT 1,
        FOREIGN KEY (branch_id) REFERENCES Branches(id)
      )
    ''');

    // 2. الأصناف (Products)

    await db.execute('''
      CREATE TABLE Products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER,
        name TEXT,
        volume_liters REAL,
        is_active INTEGER DEFAULT 1,
        FOREIGN KEY (branch_id) REFERENCES Branches(id)
      )
    ''');

    // 3. إدارة الفحوصات ومعايير الجودة الديناميكية (Dynamic Standards)
    await db.execute('''
      CREATE TABLE TestParameters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT,
        name_ar TEXT,
        unit TEXT,
        input_type TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE QualityStandards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER,
        water_type TEXT,
        parameter_id INTEGER,
        min_value REAL,
        max_value REAL,
        expected_text TEXT,
        FOREIGN KEY (product_id) REFERENCES Products(id),
        FOREIGN KEY (parameter_id) REFERENCES TestParameters(id)
      )
    ''');

    // 4. سجل الفحص الرئيسي ونتائج المياه (Water Quality Logs)
    await db.execute('''
      CREATE TABLE WaterQualityLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER DEFAULT 1,
        branch_name TEXT DEFAULT 'مصنع أرتل',
        shift_id INTEGER,
        shift_name TEXT,
        created_by INTEGER,
        report_category TEXT,
        water_type TEXT,
        batch_number TEXT,
        is_compliant INTEGER,
        general_notes TEXT,
        created_at TEXT,
        approval_status TEXT,
        approved_by INTEGER,
        approved_at TEXT,
        rejection_reason TEXT,
        water_source TEXT,
        well_number TEXT,
        sample_taker TEXT,
        manager_notified INTEGER,
        source_suspended INTEGER,
        ncr_number TEXT,
        qm_approved_by TEXT,
        qm_approved_at TEXT,
        gm_approved_by TEXT,
        gm_approved_at TEXT,
        rejected_by TEXT,
        product_name TEXT,
        bottle_size TEXT,
        production_date TEXT,
        sampling_time TEXT,
        sampling_location TEXT,
        produced_quantity TEXT,
        is_isolated INTEGER,
        is_hold_issued INTEGER,
        is_reject_issued INTEGER,
        micro_results_pending INTEGER DEFAULT 0,
        micro_entered_by TEXT,
        micro_entered_at TEXT,
        stage1_qm_approved_by TEXT,
        stage1_qm_approved_at TEXT,
        stage1_gm_approved_by TEXT,
        stage1_gm_approved_at TEXT,
        micro_qm_approved_by TEXT,
        micro_qm_approved_at TEXT,
        micro_gm_approved_by TEXT,
        micro_gm_approved_at TEXT,
        rejection_category TEXT,
        severity_level TEXT,
        rejection_notes TEXT,
        affected_products TEXT,
        immediate_action TEXT,
        corrective_action TEXT,
        corrective_owner TEXT,
        corrective_due_date TEXT,
        gm_decision TEXT,
        gm_decision_by TEXT,
        gm_decision_at TEXT,
        gm_decision_notes TEXT,
        FOREIGN KEY (branch_id) REFERENCES Branches(id),
        FOREIGN KEY (shift_id) REFERENCES Shifts(id),
        FOREIGN KEY (created_by) REFERENCES Users(id),
        FOREIGN KEY (approved_by) REFERENCES Users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS Notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER,
        title TEXT,
        body TEXT,
        report_id INTEGER,
        report_category TEXT,
        target_role TEXT,
        is_read INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE WaterQualityResults (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        log_id INTEGER,
        parameter_id INTEGER,
        numeric_result REAL,
        text_result TEXT,
        is_compliant INTEGER,
        notes TEXT,
        FOREIGN KEY (log_id) REFERENCES WaterQualityLogs(id),
        FOREIGN KEY (parameter_id) REFERENCES TestParameters(id)
      )
    ''');

    // 5. سلامة الغذاء والنظافة والعمال (Food Safety, Hygiene & Facility)
    await db.execute('''
      CREATE TABLE Employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER,
        full_name TEXT,
        job_title TEXT,
        is_active INTEGER,
        FOREIGN KEY (branch_id) REFERENCES Branches(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE Checklists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        type TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ChecklistItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        checklist_id INTEGER,
        item_name TEXT,
        FOREIGN KEY (checklist_id) REFERENCES Checklists(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE HygieneLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER,
        branch_id INTEGER,
        shift_id INTEGER,
        checklist_id INTEGER,
        employee_id INTEGER,
        created_by INTEGER,
        created_at TEXT,
        approval_status TEXT,
        approved_by INTEGER,
        approved_at TEXT,
        rejection_reason TEXT,
        FOREIGN KEY (branch_id) REFERENCES Branches(id),
        FOREIGN KEY (shift_id) REFERENCES Shifts(id),
        FOREIGN KEY (checklist_id) REFERENCES Checklists(id),
        FOREIGN KEY (employee_id) REFERENCES Employees(id),
        FOREIGN KEY (created_by) REFERENCES Users(id),
        FOREIGN KEY (approved_by) REFERENCES Users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE HygieneReports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        supervisor_name TEXT,
        employee_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE HygieneLogDetails (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hygiene_log_id INTEGER,
        checklist_item_id INTEGER,
        is_compliant INTEGER,
        photo_url TEXT,
        notes TEXT,
        FOREIGN KEY (hygiene_log_id) REFERENCES HygieneLogs(id),
        FOREIGN KEY (checklist_item_id) REFERENCES ChecklistItems(id)
      )
    ''');

    // 7. سجل العمالة اليومية (Daily Workers Registry) — معرّف ثابت لكل عامل
    await db.execute('''
      CREATE TABLE DailyWorkers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL DEFAULT 1,
        full_name TEXT NOT NULL,
        name_key TEXT NOT NULL,
        job_title TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        UNIQUE(branch_id, name_key),
        FOREIGN KEY (branch_id) REFERENCES Branches(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_daily_workers_name_key ON DailyWorkers(name_key)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_daily_workers_branch ON DailyWorkers(branch_id)',
    );

    // 8. الأرشفة الرقمية للتقارير (Archiving)
    await db.execute('''
      CREATE TABLE ArchivedReports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        log_id INTEGER,
        log_type TEXT,
        generated_by INTEGER,
        approved_by INTEGER,
        file_url TEXT,
        file_hash TEXT,
        archived_at TEXT,
        FOREIGN KEY (generated_by) REFERENCES Users(id),
        FOREIGN KEY (approved_by) REFERENCES Users(id)
      )
    ''');

    // إنشاء الجداول الإضافية (بدون بذور — البيانات تأتي من الـ API)
    await _ensureWaterQualityColumns(db);
    await _ensureRawMaterialTables(db);
    await _ensureHygieneReportTables(db);
    await _createDynamicReportTables(db);
    await _ensureCustomRolesTable(db);
    await _ensureBranchesAndShiftsTable(db);
    await _ensureSyncQueueTable(db);
  }

  Future<void> _safeAddColumn(
    Database db,
    String table,
    String col,
    String type,
  ) async {
    try {
      final tableCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [table],
      );
      if (tableCheck.isEmpty) return;

      final cols = await db.rawQuery("PRAGMA table_info('$table')");
      final existing =
          cols.map((c) => (c['name'] ?? '').toString().toLowerCase()).toSet();
      if (!existing.contains(col.toLowerCase())) {
        await db.execute('ALTER TABLE $table ADD COLUMN $col $type');
      }
    } catch (_) {}
  }

  Future<void> _ensureWaterQualityColumns(Database db) async {
    try {
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'branch_id',
        'INTEGER DEFAULT 1',
      );
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'branch_name',
        "TEXT DEFAULT 'مصنع أرتل'",
      );
      await _safeAddColumn(db, 'WaterQualityLogs', 'shift_id', 'INTEGER');
      await _safeAddColumn(db, 'WaterQualityLogs', 'shift_name', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'rejected_by', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'product_name', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'bottle_size', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'production_date', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'sampling_time', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'sampling_location', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'produced_quantity', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'is_isolated', 'INTEGER');
      await _safeAddColumn(db, 'WaterQualityLogs', 'is_hold_issued', 'INTEGER');
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'is_reject_issued',
        'INTEGER',
      );
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'micro_results_pending',
        'INTEGER DEFAULT 0',
      );
      await _safeAddColumn(db, 'WaterQualityLogs', 'micro_entered_by', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'micro_entered_at', 'TEXT');
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'stage1_qm_approved_by',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'stage1_qm_approved_at',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'stage1_gm_approved_by',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'stage1_gm_approved_at',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'micro_qm_approved_by',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'micro_qm_approved_at',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'micro_gm_approved_by',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'micro_gm_approved_at',
        'TEXT',
      );
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'micro_rejection_reason',
        'TEXT',
      );
      await _safeAddColumn(db, 'WaterQualityLogs', 'micro_rejected_by', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'micro_rejected_at', 'TEXT');
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'micro_rejection_action',
        'TEXT',
      );

      // حقول دورة الرفض والإجراء التصحيحي — مياه خام ومنتج نهائي
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'rejection_category',
        'TEXT',
      );
      await _safeAddColumn(db, 'WaterQualityLogs', 'severity_level', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'rejection_notes', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'affected_products', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'immediate_action', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'corrective_action', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'corrective_owner', 'TEXT');
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'corrective_due_date',
        'TEXT',
      );
      await _safeAddColumn(db, 'WaterQualityLogs', 'gm_decision', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'gm_decision_by', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'gm_decision_at', 'TEXT');
      await _safeAddColumn(db, 'WaterQualityLogs', 'gm_decision_notes', 'TEXT');
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'rejection_count',
        'INTEGER DEFAULT 0',
      );
    } catch (e) {
      debugPrint('Error in _ensureWaterQualityColumns: $e');
    }
  }

  Future<void> _ensureDynamicReportTables(Database db) async {
    try {
      await _safeAddColumn(db, 'dr_reports', 'icon', 'TEXT');
      await _safeAddColumn(db, 'dr_reports', 'icon_name', 'TEXT');
      await _safeAddColumn(
        db,
        'dr_reports',
        'approval_type',
        "TEXT DEFAULT 'two_level'",
      );
      await _safeAddColumn(
        db,
        'dr_reports',
        'orientation',
        "TEXT DEFAULT 'portrait'",
      );

      await _safeAddColumn(db, 'dr_records', 'branch_id', 'INTEGER DEFAULT 1');
      await _safeAddColumn(
        db,
        'dr_records',
        'branch_name',
        "TEXT DEFAULT 'مصنع أرتل'",
      );
      await _safeAddColumn(db, 'dr_records', 'shift_id', 'INTEGER DEFAULT 1');
      await _safeAddColumn(db, 'dr_records', 'shift_name', 'TEXT');
      await _safeAddColumn(
        db,
        'dr_records',
        'approval_status',
        "TEXT DEFAULT 'Pending_QM'",
      );
      await _safeAddColumn(db, 'dr_records', 'qm_approved_by', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'qm_approved_at', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'gm_approved_by', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'gm_approved_at', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'rejection_reason', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'rejected_by', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'rejected_at', 'TEXT');

      await _safeAddColumn(db, 'dr_records', 'rejection_category', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'severity_level', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'rejection_notes', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'affected_products', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'immediate_action', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'corrective_action', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'corrective_owner', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'corrective_due_date', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'gm_decision', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'gm_decision_by', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'gm_decision_at', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'gm_decision_notes', 'TEXT');
      await _safeAddColumn(db, 'dr_records', 'client_uuid', 'TEXT');
      await _safeAddColumn(
        db,
        'dr_records',
        'rejection_count',
        'INTEGER DEFAULT 0',
      );
      await _safeAddColumn(db, 'dr_records', 'record_serial', 'INTEGER');
      await _safeAddColumn(db, 'dr_records', 'record_code', 'TEXT');

      // فك قيد المفتاح الأجنبي عن dr_values إن وجد لمنع خطأ SQLite (code 787)
      final sqlCheck = await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name='dr_values'",
      );
      if (sqlCheck.isNotEmpty) {
        final ddl = sqlCheck.first['sql']?.toString() ?? '';
        if (ddl.contains('REFERENCES dr_fields')) {
          await db.execute('PRAGMA foreign_keys = OFF');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS dr_values_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              record_id INTEGER NOT NULL,
              field_id INTEGER NOT NULL,
              value TEXT
            )
          ''');
          await db.execute(
            'INSERT INTO dr_values_new (id, record_id, field_id, value) SELECT id, record_id, field_id, value FROM dr_values',
          );
          await db.execute('DROP TABLE dr_values');
          await db.execute('ALTER TABLE dr_values_new RENAME TO dr_values');
          await db.execute('PRAGMA foreign_keys = ON');
        }
      }
    } catch (_) {}
  }

  /// ضمان وجود جدول التوقيعات الرقمية وأعمدة بصمة التوقيع المتراكب
  Future<void> _ensureSignaturesAndApprovalColumns(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_signatures (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          signature_type TEXT DEFAULT 'drawn_png',
          signature_data TEXT NOT NULL,
          signature_hash TEXT,
          is_active INTEGER DEFAULT 1,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (user_id) REFERENCES Users(id) ON DELETE CASCADE
        )
      ''');

      await _safeAddColumn(
        db,
        'report_approvals',
        'signature_snapshot_blob',
        'BLOB',
      );
      await _safeAddColumn(
        db,
        'report_approvals',
        'signature_snapshot_path',
        'TEXT',
      );
      await _safeAddColumn(db, 'report_approvals', 'signature_hash', 'TEXT');
      await _safeAddColumn(db, 'report_approvals', 'signature_type', 'TEXT');
      await _safeAddColumn(
        db,
        'report_approvals',
        'action_by_position',
        'TEXT',
      );
      await _safeAddColumn(db, 'report_approvals', 'document_hash', 'TEXT');

      await _safeAddColumn(
        db,
        'dr_report_versions',
        'signature_layout_json',
        'TEXT',
      );

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_user_signatures_user ON user_signatures(user_id, is_active)',
      );
    } catch (e) {
      debugPrint('Error ensuring signatures and approval columns: $e');
    }
  }

  Future<void> _ensureCustomRolesTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS CustomRoles (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code TEXT UNIQUE NOT NULL,
          title TEXT NOT NULL,
          description TEXT,
          color INTEGER,
          icon_name TEXT,
          permissions_json TEXT NOT NULL,
          is_system INTEGER DEFAULT 0,
          created_at TEXT
        )
      ''');

      for (final role in RoleModel.defaultSystemRoles) {
        final existing = await db.query(
          'CustomRoles',
          where: 'code = ?',
          whereArgs: [role.code],
        );
        if (existing.isEmpty) {
          await db.insert('CustomRoles', role.toMap());
        }
      }
    } catch (e) {
      debugPrint('Error in _ensureCustomRolesTable: $e');
    }
  }

  Future<void> _ensureBranchesAndShiftsTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Branches (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          code TEXT UNIQUE,
          location TEXT,
          is_active INTEGER DEFAULT 1
        )
      ''');

      await _safeAddColumn(db, 'Branches', 'code', 'TEXT');
      await _safeAddColumn(db, 'Branches', 'location', 'TEXT');
      await _safeAddColumn(db, 'Branches', 'is_active', 'INTEGER DEFAULT 1');

      // ضخ وتحديث المصنعين: مصنع أرتل و مصنع سنحان
      final b1 = await db.query('Branches', where: 'id = 1');
      if (b1.isEmpty) {
        await db.rawInsert('''
          INSERT OR REPLACE INTO Branches (id, name, code, location, is_active)
          VALUES (1, 'مصنع أرتل (المصنع الرئيسي)', 'plant_1', 'الموقع الرئيسي', 1)
        ''');
      } else {
        await db.update('Branches', {
          'name': 'مصنع أرتل (المصنع الرئيسي)',
          'code': 'plant_1',
          'is_active': 1,
        }, where: 'id = 1');
      }

      final b2 = await db.query('Branches', where: 'id = 2');
      if (b2.isEmpty) {
        await db.rawInsert('''
          INSERT OR REPLACE INTO Branches (id, name, code, location, is_active)
          VALUES (2, 'مصنع سنحان (المصنع الثاني)', 'plant_2', 'الموقع الثاني', 1)
        ''');
      } else {
        await db.update('Branches', {
          'name': 'مصنع سنحان (المصنع الثاني)',
          'code': 'plant_2',
          'is_active': 1,
        }, where: 'id = 2');
      }

      // جدول الورديات
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Shifts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          branch_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          start_time TEXT NOT NULL,
          end_time TEXT NOT NULL,
          season_name TEXT DEFAULT 'التوقيت الصيفي',
          is_active INTEGER DEFAULT 1,
          FOREIGN KEY (branch_id) REFERENCES Branches(id)
        )
      ''');

      await _safeAddColumn(
        db,
        'Shifts',
        'season_name',
        "TEXT DEFAULT 'التوقيت الصيفي'",
      );
      await _safeAddColumn(db, 'Shifts', 'is_active', 'INTEGER DEFAULT 1');
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'branch_id',
        'INTEGER DEFAULT 1',
      );
      await _safeAddColumn(
        db,
        'WaterQualityLogs',
        'branch_name',
        "TEXT DEFAULT 'مصنع أرتل'",
      );
      await _safeAddColumn(db, 'WaterQualityLogs', 'shift_name', 'TEXT');

      // ضخ ورديات مصنع أرتل إذا لم تكن موجودة
      final shifts1 = await db.query(
        'Shifts',
        where: 'branch_id = ?',
        whereArgs: [1],
      );
      if (shifts1.isEmpty) {
        await db.insert('Shifts', {
          'branch_id': 1,
          'name': 'الوردية الأولى (الصباحية)',
          'start_time': '06:00',
          'end_time': '14:00',
          'season_name': 'التوقيت الصيفي',
          'is_active': 1,
        });
        await db.insert('Shifts', {
          'branch_id': 1,
          'name': 'الوردية الثانية (المسائية)',
          'start_time': '14:00',
          'end_time': '22:00',
          'season_name': 'التوقيت الصيفي',
          'is_active': 1,
        });
        await db.insert('Shifts', {
          'branch_id': 1,
          'name': 'الوردية الثالثة (الليلية)',
          'start_time': '22:00',
          'end_time': '06:00',
          'season_name': 'التوقيت الصيفي',
          'is_active': 1,
        });
      }

      // ضخ ورديات مصنع سنحان إذا لم تكن موجودة
      final shifts2 = await db.query(
        'Shifts',
        where: 'branch_id = ?',
        whereArgs: [2],
      );
      if (shifts2.isEmpty) {
        await db.insert('Shifts', {
          'branch_id': 2,
          'name': 'الوردية الأولى (الصباحية)',
          'start_time': '07:00',
          'end_time': '15:30',
          'season_name': 'التوقيت الصيفي',
          'is_active': 1,
        });
        await db.insert('Shifts', {
          'branch_id': 2,
          'name': 'الوردية الثانية (المسائية)',
          'start_time': '15:30',
          'end_time': '00:00',
          'season_name': 'التوقيت الصيفي',
          'is_active': 1,
        });
      }
    } catch (e) {
      debugPrint('Error in _ensureBranchesAndShiftsTable: $e');
    }
  }

  // =====================================
  // عمليات القراءة والكتابة (CRUD)
  // =====================================

  // =====================================
  // عمليات جلب البيانات المرجعية
  // =====================================

  Future<List<Shift>> getShifts() async {
    final db = await instance.database;
    final result = await db.query('Shifts');
    return result.map((json) => Shift.fromJson(json)).toList();
  }

  /// ورديات مصنع محدد فقط (أو كل المصانع إذا كان branchId فارغاً)
  Future<List<Shift>> getShiftsForBranch(int? branchId) async {
    final db = await instance.database;
    if (branchId == null || branchId <= 0) {
      final result = await db.query('Shifts', orderBy: 'branch_id ASC, id ASC');
      return result.map((json) => Shift.fromJson(json)).toList();
    }
    final result = await db.query(
      'Shifts',
      where: 'branch_id = ?',
      whereArgs: [branchId],
      orderBy: 'id ASC',
    );
    return result.map((json) => Shift.fromJson(json)).toList();
  }

  Future<List<Product>> getProducts() async {
    final db = await instance.database;
    final result = await db.query('Products');
    return result.map((json) => Product.fromJson(json)).toList();
  }

  // ===== إدارة العبوات (Products per Branch) =====

  /// العبوات النشطة المرئية لمستخدم فرع معين (أو كل الفروع إذا كان branchId فارغاً)
  Future<List<Product>> getActiveProducts({int? branchId}) async {
    final db = await instance.database;
    final result = await db.query(
      'Products',
      where:
          branchId != null && branchId > 0
              ? 'is_active = 1 AND branch_id = ?'
              : 'is_active = 1',
      whereArgs: branchId != null && branchId > 0 ? [branchId] : null,
      orderBy: 'branch_id ASC, volume_liters ASC',
    );
    return result.map((json) => Product.fromJson(json)).toList();
  }

  /// كل العبوات مع إمكانية التصفية حسب الفرع (تشمل غير النشطة)
  Future<List<Product>> getAllProducts({int? branchId}) async {
    final db = await instance.database;
    final result = await db.query(
      'Products',
      where: branchId != null && branchId > 0 ? 'branch_id = ?' : null,
      whereArgs: branchId != null && branchId > 0 ? [branchId] : null,
      orderBy: 'branch_id ASC, volume_liters ASC',
    );
    return result.map((json) => Product.fromJson(json)).toList();
  }

  /// عدد السجلات المرتبطة بعبوة معينة (لمنع الحذف إذا كانت مستخدمة)
  Future<int> countProductUsages(int productId) async {
    final db = await instance.database;
    final rows = await db.query(
      'QualityStandards',
      where: 'product_id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    return rows.isNotEmpty ? 1 : 0;
  }

  Future<int> insertProduct(Product product) async {
    final db = await instance.database;
    return await db.insert('Products', product.toJson());
  }

  Future<int> updateProduct(Product product) async {
    final db = await instance.database;
    if (product.id == null) return 0;
    return await db.update(
      'Products',
      {
        'name': product.name,
        'volume_liters': product.volumeLiters,
        'branch_id': product.branchId,
        'is_active': product.isActive ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> setProductActive(int productId, bool active) async {
    final db = await instance.database;
    return await db.update(
      'Products',
      {'is_active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<int> deleteProduct(int productId) async {
    final db = await instance.database;
    // حذف العبوة مع مواصفاتها القياسية المرتبطة بها (cascade يدوي ضمن معاملة)
    return await db.transaction((txn) async {
      await txn.delete(
        'QualityStandards',
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      return await txn.delete(
        'Products',
        where: 'id = ?',
        whereArgs: [productId],
      );
    });
  }

  Future<List<TestParameter>> getTestParameters() async {
    final db = await instance.database;
    final result = await db.query('TestParameters');
    return result.map((json) => TestParameter.fromJson(json)).toList();
  }

  Future<List<QualityStandard>> getQualityStandards(
    int? productId,
    String waterType,
  ) async {
    final db = await instance.database;
    if (productId != null) {
      final result = await db.query(
        'QualityStandards',
        where: '(product_id = ? OR product_id IS NULL) AND water_type = ?',
        whereArgs: [productId, waterType],
        orderBy: 'id ASC',
      );
      return result.map((json) => QualityStandard.fromJson(json)).toList();
    } else {
      final result = await db.query(
        'QualityStandards',
        where: 'product_id IS NULL AND water_type = ?',
        whereArgs: [waterType],
        orderBy: 'id ASC',
      );
      return result.map((json) => QualityStandard.fromJson(json)).toList();
    }
  }

  Future<void> syncProducts(List<Product> productsList) async {
    if (productsList.isEmpty) return;
    final db = await instance.database;
    final batch = db.batch();
    for (final p in productsList) {
      batch.insert(
        'Products',
        p.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> syncTestParameters(List<TestParameter> params) async {
    if (params.isEmpty) return;
    final db = await instance.database;
    final batch = db.batch();
    for (final p in params) {
      batch.insert(
        'TestParameters',
        p.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> syncQualityStandards(
    List<QualityStandard> standardsList, {
    String? waterType,
  }) async {
    if (standardsList.isEmpty) return;
    final db = await instance.database;
    await db.transaction((txn) async {
      if (waterType != null && waterType.isNotEmpty) {
        await txn.delete(
          'QualityStandards',
          where: 'water_type = ?',
          whereArgs: [waterType],
        );
      }
      final batch = txn.batch();
      for (final s in standardsList) {
        batch.insert(
          'QualityStandards',
          s.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  // =====================================
  // عمليات حفظ واسترجاع التقارير
  // =====================================

  Future<void> saveWaterQualityReport(
    WaterQualityLog log,
    List<WaterQualityResult> results,
  ) async {
    final db = await instance.database;
    await _ensureWaterQualityColumns(db);

    await db.transaction((txn) async {
      final logData = log.toJson();
      int logId;

      // تصفية الحقول لتطابق بنية الجدول الفعلية وتفادي أخطاء SQLite
      final info = await txn.rawQuery("PRAGMA table_info('WaterQualityLogs')");
      final validCols =
          info.map((r) => r['name'].toString().toLowerCase()).toSet();
      logData.removeWhere((key, _) => !validCols.contains(key.toLowerCase()));

      if (log.id != null) {
        // Check if the row actually exists locally (it won't when the ID came from the API)
        final existing = await txn.query(
          'WaterQualityLogs',
          where: 'id = ?',
          whereArgs: [log.id],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          logData.remove('id');
          await txn.update(
            'WaterQualityLogs',
            logData,
            where: 'id = ?',
            whereArgs: [log.id],
          );
          logId = log.id!;
          await txn.delete(
            'WaterQualityResults',
            where: 'log_id = ?',
            whereArgs: [logId],
          );
        } else {
          // Row does not exist locally (API-assigned ID) - insert it with that ID
          logData['id'] = log.id;
          await txn.insert(
            'WaterQualityLogs',
            logData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          logId = log.id!;
        }
      } else {
        // New record
        logData.remove('id');
        logId = await txn.insert('WaterQualityLogs', logData);
      }

      // حفظ النتائج مع ضمان وجود المعيار لتفادي فشل الـ Foreign Key
      for (var result in results) {
        final paramCheck = await txn.query(
          'TestParameters',
          where: 'id = ?',
          whereArgs: [result.parameterId],
          limit: 1,
        );
        if (paramCheck.isEmpty) {
          await txn.insert('TestParameters', {
            'id': result.parameterId,
            'name_ar': 'معيار #${result.parameterId}',
            'category': 'General',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        final resultData = result.toJson();
        resultData['log_id'] = logId;
        resultData.remove('id');
        await txn.insert('WaterQualityResults', resultData);
      }
    });
  }

  Future<void> deleteWaterQualityReport(int logId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete(
        'WaterQualityResults',
        where: 'log_id = ?',
        whereArgs: [logId],
      );
      await txn.delete('WaterQualityLogs', where: 'id = ?', whereArgs: [logId]);
    });
  }

  Future<int> saveDynamicReportRecordLocal(
    DynamicReportRecord record,
    List<DynamicReportValue> values, {
    int? previousLocalId,
  }) async {
    final db = await instance.database;
    return await db.transaction<int>((txn) async {
      if (previousLocalId != null &&
          record.id != null &&
          record.id! > 0 &&
          previousLocalId != record.id) {
        await txn.delete(
          'dr_values',
          where: 'record_id = ?',
          whereArgs: [previousLocalId],
        );
        await txn.delete(
          'dr_records',
          where: 'id = ?',
          whereArgs: [previousLocalId],
        );
      }

      final info = await txn.rawQuery("PRAGMA table_info('dr_records')");
      final validCols =
          info.map((r) => r['name'].toString().toLowerCase()).toSet();
      final rowMap = record.toMap();
      rowMap.removeWhere((k, _) => !validCols.contains(k.toLowerCase()));

      int effectiveId;
      if (record.id != null && record.id! > 0) {
        effectiveId = record.id!;
        rowMap['id'] = effectiveId;
        await txn.insert(
          'dr_records',
          rowMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.delete(
          'dr_values',
          where: 'record_id = ?',
          whereArgs: [effectiveId],
        );
      } else if (record.id != null && record.id! < 0) {
        // تحديث سجل محلي محفوظ أوفلاين مسبقاً بنفس المعرف السالب
        effectiveId = record.id!;
        rowMap['id'] = effectiveId;
        await txn.insert(
          'dr_records',
          rowMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.delete(
          'dr_values',
          where: 'record_id = ?',
          whereArgs: [effectiveId],
        );
      } else {
        // إنشاء سجل محلي أوفلاين جديد: نولّد له معرّفاً سالباً فريداً
        // لمنع أي تداخل مع المعرّفات الموجبة القادمة من السيرفر
        effectiveId = -DateTime.now().millisecondsSinceEpoch;
        rowMap['id'] = effectiveId;
        await txn.insert(
          'dr_records',
          rowMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final v in values) {
        await txn.insert('dr_values', {
          'record_id': effectiveId,
          'field_id': v.fieldId,
          'value': v.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return effectiveId;
    });
  }

  /// يحفظ نتائج الفحوصات الميكروبيولوجية فقط لتقرير موجود (المرحلة الثانية).
  /// يُحذف ما كان مُسجَّلاً سابقاً من نتائج الميكروبيولوجي لهذا التقرير
  /// ثم تُدرج النتائج الجديدة دون المساس بباقي نتائج الفحوصات.
  /// تحديث المعرف المؤقت السالب لسجل أوفلاين إلى المعرف الحقيقي الموجب القادم من السيرفر بعد المزامنة
  Future<void> updateDynamicReportRecordId({
    required int oldLocalId,
    required int newServerId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE dr_records SET id = ? WHERE id = ?',
        [newServerId, oldLocalId],
      );
      await txn.rawUpdate(
        'UPDATE dr_values SET record_id = ? WHERE record_id = ?',
        [newServerId, oldLocalId],
      );
    });
  }

  /// تحديث المعرف المؤقت لتقرير فحص المياه ونتائجه إلى المعرف الجديد من السيرفر
  Future<void> updateWaterQualityLogId({
    required int oldLocalId,
    required int newServerId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE WaterQualityLogs SET id = ? WHERE id = ?',
        [newServerId, oldLocalId],
      );
      await txn.rawUpdate(
        'UPDATE WaterQualityResults SET log_id = ? WHERE log_id = ?',
        [newServerId, oldLocalId],
      );
    });
  }

  /// تحديث المعرف المؤقت لتقرير النظافة وقوائم الفحص التابعة له
  Future<void> updateHygieneReportId({
    required int oldLocalId,
    required int newServerId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE HygieneReports SET id = ? WHERE id = ?',
        [newServerId, oldLocalId],
      );
      await txn.rawUpdate(
        'UPDATE HygieneLogs SET report_id = ? WHERE report_id = ?',
        [newServerId, oldLocalId],
      );
    });
  }

  /// تحديث المعرف المؤقت لتقرير المواد الأولية والنتائج التابعة له
  Future<void> updateRawMaterialReportId({
    required int oldLocalId,
    required int newServerId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE RawMaterialReports SET id = ? WHERE id = ?',
        [newServerId, oldLocalId],
      );
      await txn.rawUpdate(
        'UPDATE RawMaterialGeneralResults SET report_id = ? WHERE report_id = ?',
        [newServerId, oldLocalId],
      );
      await txn.rawUpdate(
        'UPDATE RawMaterialAnnexResults SET report_id = ? WHERE report_id = ?',
        [newServerId, oldLocalId],
      );
    });
  }

  Future<void> saveMicrobiologicalResults(
    int logId,
    List<WaterQualityResult> microResults,
  ) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.rawDelete(
        '''DELETE FROM WaterQualityResults
           WHERE log_id = ? AND parameter_id IN (
             SELECT id FROM TestParameters WHERE category = 'Microbiological'
           )''',
        [logId],
      );
      for (var result in microResults) {
        final paramCheck = await txn.query(
          'TestParameters',
          where: 'id = ?',
          whereArgs: [result.parameterId],
          limit: 1,
        );
        if (paramCheck.isEmpty) {
          await txn.insert('TestParameters', {
            'id': result.parameterId,
            'name_ar': 'معيار #${result.parameterId}',
            'category': 'Microbiological',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        final resultData = result.toJson();
        resultData['log_id'] = logId;
        resultData.remove('id');
        await txn.insert('WaterQualityResults', resultData);
      }
    });
  }

  Future<List<WaterQualityLog>> getAllWaterQualityLogs({int? branchId}) async {
    final db = await instance.database;
    String? where;
    List<dynamic>? whereArgs;

    if (branchId != null && branchId > 0) {
      if (branchId == 1) {
        where = '(branch_id = 1 OR branch_id IS NULL)';
      } else {
        where = 'branch_id = ?';
        whereArgs = [branchId];
      }
    }

    final result = await db.query(
      'WaterQualityLogs',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return result.map((json) => WaterQualityLog.fromJson(json)).toList();
  }

  Future<List<WaterQualityLog>> getWaterQualityLogsByCategory(
    String category, {
    int? branchId,
  }) async {
    final db = await instance.database;
    String where = 'report_category = ?';
    List<dynamic> whereArgs = [category];

    if (branchId != null && branchId > 0) {
      if (branchId == 1) {
        where += ' AND (branch_id = 1 OR branch_id IS NULL)';
      } else {
        where += ' AND branch_id = ?';
        whereArgs.add(branchId);
      }
    }

    final result = await db.query(
      'WaterQualityLogs',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return result.map((json) => WaterQualityLog.fromJson(json)).toList();
  }

  Future<List<WaterQualityResult>> getWaterQualityResultsByLogId(
    int logId,
  ) async {
    final db = await instance.database;
    final result = await db.query(
      'WaterQualityResults',
      where: 'log_id = ?',
      whereArgs: [logId],
    );
    return result.map((json) => WaterQualityResult.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> getDashboardStats({
    String timeframe = 'all',
    int? branchId,
  }) async {
    final db = await instance.database;
    final now = DateTime.now();
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (timeframe == 'today') {
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      whereClause = 'WHERE substr(created_at, 1, 10) = ?';
      whereArgs = [dateStr];
    } else if (timeframe == 'week') {
      final weekAgo = now.subtract(const Duration(days: 7));
      final dateStr =
          '${weekAgo.year}-${weekAgo.month.toString().padLeft(2, '0')}-${weekAgo.day.toString().padLeft(2, '0')}';
      whereClause = 'WHERE substr(created_at, 1, 10) >= ?';
      whereArgs = [dateStr];
    } else if (timeframe == 'month') {
      final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      whereClause = 'WHERE substr(created_at, 1, 7) = ?';
      whereArgs = [monthStr];
    }

    if (branchId != null && branchId > 0) {
      if (whereClause.isEmpty) {
        whereClause = 'WHERE branch_id = ?';
      } else {
        whereClause += ' AND branch_id = ?';
      }
      whereArgs.add(branchId);
    }

    final totalRes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM WaterQualityLogs $whereClause',
      whereArgs,
    );
    final int totalSamples = Sqflite.firstIntValue(totalRes) ?? 0;

    String compWhere =
        whereClause.isEmpty
            ? 'WHERE is_compliant = 1'
            : '$whereClause AND is_compliant = 1';
    final compRes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM WaterQualityLogs $compWhere',
      whereArgs,
    );
    final int compliantSamples = Sqflite.firstIntValue(compRes) ?? 0;

    double complianceRate =
        totalSamples > 0 ? (compliantSamples / totalSamples) * 100 : 100.0;

    return {
      'totalSamples': totalSamples,
      'compliantSamples': compliantSamples,
      'complianceRate': complianceRate,
    };
  }

  Future<List<Map<String, dynamic>>> getLatestKeyParameters({
    int? branchId,
  }) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> results = [];
    final paramConfigs = [
      {
        'name': 'TDS',
        'standard': '100 - 200',
        'min': 100.0,
        'max': 200.0,
        'unit': 'ppm',
        'default': 128.0,
      },
      {
        'name': 'pH',
        'standard': '6.5 - 8.5',
        'min': 6.5,
        'max': 8.5,
        'unit': '',
        'default': 7.2,
      },
      {
        'name': 'Turbidity',
        'standard': '< 1.0',
        'min': 0.0,
        'max': 1.0,
        'unit': 'NTU',
        'default': 0.18,
      },
      {
        'name': 'Total Hardness',
        'standard': '< 150',
        'min': 0.0,
        'max': 150.0,
        'unit': 'mg/L',
        'default': 45.0,
      },
    ];

    for (var cfg in paramConfigs) {
      final name = cfg['name'] as String;
      String query = '''
        SELECT p.name_ar, p.unit, r.numeric_result, r.is_compliant, l.created_at, l.batch_number
        FROM WaterQualityResults r
        JOIN TestParameters p ON r.parameter_id = p.id
        JOIN WaterQualityLogs l ON r.log_id = l.id
        WHERE p.name_ar = ? AND r.numeric_result IS NOT NULL
      ''';
      List<dynamic> queryArgs = [name];
      if (branchId != null && branchId > 0) {
        query += ' AND (l.branch_id = ? OR l.branch_id IS NULL)';
        queryArgs.add(branchId);
      }
      query += ' ORDER BY r.id DESC LIMIT 1';

      final res = await db.rawQuery(query, queryArgs);

      if (res.isNotEmpty) {
        final row = Map<String, dynamic>.from(res.first);
        row['standard'] = cfg['standard'];
        row['min'] = cfg['min'];
        row['max'] = cfg['max'];
        results.add(row);
      } else {
        results.add({
          'name_ar': name,
          'unit': cfg['unit'],
          'numeric_result': cfg['default'],
          'is_compliant': 1,
          'standard': cfg['standard'],
          'min': cfg['min'],
          'max': cfg['max'],
          'created_at': null,
          'batch_number': null,
        });
      }
    }
    return results;
  }

  Future<int> getQualityLogsPendingCount(
    String status, {
    int? branchId,
    String? microStatus,
    bool includeWater = true,
    bool includeHygiene = true,
    bool includeRawMaterial = true,
  }) async {
    final db = await instance.database;
    int total = 0;

    String branchFilter = '';
    List<dynamic> branchArgs = [];
    if (branchId != null && branchId > 0) {
      if (branchId == 1) {
        branchFilter = ' AND (branch_id = 1 OR branch_id IS NULL)';
      } else {
        branchFilter = ' AND branch_id = ?';
        branchArgs.add(branchId);
      }
    }

    if (includeWater) {
      final wqSql =
          'SELECT COUNT(*) FROM WaterQualityLogs WHERE approval_status = ?$branchFilter';
      final count =
          Sqflite.firstIntValue(
            await db.rawQuery(wqSql, [status, ...branchArgs]),
          ) ??
          0;
      total += count;
    }

    if (includeHygiene) {
      final hySql =
          'SELECT COUNT(*) FROM HygieneReports WHERE approval_status = ?$branchFilter';
      final count =
          Sqflite.firstIntValue(
            await db.rawQuery(hySql, [status, ...branchArgs]),
          ) ??
          0;
      total += count;
    }

    if (includeRawMaterial) {
      try {
        await _ensureRawMaterialTables(db);
        final rmSql =
            'SELECT COUNT(*) FROM RawMaterialReports WHERE approval_status = ?$branchFilter';
        final count =
            Sqflite.firstIntValue(
              await db.rawQuery(rmSql, [status, ...branchArgs]),
            ) ??
            0;
        total += count;
      } catch (_) {}
    }

    // إضافة عدّ حالات اعتماد نتائج الميكروبيولوجي (المرحلة الثانية) إن وُجدت
    if (microStatus != null && microStatus.isNotEmpty && includeWater) {
      total += await getQualityLogsPendingCount(
        microStatus,
        branchId: branchId,
        includeWater: true,
        includeHygiene: false,
        includeRawMaterial: false,
      );
    }
    return total;
  }

  Future<List<Map<String, dynamic>>> getPendingLogsForRole(
    String status, {
    int? branchId,
    String? microStatus,
    bool includeWater = true,
    bool includeHygiene = true,
    bool includeRawMaterial = true,
  }) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> items = [];

    String branchFilter = '';
    List<dynamic> branchArgs = [];
    if (branchId != null && branchId > 0) {
      if (branchId == 1) {
        branchFilter = ' AND (branch_id = 1 OR branch_id IS NULL)';
      } else {
        branchFilter = ' AND branch_id = ?';
        branchArgs.add(branchId);
      }
    }

    if (includeWater) {
      String wqSql = '''
        SELECT id, report_category, batch_number, created_at, approval_status, product_name, bottle_size, branch_id
        FROM WaterQualityLogs
        WHERE approval_status = ?$branchFilter
        ORDER BY id DESC LIMIT 10
      ''';
      final logs = await db.rawQuery(wqSql, [status, ...branchArgs]);

      for (var l in logs) {
        final cat = l['report_category'] as String? ?? 'Raw Water';
        String title = 'فحص مياه خام';
        if (cat == 'Final Product') {
          title = 'فحص منتج نهائي (${l['product_name'] ?? ""})';
        } else if (cat == 'Raw Material') {
          title = 'فحص مواد أولية';
        }
        items.add({
          'id': l['id'],
          'type': 'water_log',
          'category': cat,
          'title': '$title #${l['id']}',
          'created_at': l['created_at'],
          'approval_status': l['approval_status'],
          'branch_id': l['branch_id'] ?? 1,
        });
      }
    }

    if (includeHygiene) {
      String hySql = '''
        SELECT id, created_at, approval_status, branch_id
        FROM HygieneReports
        WHERE approval_status = ?$branchFilter
        ORDER BY id DESC LIMIT 10
      ''';
      final hygiene = await db.rawQuery(hySql, [status, ...branchArgs]);

      for (var h in hygiene) {
        items.add({
          'id': h['id'],
          'type': 'hygiene',
          'category': 'Hygiene',
          'title': 'تقرير فحص النظافة العامة #${h['id']}',
          'created_at': h['created_at'],
          'approval_status': h['approval_status'],
          'branch_id': h['branch_id'] ?? 1,
        });
      }
    }

    if (includeRawMaterial) {
      try {
        await _ensureRawMaterialTables(db);
        String rmSql = '''
          SELECT id, created_at, approval_status, material_name, branch_id
          FROM RawMaterialReports
          WHERE approval_status = ?$branchFilter
          ORDER BY id DESC LIMIT 10
        ''';
        final rawReports = await db.rawQuery(rmSql, [status, ...branchArgs]);
        for (var r in rawReports) {
          items.add({
            'id': r['id'],
            'type': 'raw_material',
            'category': 'Raw Material',
            'title': 'فحص مادة خام (${r['material_name'] ?? ""}) #${r['id']}',
            'created_at': r['created_at'],
            'approval_status': r['approval_status'],
            'branch_id': r['branch_id'] ?? 1,
          });
        }
      } catch (_) {}
    }

    // إدراج عناصر اعتماد نتائج الميكروبيولوجي (المرحلة الثانية) إن وُجدت
    if (microStatus != null && microStatus.isNotEmpty && includeWater) {
      final microItems = await getPendingLogsForRole(
        microStatus,
        branchId: branchId,
        includeWater: true,
        includeHygiene: false,
        includeRawMaterial: false,
      );
      items.addAll(microItems);
    }

    return items;
  }

  /// جلب جميع التقارير في دورة الإجراء التصحيحي من الجداول الثابتة
  /// (مياه خام، منتج نهائي، مواد أولية، نظافة) — لبطاقة مدير المصنع
  Future<List<Map<String, dynamic>>> getCorrectiveActionLegacyReports({
    int? branchId,
    bool includeWater = true,
    bool includeHygiene = true,
    bool includeRawMaterial = true,
  }) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> items = [];

    String branchWq = '';
    String branchHy = '';
    String branchRm = '';
    List<dynamic> argsWq = [];
    List<dynamic> argsHy = [];
    List<dynamic> argsRm = [];

    if (branchId != null && branchId > 0) {
      if (branchId == 1) {
        branchWq = ' AND (branch_id = 1 OR branch_id IS NULL)';
        branchHy = ' AND (branch_id = 1 OR branch_id IS NULL)';
        branchRm = ' AND (branch_id = 1 OR branch_id IS NULL)';
      } else {
        branchWq = ' AND branch_id = ?';
        branchHy = ' AND branch_id = ?';
        branchRm = ' AND branch_id = ?';
        argsWq.add(branchId);
        argsHy.add(branchId);
        argsRm.add(branchId);
      }
    }

    const statusFilter =
        "approval_status IN ('Rejected', 'Corrective_In_Progress', 'Pending_QM_Decision', 'Pending_GM_Decision')";

    // مياه خام + منتج نهائي
    if (includeWater) {
      final wqSql = '''
        SELECT id, report_category, batch_number, created_at, approval_status, product_name,
               rejection_reason, rejected_by, rejection_category, severity_level,
               affected_products, immediate_action, corrective_action, corrective_owner,
               corrective_due_date, gm_decision, gm_decision_by, gm_decision_notes, branch_id
        FROM WaterQualityLogs
        WHERE $statusFilter$branchWq
        ORDER BY id DESC LIMIT 20
      ''';
      final logs = await db.rawQuery(wqSql, argsWq);
      for (var l in logs) {
        final cat = l['report_category'] as String? ?? 'Raw Water';
        String title = 'فحص مياه خام';
        if (cat == 'Final Product') {
          title = 'فحص منتج نهائي (${l['product_name'] ?? ""})';
        }
        items.add({
          'id': l['id'],
          'type': 'water_log',
          'category': cat,
          'title': '$title #${l['id']}',
          'created_at': l['created_at'],
          'approval_status': l['approval_status'],
          'rejection_reason': l['rejection_reason'],
          'rejected_by': l['rejected_by'],
          'rejection_category': l['rejection_category'],
          'severity_level': l['severity_level'],
          'affected_products': l['affected_products'],
          'immediate_action': l['immediate_action'],
          'corrective_action': l['corrective_action'],
          'corrective_owner': l['corrective_owner'],
          'corrective_due_date': l['corrective_due_date'],
          'gm_decision': l['gm_decision'],
          'gm_decision_by': l['gm_decision_by'],
          'gm_decision_notes': l['gm_decision_notes'],
          'branch_id': l['branch_id'] ?? 1,
        });
      }
    }

    // النظافة
    if (includeHygiene) {
      final hySql = '''
        SELECT id, created_at, approval_status, rejection_reason, rejected_by,
               rejection_category, severity_level, affected_products, immediate_action,
               corrective_action, corrective_owner, corrective_due_date,
               gm_decision, gm_decision_by, gm_decision_notes, branch_id
        FROM HygieneReports
        WHERE $statusFilter$branchHy
        ORDER BY id DESC LIMIT 20
      ''';
      final hygiene = await db.rawQuery(hySql, argsHy);
      for (var h in hygiene) {
        items.add({
          'id': h['id'],
          'type': 'hygiene',
          'category': 'Hygiene',
          'title': 'تقرير فحص النظافة العامة #${h['id']}',
          'created_at': h['created_at'],
          'approval_status': h['approval_status'],
          'rejection_reason': h['rejection_reason'],
          'rejected_by': h['rejected_by'],
          'rejection_category': h['rejection_category'],
          'severity_level': h['severity_level'],
          'affected_products': h['affected_products'],
          'immediate_action': h['immediate_action'],
          'corrective_action': h['corrective_action'],
          'corrective_owner': h['corrective_owner'],
          'corrective_due_date': h['corrective_due_date'],
          'gm_decision': h['gm_decision'],
          'gm_decision_by': h['gm_decision_by'],
          'gm_decision_notes': h['gm_decision_notes'],
          'branch_id': h['branch_id'] ?? 1,
        });
      }
    }

    // المواد الأولية
    if (includeRawMaterial) {
      try {
        await _ensureRawMaterialTables(db);
        final rmSql = '''
          SELECT id, created_at, approval_status, material_name, rejection_reason, rejected_by,
                 rejection_category, severity_level, affected_products, immediate_action,
                 corrective_action, corrective_owner, corrective_due_date,
                 gm_decision, gm_decision_by, gm_decision_notes, branch_id
          FROM RawMaterialReports
          WHERE $statusFilter$branchRm
          ORDER BY id DESC LIMIT 20
        ''';
        final raws = await db.rawQuery(rmSql, argsRm);
        for (var r in raws) {
          items.add({
            'id': r['id'],
            'type': 'raw_material',
            'category': 'Raw Material',
            'title': 'فحص مادة خام (${r['material_name'] ?? ""}) #${r['id']}',
            'created_at': r['created_at'],
            'approval_status': r['approval_status'],
            'rejection_reason': r['rejection_reason'],
            'rejected_by': r['rejected_by'],
            'rejection_category': r['rejection_category'],
            'severity_level': r['severity_level'],
            'affected_products': r['affected_products'],
            'immediate_action': r['immediate_action'],
            'corrective_action': r['corrective_action'],
            'corrective_owner': r['corrective_owner'],
            'corrective_due_date': r['corrective_due_date'],
            'gm_decision': r['gm_decision'],
            'gm_decision_by': r['gm_decision_by'],
            'gm_decision_notes': r['gm_decision_notes'],
            'branch_id': r['branch_id'] ?? 1,
          });
        }
      } catch (e) {
        debugPrint('Error loading raw material corrective records: $e');
      }
    }

    return items;
  }

  /// جلب كل السجلات الثابتة بحالة محددة (لمدونة الإجراء التصحيحي)
  Future<int> getLegacyReportsCountByStatus(
    String status, {
    int? branchId,
  }) async {
    final db = await instance.database;
    String branch = '';
    List<dynamic> args = [status];

    if (branchId != null && branchId > 0) {
      if (branchId == 1) {
        branch = ' AND (branch_id = 1 OR branch_id IS NULL)';
      } else {
        branch = ' AND branch_id = ?';
        args.add(branchId);
      }
    }

    int total = 0;
    total +=
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM WaterQualityLogs WHERE approval_status = ?$branch',
            args,
          ),
        ) ??
        0;
    total +=
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM HygieneReports WHERE approval_status = ?$branch',
            args,
          ),
        ) ??
        0;
    try {
      await _ensureRawMaterialTables(db);
      total +=
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM RawMaterialReports WHERE approval_status = ?$branch',
              args,
            ),
          ) ??
          0;
    } catch (_) {}

    return total;
  }

  Future<Map<String, dynamic>> getWeeklyDailyStats({int? branchId}) async {
    final db = await instance.database;
    final now = DateTime.now();

    final List<Map<String, dynamic>> daysData = [];
    int thisWeekTotal = 0;
    int prevWeekTotal = 0;

    final arabicDayNames = {
      DateTime.monday: 'إثن',
      DateTime.tuesday: 'ثلا',
      DateTime.wednesday: 'أرب',
      DateTime.thursday: 'خمي',
      DateTime.friday: 'جمع',
      DateTime.saturday: 'سبت',
      DateTime.sunday: 'أحد',
    };

    String branchFilter = '';
    List<dynamic> branchArg = [];
    if (branchId != null && branchId > 0) {
      branchFilter = ' AND (branch_id = ? OR branch_id IS NULL)';
      branchArg = [branchId];
    }

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final wqRes = await db.rawQuery(
        'SELECT COUNT(*) as c FROM WaterQualityLogs WHERE substr(created_at, 1, 10) = ?$branchFilter',
        [dateStr, ...branchArg],
      );
      final wqCount = Sqflite.firstIntValue(wqRes) ?? 0;

      final drRes = await db.rawQuery(
        'SELECT COUNT(*) as c FROM dr_records WHERE substr(created_at, 1, 10) = ?$branchFilter',
        [dateStr, ...branchArg],
      );
      final drCount = Sqflite.firstIntValue(drRes) ?? 0;

      final total = wqCount + drCount;
      thisWeekTotal += total;

      daysData.add({
        'dateStr': dateStr,
        'dayName': arabicDayNames[date.weekday] ?? '',
        'count': total,
        'isToday': i == 0,
      });
    }

    for (int i = 13; i >= 7; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final wqRes = await db.rawQuery(
        'SELECT COUNT(*) as c FROM WaterQualityLogs WHERE substr(created_at, 1, 10) = ?$branchFilter',
        [dateStr, ...branchArg],
      );
      final wqCount = Sqflite.firstIntValue(wqRes) ?? 0;

      final drRes = await db.rawQuery(
        'SELECT COUNT(*) as c FROM dr_records WHERE substr(created_at, 1, 10) = ?$branchFilter',
        [dateStr, ...branchArg],
      );
      final drCount = Sqflite.firstIntValue(drRes) ?? 0;

      prevWeekTotal += (wqCount + drCount);
    }

    int maxCount = 1;
    for (var d in daysData) {
      final c = d['count'] as int;
      if (c > maxCount) {
        maxCount = c;
      }
    }

    double trendPercentage = 0.0;
    if (prevWeekTotal > 0) {
      trendPercentage = ((thisWeekTotal - prevWeekTotal) / prevWeekTotal) * 100;
    } else if (thisWeekTotal > 0) {
      trendPercentage = 100.0;
    }

    return {
      'days': daysData,
      'maxCount': maxCount,
      'thisWeekTotal': thisWeekTotal,
      'prevWeekTotal': prevWeekTotal,
      'trendPercentage': trendPercentage,
    };
  }

  Future<Map<String, dynamic>> getShiftDistribution({int? branchId}) async {
    final db = await instance.database;

    // جلب ورديات المصنع من جدول Shifts
    String shiftQuery =
        'SELECT id, name, start_time, end_time FROM Shifts WHERE is_active = 1';
    List<dynamic> shiftArgs = [];
    if (branchId != null && branchId > 0) {
      shiftQuery += ' AND branch_id = ?';
      shiftArgs.add(branchId);
    }
    shiftQuery += ' ORDER BY start_time ASC';
    final branchShifts = await db.rawQuery(shiftQuery, shiftArgs);

    final List<Map<String, dynamic>> items = [];
    int shift1 = 0;
    int shift2 = 0;
    int shift3 = 0;

    int idx = 1;
    for (var s in branchShifts) {
      final sName = s['name'] as String;
      final sId = s['id'] as int;

      final branchCondition =
          (branchId != null && branchId > 0)
              ? ' AND (branch_id = $branchId OR branch_id IS NULL)'
              : '';
      int count = 0;
      try {
        final countRes = await db.rawQuery(
          'SELECT COUNT(*) as c FROM dr_records WHERE shift_name = ?$branchCondition',
          [sName],
        );
        count = Sqflite.firstIntValue(countRes) ?? 0;
      } catch (_) {}

      final wqRes = await db.rawQuery(
        'SELECT COUNT(*) as c FROM WaterQualityLogs WHERE (shift_name = ? OR shift_id = ?)$branchCondition',
        [sName, sId],
      );
      final totalForShift = count + (Sqflite.firstIntValue(wqRes) ?? 0);

      items.add({
        'id': sId,
        'name': sName,
        'start_time': s['start_time'],
        'end_time': s['end_time'],
        'count': totalForShift,
      });

      if (idx == 1) shift1 = totalForShift;
      if (idx == 2) shift2 = totalForShift;
      if (idx == 3) shift3 = totalForShift;
      idx++;
    }

    // fallback إذا لم يكن هناك ورديات مدخلة
    if (items.isEmpty) {
      final s1 =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM WaterQualityLogs WHERE shift_id = 1',
            ),
          ) ??
          0;
      final s2 =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM WaterQualityLogs WHERE shift_id = 2',
            ),
          ) ??
          0;
      final s3 =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM WaterQualityLogs WHERE shift_id = 3',
            ),
          ) ??
          0;
      shift1 = s1;
      shift2 = s2;
      shift3 = s3;
    }

    return {
      'shift1': shift1,
      'shift2': shift2,
      'shift3': shift3,
      'shiftsList': items,
    };
  }

  Future<List<Map<String, dynamic>>> getNonCompliantLogs({
    int? branchId,
  }) async {
    final db = await instance.database;
    String where = 'WHERE is_compliant = 0';
    List<dynamic> args = [];
    if (branchId != null && branchId > 0) {
      where += ' AND (branch_id = ? OR branch_id IS NULL)';
      args.add(branchId);
    }
    return await db.rawQuery('''
      SELECT id, report_category, batch_number, general_notes, created_at, product_name, water_type, branch_name, shift_name
      FROM WaterQualityLogs
      $where
      ORDER BY id DESC
      LIMIT 5
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getRecentActivities({
    int? branchId,
    bool includeWater = true,
    bool includeHygiene = true,
    bool includeRawMaterial = true,
    bool includeDynamic = true,
    List<int>? allowedDynamicReportIds,
    List<int>? allowedCategoryIds,
  }) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> activities = [];

    String wqWhere = '';
    String drWhere = '';
    String hyWhere = '';
    String rmWhere = '';
    List<dynamic> branchArgs = [];

    if (branchId != null && branchId > 0) {
      if (branchId == 1) {
        wqWhere = 'WHERE (branch_id = 1 OR branch_id IS NULL)';
        drWhere = 'WHERE (r.branch_id = 1 OR r.branch_id IS NULL)';
        hyWhere = 'WHERE (branch_id = 1 OR branch_id IS NULL)';
        rmWhere = 'WHERE (branch_id = 1 OR branch_id IS NULL)';
      } else {
        wqWhere = 'WHERE branch_id = ?';
        drWhere = 'WHERE r.branch_id = ?';
        hyWhere = 'WHERE branch_id = ?';
        rmWhere = 'WHERE branch_id = ?';
        branchArgs.add(branchId);
      }
    }

    if (includeWater) {
      final logs = await db.rawQuery('''
        SELECT id, report_category, product_name, created_at, approval_status, is_compliant, branch_id, branch_name, shift_name
        FROM WaterQualityLogs
        $wqWhere
        ORDER BY id DESC
        LIMIT 5
      ''', branchArgs);

      for (var l in logs) {
        final cat = l['report_category'] as String? ?? 'Raw Water';
        String title = 'فحص مياه خام';
        if (cat == 'Final Product') {
          title = 'فحص منتج نهائي (${l['product_name'] ?? ""})';
        } else if (cat == 'Raw Material') {
          title = 'فحص مواد أولية';
        }
        activities.add({
          'id': l['id'],
          'type': 'water_log',
          'category': cat,
          'title': title,
          'created_at': l['created_at'],
          'approval_status': l['approval_status'],
          'is_compliant': l['is_compliant'] == 1,
          'branch_id': l['branch_id'] ?? 1,
          'branch_name': l['branch_name'] ?? 'مصنع أرتل',
          'shift_name': l['shift_name'] ?? '',
        });
      }
    }

    if (includeHygiene) {
      try {
        final hyLogs = await db.rawQuery('''
          SELECT id, created_at, approval_status, branch_id, branch_name, shift_name
          FROM HygieneReports
          $hyWhere
          ORDER BY id DESC
          LIMIT 5
        ''', branchArgs);
        for (var h in hyLogs) {
          final bId = h['branch_id'] as int? ?? 1;
          activities.add({
            'id': h['id'],
            'type': 'hygiene',
            'category': 'Hygiene',
            'title': 'فحص النظافة العامة #${h['id']}',
            'created_at': h['created_at'],
            'approval_status': h['approval_status'],
            'is_compliant': true,
            'branch_id': bId,
            'branch_name':
                h['branch_name'] ?? (bId == 2 ? 'مصنع سنحان' : 'مصنع أرتل'),
            'shift_name': h['shift_name'] ?? '',
          });
        }
      } catch (e) {
        debugPrint('Warning: getRecentActivities hygiene query skipped: $e');
      }
    }

    if (includeRawMaterial) {
      try {
        await _ensureRawMaterialTables(db);
        final rmLogs = await db.rawQuery('''
          SELECT id, created_at, approval_status, material_name, branch_id, branch_name, shift_name
          FROM RawMaterialReports
          $rmWhere
          ORDER BY id DESC
          LIMIT 5
        ''', branchArgs);
        for (var r in rmLogs) {
          final bId = r['branch_id'] as int? ?? 1;
          activities.add({
            'id': r['id'],
            'type': 'raw_material',
            'category': 'Raw Material',
            'title': 'فحص مادة خام (${r['material_name'] ?? ""}) #${r['id']}',
            'created_at': r['created_at'],
            'approval_status': r['approval_status'],
            'is_compliant': true,
            'branch_id': bId,
            'branch_name':
                r['branch_name'] ?? (bId == 2 ? 'مصنع سنحان' : 'مصنع أرتل'),
            'shift_name': r['shift_name'] ?? '',
          });
        }
      } catch (e) {
        debugPrint(
          'Warning: getRecentActivities raw material query skipped: $e',
        );
      }
    }

    if (includeDynamic) {
      bool skipDynamic = false;
      String dynFilter = '';
      if (allowedDynamicReportIds != null) {
        if (allowedDynamicReportIds.isEmpty) {
          skipDynamic = true;
        } else {
          dynFilter +=
              ' AND r.report_id IN (${allowedDynamicReportIds.join(',')})';
        }
      }
      if (allowedCategoryIds != null) {
        if (allowedCategoryIds.isEmpty) {
          skipDynamic = true;
        } else {
          dynFilter +=
              ' AND rep.category_id IN (${allowedCategoryIds.join(',')})';
        }
      }

      if (!skipDynamic) {
        try {
          String fullDrWhere = drWhere.isEmpty ? 'WHERE 1=1' : drWhere;
          final dynRecords = await db.rawQuery('''
            SELECT r.id, r.report_id, rep.category_id, r.created_at, r.approval_status, rep.name as report_name, r.branch_id, 
                   COALESCE(r.shift_name, '') as shift_name
            FROM dr_records r
            JOIN dr_reports rep ON r.report_id = rep.id
            $fullDrWhere$dynFilter
            ORDER BY r.id DESC
            LIMIT 5
          ''', branchArgs);

          for (var d in dynRecords) {
            final bId = d['branch_id'] as int? ?? 1;
            activities.add({
              'id': d['id'],
              'report_id': d['report_id'],
              'category_id': d['category_id'],
              'type': 'dynamic',
              'category': 'Dynamic Report',
              'title': '${d['report_name']}',
              'created_at': d['created_at'],
              'approval_status': d['approval_status'],
              'is_compliant': true,
              'branch_id': bId,
              'branch_name': bId == 2 ? 'مصنع سنحان' : 'مصنع أرتل',
              'shift_name': d['shift_name'] ?? '',
            });
          }
        } catch (e) {
          debugPrint('Warning: getRecentActivities dynamic query skipped: $e');
        }
      }
    }

    activities.sort((a, b) {
      final aDate = a['created_at']?.toString() ?? '';
      final bDate = b['created_at']?.toString() ?? '';
      return bDate.compareTo(aDate);
    });

    return activities.take(5).toList();
  }

  /// مقارنة أداء المصنع أرتل ومصنع سنحان للمدير العام والتنفيذي
  Future<List<Map<String, dynamic>>> getFactoryComparisonStats() async {
    final db = await instance.database;
    final branches = await db.query(
      'Branches',
      where: 'is_active = 1',
      orderBy: 'id ASC',
    );
    final List<Map<String, dynamic>> comparison = [];

    for (var b in branches) {
      final bId = b['id'] as int;
      final bName = b['name'] as String;

      // عينات الفحص المائي
      final wqTotalRes = await db.rawQuery(
        'SELECT COUNT(*) as c FROM WaterQualityLogs WHERE branch_id = ? OR branch_id IS NULL',
        [bId],
      );
      final wqTotal = Sqflite.firstIntValue(wqTotalRes) ?? 0;

      final wqCompRes = await db.rawQuery(
        'SELECT COUNT(*) as c FROM WaterQualityLogs WHERE (branch_id = ? OR branch_id IS NULL) AND is_compliant = 1',
        [bId],
      );
      final wqComp = Sqflite.firstIntValue(wqCompRes) ?? 0;

      // تقارير الفحص الديناميكي
      final drTotalRes = await db.rawQuery(
        'SELECT COUNT(*) as c FROM dr_records WHERE branch_id = ? OR branch_id IS NULL',
        [bId],
      );
      final drTotal = Sqflite.firstIntValue(drTotalRes) ?? 0;

      final drAppRes = await db.rawQuery(
        "SELECT COUNT(*) as c FROM dr_records WHERE (branch_id = ? OR branch_id IS NULL) AND approval_status = 'Approved'",
        [bId],
      );
      final drApp = Sqflite.firstIntValue(drAppRes) ?? 0;

      final totalSamples = wqTotal + drTotal;
      final totalCompliant = wqComp + drApp;
      final rate =
          totalSamples > 0 ? (totalCompliant / totalSamples) * 100 : 100.0;

      comparison.add({
        'branch_id': bId,
        'branch_name': bName,
        'code': b['code'] ?? 'plant_$bId',
        'totalSamples': totalSamples,
        'complianceRate': rate,
        'approvedRecords': drApp,
      });
    }

    return comparison;
  }

  // =====================================
  // الإشعارات
  // =====================================

  Future<int> insertNotification(AppNotification notification) async {
    final db = await instance.database;
    return await db.insert(
      'Notifications',
      notification.toJson()..remove('id'),
    );
  }

  Future<List<AppNotification>> getNotifications({
    String? role,
    int? branchId,
  }) async {
    final db = await instance.database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (role != null && role != 'All') {
      conditions.add('(target_role = ? OR target_role = ?)');
      args.addAll([role, 'All']);
    }

    if (branchId != null && branchId > 0) {
      conditions.add('(branch_id = ? OR branch_id IS NULL)');
      args.add(branchId);
    }

    final whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : null;

    final results = await db.query(
      'Notifications',
      where: whereClause,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'created_at DESC',
    );
    return results.map((json) => AppNotification.fromJson(json)).toList();
  }

  Future<int> getUnreadNotificationsCount({String? role, int? branchId}) async {
    final db = await instance.database;
    String sql =
        'SELECT COUNT(*) as count FROM Notifications WHERE is_read = 0';
    final args = <dynamic>[];

    if (role != null && role != 'All') {
      sql += ' AND (target_role = ? OR target_role = ?)';
      args.addAll([role, 'All']);
    }

    if (branchId != null && branchId > 0) {
      sql += ' AND (branch_id = ? OR branch_id IS NULL)';
      args.add(branchId);
    }

    final result = await db.rawQuery(sql, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markNotificationAsRead(int id) async {
    final db = await instance.database;
    await db.update(
      'Notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllNotificationsAsRead({String? role, int? branchId}) async {
    final db = await instance.database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (role != null && role != 'All') {
      conditions.add('(target_role = ? OR target_role = ?)');
      args.addAll([role, 'All']);
    }

    if (branchId != null && branchId > 0) {
      conditions.add('(branch_id = ? OR branch_id IS NULL)');
      args.add(branchId);
    }

    final whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : null;

    await db.update(
      'Notifications',
      {'is_read': 1},
      where: whereClause,
      whereArgs: args.isNotEmpty ? args : null,
    );
  }

  Future<void> deleteNotification(int id) async {
    final db = await instance.database;
    await db.delete('Notifications', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateWaterQualityLogApproval({
    required int logId,
    required String approvalStatus,
    String? qmApprovedBy,
    DateTime? qmApprovedAt,
    String? gmApprovedBy,
    DateTime? gmApprovedAt,
    String? rejectionReason,
    String? rejectedBy,
    String? rejectionCategory,
    String? severityLevel,
    String? rejectionNotes,
    String? affectedProducts,
    String? immediateAction,
    String? correctiveAction,
    String? correctiveOwner,
    DateTime? correctiveDueDate,
    String? gmDecision,
    String? gmDecisionBy,
    DateTime? gmDecisionAt,
    String? gmDecisionNotes,
    bool? microResultsPending,
    String? microEnteredBy,
    DateTime? microEnteredAt,
    String? stage1QmApprovedBy,
    DateTime? stage1QmApprovedAt,
    String? stage1GmApprovedBy,
    DateTime? stage1GmApprovedAt,
    String? microQmApprovedBy,
    DateTime? microQmApprovedAt,
    String? microGmApprovedBy,
    DateTime? microGmApprovedAt,
    String? microRejectionReason,
    String? microRejectedBy,
    DateTime? microRejectedAt,
    String? microRejectionAction,
    int? rejectionCount,
  }) async {
    final db = await instance.database;
    final Map<String, dynamic> data = {'approval_status': approvalStatus};
    if (rejectionCount != null) data['rejection_count'] = rejectionCount;
    if (qmApprovedBy != null) data['qm_approved_by'] = qmApprovedBy;
    if (qmApprovedAt != null) {
      data['qm_approved_at'] = qmApprovedAt.toIso8601String();
    }
    if (gmApprovedBy != null) data['gm_approved_by'] = gmApprovedBy;
    if (gmApprovedAt != null) {
      data['gm_approved_at'] = gmApprovedAt.toIso8601String();
    }
    if (rejectionReason != null) data['rejection_reason'] = rejectionReason;
    if (rejectedBy != null) data['rejected_by'] = rejectedBy;
    if (rejectionCategory != null) {
      data['rejection_category'] = rejectionCategory;
    }
    if (severityLevel != null) data['severity_level'] = severityLevel;
    if (rejectionNotes != null) data['rejection_notes'] = rejectionNotes;
    if (affectedProducts != null) data['affected_products'] = affectedProducts;
    if (immediateAction != null) data['immediate_action'] = immediateAction;
    if (correctiveAction != null) data['corrective_action'] = correctiveAction;
    if (correctiveOwner != null) data['corrective_owner'] = correctiveOwner;
    if (correctiveDueDate != null) {
      data['corrective_due_date'] = correctiveDueDate.toIso8601String();
    }
    if (gmDecision != null) data['gm_decision'] = gmDecision;
    if (gmDecisionBy != null) data['gm_decision_by'] = gmDecisionBy;
    if (gmDecisionAt != null) {
      data['gm_decision_at'] = gmDecisionAt.toIso8601String();
    }
    if (gmDecisionNotes != null) data['gm_decision_notes'] = gmDecisionNotes;
    if (microResultsPending != null) {
      data['micro_results_pending'] = microResultsPending ? 1 : 0;
    }
    if (microEnteredBy != null) data['micro_entered_by'] = microEnteredBy;
    if (microEnteredAt != null) {
      data['micro_entered_at'] = microEnteredAt.toIso8601String();
    }
    if (stage1QmApprovedBy != null) {
      data['stage1_qm_approved_by'] = stage1QmApprovedBy;
    }
    if (stage1QmApprovedAt != null) {
      data['stage1_qm_approved_at'] = stage1QmApprovedAt.toIso8601String();
    }
    if (stage1GmApprovedBy != null) {
      data['stage1_gm_approved_by'] = stage1GmApprovedBy;
    }
    if (stage1GmApprovedAt != null) {
      data['stage1_gm_approved_at'] = stage1GmApprovedAt.toIso8601String();
    }
    if (microQmApprovedBy != null) {
      data['micro_qm_approved_by'] = microQmApprovedBy;
    }
    if (microQmApprovedAt != null) {
      data['micro_qm_approved_at'] = microQmApprovedAt.toIso8601String();
    }
    if (microGmApprovedBy != null) {
      data['micro_gm_approved_by'] = microGmApprovedBy;
    }
    if (microGmApprovedAt != null) {
      data['micro_gm_approved_at'] = microGmApprovedAt.toIso8601String();
    }
    if (microRejectionReason != null) {
      data['micro_rejection_reason'] = microRejectionReason;
    }
    if (microRejectedBy != null) data['micro_rejected_by'] = microRejectedBy;
    if (microRejectedAt != null) {
      data['micro_rejected_at'] = microRejectedAt.toIso8601String();
    }
    if (microRejectionAction != null) {
      data['micro_rejection_action'] = microRejectionAction;
    }

    await _ensureWaterQualityColumns(db);
    final info = await db.rawQuery("PRAGMA table_info('WaterQualityLogs')");
    final validCols =
        info.map((r) => r['name'].toString().toLowerCase()).toSet();
    data.removeWhere((key, _) => !validCols.contains(key.toLowerCase()));

    await db.update(
      'WaterQualityLogs',
      data,
      where: 'id = ?',
      whereArgs: [logId],
    );
  }

  Future<WaterQualityLog?> getWaterQualityLogById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'WaterQualityLogs',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return WaterQualityLog.fromJson(result.first);
    }
    return null;
  }

  // =====================================
  // تقارير النظافة
  // =====================================

  Future<int> saveHygieneReport({
    int? reportId,
    int? branchId,
    String? branchName,
    int? shiftId,
    String? shiftName,
    String? supervisorName,
    required List<Employee> employees,
    required List<ChecklistItem> criteria,
    required Map<String, bool?> complianceMatrix,
    required Map<int, String> correctiveActions,
    String approvalStatus = 'Pending_QM',
    String? rejectionReason,
  }) async {
    final db = await instance.database;
    await _ensureHygieneReportTables(db);
    final createdAt = DateTime.now().toIso8601String();

    final newReportId = await db.transaction<int>((transaction) async {
      if (reportId != null && reportId > 0) {
        final logs = await transaction.query(
          'HygieneLogs',
          where: 'report_id = ?',
          whereArgs: [reportId],
        );
        for (final log in logs) {
          final logId = log['id'] as int;
          await transaction.delete(
            'HygieneLogDetails',
            where: 'hygiene_log_id = ?',
            whereArgs: [logId],
          );
        }
        await transaction.delete(
          'HygieneLogs',
          where: 'report_id = ?',
          whereArgs: [reportId],
        );
        await transaction.delete(
          'HygieneReports',
          where: 'id = ?',
          whereArgs: [reportId],
        );
      }

      final actualBranchId = branchId ?? 1;
      final actualBranchName =
          branchName ?? (actualBranchId == 2 ? 'مصنع سنحان' : 'مصنع أرتل');
      final actualShiftId = shiftId ?? 1;
      final actualShiftName =
          shiftName ??
          (actualShiftId == 2
              ? 'وردية ثانية (مسائية)'
              : (actualShiftId == 3
                  ? 'وردية ثالثة (ليلية)'
                  : 'وردية أولى (صباحية)'));
      final actualSupervisorName =
          (supervisorName != null && supervisorName.trim().isNotEmpty)
              ? supervisorName.trim()
              : 'مفتش الجودة';

      final reportRow = <String, dynamic>{
        if (reportId != null && reportId > 0) 'id': reportId,
        'created_at': createdAt,
        'supervisor_name': actualSupervisorName,
        'employee_count': employees.length,
        'approval_status': approvalStatus,
        'rejection_reason': rejectionReason,
        'branch_id': actualBranchId,
        'branch_name': actualBranchName,
        'shift_id': actualShiftId,
        'shift_name': actualShiftName,
      };

      final insertedId = await transaction.insert(
        'HygieneReports',
        reportRow,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final newReportId =
          (reportId != null && reportId > 0) ? reportId : insertedId;
      final checklistAndItems = await _ensureHygieneChecklist(
        transaction,
        criteria,
      );
      final checklistId = checklistAndItems.checklistId;

      for (final employee in employees) {
        // إذا كان الموظف مسجّلاً في سجل العمالة اليومية (يحمل معرّفاً ثابتاً)
        // نربط السجل به مباشرة دون إدراج صف جديد، لضمان ثبات الهوية عبر
        // التقارير وتمكين التقييم الشهري والتجميع بالـ ID.
        int employeeId;
        if (employee.databaseWorkerId != null) {
          await _ensureDailyWorkersTable(transaction);
          final existing = await transaction.query(
            'DailyWorkers',
            where: 'id = ?',
            whereArgs: [employee.databaseWorkerId],
            limit: 1,
          );
          if (existing.isNotEmpty) {
            final workerId = existing.first['id'] as int;
            // الحفاظ على سلامة قيد المفتاح الأجنبي: HygieneLogs.employee_id
            // يشير لـ Employees.id، لذا نضمن وجود صف مرآة مطابق في Employees.
            final empRow = await transaction.query(
              'Employees',
              where: 'id = ?',
              whereArgs: [workerId],
              limit: 1,
            );
            if (empRow.isEmpty) {
              await transaction.insert('Employees', {
                'id': workerId,
                'branch_id': actualBranchId,
                'full_name': employee.fullName,
                'job_title': employee.jobTitle,
                'is_active': 1,
              });
            }
            employeeId = workerId;
          } else {
            employeeId = await transaction.insert('Employees', {
              'branch_id': actualBranchId,
              'full_name': employee.fullName,
              'job_title': employee.jobTitle,
              'is_active': 1,
            });
          }
        } else {
          employeeId = await transaction.insert('Employees', {
            'branch_id': actualBranchId,
            'full_name': employee.fullName,
            'job_title': employee.jobTitle,
            'is_active': 1,
          });
        }
        final hygieneLogId = await transaction.insert('HygieneLogs', {
          'report_id': newReportId,
          'branch_id': actualBranchId,
          'shift_id': actualShiftId,
          'shift_name': actualShiftName,
          'checklist_id': checklistId,
          'employee_id': employeeId,
          'created_by': 1,
          'created_at': createdAt,
          'approval_status': 'Completed',
        });

        for (final criterion in criteria) {
          final isCompliant =
              complianceMatrix['${employee.id}_${criterion.id}'];
          final action =
              isCompliant == false ? correctiveActions[employee.id] : null;
          final itemId =
              checklistAndItems.itemIds[criterion.id] ?? criterion.id ?? 1;
          await transaction.insert('HygieneLogDetails', {
            'hygiene_log_id': hygieneLogId,
            'checklist_item_id': itemId,
            'is_compliant': isCompliant == true ? 1 : 0,
            'notes': action,
          });
        }
      }
      return newReportId;
    });

    return newReportId;
  }

  Future<void> _ensureHygieneReportTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS HygieneReports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        supervisor_name TEXT,
        employee_count INTEGER NOT NULL DEFAULT 0,
        approval_status TEXT DEFAULT 'Pending_QM',
        rejection_reason TEXT,
        rejected_by TEXT,
        qm_approved_by TEXT,
        qm_approved_at TEXT,
        gm_approved_by TEXT,
        gm_approved_at TEXT,
        branch_id INTEGER DEFAULT 1,
        branch_name TEXT,
        shift_id INTEGER DEFAULT 1,
        shift_name TEXT
      )
    ''');
    await _safeAddColumn(
      db,
      'HygieneReports',
      'approval_status',
      "TEXT DEFAULT 'Pending_QM'",
    );
    await _safeAddColumn(db, 'HygieneReports', 'rejection_reason', 'TEXT');
    await _safeAddColumn(db, 'HygieneReports', 'rejected_by', 'TEXT');
    await _safeAddColumn(db, 'HygieneReports', 'qm_approved_by', 'TEXT');
    await _safeAddColumn(db, 'HygieneReports', 'qm_approved_at', 'TEXT');
    await _safeAddColumn(db, 'HygieneReports', 'gm_approved_by', 'TEXT');
    await _safeAddColumn(db, 'HygieneReports', 'gm_approved_at', 'TEXT');
    await _safeAddColumn(
      db,
      'HygieneReports',
      'branch_id',
      'INTEGER DEFAULT 1',
    );
    await _safeAddColumn(db, 'HygieneReports', 'branch_name', 'TEXT');
    await _safeAddColumn(db, 'HygieneReports', 'shift_id', 'INTEGER DEFAULT 1');
    await _safeAddColumn(db, 'HygieneReports', 'shift_name', 'TEXT');
    await _safeAddColumn(db, 'HygieneLogs', 'report_id', 'INTEGER');
    await _safeAddColumn(db, 'HygieneLogs', 'branch_id', 'INTEGER DEFAULT 1');
    await _safeAddColumn(db, 'HygieneLogs', 'shift_id', 'INTEGER DEFAULT 1');
    await _safeAddColumn(db, 'HygieneLogs', 'shift_name', 'TEXT');

    // حقول دورة الرفض والإجراء التصحيحي — تقارير النظافة
    await _safeAddColumn(db, 'HygieneReports', 'rejection_category', 'TEXT');
    await _safeAddColumn(db, 'HygieneReports', 'severity_level', 'TEXT');
    await _safeAddColumn(db, 'HygieneReports', 'rejection_notes', 'TEXT');
    await _safeAddColumn(db, 'HygieneReports', 'affected_products', 'TEXT');
    await _safeAddColumn(db, 'HygieneReports', 'immediate_action', 'TEXT');
    await _safeAddColumn(db, 'HygieneReports', 'corrective_action', 'TEXT');
    await _safeAddColumn(db, 'HygieneReports', 'corrective_owner', 'TEXT');
    await _safeAddColumn(db, 'HygieneReports', 'corrective_due_date', 'TEXT');
    await _safeAddColumn(db, 'HygieneReports', 'gm_decision', 'TEXT');
    await _safeAddColumn(db, 'HygieneReports', 'gm_decision_by', 'TEXT');
    await _safeAddColumn(db, 'HygieneReports', 'gm_decision_at', 'TEXT');
    await _safeAddColumn(db, 'HygieneReports', 'gm_decision_notes', 'TEXT');
    await _safeAddColumn(
      db,
      'HygieneReports',
      'rejection_count',
      'INTEGER DEFAULT 0',
    );
  }

  Future<void> updateHygieneReportApproval({
    required int reportId,
    required String approvalStatus,
    String? qmApprovedBy,
    DateTime? qmApprovedAt,
    String? gmApprovedBy,
    DateTime? gmApprovedAt,
    String? rejectionReason,
    String? rejectedBy,
    String? rejectionCategory,
    String? severityLevel,
    String? rejectionNotes,
    String? affectedProducts,
    String? immediateAction,
    String? correctiveAction,
    String? correctiveOwner,
    DateTime? correctiveDueDate,
    String? gmDecision,
    String? gmDecisionBy,
    DateTime? gmDecisionAt,
    String? gmDecisionNotes,
    int? rejectionCount,
  }) async {
    final db = await instance.database;
    await _ensureHygieneReportTables(db);
    final Map<String, dynamic> data = {'approval_status': approvalStatus};
    if (rejectionCount != null) data['rejection_count'] = rejectionCount;
    if (qmApprovedBy != null) data['qm_approved_by'] = qmApprovedBy;
    if (qmApprovedAt != null) {
      data['qm_approved_at'] = qmApprovedAt.toIso8601String();
    }
    if (gmApprovedBy != null) data['gm_approved_by'] = gmApprovedBy;
    if (gmApprovedAt != null) {
      data['gm_approved_at'] = gmApprovedAt.toIso8601String();
    }
    if (rejectionReason != null) data['rejection_reason'] = rejectionReason;
    if (rejectedBy != null) data['rejected_by'] = rejectedBy;
    if (rejectionCategory != null) {
      data['rejection_category'] = rejectionCategory;
    }
    if (severityLevel != null) data['severity_level'] = severityLevel;
    if (rejectionNotes != null) data['rejection_notes'] = rejectionNotes;
    if (affectedProducts != null) data['affected_products'] = affectedProducts;
    if (immediateAction != null) data['immediate_action'] = immediateAction;
    if (correctiveAction != null) data['corrective_action'] = correctiveAction;
    if (correctiveOwner != null) data['corrective_owner'] = correctiveOwner;
    if (correctiveDueDate != null) {
      data['corrective_due_date'] = correctiveDueDate.toIso8601String();
    }
    if (gmDecision != null) data['gm_decision'] = gmDecision;
    if (gmDecisionBy != null) data['gm_decision_by'] = gmDecisionBy;
    if (gmDecisionAt != null) {
      data['gm_decision_at'] = gmDecisionAt.toIso8601String();
    }
    if (gmDecisionNotes != null) data['gm_decision_notes'] = gmDecisionNotes;

    final info = await db.rawQuery("PRAGMA table_info('HygieneReports')");
    final validCols =
        info.map((r) => r['name'].toString().toLowerCase()).toSet();
    data.removeWhere((key, _) => !validCols.contains(key.toLowerCase()));

    await db.update(
      'HygieneReports',
      data,
      where: 'id = ?',
      whereArgs: [reportId],
    );
  }

  Future<void> deleteHygieneReport(int reportId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final logs = await txn.query(
        'HygieneLogs',
        where: 'report_id = ?',
        whereArgs: [reportId],
      );
      for (final log in logs) {
        final logId = log['id'] as int;
        await txn.delete(
          'HygieneLogDetails',
          where: 'hygiene_log_id = ?',
          whereArgs: [logId],
        );
      }
      await txn.delete(
        'HygieneLogs',
        where: 'report_id = ?',
        whereArgs: [reportId],
      );
      await txn.delete(
        'HygieneReports',
        where: 'id = ?',
        whereArgs: [reportId],
      );
    });
  }

  Future<List<Map<String, Object?>>> getHygieneReports({int? branchId}) async {
    final db = await instance.database;
    await _ensureHygieneReportTables(db);
    String? where;
    List<dynamic>? whereArgs;
    if (branchId != null && branchId > 0) {
      if (branchId == 1) {
        where = '(branch_id = 1 OR branch_id IS NULL)';
      } else {
        where = 'branch_id = ?';
        whereArgs = [branchId];
      }
    }
    return db.query(
      'HygieneReports',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getHygieneReportDetails(int reportId) async {
    final db = await instance.database;
    await _ensureHygieneReportTables(db);
    final report = await db.query(
      'HygieneReports',
      where: 'id = ?',
      whereArgs: [reportId],
      limit: 1,
    );
    if (report.isEmpty) return null;

    final logs = await db.rawQuery(
      '''
      SELECT HygieneLogs.id AS log_id, HygieneLogs.employee_id, HygieneLogs.checklist_id,
             COALESCE(DailyWorkers.full_name, Employees.full_name) AS full_name,
             COALESCE(DailyWorkers.job_title, Employees.job_title) AS job_title
      FROM HygieneLogs
      LEFT JOIN DailyWorkers ON DailyWorkers.id = HygieneLogs.employee_id
      LEFT JOIN Employees ON Employees.id = HygieneLogs.employee_id
      WHERE HygieneLogs.report_id = ?
      ORDER BY HygieneLogs.id ASC
    ''',
      [reportId],
    );
    if (logs.isEmpty) {
      return {
        'report': report.first,
        'employees': <Map<String, Object?>>[],
        'criteria': <Map<String, Object?>>[],
        'details': <Map<String, Object?>>[],
      };
    }

    final checklistId = logs.first['checklist_id'] as int;
    final criteria = await db.query(
      'ChecklistItems',
      where: 'checklist_id = ?',
      whereArgs: [checklistId],
      orderBy: 'id ASC',
    );
    final details = await db.rawQuery(
      '''
      SELECT HygieneLogs.employee_id, HygieneLogDetails.checklist_item_id,
             HygieneLogDetails.is_compliant, HygieneLogDetails.notes
      FROM HygieneLogDetails
      INNER JOIN HygieneLogs ON HygieneLogs.id = HygieneLogDetails.hygiene_log_id
      WHERE HygieneLogs.report_id = ?
    ''',
      [reportId],
    );
    return {
      'report': report.first,
      'employees': logs,
      'criteria': criteria,
      'details': details,
    };
  }

  Future<_HygieneChecklistIds> _ensureHygieneChecklist(
    Transaction transaction,
    List<ChecklistItem> criteria,
  ) async {
    final savedChecklist = await transaction.query(
      'Checklists',
      where: 'type = ?',
      whereArgs: ['PersonalHygiene'],
      limit: 1,
    );
    final checklistId =
        savedChecklist.isEmpty
            ? await transaction.insert('Checklists', {
              'title': 'فحص النظافة الشخصية',
              'type': 'PersonalHygiene',
            })
            : savedChecklist.first['id'] as int;
    final itemIds = <int?, int>{};

    for (final criterion in criteria) {
      final savedItem = await transaction.query(
        'ChecklistItems',
        where: 'checklist_id = ? AND item_name = ?',
        whereArgs: [checklistId, criterion.itemName],
        limit: 1,
      );
      itemIds[criterion.id] =
          savedItem.isEmpty
              ? await transaction.insert('ChecklistItems', {
                'checklist_id': checklistId,
                'item_name': criterion.itemName,
              })
              : savedItem.first['id'] as int;
    }
    return _HygieneChecklistIds(checklistId, itemIds);
  }

  // =====================================
  // المواد الأولية
  // =====================================

  Future<void> _ensureRawMaterialTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS RawMaterialReports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_key TEXT NOT NULL,
        annex_code TEXT NOT NULL,
        annex_title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        date_str TEXT NOT NULL,
        time_str TEXT NOT NULL,
        supplier_name TEXT NOT NULL,
        po_number TEXT NOT NULL,
        material_name TEXT NOT NULL,
        receipt_number TEXT NOT NULL,
        received_quantity TEXT NOT NULL,
        inspected_quantity TEXT NOT NULL,
        inspector_name TEXT NOT NULL,
        batch_number TEXT NOT NULL,
        quality_decision TEXT NOT NULL,
        action_hold INTEGER DEFAULT 0,
        action_reject INTEGER DEFAULT 0,
        action_return_to_supplier INTEGER DEFAULT 0,
        action_ncr INTEGER DEFAULT 0,
        ncr_number TEXT,
        general_notes TEXT,
        annex_notes TEXT,
        approval_status TEXT DEFAULT 'Pending_QM',
        qm_approved_by TEXT,
        qm_approved_at TEXT,
        gm_approved_by TEXT,
        gm_approved_at TEXT,
        lab_responsible_name TEXT,
        lab_responsible_at TEXT,
        rejected_by TEXT,
        rejection_reason TEXT,
        rejection_category TEXT,
        severity_level TEXT,
        rejection_notes TEXT,
        affected_products TEXT,
        immediate_action TEXT,
        corrective_action TEXT,
        corrective_owner TEXT,
        corrective_due_date TEXT,
        gm_decision TEXT,
        gm_decision_by TEXT,
        gm_decision_at TEXT,
        gm_decision_notes TEXT,
        accepted_quantity TEXT,
        rejected_quantity TEXT,
        branch_id INTEGER,
        branch_name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS RawMaterialGeneralResults (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        acceptance_criteria TEXT NOT NULL,
        is_compliant INTEGER,
        result_value TEXT,
        notes TEXT,
        FOREIGN KEY (report_id) REFERENCES RawMaterialReports (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS RawMaterialAnnexResults (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        acceptance_criteria TEXT NOT NULL,
        is_compliant INTEGER,
        result_value TEXT,
        notes TEXT,
        FOREIGN KEY (report_id) REFERENCES RawMaterialReports (id) ON DELETE CASCADE
      )
    ''');

    // ترحيل آمن للأعمدة في حال كان الجدول منشأً مسبقاً بإصدار قديم
    await _safeAddColumn(
      db,
      'RawMaterialReports',
      'rejection_category',
      'TEXT',
    );
    await _safeAddColumn(db, 'RawMaterialReports', 'severity_level', 'TEXT');
    await _safeAddColumn(db, 'RawMaterialReports', 'rejection_notes', 'TEXT');
    await _safeAddColumn(db, 'RawMaterialReports', 'affected_products', 'TEXT');
    await _safeAddColumn(db, 'RawMaterialReports', 'immediate_action', 'TEXT');
    await _safeAddColumn(db, 'RawMaterialReports', 'corrective_action', 'TEXT');
    await _safeAddColumn(db, 'RawMaterialReports', 'corrective_owner', 'TEXT');
    await _safeAddColumn(
      db,
      'RawMaterialReports',
      'corrective_due_date',
      'TEXT',
    );
    await _safeAddColumn(db, 'RawMaterialReports', 'gm_decision', 'TEXT');
    await _safeAddColumn(db, 'RawMaterialReports', 'gm_decision_by', 'TEXT');
    await _safeAddColumn(db, 'RawMaterialReports', 'gm_decision_at', 'TEXT');
    await _safeAddColumn(db, 'RawMaterialReports', 'gm_decision_notes', 'TEXT');
    await _safeAddColumn(db, 'RawMaterialReports', 'accepted_quantity', 'TEXT');
    await _safeAddColumn(db, 'RawMaterialReports', 'rejected_quantity', 'TEXT');
    await _safeAddColumn(db, 'RawMaterialReports', 'branch_id', 'INTEGER');
    await _safeAddColumn(db, 'RawMaterialReports', 'branch_name', 'TEXT');
    await _safeAddColumn(
      db,
      'RawMaterialReports',
      'rejection_count',
      'INTEGER DEFAULT 0',
    );
  }

  Future<int> saveRawMaterialReport({
    int? reportId,
    required RawMaterialReport report,
    required List<RawMaterialItemResult> generalResults,
    required List<RawMaterialItemResult> annexResults,
  }) async {
    final db = await instance.database;
    await _ensureRawMaterialTables(db);

    final id = await db.transaction<int>((txn) async {
      int reportIdResult;
      final reportMap = report.toJson()..remove('id');

      if (reportId != null) {
        final existing = await txn.query(
          'RawMaterialReports',
          where: 'id = ?',
          whereArgs: [reportId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          reportIdResult = reportId;
          await txn.update(
            'RawMaterialReports',
            reportMap,
            where: 'id = ?',
            whereArgs: [reportIdResult],
          );
          await txn.delete(
            'RawMaterialGeneralResults',
            where: 'report_id = ?',
            whereArgs: [reportIdResult],
          );
          await txn.delete(
            'RawMaterialAnnexResults',
            where: 'report_id = ?',
            whereArgs: [reportIdResult],
          );
        } else {
          reportIdResult = reportId;
          final insertMap = Map<String, dynamic>.from(reportMap);
          insertMap['id'] = reportIdResult;
          await txn.insert(
            'RawMaterialReports',
            insertMap,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } else {
        reportIdResult = await txn.insert('RawMaterialReports', reportMap);
      }

      // Insert General Results (Page 1)
      for (final item in generalResults) {
        final map = item.toJson()..remove('id');
        map['report_id'] = reportIdResult;
        await txn.insert('RawMaterialGeneralResults', map);
      }

      // Insert Annex Results (Page 2)
      for (final item in annexResults) {
        final map = item.toJson()..remove('id');
        map['report_id'] = reportIdResult;
        await txn.insert('RawMaterialAnnexResults', map);
      }

      return reportIdResult;
    });

    return id;
  }

  Future<List<RawMaterialReport>> getRawMaterialReports({int? branchId}) async {
    final db = await instance.database;
    await _ensureRawMaterialTables(db);
    String? where;
    List<dynamic>? whereArgs;
    if (branchId != null && branchId > 0) {
      if (branchId == 1) {
        where = '(branch_id = 1 OR branch_id IS NULL)';
      } else {
        where = 'branch_id = ?';
        whereArgs = [branchId];
      }
    }
    final results = await db.query(
      'RawMaterialReports',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return results.map((e) => RawMaterialReport.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>?> getRawMaterialReportDetails(
    int reportId,
  ) async {
    final db = await instance.database;
    await _ensureRawMaterialTables(db);

    final reportRows = await db.query(
      'RawMaterialReports',
      where: 'id = ?',
      whereArgs: [reportId],
      limit: 1,
    );
    if (reportRows.isEmpty) return null;

    final report = RawMaterialReport.fromJson(reportRows.first);

    final generalRows = await db.query(
      'RawMaterialGeneralResults',
      where: 'report_id = ?',
      whereArgs: [reportId],
      orderBy: 'item_id ASC',
    );
    final generalResults =
        generalRows.map((e) => RawMaterialItemResult.fromJson(e)).toList();

    final annexRows = await db.query(
      'RawMaterialAnnexResults',
      where: 'report_id = ?',
      whereArgs: [reportId],
      orderBy: 'item_id ASC',
    );
    final annexResults =
        annexRows.map((e) => RawMaterialItemResult.fromJson(e)).toList();

    return {
      'report': report,
      'generalResults': generalResults,
      'annexResults': annexResults,
    };
  }

  Future<void> updateRawMaterialReportApproval({
    required int reportId,
    required String approvalStatus,
    String? qmApprovedBy,
    DateTime? qmApprovedAt,
    String? gmApprovedBy,
    DateTime? gmApprovedAt,
    String? labResponsibleName,
    DateTime? labResponsibleAt,
    String? rejectionReason,
    String? rejectedBy,
    String? rejectionCategory,
    String? severityLevel,
    String? rejectionNotes,
    String? affectedProducts,
    String? immediateAction,
    String? correctiveAction,
    String? correctiveOwner,
    DateTime? correctiveDueDate,
    String? gmDecision,
    String? gmDecisionBy,
    DateTime? gmDecisionAt,
    String? gmDecisionNotes,
    int? rejectionCount,
  }) async {
    final db = await instance.database;
    await _ensureRawMaterialTables(db);

    final Map<String, dynamic> data = {'approval_status': approvalStatus};
    if (rejectionCount != null) data['rejection_count'] = rejectionCount;
    if (qmApprovedBy != null) data['qm_approved_by'] = qmApprovedBy;
    if (qmApprovedAt != null) {
      data['qm_approved_at'] = qmApprovedAt.toIso8601String();
    }
    if (gmApprovedBy != null) data['gm_approved_by'] = gmApprovedBy;
    if (gmApprovedAt != null) {
      data['gm_approved_at'] = gmApprovedAt.toIso8601String();
    }
    if (labResponsibleName != null) {
      data['lab_responsible_name'] = labResponsibleName;
    }
    if (labResponsibleAt != null) {
      data['lab_responsible_at'] = labResponsibleAt.toIso8601String();
    }
    if (rejectionReason != null) data['rejection_reason'] = rejectionReason;
    if (rejectedBy != null) data['rejected_by'] = rejectedBy;
    if (rejectionCategory != null) {
      data['rejection_category'] = rejectionCategory;
    }
    if (severityLevel != null) data['severity_level'] = severityLevel;
    if (rejectionNotes != null) data['rejection_notes'] = rejectionNotes;
    if (affectedProducts != null) data['affected_products'] = affectedProducts;
    if (immediateAction != null) data['immediate_action'] = immediateAction;
    if (correctiveAction != null) data['corrective_action'] = correctiveAction;
    if (correctiveOwner != null) data['corrective_owner'] = correctiveOwner;
    if (correctiveDueDate != null) {
      data['corrective_due_date'] = correctiveDueDate.toIso8601String();
    }
    if (gmDecision != null) data['gm_decision'] = gmDecision;
    if (gmDecisionBy != null) data['gm_decision_by'] = gmDecisionBy;
    if (gmDecisionAt != null) {
      data['gm_decision_at'] = gmDecisionAt.toIso8601String();
    }
    if (gmDecisionNotes != null) data['gm_decision_notes'] = gmDecisionNotes;

    await db.update(
      'RawMaterialReports',
      data,
      where: 'id = ?',
      whereArgs: [reportId],
    );
  }

  Future<void> deleteRawMaterialReport(int reportId) async {
    final db = await instance.database;
    await _ensureRawMaterialTables(db);
    await db.transaction((txn) async {
      await txn.delete(
        'RawMaterialGeneralResults',
        where: 'report_id = ?',
        whereArgs: [reportId],
      );
      await txn.delete(
        'RawMaterialAnnexResults',
        where: 'report_id = ?',
        whereArgs: [reportId],
      );
      await txn.delete(
        'RawMaterialReports',
        where: 'id = ?',
        whereArgs: [reportId],
      );
    });
  }

  // =====================================
  // محرك التقارير الديناميكية
  // =====================================

  Future _createDynamicReportTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dr_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        icon TEXT,
        sort_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dr_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        name TEXT NOT NULL,
        description TEXT,
        icon TEXT,
        sort_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        approval_type TEXT DEFAULT 'two_level',
        orientation TEXT DEFAULT 'portrait',
        doc_number TEXT,
        version_number TEXT,
        issue_date TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (category_id) REFERENCES dr_categories(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dr_sections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        sort_order INTEGER DEFAULT 0,
        is_collapsible INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (report_id) REFERENCES dr_reports(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dr_fields (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL,
        section_id INTEGER NOT NULL,
        field_key TEXT NOT NULL,
        label TEXT NOT NULL,
        hint TEXT,
        field_type TEXT NOT NULL,
        is_required INTEGER DEFAULT 0,
        sort_order INTEGER DEFAULT 0,
        default_value TEXT,
        options_json TEXT,
        validation_json TEXT,
        min_value REAL,
        max_value REAL,
        unit TEXT,
        is_visible INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (report_id) REFERENCES dr_reports(id) ON DELETE CASCADE,
        FOREIGN KEY (section_id) REFERENCES dr_sections(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dr_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL,
        created_by TEXT,
        created_at TEXT,
        updated_at TEXT,
        status TEXT,
        approval_status TEXT DEFAULT 'Pending_QM',
        qm_approved_by TEXT,
        qm_approved_at TEXT,
        gm_approved_by TEXT,
        gm_approved_at TEXT,
        rejection_reason TEXT,
        rejected_by TEXT,
        rejected_at TEXT,
        record_serial INTEGER,
        record_code TEXT,
        FOREIGN KEY (report_id) REFERENCES dr_reports(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dr_values (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id INTEGER NOT NULL,
        field_id INTEGER NOT NULL,
        value TEXT
      )
    ''');

    // Seed default categories if empty
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM dr_categories'),
    );
    if (count == 0) {
      final now = DateTime.now().toIso8601String();
      await db.insert('dr_categories', {
        'id': 1,
        'name': 'إدارة الجودة',
        'description': 'تقارير وفحوصات الجودة',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('dr_categories', {
        'id': 2,
        'name': 'سلامة الغذاء',
        'description': 'تقارير وسجلات سلامة الغذاء',
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

class _HygieneChecklistIds {
  const _HygieneChecklistIds(this.checklistId, this.itemIds);

  final int checklistId;
  final Map<int?, int> itemIds;
}
