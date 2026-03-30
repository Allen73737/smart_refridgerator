import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_service.dart';
import 'secure_storage_service.dart';

class SocketService {
  static IO.Socket? _socket;
  static String? _currentUrl;
  
  // 📚 Listener Registry: Keeps track of event handlers to re-apply them on reconnect/re-init
  static final Map<String, List<Function(dynamic)>> _registry = {};

  static void init() {
    String url = ApiService.baseDomain;

    // 🔹 If URL changed, disconnect old socket and re-init
    if (_socket != null && _currentUrl == url) return;
    
    if (_socket != null) {
      print('🔌 URL Changed! Reconnecting socket to: $url');
      _socket!.dispose();
      _socket = null;
    }

    // 🔹 Robust Sanitization using Uri
    Uri uri = Uri.parse(url.trim());
    
    // Remove port 0 or default ports to avoid library confusion
    if (uri.port == 0 || (uri.scheme == 'https' && uri.port == 443) || (uri.scheme == 'http' && uri.port == 80)) {
      uri = uri.replace(port: null);
    }
    
    String sanitizedUrl = uri.toString();
    if (sanitizedUrl.endsWith('/')) {
      sanitizedUrl = sanitizedUrl.substring(0, sanitizedUrl.length - 1);
    }
    
    _currentUrl = sanitizedUrl;
    print('🔌 Connecting to Socket: $sanitizedUrl');

    _socket = IO.io(sanitizedUrl, <String, dynamic>{
      'transports': ['websocket', 'polling'],
      'autoConnect': true,
      'forceNew': true,
    });

    // 💡 RE-APPLY REGISTERED LISTENERS
    _registry.forEach((event, handlers) {
      for (var handler in handlers) {
        _socket!.on(event, handler);
      }
    });

    _socket!.onConnect((_) async {
      print('⚡ Socket connected: ${_socket!.id}');
      // 🔑 Register user ID so backend can send targeted events
      final userId = await SecureStorageService.getUserId();
      if (userId != null) {
        _socket!.emit('register', userId);
        print('🔑 Registered socket room for user: $userId');
      }
    });

    _socket!.onDisconnect((_) {
      print('🔌 Socket disconnected');
    });

    _socket!.onReconnectAttempt((_) {
      print('🔄 Socket Reconnecting attempt to: $url');
    });

    _socket!.onReconnect((_) {
      print('✅ Socket Reconnected successfully!');
    });

    _socket!.onConnectError((err) {
      print('❌ Socket Connect Error: $err');
    });

    // 🔹 Listen for future backend switches automatically
    ApiService.currentBaseUrl.removeListener(_onUrlChange);
    ApiService.currentBaseUrl.addListener(_onUrlChange);
  }

  static void _onUrlChange() {
    print("🌍 SocketService: Backend URL changed to ${ApiService.baseDomain}. Re-initializing...");
    init();
  }

  static void on(String event, Function(dynamic) handler) {
    if (_socket == null) init();
    
    // 1. Add to local registry
    _registry.putIfAbsent(event, () => []).add(handler);
    
    // 2. Add to active socket
    _socket?.on(event, handler);
  }

  static void off(String event, [Function(dynamic)? handler]) {
    if (handler != null) {
      _registry[event]?.remove(handler);
      _socket?.off(event, handler);
    } else {
      _registry.remove(event);
      _socket?.off(event);
    }
  }

  static void disconnect() {
    ApiService.currentBaseUrl.removeListener(_onUrlChange);
    _socket?.disconnect();
    _socket = null;
    _currentUrl = null;
    _registry.clear();
  }
}
