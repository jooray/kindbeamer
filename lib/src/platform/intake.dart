import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class Intake {
  static const _servicesChannel = MethodChannel('dev.stkn/services');
  static StreamSubscription<List<SharedMediaFile>>? _sub;

  static Future<List<String>> initial(List<String> args) async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final media = await ReceiveSharingIntent.instance.getInitialMedia();
        return media.map((m) => m.path).toList();
      } catch (_) {
        return const [];
      }
    }
    return args;
  }

  static void listen(void Function(List<String> paths) onFiles) {
    if (Platform.isAndroid || Platform.isIOS) {
      _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (media) => onFiles(media.map((m) => m.path).toList()),
        onError: (_) {},
      );
    }
  }

  static Future<List<String>> takeMacPending() async {
    if (!Platform.isMacOS) return const [];
    try {
      final res = await _servicesChannel.invokeMethod<List>('takePendingFiles');
      return (res ?? []).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
