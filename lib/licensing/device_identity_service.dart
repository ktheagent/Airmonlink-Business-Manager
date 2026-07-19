import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class DeviceIdentityService {
  DeviceIdentityService({DeviceInfoPlugin? plugin})
    : _plugin = plugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _plugin;

  Future<String> getDeviceIdentifier() async {
    switch (Platform.operatingSystem) {
      case 'windows':
        final info = await _plugin.windowsInfo;
        return info.deviceId;
      case 'android':
        final info = await _plugin.androidInfo;
        return info.id;
      case 'ios':
        final info = await _plugin.iosInfo;
        return info.identifierForVendor ?? 'ios-device';
      default:
        return 'desktop-device';
    }
  }
}
