import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/utils/telefono_escritorio.dart';

void main() {
  test('teléfono de escritorio admite México y lada internacional', () {
    expect(telefonoEscritorio('(811) 123-4567'), '+528111234567');
    expect(telefonoEscritorio('+1 415 555 1234'), '+14155551234');
    expect(telefonoEscritorio('abc1234567'), isNull);
    expect(telefonoEscritorio('123'), isNull);
    expect(telefonoEscritorio('1234567890123456'), isNull);
  });
}
