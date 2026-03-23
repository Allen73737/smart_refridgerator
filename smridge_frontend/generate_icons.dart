import 'dart:io';
import 'package:image/image.dart';

void main() async {
  final warningSrc = 'assets/images/smridge_logo_warning.png';
  final dangerSrc = 'assets/images/smridge_logo_danger.png';

  final androidIconNames = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  await generateIcons(warningSrc, 'launcher_icon_warning', androidIconNames);
  await generateIcons(dangerSrc, 'launcher_icon_danger', androidIconNames);

  print('Icon generation complete!');
}

Future<void> generateIcons(String srcPath, String baseName, Map<String, int> resolutions) async {
  final image = decodeImage(File(srcPath).readAsBytesSync())!;

  // Android
  for (var entry in resolutions.entries) {
    final res = entry.value;
    final dir = Directory('android/app/src/main/res/${entry.key}');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    
    final resized = copyResize(image, width: res, height: res);
    File('${dir.path}/$baseName.png').writeAsBytesSync(encodePng(resized));
    print('Generated Android icon: ${dir.path}/$baseName.png');
  }

  // iOS (Simpler for Alternate Icons, usually just high-res versions with @2x, @3x)
  final iosDir = Directory('ios/Runner/AlternateIcons');
  if (!iosDir.existsSync()) iosDir.createSync(recursive: true);
  
  final res2x = copyResize(image, width: 120, height: 120);
  final res3x = copyResize(image, width: 180, height: 180);
  
  File('${iosDir.path}/$baseName@2x.png').writeAsBytesSync(encodePng(res2x));
  File('${iosDir.path}/$baseName@3x.png').writeAsBytesSync(encodePng(res3x));
  print('Generated iOS icons in ${iosDir.path}');
}
