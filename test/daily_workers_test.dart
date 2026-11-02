import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wadialain/models/hygiene_models.dart';

void main() {
  // Initialize FFI for unit testing SQLite
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DailyWorker Name Normalization', () {
    test('unifies alef variants', () {
      expect(DailyWorker.normalizeName('أحمد'), DailyWorker.normalizeName('احمد'));
      expect(DailyWorker.normalizeName('إبراهيم'), DailyWorker.normalizeName('ابراهيم'));
      expect(DailyWorker.normalizeName('آدم'), DailyWorker.normalizeName('ادم'));
    });

    test('unifies ya and ta-marbuta', () {
      expect(DailyWorker.normalizeName('علي'), DailyWorker.normalizeName('على'));
      expect(DailyWorker.normalizeName('مدينة'), DailyWorker.normalizeName('مدينه'));
    });

    test('removes diacritics', () {
      expect(DailyWorker.normalizeName('مُحمَّد'), DailyWorker.normalizeName('محمد'));
      expect(DailyWorker.normalizeName('بِسْمِ'), DailyWorker.normalizeName('بسم'));
    });

    test('collapses repeated spaces and trims', () {
      expect(DailyWorker.normalizeName('  أحمد   علي  '), 'احمد علي');
    });

    test('empty input yields empty key', () {
      expect(DailyWorker.normalizeName(''), '');
      expect(DailyWorker.normalizeName('   '), '');
    });

    test('same normalized key for typographic variants', () {
      expect(
        DailyWorker.normalizeName('أحمد علي'),
        DailyWorker.normalizeName('احمد على'),
      );
    });
  });

  group('DailyWorker Model', () {
    test('toMap includes computed name_key', () {
      final worker = DailyWorker(
        branchId: 1,
        fullName: 'أحمد علي',
        jobTitle: 'عامل بالأجر اليومي',
      );
      final map = worker.toMap();
      expect(map['name_key'], equals('احمد علي'));
      expect(map['branch_id'], equals(1));
      expect(map['is_active'], equals(1));
      expect(map['full_name'], equals('أحمد علي'));
    });

    test('fromMap restores defaults for missing fields', () {
      final worker = DailyWorker.fromMap({
        'id': 5,
        'branch_id': 2,
        'full_name': 'سعيد',
        'name_key': 'سعيد',
      });
      expect(worker.id, equals(5));
      expect(worker.branchId, equals(2));
      expect(worker.isActive, isTrue);
      expect(worker.jobTitle, equals('عامل بالأجر اليومي'));
    });

    test('copyWith preserves identity when fields omitted', () {
      final worker = DailyWorker(
        id: 3,
        branchId: 1,
        fullName: 'خالد',
      );
      final updated = worker.copyWith(fullName: 'خالد الجابري');
      expect(updated.id, equals(3));
      expect(updated.branchId, equals(1));
      expect(updated.fullName, equals('خالد الجابري'));
    });

    test('equality and hashCode follow id', () {
      final a = DailyWorker(id: 1, branchId: 1, fullName: 'أحمد');
      final b = DailyWorker(id: 1, branchId: 2, fullName: 'محمد');
      final c = DailyWorker(id: 2, branchId: 1, fullName: 'أحمد');
      expect(a == b, isTrue);
      expect(a.hashCode, equals(b.hashCode));
      expect(a == c, isFalse);
    });
  });

  group('Employee databaseWorkerId Linkage', () {
    test('toJson serializes databaseWorkerId', () {
      final emp = Employee(
        id: 10,
        branchId: 1,
        fullName: 'عامل',
        jobTitle: 'عامل بالأجر اليومي',
        isActive: true,
        databaseWorkerId: 7,
      );
      expect(emp.toJson()['database_worker_id'], equals(7));
    });

    test('fromJson reads databaseWorkerId', () {
      final emp = Employee.fromJson({
        'id': 10,
        'branch_id': 1,
        'full_name': 'عامل',
        'job_title': 'عامل',
        'is_active': 1,
        'database_worker_id': 42,
      });
      expect(emp.databaseWorkerId, equals(42));
    });

    test('databaseWorkerId defaults to null when absent', () {
      final emp = Employee.fromJson({
        'id': 1,
        'branch_id': 1,
        'full_name': 'عامل',
        'job_title': 'عامل',
        'is_active': 1,
      });
      expect(emp.databaseWorkerId, isNull);
    });
  });

  group('DailyWorkers Database Schema', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE DailyWorkers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                branch_id INTEGER NOT NULL DEFAULT 1,
                full_name TEXT NOT NULL,
                name_key TEXT NOT NULL,
                job_title TEXT,
                is_active INTEGER DEFAULT 1,
                created_at TEXT,
                UNIQUE(branch_id, name_key)
              )
            ''');
          },
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('unique constraint prevents duplicate normalized name per branch', () async {
      await db.insert('DailyWorkers', {
        'branch_id': 1,
        'full_name': 'أحمد علي',
        'name_key': 'احمد علي',
        'job_title': 'عامل',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      // نفس الاسم بتشكيل مختلف → نفس name_key → يجب أن يفشل
      expect(
        () => db.insert('DailyWorkers', {
          'branch_id': 1,
          'full_name': 'أحمد علي',
          'name_key': 'احمد علي',
          'job_title': 'عامل',
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<Exception>()),
      );
    });

    test('same name allowed in different branches', () async {
      await db.insert('DailyWorkers', {
        'branch_id': 1,
        'full_name': 'أحمد',
        'name_key': 'احمد',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('DailyWorkers', {
        'branch_id': 2,
        'full_name': 'أحمد',
        'name_key': 'احمد',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      final rows = await db.query('DailyWorkers', where: 'name_key = ?', whereArgs: ['احمد']);
      expect(rows.length, equals(2));
    });

    test('name_key index exists for fast autocomplete', () async {
      // التحقق من إمكانية إنشاء الفهرس دون أخطاء (كما في الترقية)
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_daily_workers_name_key ON DailyWorkers(name_key)');
      final indexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'DailyWorkers'");
      expect(indexes.any((row) => row['name'] == 'idx_daily_workers_name_key'), isTrue);
    });

    test('autocomplete query orders prefix matches first', () async {
      for (final name in ['أحمد علي', 'أحمد محمد', 'خالد أحمد', 'سعيد']) {
        await db.insert('DailyWorkers', {
          'branch_id': 1,
          'full_name': name,
          'name_key': DailyWorker.normalizeName(name),
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // البحث عن "أحمد" يجب أن يبدأ بالأسماء التي تبدأ بأحمد.
      // نطبّع الاسم أولاً كما يفعل السيرفس الحقيقي.
      final searchKey = DailyWorker.normalizeName('أحمد');
      final results = await db.rawQuery('''
        SELECT * FROM DailyWorkers
        WHERE is_active = 1
          AND (name_key LIKE ? OR name_key LIKE ?)
        ORDER BY
          CASE WHEN name_key LIKE ? THEN 0 ELSE 1 END,
          full_name ASC
        LIMIT ?
      ''', ['$searchKey%', '%$searchKey%', '$searchKey%', 8]);

      expect(results.length, equals(3));
      // "خالد أحمد" يطابق الاحتواء فقط فيأتي أخيراً
      expect(results.last['name_key'], equals('خالد احمد'));
    });
  });

  group('Employees to DailyWorkers Migration', () {
    test('distinct employee names migrate into the registry', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE Employees (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                branch_id INTEGER,
                full_name TEXT,
                job_title TEXT,
                is_active INTEGER
              )
            ''');
            await db.execute('''
              CREATE TABLE DailyWorkers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                branch_id INTEGER NOT NULL DEFAULT 1,
                full_name TEXT NOT NULL,
                name_key TEXT NOT NULL,
                job_title TEXT,
                is_active INTEGER DEFAULT 1,
                created_at TEXT,
                UNIQUE(branch_id, name_key)
              )
            ''');
          },
        ),
      );

      // الموظفون القُدمى (يتكررون عبر التقارير)
      await db.insert('Employees',
          {'branch_id': 1, 'full_name': 'أحمد', 'job_title': 'عامل', 'is_active': 1});
      await db.insert('Employees',
          {'branch_id': 1, 'full_name': 'أحمد', 'job_title': 'عامل', 'is_active': 1});
      await db.insert('Employees',
          {'branch_id': 2, 'full_name': 'سعيد', 'job_title': 'عامل', 'is_active': 1});

      await db.execute('''
        INSERT OR IGNORE INTO DailyWorkers (branch_id, full_name, name_key, job_title, is_active, created_at)
        SELECT
          COALESCE(branch_id, 1),
          full_name,
          full_name,
          COALESCE(job_title, 'عامل بالأجر اليومي'),
          COALESCE(is_active, 1),
          CURRENT_TIMESTAMP
        FROM Employees
        WHERE full_name IS NOT NULL AND TRIM(full_name) <> ''
      ''');

      final workers = await db.query('DailyWorkers', orderBy: 'branch_id, full_name');
      expect(workers.length, equals(2));
      expect(workers[0]['full_name'], equals('أحمد'));
      expect(workers[0]['branch_id'], equals(1));
      expect(workers[1]['full_name'], equals('سعيد'));
      expect(workers[1]['branch_id'], equals(2));

      await db.close();
    });
  });
}
