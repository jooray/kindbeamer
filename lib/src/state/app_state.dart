import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../amazon/client.dart';
import '../convert/markdown.dart';
import '../amazon/models.dart';
import '../amazon/oauth.dart';
import '../platform/intake.dart';
import 'credentials_store.dart';
import 'documents.dart';

enum SendPhase { idle, sending, done, error }

class AppState extends ChangeNotifier {
  AppState({
    required this.supportDir,
    required CredentialsStore store,
    StkClient? client,
    MarkdownConversionFn? convertMarkdown,
  }) : _store = store,
       _client = client,
       _convertMarkdown = convertMarkdown ?? MarkdownConverter.convert;

  final Directory supportDir;
  final CredentialsStore _store;

  /// Injectable so tests need not depend on the machine's toolchain.
  final MarkdownConversionFn _convertMarkdown;

  CredentialsBackend get credentialsBackend => _store.backend;
  StkClient? _client;

  List<OwnedDevice> devices = [];
  Set<String> selectedSerials = {};
  bool archive = true;

  final List<DocItem> docs = [];
  int selectedIndex = -1;

  SendPhase phase = SendPhase.idle;
  String statusMessage = '';
  String? notice;

  OAuth2? _pendingOAuth;

  StkClient? get client => _client;
  bool get signedIn => _client != null;
  String get accountName => _client?.accountName ?? '';

  DocItem? get selectedDoc => selectedIndex >= 0 && selectedIndex < docs.length
      ? docs[selectedIndex]
      : null;

  bool get converting => docs.any((d) => d.converting);

  bool get canSend =>
      signedIn &&
      docs.isNotEmpty &&
      selectedSerials.isNotEmpty &&
      phase != SendPhase.sending &&
      !converting &&
      !docs.any((d) => d.needsConversion);

  File get _prefsFile => File(p.join(supportDir.path, 'settings.json'));

