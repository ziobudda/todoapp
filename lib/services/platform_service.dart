import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PlatformService {
  static Future<bool> checkStoragePermission() async {
    // Su desktop non serve il check dei permessi
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return true;
    }

    // Su mobile (Android/iOS) verifica i permessi
    if (Platform.isAndroid) {
      return await Permission.storage.request().isGranted;
    }

    if (Platform.isIOS) {
      // iOS gestisce i permessi tramite il file picker
      return true;
    }

    return false;
  }
}
