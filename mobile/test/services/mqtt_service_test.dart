import 'package:flutter_test/flutter_test.dart';
import 'package:soil_nutrient_app/services/mqtt_service.dart';

void main() {
  test('MqttService keeps retrying after a failed first connection and stops once disposed', () async {
    final service = MqttService(retryDelay: const Duration(milliseconds: 300));
    final states = <AppMqttState>[];
    final subscription = service.stateStream.listen(states.add);

    // Nothing listens on port 1, so every attempt is refused straight away
    await service.connect(broker: '127.0.0.1', port: 1);
    await Future<void>.delayed(const Duration(seconds: 3));
    service.dispose();
    final countAtDispose = states.length;
    await Future<void>.delayed(const Duration(seconds: 1));
    await subscription.cancel();

    expect(states.first, AppMqttState.connecting);
    expect(states.where((s) => s == AppMqttState.error).length, greaterThanOrEqualTo(2),
        reason: 'states seen: $states');
    expect(states.length, countAtDispose, reason: 'no retry may run after dispose');
    expect(service.publishCommand({'action': 'SET_PUMP', 'state': true}), isFalse);
  });
}
