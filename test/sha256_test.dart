import 'package:abasteceapp/utils/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SHA-256', () {
    test('coincide con los vectores oficiales', () {
      expect(
        Hex.encode(Sha256.digest(<int>[])),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        Hex.encode(Sha256.digest('abc'.codeUnits)),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(
        Hex.encode(
          Sha256.digest(
            'The quick brown fox jumps over the lazy dog'.codeUnits,
          ),
        ),
        'd7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592',
      );
    });

    test('procesa mensajes de más de un bloque', () {
      final String message = 'a' * 1000;
      final String digest = Hex.encode(Sha256.digest(message.codeUnits));
      expect(digest.length, 64);
      expect(
        digest,
        isNot(Hex.encode(Sha256.digest(('a' * 999).codeUnits))),
      );
    });
  });

  group('PasswordHasher', () {
    test('deriva siempre el mismo hash para la misma sal', () {
      const String salt = '0123456789abcdef0123456789abcdef';
      final String first = PasswordHasher.derive('Abastece2026', salt);
      final String second = PasswordHasher.derive('Abastece2026', salt);
      expect(first, second);
      expect(first.length, 64);
    });

    test('cambia el hash si cambia la sal o la contraseña', () {
      final String salt = PasswordHasher.generateSalt();
      final String otherSalt = PasswordHasher.generateSalt();
      expect(salt, isNot(otherSalt));

      final String hash = PasswordHasher.derive('Abastece2026', salt);
      expect(
        PasswordHasher.verify(
          password: 'Abastece2026',
          salt: salt,
          hash: hash,
        ),
        isTrue,
      );
      expect(
        PasswordHasher.verify(
          password: 'Abastece2026',
          salt: otherSalt,
          hash: hash,
        ),
        isFalse,
      );
      expect(
        PasswordHasher.verify(
          password: 'otra-clave',
          salt: salt,
          hash: hash,
        ),
        isFalse,
      );
    });

    test('compara en tiempo constante solo con igual longitud', () {
      expect(PasswordHasher.constantTimeEquals('abc', 'abc'), isTrue);
      expect(PasswordHasher.constantTimeEquals('abc', 'abd'), isFalse);
      expect(PasswordHasher.constantTimeEquals('abc', 'abcd'), isFalse);
    });
  });
}
