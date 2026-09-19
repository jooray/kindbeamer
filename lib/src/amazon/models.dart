class DeviceInfo {
  const DeviceInfo({
    required this.devicePrivateKey,
    required this.adpToken,
    required this.deviceType,
    required this.givenName,
    required this.name,
    required this.accountPool,
    required this.userDirectedId,
    required this.userDeviceName,
    this.homeRegion,
  });

  final String devicePrivateKey;
  final String adpToken;
  final String deviceType;
  final String givenName;
  final String name;
  final String accountPool;
  final String userDirectedId;
  final String userDeviceName;
  final String? homeRegion;

  static DeviceInfo fromMap(Map<String, dynamic> d) => DeviceInfo(
        devicePrivateKey: d['device_private_key'] as String,
        adpToken: d['adp_token'] as String,
        deviceType: d['device_type'] as String,
        givenName: d['given_name'] as String? ?? '',
        name: d['name'] as String? ?? '',
        accountPool: d['account_pool'] as String? ?? 'Amazon',
        userDirectedId: d['user_directed_id'] as String? ?? '',
        userDeviceName: d['user_device_name'] as String? ?? '',
        homeRegion: d['home_region'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'device_private_key': devicePrivateKey,
        'adp_token': adpToken,
        'device_type': deviceType,
        'given_name': givenName,
        'name': name,
        'account_pool': accountPool,
        'user_directed_id': userDirectedId,
        'user_device_name': userDeviceName,
        'home_region': homeRegion,
      };
}

class OwnedDevice {
  const OwnedDevice({
    required this.deviceCapabilities,
    required this.deviceName,
    required this.deviceSerialNumber,
  });

  final Map<String, dynamic> deviceCapabilities;
  final String deviceName;
  final String deviceSerialNumber;

  static OwnedDevice fromMap(Map<String, dynamic> d) => OwnedDevice(
        deviceCapabilities:
            (d['deviceCapabilities'] as Map<String, dynamic>?) ?? const {},
        deviceName: d['deviceName'] as String? ?? '',
        deviceSerialNumber: d['deviceSerialNumber'] as String? ?? '',
      );
}

class UploadUrlResponse {
  const UploadUrlResponse({
    required this.expiryTime,
    required this.statusCode,
    required this.stkToken,
    required this.uploadUrl,
  });

  final int expiryTime;
  final int statusCode;
  final String stkToken;
  final String uploadUrl;

  static UploadUrlResponse fromMap(Map<String, dynamic> d) =>
      UploadUrlResponse(
        expiryTime: d['expiryTime'] as int? ?? 0,
        statusCode: d['statusCode'] as int? ?? -1,
        stkToken: d['stkToken'] as String,
        uploadUrl: d['uploadUrl'] as String,
      );
}

class SendToKindleResponse {
  const SendToKindleResponse({required this.sku, required this.statusCode});

  final String sku;
  final int statusCode;

  static SendToKindleResponse fromMap(Map<String, dynamic> d) =>
      SendToKindleResponse(
        sku: d['sku'] as String? ?? '',
        statusCode: d['statusCode'] as int? ?? -1,
      );
}

class ApiError implements Exception {
  ApiError(this.message, [this.body]);

  final String message;
  final String? body;

  @override
  String toString() =>
      body == null || body!.isEmpty ? message : '$message $body';
}
