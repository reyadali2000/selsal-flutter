import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wadialain/services/user_signature_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Executive Dashboard PDF Generator & Preparer Signature Tests', () {
    test('Preparer signature generates properly and fallback works', () async {
      final service = UserSignatureService.instance;
      final signatureBytes = await service.getSignatureBytesForUser(
        userId: -1, // Test id <= 0 fallback
        userName: 'أ. حمود يسر (مدير الجودة)',
        userPosition: 'مدير توكيد ورقابة الجودة',
      );

      expect(signatureBytes, isNotNull);
      expect(signatureBytes.isNotEmpty, isTrue);
      // Verify PNG header
      expect(signatureBytes[0], equals(0x89));
      expect(signatureBytes[1], equals(0x50));
      expect(signatureBytes[2], equals(0x4E));
      expect(signatureBytes[3], equals(0x47));
    });
  });
}