  Future<void> loadPrefs() async {
    try {
      if (await _prefsFile.exists()) {
        final m =
            json.decode(await _prefsFile.readAsString())
                as Map<String, dynamic>;
        selectedSerials = ((m['selected'] as List?) ?? [])
            .cast<String>()
            .toSet();
        archive = m['archive'] as bool? ?? true;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _savePrefs() async {
    try {
      await supportDir.create(recursive: true);
      await _prefsFile.writeAsString(
        json.encode({'selected': selectedSerials.toList(), 'archive': archive}),
      );
    } catch (_) {}
  }

  void addFiles(List<String> paths) {
    final items = Ingest.itemsFor(paths);
    final skipped = Ingest.unsupported(paths).length;
    if (items.isEmpty) {
      if (paths.isNotEmpty) {
        notice =
            'Unsupported file type. Drop PDF, EPUB or other Kindle documents.';
        notifyListeners();
      }
      return;
    }
    for (final item in items) {
      if (docs.any((d) => d.path == item.path)) continue;
      docs.add(item);
    }
    if (skipped > 0) {
      notice = skipped == 1
          ? 'Skipped 1 file with an unsupported format.'
          : 'Skipped $skipped files with unsupported formats.';
    }
    if (selectedIndex < 0) selectedIndex = 0;
    if (phase != SendPhase.sending) {
      phase = SendPhase.idle;
      statusMessage = '';
    }
    notifyListeners();
    unawaited(_convertPending());
  }

  /// Markdown has no input format on the service, so it is turned into a PDF
  /// (or HTML, where no converter exists) as soon as it lands in the queue —
  /// that way the format banner and the size shown are the ones really sent.
  Future<void> _convertPending() async {
    for (final doc in docs) {
      if (!doc.needsConversion || doc.converting) continue;
      doc.converting = true;
      notifyListeners();
      try {
        final result = await _convertMarkdown(File(doc.path), supportDir);
        doc.uploadPath = result.path;
        doc.format = result.format;
        doc.size = await File(result.path).length();
        doc.conversionNote = result.note;
      } catch (e) {
        doc.conversionNote = 'could not convert: $e';
      } finally {
        doc.converting = false;
        notifyListeners();
      }
    }
  }

  void selectDoc(int i) {
    selectedIndex = i;
    notifyListeners();
  }

  void removeDoc(int i) {
    docs.removeAt(i);
    if (i < selectedIndex) selectedIndex--;
    if (selectedIndex >= docs.length) selectedIndex = docs.length - 1;
    notifyListeners();
  }

  void clearDocs() {
    docs.clear();
    selectedIndex = -1;
    phase = SendPhase.idle;
    statusMessage = '';
    notifyListeners();
  }

  void setArchive(bool v) {
    archive = v;
    _savePrefs();
    notifyListeners();
  }

  void toggleDevice(String serial, bool? on) {
    if (on ?? false) {
      selectedSerials.add(serial);
    } else {
      selectedSerials.remove(serial);
    }
    _savePrefs();
    notifyListeners();
  }

  void clearNotice() {
    notice = null;
    notifyListeners();
  }

  Future<void> refreshFromPlatform() async {
    final pending = await Intake.takeMacPending();
    if (pending.isNotEmpty) addFiles(pending);
  }

  String beginLogin() {
    _pendingOAuth = OAuth2();
    return _pendingOAuth!.signinUrl;
  }

  Future<bool> completeLogin(String redirectUrl) async {
    final oauth = _pendingOAuth;
    if (oauth == null) return false;
    try {
      final info = await oauth.complete(redirectUrl);
      _client = StkClient(info);
      await _store.save(_client!);
      await refreshDevices();
      notifyListeners();
      return true;
    } catch (e) {
      notice = 'Sign-in failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> restoreSession() async {
    _client = await _store.load();
    if (_client != null) {
      await refreshDevices();
    }
    notifyListeners();
  }

  Future<void> refreshDevices() async {
    final c = _client;
    if (c == null) return;
    try {
      devices = await c.getOwnedDevices();
      final known = devices.map((d) => d.deviceSerialNumber).toSet();
      selectedSerials.removeWhere((s) => !known.contains(s));
      if (selectedSerials.isEmpty && devices.isNotEmpty) {
        selectedSerials = {devices.first.deviceSerialNumber};
        _savePrefs();
      }
      statusMessage = '';
    } catch (e) {
      notice = 'Could not load devices: $e';
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    final c = _client;
    _client = null;
    devices = [];
    selectedSerials = {};
    await _store.clear();
    if (c != null) {
      try {
        await c.logout();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<bool> send() async {
    final c = _client;
    if (!canSend || c == null) return false;
    phase = SendPhase.sending;
    notifyListeners();
    final targets = selectedSerials.toList();
    var ok = true;
    for (var i = 0; i < docs.length; i++) {
      final doc = docs[i];
      statusMessage = 'Sending ${doc.name} (${i + 1}/${docs.length})…';
      notifyListeners();
      var lastPct = -1;
      try {
        await c.sendFile(
          File(doc.uploadPath),
          targets,
          author: doc.effectiveAuthor,
          title: doc.effectiveTitle,
          format: doc.format.inputFormat,
          archive: archive,
          onProgress: (sent, total) {
            if (total <= 0) return;
            final pct = (sent * 100 / total).clamp(0, 100).round();
            if (pct == lastPct) return;
            lastPct = pct;
            statusMessage =
                'Sending ${doc.name} (${i + 1}/${docs.length}) — $pct%';
            notifyListeners();
          },
        );
      } catch (e) {
        ok = false;
        phase = SendPhase.error;
        statusMessage = 'Failed: $e';
        notifyListeners();
        return false;
      }
    }
    phase = SendPhase.done;
    statusMessage = ok ? 'Sent ${docs.length} document(s).' : statusMessage;
    final sent = docs.length;
    docs.clear();
    selectedIndex = -1;
    statusMessage = 'Sent $sent document(s) to ${targets.length} device(s).';
    notifyListeners();
    return true;
  }
}
