import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() async {
  final client = MqttServerClient.withPort('broker.emqx.io', 'test_ws_client', 8083);
  client.useWebSocket = true;
  client.logging(on: true);
  try {
    await client.connect();
    print('WS CONNECTED STATUS: ${client.connectionStatus?.state}');
    client.disconnect();
  } catch(e) {
    print('WS ERROR: $e');
  }
}
