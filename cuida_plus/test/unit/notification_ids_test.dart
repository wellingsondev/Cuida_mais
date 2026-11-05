import 'package:cuida_plus/core/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('IDs de notificação são estáveis (sem duplicatas ao reagendar)', () {
    expect(NotificationService.stableId('med_m1_0800'), NotificationService.stableId('med_m1_0800'));
    expect(NotificationService.stableId('med_m1_0800'), isNot(NotificationService.stableId('med_m1_1400')));
  });
  test('IDs cabem em 31 bits (limite do Android)', () {
    for (final s in ['a', 'med_x_2000', 'consult_abc']) {
      final id = NotificationService.stableId(s);
      expect(id, inInclusiveRange(0, 0x7FFFFFFF));
    }
  });
}
