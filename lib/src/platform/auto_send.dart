import 'dart:async';
import 'dart:io';

import '../amazon/models.dart';
import '../state/app_state.dart';

/// `--send`: deliver the files on the command line and quit, with no window to
/// answer. Everything else — the stored sign-in, the devices ticked last time,
/// the library copy — comes from the same state the window uses.
///
/// ```
/// KindBeamer --send [--all-devices | --device NAME ...] [--title T]
///            [--author A] [--original-pdf | --reformat-pdf] [--dry-run]
///            FILE...
/// ```
class SendRequest {
  const SendRequest({
    this.paths = const [],
    this.devices = const [],
    this.allDevices = false,
    this.title,
    this.author,
    this.pdfLayout,
    this.dryRun = false,
  });

  final List<String> paths;

  /// Device names or serials; empty means the devices ticked last time.
  final List<String> devices;
  final bool allDevices;
  final String? title;
  final String? author;

  /// How PDFs go out; null takes the layout chosen in the window last time.
  final PdfLayout? pdfLayout;

  /// Resolve the files and devices, then stop short of uploading.
  final bool dryRun;

  static const usage =
      'usage: KindBeamer --send [--all-devices | --device NAME ...] '
      '[--title TITLE] [--author AUTHOR] [--original-pdf | --reformat-pdf] '
      '[--dry-run] FILE...';

  /// The request in [args], or null when the launch is an ordinary one. Throws
  /// [FormatException] for a `--send` launch it cannot make sense of.
  static SendRequest? parse(List<String> args) {
    if (!args.contains('--send')) return null;
    final paths = <String>[];
    final devices = <String>[];
    var all = false;
    var dryRun = false;
    String? title;
    String? author;
    PdfLayout? layout;
    void setLayout(PdfLayout l) {
      if (layout != null && layout != l) {
        throw const FormatException(
          'use either --original-pdf or --reformat-pdf',
        );
      }
      layout = l;
    }

    String value(int i, String flag) {
      if (i >= args.length) throw FormatException('$flag needs a value');
      return args[i];
    }

    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      switch (a) {
        case '--send':
          break;
        case '--all-devices':
          all = true;
        case '--dry-run':
          dryRun = true;
        case '--original-pdf':
          setLayout(PdfLayout.original);
        case '--reformat-pdf':
          setLayout(PdfLayout.reformatted);
        case '--device':
          devices.add(value(++i, a));
        case '--title':
          title = value(++i, a);
        case '--author':
          author = value(++i, a);
        default:
          if (a.startsWith('--')) throw FormatException('unknown option $a');
          paths.add(a);
      }
    }
    if (all && devices.isNotEmpty) {
      throw const FormatException('use either --all-devices or --device');
    }
    if (title != null && paths.length > 1) {
      throw const FormatException('--title needs exactly one file');
    }
    return SendRequest(
      paths: paths,
      devices: devices,
      allDevices: all,
      title: title,
      author: author,
      pdfLayout: layout,
      dryRun: dryRun,
    );
  }

  /// Exit codes a script can branch on.
  static const ok = 0;
  static const failed = 1;
  static const badUsage = 2;
  static const notSignedIn = 3;

  /// Runs the request against [state], which has already restored the session
  /// and listed the devices, and returns the exit code. [awaitFiles] gives
  /// files that arrive after launch (macOS hands `open -a` documents over by
  /// Apple Event) a moment to land in the queue.
  Future<int> run(
    AppState state, {
    StringSink? out,
    StringSink? err,
    Future<void> Function()? awaitFiles,
  }) async {
    final o = out ?? stdout;
    final e = err ?? stderr;
    int fail(int code, String message) {
      e.writeln('KindBeamer: error: $message');
      return code;
    }

    if (!state.signedIn) {
      return fail(
        notSignedIn,
        'not signed in. Open KindBeamer and sign in first.',
      );
    }
    final trouble = state.deviceTrouble;
    if (trouble != null) {
      return fail(
        trouble.needsSignIn ? notSignedIn : failed,
        '${trouble.sentence} ${trouble.recovery}',
      );
    }

    final missing = paths.where((p) => !File(p).existsSync()).toList();
    if (missing.isNotEmpty) {
      return fail(failed, 'no such file: ${missing.join(', ')}');
    }
    if (state.docs.isEmpty && awaitFiles != null) await awaitFiles();
    if (state.docs.isEmpty) {
      return fail(
        badUsage,
        paths.isEmpty
            ? 'no file to send.\n$usage'
            : 'none of these is a format Kindle accepts: ${paths.join(', ')}',
      );
    }
    if (title != null && state.docs.length > 1) {
      return fail(badUsage, '--title needs exactly one file');
    }
    for (final doc in state.docs) {
      try {
        await File(doc.path).openRead(0, 1).drain<void>();
      } catch (_) {
        return fail(failed, 'cannot read ${doc.path}');
      }
    }

    final targets = _targets(state.devices, state.selectedSerials);
    if (targets is String) return fail(badUsage, targets);
    final chosen = targets as List<OwnedDevice>;
    state.selectedSerials = chosen.map((d) => d.deviceSerialNumber).toSet();
    // Like the devices, for this send only: the window keeps its own default.
    if (pdfLayout != null) state.pdfLayout = pdfLayout!;

    final doc = state.docs.first;
    if (title != null) doc.title = title!;
    if (author != null) {
      for (final d in state.docs) {
        d.author = author!;
      }
    }

    while (state.converting) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final unconverted = state.docs.where((d) => d.needsConversion).toList();
    if (unconverted.any((d) => d.uploadPath == d.path)) {
      return fail(
        failed,
        'could not convert ${unconverted.first.name}: '
        '${unconverted.first.conversionNote ?? 'no converter'}',
      );
    }

    final names = chosen.map((d) => d.deviceName).join(', ');
    final what = state.docs.length == 1
        ? '"${doc.effectiveTitle}"'
        : '${state.docs.length} documents';
    final layout = state.hasPdf
        ? ' (${state.pdfLayout == PdfLayout.original ? 'original PDF formatting' : 'PDF reformatted for Kindle'})'
        : '';
    if (dryRun) {
      o.writeln('KindBeamer: dry run, would send $what to $names$layout');
      return ok;
    }
    if (!await state.send()) {
      final t = state.sendTrouble;
      return fail(
        t != null && t.needsSignIn ? notSignedIn : failed,
        t == null ? 'the send did not start' : '${t.sentence} ${t.detail}',
      );
    }
    o.writeln('KindBeamer: sent $what to $names$layout');
    return ok;
  }

  /// The devices to deliver to, or a message saying why there are none.
  Object _targets(List<OwnedDevice> devices, Set<String> remembered) {
    if (devices.isEmpty) return 'no Kindle devices on this account';
    if (allDevices) return devices;
    if (this.devices.isEmpty) {
      final last = devices
          .where((d) => remembered.contains(d.deviceSerialNumber))
          .toList();
      return last.isEmpty ? [devices.first] : last;
    }
    final chosen = <OwnedDevice>[];
    for (final want in this.devices) {
      final w = want.toLowerCase();
      final match = devices.where(
        (d) => d.deviceSerialNumber == want || d.deviceName.toLowerCase() == w,
      );
      if (match.isEmpty) {
        final known = devices.map((d) => d.deviceName).join(', ');
        return 'no device named "$want". Devices: $known';
      }
      chosen.addAll(match.where((d) => !chosen.contains(d)));
    }
    return chosen;
  }
}
