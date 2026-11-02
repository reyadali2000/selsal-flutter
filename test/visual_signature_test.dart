import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:wadialain/models/dynamic_report_models.dart';
import 'package:wadialain/services/user_signature_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Visual Overlay Signature Tests', () {
    test('UserSignatureService computes valid SHA-256 hashes', () {
      final service = UserSignatureService.instance;
      final bytes = utf8.encode('Hello Quality System Signature');
      final hash = service.computeHash(bytes);

      expect(hash, isNotEmpty);
      expect(hash.length, equals(64)); // SHA-256 is 64 hex characters
    });

    test('UserSignatureService computes tamper-evident document hash', () {
      final service = UserSignatureService.instance;
      final hash1 = service.computeDocumentHash(
        recordId: 101,
        reportName: 'تقرير فحص خط الإنتاج',
        dataJson: {'ph': 7.2, 'tds': 115},
        actionAt: '2026-09-17T10:00:00',
        actionBy: 'نبيل مراد (مدير الجودة)',
      );

      final hash2 = service.computeDocumentHash(
        recordId: 101,
        reportName: 'تقرير فحص خط الإنتاج',
        dataJson: {'ph': 7.2, 'tds': 115},
        actionAt: '2026-09-17T10:00:00',
        actionBy: 'نبيل مراد (مدير الجودة)',
      );

      // Mutated data should change hash
      final hashMutated = service.computeDocumentHash(
        recordId: 101,
        reportName: 'تقرير فحص خط الإنتاج',
        dataJson: {'ph': 7.8, 'tds': 115}, // altered value
        actionAt: '2026-09-17T10:00:00',
        actionBy: 'نبيل مراد (مدير الجودة)',
      );

      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(hashMutated)));
    });

    test('UserSignatureService generates valid transparent PNG signature', () async {
      final service = UserSignatureService.instance;
      final pngBytes = await service.generateDefaultTransparentSignature(
        signerName: 'نبيل مراد',
        signerPosition: 'مدير توكيد ورقابة الجودة',
      );

      expect(pngBytes, isNotNull);
      expect(pngBytes.isNotEmpty, isTrue);

      // Verify PNG magic header: 0x89 0x50 0x4E 0x47 (‰PNG)
      expect(pngBytes[0], equals(0x89));
      expect(pngBytes[1], equals(0x50));
      expect(pngBytes[2], equals(0x4E));
      expect(pngBytes[3], equals(0x47));
    });

    test('UserSignature model toMap and fromMap serialization', () {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final base64Str = base64Encode(dummyBytes);

      final sig = UserSignature(
        id: 1,
        userId: 10,
        signatureType: 'drawn_png',
        signatureData: base64Str,
        signatureHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        isActive: true,
        createdAt: DateTime.now(),
      );

      final map = sig.toMap();
      expect(map['user_id'], equals(10));
      expect(map['is_active'], equals(1));

      final restored = UserSignature.fromMap(map);
      expect(restored.userId, equals(10));
      expect(restored.isActive, isTrue);
      expect(restored.bytes, isNotNull);
      expect(restored.bytes!.length, equals(8));
    });

    test('ReportApproval freezes immutable signature snapshot and document hash', () {
      final samplePng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final hash = UserSignatureService.instance.computeHash(samplePng);

      final approval = ReportApproval(
        id: 1,
        recordId: 45,
        stepName: 'اعتماد مدير الجودة',
        action: 'approve',
        actedBy: 'نبيل مراد (مدير الجودة)',
        actionByPosition: 'QualityManager',
        actedAt: DateTime.now(),
        previousStatus: 'Pending_QM',
        newStatus: 'Pending_GM',
        signatureSnapshotBlob: samplePng,
        signatureHash: hash,
        signatureType: 'drawn_png',
        documentHash: 'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3',
      );

      final map = approval.toMap();
      expect(map['signature_hash'], equals(hash));
      expect(map['action_by_position'], equals('QualityManager'));
      expect(map['signature_snapshot_blob'], equals(samplePng));

      final restored = ReportApproval.fromMap(map);
      expect(restored.signatureBytes, isNotNull);
      expect(restored.signatureBytes!.length, equals(samplePng.length));
      expect(restored.signatureHash, equals(hash));
      expect(restored.documentHash, equals('a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3'));
    });
  });
}
