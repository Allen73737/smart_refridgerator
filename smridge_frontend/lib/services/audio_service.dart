import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioPlayer _logoRevealPlayer = AudioPlayer();
  static final AudioPlayer _doorOpenPlayer = AudioPlayer();
  static final AudioPlayer _fridgeHumPlayer = AudioPlayer();
  static final AudioPlayer _successPlayer = AudioPlayer();
  static final AudioPlayer _notificationPlayer = AudioPlayer();

  static Future<void> playLogoReveal() async {
    await _logoRevealPlayer.setReleaseMode(ReleaseMode.release);
    await _logoRevealPlayer.play(AssetSource('audio/logo_reveal.wav'));
  }

  static Future<void> stopLogoReveal() async {
    await _logoRevealPlayer.stop();
  }

  static Future<void> playDoorOpen({int index = 0, String? customPath}) async {
    if (index == -1) return;
    await _doorOpenPlayer.setReleaseMode(ReleaseMode.release);
    
    try {
      if (index == 99 && customPath != null && customPath.isNotEmpty) {
        await _doorOpenPlayer.play(DeviceFileSource(customPath));
        return;
      }
      String soundFile = index == 0 ? 'door_open.wav' : 'door_open_$index.wav';
      await _doorOpenPlayer.play(AssetSource('audio/$soundFile'));
    } catch (_) {
      await _doorOpenPlayer.play(AssetSource('audio/door_open.wav'));
    }
  }

  static Future<void> playFridgeHum({int index = 0, String? customPath}) async {
    if (index == -1) return;
    await _fridgeHumPlayer.setReleaseMode(ReleaseMode.loop);
    
    try {
      if (index == 99 && customPath != null && customPath.isNotEmpty) {
        await _fridgeHumPlayer.play(DeviceFileSource(customPath), volume: 0.3);
        return;
      }
      String soundFile = index == 0 ? 'fridge_hum.wav' : 'fridge_hum_$index.wav';
      await _fridgeHumPlayer.play(AssetSource('audio/$soundFile'), volume: 0.3);
    } catch (_) {
      await _fridgeHumPlayer.play(AssetSource('audio/fridge_hum.wav'), volume: 0.3);
    }
  }
  
  static Future<void> stopFridgeHum() async {
    await _fridgeHumPlayer.stop();
  }

  static Future<void> playSuccess({int index = 0, String? customPath}) async {
    if (index == -1) return;
    await _successPlayer.setReleaseMode(ReleaseMode.release);
    
    try {
      if (index == 99 && customPath != null && customPath.isNotEmpty) {
        await _successPlayer.play(DeviceFileSource(customPath));
        return;
      }
      String soundFile = index == 0 ? 'success.ogg' : 'success_$index.ogg';
      await _successPlayer.play(AssetSource('audio/$soundFile'));
    } catch (_) {
      await _successPlayer.play(AssetSource('audio/success.ogg'));
    }
  }

  static Future<void> playNotification({int index = 0, String? customPath}) async {
    if (index == -1) return;
    await _notificationPlayer.setReleaseMode(ReleaseMode.release);
    
    try {
      if (index == 99 && customPath != null && customPath.isNotEmpty) {
        await _notificationPlayer.play(DeviceFileSource(customPath), volume: 0.6);
        return;
      }
      String soundFile = index == 0 ? 'notification.ogg' : 'notification_$index.ogg';
      await _notificationPlayer.play(AssetSource('audio/$soundFile'), volume: 0.6);
    } catch (_) {
      await _notificationPlayer.play(AssetSource('audio/notification.ogg'), volume: 0.6);
    }
  }

  static void dispose() {
    _logoRevealPlayer.dispose();
    _doorOpenPlayer.dispose();
    _fridgeHumPlayer.dispose();
    _successPlayer.dispose();
    _notificationPlayer.dispose();
  }
}
