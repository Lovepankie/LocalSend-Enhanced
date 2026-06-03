import 'dart:io';

import 'package:localsend_app/service/wifi_direct_service.dart';
import 'package:localsend_app/service/platform/android_wifi_direct_service.dart';
import 'package:localsend_app/service/platform/ios_wifi_direct_service.dart';
import 'package:localsend_app/service/platform/desktop_wifi_direct_service.dart';
import 'package:localsend_app/service/platform/unsupported_wifi_direct_service.dart';

WifiDirectService createWifiDirectService() {
  if (Platform.isAndroid) return AndroidWifiDirectService();
  if (Platform.isIOS) return IosWifiDirectService();
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    return DesktopWifiDirectService();
  }
  return UnsupportedWifiDirectService();
}
