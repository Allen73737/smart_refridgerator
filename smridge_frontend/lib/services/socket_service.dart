import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_service.dart';

class SocketService {
  static IO.Socket? _socket;

  static void init() {
    if (_socket != null) return;

    String url = ApiService.baseDomain;
    print('🔌 Connecting to Socket: $url');

    _socket = IO.io(url, IO.OptionBuilder()
      .setTransports(['websocket'])
      .enableAutoConnect()
      .build());

    _socket!.onConnect((_) {
      print('⚡ Socket connected: ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      print('🔌 Socket disconnected');
    });

    _socket!.onConnectError((err) {
      print('❌ Socket Connect Error: $err');
    });
  }

  static void on(String event, Function(dynamic) handler) {
    if (_socket == null) init();
    _socket!.on(event, handler);
  }

  static void off(String event, [Function(dynamic)? handler]) {
    if (handler != null) {
      _socket?.off(event, handler);
    } else {
      _socket?.off(event);
    }
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
