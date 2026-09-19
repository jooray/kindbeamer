import 'dart:io';

import 'api.dart' as api;
import 'models.dart';
import 'signer.dart';

class StkClient {
  StkClient(this.deviceInfo) : signer = AdpSigner.fromDeviceInfo(deviceInfo);

  final DeviceInfo deviceInfo;
  final AdpSigner signer;

  String get accountName =>
      deviceInfo.name.isEmpty ? deviceInfo.userDeviceName : deviceInfo.name;

  Future<List<OwnedDevice>> getOwnedDevices() => api.getOwnedDevices(signer);

  Future<String> sendFile(
    File file,
    List<String> targetDeviceSerialNumbers, {
    required String author,
    required String title,
    required String format,
    required bool archive,
    void Function(int sent, int total)? onProgress,
  }) async {
    final length = await file.length();
    final upload = await api.getUploadUrl(signer, length);
    await api.uploadFile(
      upload.uploadUrl,
      file,
      length: length,
      onProgress: onProgress,
    );
    final res = await api.sendToKindle(
      signer,
      stkToken: upload.stkToken,
      targetDeviceSerialNumbers: targetDeviceSerialNumbers,
      author: author,
      title: title,
      format: format,
      archive: archive,
    );
    return res.sku;
  }

  Future<void> logout() => api.logout(signer);

  Map<String, dynamic> toMap() => {
    'version': 1,
    'device_info': deviceInfo.toMap(),
  };

  static StkClient fromMap(Map<String, dynamic> m) {
    if (m['version'] != 1) {
      throw const FormatException('invalid credentials version');
    }
    return StkClient(
      DeviceInfo.fromMap((m['device_info'] as Map).cast<String, dynamic>()),
    );
  }
}
