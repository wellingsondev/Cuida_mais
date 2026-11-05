import 'package:cuida_plus/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('e-mail', () {
    expect(Validators.email('a@b.com'), isNull);
    expect(Validators.email('abc'), isNotNull);
    expect(Validators.email(''), isNotNull);
  });
  test('senha exige 8+ caracteres, letras e números', () {
    expect(Validators.password('abc12'), isNotNull);
    expect(Validators.password('abcdefgh'), isNotNull);
    expect(Validators.password('abcd1234'), isNull);
  });
  test('horários inválidos são rejeitados', () {
    expect(Validators.isValidTime(24, 0), isFalse);
    expect(Validators.isValidTime(8, 60), isFalse);
    expect(Validators.isValidTime(23, 59), isTrue);
  });
  test('nome', () {
    expect(Validators.name(' '), isNotNull);
    expect(Validators.name('Maria Silva'), isNull);
  });
}
