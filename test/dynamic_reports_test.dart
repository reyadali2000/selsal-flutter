import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wadialain/models/dynamic_report_models.dart';

void main() {
  // Initialize FFI for unit testing SQLite
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Dynamic Reports Database Service Tests', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(
        version: 7,
        onCreate: (db, version) async {
          // Manually recreate just the tables we need for isolated testing
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
              branch_id INTEGER,
              branch_name TEXT,
              shift_name TEXT,
              report_version_id INTEGER,
              department_id INTEGER,
              position_id INTEGER,
              product_id INTEGER,
              sampling_datetime TEXT,
              is_compliant INTEGER,
              current_step_id INTEGER,
              current_step_name TEXT,
              summary_notes TEXT,
              data_json TEXT,
              FOREIGN KEY (report_id) REFERENCES dr_reports(id) ON DELETE CASCADE
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS dr_values (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              record_id INTEGER NOT NULL,
              field_id INTEGER NOT NULL,
              value TEXT,
              FOREIGN KEY (record_id) REFERENCES dr_records(id) ON DELETE CASCADE,
              FOREIGN KEY (field_id) REFERENCES dr_fields(id) ON DELETE CASCADE
            )
          ''');
        },
      ));

      // Overriding the db getter for testing
      // (Normally you'd use dependency injection, but here we can't easily mock the singleton without changing it.
      // We will assume the service functions can be tested if we were using a mockable architecture.
      // For this test script, we will test the models and the general SQL logic).
    });

    tearDown(() async {
      await db.close();
    });

    test('1. إنشاء فئة (Category) و قراءتها', () async {
      final category = DynamicReportCategory(name: 'اختبار', description: 'وصف الاختبار');
      int id = await db.insert('dr_categories', category.toMap());
      expect(id, greaterThan(0));

      final rows = await db.query('dr_categories');
      expect(rows.length, 1);
      expect(rows.first['name'], 'اختبار');
    });

    test('2 & 3. إنشاء تقرير، قسم، وحقل (Create Report, Section, Field)', () async {
      // Report
      int reportId = await db.insert('dr_reports', DynamicReport(name: 'تقرير جودة المياه').toMap());
      expect(reportId, greaterThan(0));

      // Section
      int sectionId = await db.insert('dr_sections', DynamicReportSection(
        reportId: reportId,
        title: 'معلومات العينة',
      ).toMap());
      expect(sectionId, greaterThan(0));

      // Field
      int fieldId = await db.insert('dr_fields', DynamicReportField(
        reportId: reportId,
        sectionId: sectionId,
        fieldKey: 'ph_level',
        label: 'مستوى الـ PH',
        fieldType: 'decimal',
        isRequired: true,
        minValue: 6.5,
        maxValue: 8.5,
      ).toMap());
      expect(fieldId, greaterThan(0));
    });

    test('4. حفظ وقراءة تقرير بسجل (Records and Values)', () async {
      int reportId = await db.insert('dr_reports', DynamicReport(name: 'Test Report').toMap());
      int sectionId = await db.insert('dr_sections', DynamicReportSection(reportId: reportId, title: 'Sec').toMap());
      int fieldId = await db.insert('dr_fields', DynamicReportField(reportId: reportId, sectionId: sectionId, fieldKey: 'f1', label: 'L1', fieldType: 'text').toMap());

      int recordId = await db.insert('dr_records', DynamicReportRecord(reportId: reportId, status: 'مكتمل').toMap());
      await db.insert('dr_values', DynamicReportValue(recordId: recordId, fieldId: fieldId, value: 'Test Value').toMap());

      final records = await db.query('dr_records');
      final values = await db.query('dr_values');

      expect(records.length, 1);
      expect(values.length, 1);
      expect(values.first['value'], 'Test Value');
    });

    test('5. حفظ وقراءة بيانات تذييلة التقرير (Document Control Footer: docNumber, versionNumber, issueDate)', () async {
      final report = DynamicReport(
        name: 'تقرير تحليل البيئة والميكروبيولوجي',
        docNumber: 'SELSAL-QA-SOP-09',
        versionNumber: '03',
        issueDate: '2026/07/15',
        approvalType: 'two_level',
        orientation: 'landscape',
      );

      final map = report.toMap();
      expect(map['doc_number'], 'SELSAL-QA-SOP-09');
      expect(map['version_number'], '03');
      expect(map['issue_date'], '2026/07/15');

      int reportId = await db.insert('dr_reports', map);
      expect(reportId, greaterThan(0));

      final rows = await db.query('dr_reports', where: 'id = ?', whereArgs: [reportId]);
      expect(rows.length, 1);
      final fetched = DynamicReport.fromMap(rows.first);
      expect(fetched.docNumber, 'SELSAL-QA-SOP-09');
      expect(fetched.versionNumber, '03');
      expect(fetched.issueDate, '2026/07/15');
      expect(fetched.approvalType, 'two_level');
      expect(fetched.orientation, 'landscape');
    });
  });
}
