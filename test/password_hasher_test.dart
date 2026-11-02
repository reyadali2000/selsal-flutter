import 'package:flutter_test/flutter_test.dart';
import 'package:wadialain/utils/password_hasher.dart';

void main() {
  group('PasswordHasher', () {
    test('hash is 64 hex chars and deterministic', () {
      final h1 = PasswordHasher.hash('123456');
      final h2 = PasswordHasher.hash('123456');
      expect(h1, equals(h2));
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(h1), isTrue);
    });

    test('hash never equals plaintext', () {
      expect(PasswordHasher.hash('123456'), isNot(equals('123456')));
    });

    test('verify succeeds with correct password', () {
      final hash = PasswordHasher.hash('mySecret123');
      expect(PasswordHasher.verify('mySecret123', hash), isTrue);
    });

    test('verify fails with wrong password', () {
      final hash = PasswordHasher.hash('correct');
      expect(PasswordHasher.verify('wrong', hash), isFalse);
      expect(PasswordHasher.verify('Correct', hash), isFalse);
      expect(PasswordHasher.verify('correct1', hash), isFalse);
    });

    test('verify fails when stored hash is empty (blocks empty-password bypass)', () {
      expect(PasswordHasher.verify('anything', ''), isFalse);
      expect(PasswordHasher.verify('anything', null), isFalse);
    });

    test('verify fails for random username/password pairs', () {
      // محاكاة محاولة دخول ببيانات عشوائية ضد هاش كلمة مرور حقيقية
      final stored = PasswordHasher.hash('123456');
      for (final guess in ['0000', 'random', 'password', 'admin', '1111', 'xyz']) {
        expect(PasswordHasher.verify(guess, stored), isFalse,
            reason: 'guess "$guess" must not match');
      }
    });

    test('looksLikeHash distinguishes hashes from plaintext', () {
      expect(PasswordHasher.looksLikeHash('123456'), isFalse);
      expect(PasswordHasher.looksLikeHash('admin'), isFalse);
      expect(PasswordHasher.looksLikeHash(PasswordHasher.hash('123456')), isTrue);
    });
  });
}
