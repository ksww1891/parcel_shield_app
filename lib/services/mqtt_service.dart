import 'dart:convert';
import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter/foundation.dart';

class MqttService {
  final String broker = '8170eaccdd7f45dcb2c9abf3f3903959.s1.eu.hivemq.cloud'; 
  final int port = 8883; 
  final String username = 'application'; 
  final String password = 'Qwer1234';
  final String deviceId = 'device_001';
  
  late MqttServerClient client;
  
  // 라즈베리파이로부터 받는 실시간 상태 데이터를 전달할 스트림
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  Future<bool> connect() async {
    client = MqttServerClient.withPort(broker, 'flutter_app_${DateTime.now().millisecondsSinceEpoch}', port);
    client.secure = true;
    client.logging(on: false);
    client.keepAlivePeriod = 60;

    final connMessage = MqttConnectMessage()
        .authenticateAs(username, password)
        .startClean();
    client.connectionMessage = connMessage;

    try { 
      await client.connect();
    } catch (e) {
      debugPrint('MQTT 연결 실패: $e');
      client.disconnect();
      return false;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      debugPrint('HiveMQ 브로커 연결 성공! 🚀');
      
      // 상우님이 지정하신 status 토픽 구독
      final String statusTopic = 'parcelshield/$deviceId/status';
      client.subscribe(statusTopic, MqttQos.atLeastOnce);
      
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        
        try {
          final Map<String, dynamic> data = jsonDecode(pt);
          final statusKey = '${deviceId}_status';
          
          if (data.containsKey(statusKey)) {
            _statusController.add(data[statusKey]);
          }
        } catch (e) {
          debugPrint('JSON 파싱 에러: $e');
        }
      });
      return true;
    }
    return false;
  }

  // 잠금/해제 명령 발행 메서드
  void publishLock(bool isLocked) {
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('MQTT 연결이 되어있지 않습니다.');
      return;
    }

    final String commandTopic = 'parcelshield/$deviceId/command';
    late Map<String, dynamic> payloadMap;

    if(isLocked){
      payloadMap = {
        "${deviceId}_command": {
          "command": "Lock",
        }
      };
    }else {
      payloadMap = {
        "${deviceId}_command": {
          "command": "Unlock",
          "duration": 30 // 잠금 해제 후 30초 뒤에 자동으로 다시 잠금 명령이 발행되도록 duration 필드 추가
        }
      };
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payloadMap));
    client.publishMessage(commandTopic, MqttQos.atLeastOnce, builder.payload!);
    debugPrint('[$commandTopic] 변경 명령 발행 완료: ${isLocked ? 'Lock' : 'Unlock'}');
  }
  
  void dispose() {
    _statusController.close();
    client.disconnect();
  }
}