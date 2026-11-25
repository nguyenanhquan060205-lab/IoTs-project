import 'package:flutter/material.dart';
import '../models/soil_telemetry.dart';
import '../models/soil_type.dart';
import '../services/agronomic_engine.dart';
import '../services/history_repository.dart';
import '../services/mqtt_service.dart';

class SoilDataProvider extends ChangeNotifier {
  final MqttService _mqttService = MqttService();
  final HistoryRepository historyRepository;

  SoilTelemetry _currentTelemetry = SoilTelemetry.initial();
  final List<SoilTelemetry> _history = [];
  AppMqttState _connectionState = AppMqttState.disconnected;
  SoilType? _pendingSoilType; // Loại đất vừa chọn trên App, đang chờ trạm xác nhận
  final Map<Actuator, _PendingSwitch> _pendingSwitches = {}; // Lệnh bật/tắt rơ-le đang chờ trạm xác nhận

  SoilTelemetry get currentTelemetry => _currentTelemetry;
  List<SoilTelemetry> get history => _history;
  AppMqttState get connectionState => _connectionState;

  /// Loại đất hiển thị là đang chọn: ưu tiên lựa chọn chờ xác nhận, sau đó tới loại trạm báo về
  SoilType get selectedSoilType =>
      _pendingSoilType ?? _currentTelemetry.soilType ?? SoilType.garden;

  /// true khi trạm chưa gửi về số liệu đo theo loại đất vừa chọn
  bool get isSoilTypeSyncing => _pendingSoilType != null;

  /// Trạng thái rơ-le đang hiển thị: ưu tiên lệnh vừa gửi, sau đó tới trạng thái trạm báo về
  bool actuatorState(Actuator actuator) =>
      _pendingSwitches[actuator]?.state ?? _reportedState(_currentTelemetry, actuator) ?? false;

  /// true khi đã gửi lệnh bật/tắt nhưng trạm chưa báo lại trạng thái mới
  bool isActuatorSyncing(Actuator actuator) => _pendingSwitches.containsKey(actuator);

  /// true khi trạm đã từng báo trạng thái rơ-le (firmware cũ hoặc chưa có số đo thật thì false)
  bool get hasActuatorReport => _currentTelemetry.pump != null;

  AgronomicDiagnosis get currentDiagnosis => AgronomicEngine.evaluate(
        telemetry: _currentTelemetry,
      );

  SoilDataProvider({HistoryRepository? historyRepository})
      : historyRepository = historyRepository ?? HistoryRepository() {
    _history.add(_currentTelemetry);
    _initMqtt();
  }

  void _initMqtt() {
    _mqttService.stateStream.listen((state) {
      _connectionState = state;
      // Mất mạng lúc vừa chọn loại đất thì gửi lại khi kết nối xong
      if (state == AppMqttState.connected && _pendingSoilType != null) {
        _publishSoilType(_pendingSoilType!);
      }
      notifyListeners();
    });

    _mqttService.telemetryStream.listen((telemetry) {
      _currentTelemetry = telemetry;
      if (telemetry.soilType == _pendingSoilType) {
        _pendingSoilType = null;
      }
      _settlePendingSwitches(telemetry);
      _history.add(telemetry);
      if (_history.length > 30) {
        _history.removeAt(0);
      }
      // Chỉ lưu số đo thật từ trạm, không lưu dữ liệu nút Demo
      historyRepository.save(telemetry);
      notifyListeners();
    });

    // Tự động kết nối MQTT khi khởi tạo
    _mqttService.connect();
  }

  void selectSoilType(SoilType type) {
    if (type == selectedSoilType) return;
    _pendingSoilType = type;
    notifyListeners();
    _publishSoilType(type);
  }

  bool _publishSoilType(SoilType type) =>
      _mqttService.publishCommand({'action': 'SET_SOIL_TYPE', 'soil_type': type.code});

  /// Gửi lệnh bật/tắt rơ-le bơm hoặc van. Trả về false nếu chưa kết nối MQTT.
  bool setActuator(Actuator actuator, bool on) {
    final sent = _mqttService.publishCommand({'action': actuator.command, 'state': on});
    if (sent) {
      _pendingSwitches[actuator] = _PendingSwitch(on, DateTime.now());
      notifyListeners();
    }
    return sent;
  }

  static bool? _reportedState(SoilTelemetry telemetry, Actuator actuator) =>
      actuator == Actuator.pump ? telemetry.pump : telemetry.valve;

  // Trạm gửi số đo ngay sau khi nhận lệnh. Bản tin khớp lệnh thì xác nhận; quá [_switchConfirmWindow]
  // mà vẫn khác thì trạm đã từ chối hoặc tự ngắt (bơm khi đất quá ẩm), hiển thị theo trạm.
  // Không xóa ngay ở bản tin khác đầu tiên vì bản tin đó có thể được gửi trước lúc trạm nhận lệnh.
  static const Duration _switchConfirmWindow = Duration(seconds: 6);

  void _settlePendingSwitches(SoilTelemetry telemetry) {
    _pendingSwitches.removeWhere((actuator, pending) {
      final reported = _reportedState(telemetry, actuator);
      if (reported == null) return false;
      return reported == pending.state ||
          DateTime.now().difference(pending.sentAt) > _switchConfirmWindow;
    });
  }

  /// Yêu cầu trạm lấy ADC hiện tại làm mốc khô / ướt. Trả về false nếu chưa kết nối MQTT.
  bool calibrate(CalibrationPoint point) =>
      _mqttService.publishCommand({'action': 'CALIBRATE', 'point': point.code});

  void reconnect() {
    _mqttService.connect();
  }

  // Dùng để test mô phỏng dữ liệu khi cần
  void simulateRandomReading() {
    _currentTelemetry = SoilTelemetry(
      nitrogen: (40 + (DateTime.now().second % 40)).toDouble(),
      phosphorus: (20 + (DateTime.now().second % 35)).toDouble(),
      potassium: (70 + (DateTime.now().second % 60)).toDouble(),
      ph: (5.2 + ((DateTime.now().second % 20) / 10)).toDouble(),
      ec: (400 + (DateTime.now().second * 15)).toDouble(),
      moisture: (45 + (DateTime.now().second % 30)).toDouble(),
      temperature: (25 + ((DateTime.now().second % 50) / 10)).toDouble(),
      timestamp: DateTime.now(),
      soilType: _currentTelemetry.soilType,
      pump: _currentTelemetry.pump,
      valve: _currentTelemetry.valve,
    );
    _history.add(_currentTelemetry);
    if (_history.length > 30) {
      _history.removeAt(0);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _mqttService.dispose();
    historyRepository.close();
    super.dispose();
  }
}

/// Rơ-le trên trạm điều khiển được từ App, [command] khớp tên lệnh trong firmware
enum Actuator {
  pump('SET_PUMP'),
  valve('SET_VALVE');

  const Actuator(this.command);
  final String command;
}

class _PendingSwitch {
  final bool state;
  final DateTime sentAt;

  const _PendingSwitch(this.state, this.sentAt);
}
