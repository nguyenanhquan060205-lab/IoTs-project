import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() async {
  // Test with withWillQos but no will topic/message
  final client = MqttServerClient('broker.emqx.io', 'test_will_qos_${DateTime.now().millisecondsSinceEpoch}');
  client.port = 1883;
  client.logging(on: true);

  final connMessage = MqttConnectMessage()
      .withClientIdentifier(client.clientIdentifier)
      .startClean()
      .withWillQos(MqttQos.atLeastOnce); // <--- This!
  client.connectionMessage = connMessage;

  try {
    await client.connect();
    print('STATUS: ${client.connectionStatus?.state}');
    client.disconnect();
  } catch(e) {
    print('FAILED AS EXPECTED: $e');
  }
}
