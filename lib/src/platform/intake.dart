import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Files handed to the app by the OS: CLI arguments, macOS Services / "Open
/// With" / dock drops, Android share sheet, "Open with" and the KindBeamer
/// printer.
///
/// macOS and the Android print service share one native queue: native only
/// queues and nudges with `filesAvailable`, and Dart drains it with
/// `takePendingFiles`.
class Intake {
  static const _channel = MethodChannel('dev.stkn.kindbeamer/intake');
  static StreamSubscription<List<SharedMediaFile>>? _sub;

  static Future<List<String>> initial(List<String> args) async {
    if (Platform.isAndroid || Platform.isIOS) {
      List<String> shared;
      try {
        final media = await ReceiveSharingIntent.instance.getInitialMedia();
        ReceiveSharingIntent.instance.reset();
        shared = media.map((m) => m.path).toList();
      } catch (_) {
        shared = const [];
      }
      return [...shared, ...await takePending()];
    }
    if (Platform.isMacOS) {
      // Files opened before the engine was ready are waiting in the native queue.
      return [...args, ...await takePending()];
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
    if (Platform.isMacOS || Platform.isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'filesAvailable') {
          final paths = await takePending();
          if (paths.isNotEmpty) onFiles(paths);
        }
        return null;
      });
    }
  }

  static Future<List<String>> takePending() async {
    if (!Platform.isMacOS && !Platform.isAndroid) return const [];
    try {
      final res = await _channel.invokeMethod<List>('takePendingFiles');
      return (res ?? []).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  /// Opens the system print settings, where the KindBeamer printer is turned
  /// on (Android). False where there is no such screen.
  static Future<bool> openPrintSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openPrintSettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
