import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Files handed to the app by the OS: CLI arguments, macOS Services / "Open
/// With" / dock drops, Android share sheet and "Open with".
class Intake {
  static const _macChannel = MethodChannel('dev.stkn.kindbeamer/intake');
  static StreamSubscription<List<SharedMediaFile>>? _sub;

  static Future<List<String>> initial(List<String> args) async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final media = await ReceiveSharingIntent.instance.getInitialMedia();
        ReceiveSharingIntent.instance.reset();
        return media.map((m) => m.path).toList();
      } catch (_) {
        return const [];
      }
    }
    if (Platform.isMacOS) {
      // Files opened before the engine was ready are waiting in the native queue.
      return [...args, ...await takeMacPending()];
    }
    return args;
  }

  static void listen(void Function(List<String> paths) onFiles) {
    if (Platform.isAndroid || Platform.isIOS) {
      _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (media) => onFiles(media.map((m) => m.path).toList()),
        onError: (_) {},
      );
      return;
    }
    if (Platform.isMacOS) {
      _macChannel.setMethodCallHandler((call) async {
        if (call.method == 'filesAvailable') {
          final paths = await takeMacPending();
          if (paths.isNotEmpty) onFiles(paths);
        }
        return null;
      });
    }
  }

  static Future<List<String>> takeMacPending() async {
    if (!Platform.isMacOS) return const [];
    try {
      final res = await _macChannel.invokeMethod<List>('takePendingFiles');
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
