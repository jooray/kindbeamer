import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../state/app_state.dart';
import '../state/documents.dart';
import 'label_parts.dart';
import 'login_dialog.dart';
import 'settings_dialog.dart';
import 'theme.dart';

/// The window is one dispatch label: contents, description, addressees,
/// endorsement, franking. It opens already filled in, and the whole task is to
/// press the stamp down.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.state,
    this.onRequestClose,
    this.openOverlay,
  });

  final AppState state;

  /// Opens one of the states a screenshot cannot reach by itself — `drop`,
  /// `keys` or `settings`. Set only by the harness in `tool/demo_main.dart`.
  final String? openOverlay;

  /// How the app closes itself — after a delivery, or on an Escape with an
  /// empty queue. Injectable so a test need not shut down the test harness.
  final Future<void> Function()? onRequestClose;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool _dragging = false;
  bool _keysOpen = false;

  final TextEditingController _title = TextEditingController();
  final TextEditingController _author = TextEditingController();
  final FocusNode _titleFocus = FocusNode(debugLabel: 'title');
  final FocusNode _authorFocus = FocusNode(debugLabel: 'author');
  final FocusNode _root = FocusNode(debugLabel: 'label');
  String? _boundTo;

  /// True while the label runs past the bottom of the window, so the page can
  /// print that it continues rather than letting a row end in mid-air.
  bool _moreBelow = false;
  final ScrollController _queueScroll = ScrollController();

  SendPhase _lastPhase = SendPhase.idle;
  Timer? _closeTimer;
  Timer? _noticeTimer;

  AppState get state => widget.state;

  bool get _typing => _titleFocus.hasFocus || _authorFocus.hasFocus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastPhase = state.phase;
    state.addListener(_onStateChanged);
    // The ruled line under a field inks itself when the field is being typed
    // into, so the page has to rebuild when focus moves.
    _titleFocus.addListener(_onFocusChanged);
    _authorFocus.addListener(_onFocusChanged);
    switch (widget.openOverlay) {
      case 'drop':
        _dragging = true;
      case 'keys':
        _keysOpen = true;
      case 'settings':
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => showSettingsDialog(context, state),
        );
    }
  }

  @override
  void dispose() {
    state.removeListener(_onStateChanged);
    _titleFocus.removeListener(_onFocusChanged);
    _authorFocus.removeListener(_onFocusChanged);
    _closeTimer?.cancel();
    _noticeTimer?.cancel();
    _titleFocus.dispose();
    _authorFocus.dispose();
    _root.dispose();
    _title.dispose();
    _author.dispose();
    _queueScroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      state.refreshFromPlatform();
    }
  }

  /// A delivered send takes the window with it, unless Settings says otherwise.
  /// The delay is there so the postmark is seen to land.
  void _onStateChanged() {
    if (state.phase != SendPhase.done) _closeTimer?.cancel();
    if (state.phase == SendPhase.done &&
        _lastPhase != SendPhase.done &&
        state.closeOnSuccess) {
      _closeTimer?.cancel();
      _closeTimer = Timer(const Duration(milliseconds: 1250), () async {
        if (!mounted) return;
        if (state.phase == SendPhase.done && state.docs.isEmpty) {
          await (widget.onRequestClose ?? _closeApp)();
        }
      });
    }
    if (state.notice != null) {
      _noticeTimer?.cancel();
      _noticeTimer = Timer(const Duration(seconds: 8), () {
        if (mounted && state.notice != null) state.clearNotice();
      });
    }
    _lastPhase = state.phase;
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  bool _noteOverflow(Notification n) {
    final more = n is ScrollMetricsNotification
        ? n.metrics.extentAfter > 1
        : n is ScrollUpdateNotification
        ? n.metrics.extentAfter > 1
        : _moreBelow;
    if (more != _moreBelow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && more != _moreBelow) setState(() => _moreBelow = more);
      });
    }
    return false;
  }

  void _syncControllers() {
    final doc = state.selectedDoc;
    if (_boundTo != doc?.path) {
      _boundTo = doc?.path;
      _title.text = doc?.title ?? '';
      _author.text = doc?.author ?? '';
    }
  }

  Future<void> _closeApp() async {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      await windowManager.close();
    } else {
      await SystemNavigator.pop();
    }
  }

  /// Escape empties the queue, and closes the window when there is nothing
  /// left to empty.
  Future<void> _cancel() async {
    if (state.docs.isNotEmpty) {
      state.clearDocs();
      return;
    }
    await (widget.onRequestClose ?? _closeApp)();
  }

  Future<void> _browse() async {
    final files = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(
          label: 'Kindle documents',
          extensions: DocFormat.supported.map((f) => f.extension).toList(),
        ),
      ],
    );
    state.addFiles(files.map((f) => f.path).toList());
  }

  void _send() {
    if (state.canSend) {
      state.send();
      return;
    }
    if (!state.signedIn) showLoginDialog(context, state);
  }

  void _toggleLane(int index) {
    if (index >= state.devices.length) return;
    final serial = state.devices[index].deviceSerialNumber;
    state.toggleDevice(serial, !state.selectedSerials.contains(serial));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (_keysOpen) {
      setState(() => _keysOpen = false);
      return KeyEventResult.handled;
    }

    final mod = Platform.isMacOS
        ? HardwareKeyboard.instance.isMetaPressed
        : HardwareKeyboard.instance.isControlPressed;
    if (mod) {
      if (key == LogicalKeyboardKey.keyO) {
        _browse();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.comma) {
        showSettingsDialog(context, state);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (state.phase != SendPhase.sending) _send();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_typing) {
        _root.requestFocus();
        return KeyEventResult.handled;
      }
      _cancel();
      return KeyEventResult.handled;
    }
    if (_typing) return KeyEventResult.ignored;

    // The key's own label, not the character it produced: a digit is a lane
    // number whatever the layout puts on that key with a modifier held.
    final label = key.keyLabel;
    if (label.length == 1) {
      final digit = int.tryParse(label);
      if (digit != null) {
        _toggleLane(digit == 0 ? 9 : digit - 1);
        return KeyEventResult.handled;
      }
      switch (label.toUpperCase()) {
        case 'A':
          state.setAllDevices(
            state.selectedSerials.length != state.devices.length,
          );
          return KeyEventResult.handled;
        case 'E':
          state.setArchive(!state.archive);
          return KeyEventResult.handled;
      }
    }
    if (event.character == '?') {
      setState(() => _keysOpen = true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      if (state.selectedIndex >= 0) state.removeDoc(state.selectedIndex);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = Ink0.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _syncControllers());
        return Scaffold(
          backgroundColor: c.ground,
          body: SafeArea(
            child: Focus(
              focusNode: _root,
              autofocus: true,
              onKeyEvent: _onKey,
              child: DropTarget(
                onDragEntered: (_) => setState(() => _dragging = true),
                onDragExited: (_) => setState(() => _dragging = false),
                onDragDone: (details) {
                  setState(() => _dragging = false);
                  state.addFiles(details.files.map((f) => f.path).toList());
                },
                // The overlays turn the label over between its own edges: the
                // barred border never leaves the window.
                child: Column(
                  children: [
                    const BarredEdge(),
                    Expanded(
                      child: Stack(
                        children: [
                          _label(c),
                          if (_dragging) _overlay(c, _dropSheet(c)),
                          if (_keysOpen) _overlay(c, _keySheet(c)),
                        ],
                      ),
                    ),
                    const BarredEdge(flip: true),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _label(Ink0 c) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Metrics.labelMaxWidth),
        child: Column(
          children: [
            _header(c),
            const Rule(strong: true),
            Expanded(
              child: Stack(
                children: [
                  NotificationListener<ScrollMetricsNotification>(
                    onNotification: _noteOverflow,
                    child: NotificationListener<ScrollUpdateNotification>(
                      onNotification: _noteOverflow,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          Metrics.gutter,
                          14,
                          Metrics.gutter,
                          14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Legend(letter: 'A', name: 'CONTENTS'),
                            _contents(c),
                            const SizedBox(height: Metrics.sectionGap),
                            const Legend(letter: 'B', name: 'DESCRIPTION'),
                            _description(c),
                            const SizedBox(height: Metrics.sectionGap),
                            _deliverTo(c),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_moreBelow)
                    Positioned(
                      right: Metrics.gutter,
                      bottom: 0,
                      child: Container(
                        color: c.ground,
                        padding: const EdgeInsets.fromLTRB(8, 3, 2, 2),
                        child: Text(
                          'CONTINUES BELOW',
                          style: press(
                            size: 8.5,
                            color: c.inkFaint,
                            tracking: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (state.notice != null) _noticeBand(c),
            _franking(c),
          ],
        ),
      ),
    );
  }

  Widget _header(Ink0 c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Metrics.gutter,
        13,
        Metrics.gutter,
        12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The wordmark keeps its split; in a world with one ink, the
                // split is carried by weight instead of colour.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    maxLines: 1,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'kind',
                          style: press(
                            size: 21,
                            weight: FontWeight.w700,
                            color: c.ink,
                            tracking: -0.2,
                          ),
                        ),
                        TextSpan(
                          text: 'beamer',
                          style: press(
                            size: 21,
                            weight: FontWeight.w300,
                            color: c.inkMid,
                            tracking: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'UNOFFICIAL SEND-TO-KINDLE CLIENT',
                  style: press(size: 8.5, color: c.inkFaint, tracking: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PressButton(
            label: 'ADD',
            cap: '${modKey}O',
            dense: true,
            onPressed: _browse,
          ),
          const SizedBox(width: 8),
          PressButton(
            label: 'SETTINGS',
            cap: '$modKey,',
            dense: true,
            onPressed: () => showSettingsDialog(context, state),
          ),
        ],
      ),
    );
  }

  /// The queue is the only section whose length the user controls, so it is
  /// the one that is capped: three rows, then it scrolls inside its own box and
  /// the rest of the label stays where it was.
  static const int _queueRows = 3;

  Widget _contents(Ink0 c) {
    if (state.docs.isEmpty) {
      final delivered = state.phase == SendPhase.done;
      return Well(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
        child: Text(
          delivered
              ? 'Delivered. Drop another document to send it on.'
              : touchLayout
              ? 'Share a document to KindBeamer, or tap ADD.'
              : 'Drop a document here, or press ${modKey}O to choose one.',
          style: typed(size: 12.5, color: c.inkFaint),
        ),
      );
    }
    // What the converter did is a footnote on the contents, not a state of the
    // send: it has to survive being signed out or having no device ticked.
    final converted = state.docs
        .map((d) => d.conversionNote)
        .whereType<String>()
        .toSet();
    final rows = Column(
      children: [for (var i = 0; i < state.docs.length; i++) _docRow(c, i)],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Well(
          child: state.docs.length <= _queueRows
              ? rows
              : SizedBox(
                  height: laneHeight * _queueRows,
                  child: Scrollbar(
                    controller: _queueScroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _queueScroll,
                      child: rows,
                    ),
                  ),
                ),
        ),
        for (final note in converted)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              note,
              style: typed(size: 11.5, color: c.inkFaint, height: 1.4),
            ),
          ),
      ],
    );
  }

  Widget _docRow(Ink0 c, int i) {
    final doc = state.docs[i];
    final selected = i == state.selectedIndex;
    return _HoverRow(
      onTap: () => state.selectDoc(i),
      height: laneHeight,
      child: Row(
        children: [
          const SizedBox(width: 10),
          // The line the carriage is on.
          SizedBox(
            width: 14,
            child: selected
                ? Center(child: Container(width: 6, height: 6, color: c.ink))
                : null,
          ),
          Expanded(
            child: Text(
              doc.name,
              overflow: TextOverflow.ellipsis,
              style: typed(
                size: 13,
                color: selected ? c.ink : c.inkMid,
                weight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            doc.converting ? 'CONVERTING' : doc.format.label.toUpperCase(),
            style: press(size: 9, color: c.inkMid, tracking: 1.2),
          ),
          SizedBox(
            width: 82,
            child: Text(
              DocItem.humanSize(doc.size),
              textAlign: TextAlign.right,
              style: typed(size: 11, color: c.inkFaint),
            ),
          ),
          _IconTap(
            tooltip: 'Remove ${doc.name}',
            onTap: () => state.removeDoc(i),
            builder: (hover) => CrossMark(strong: hover),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _description(Ink0 c) {
    final doc = state.selectedDoc;
    return Column(
      children: [
        _field(
          c,
          label: 'TITLE',
          controller: _title,
          focus: _titleFocus,
          hint: 'document title',
          enabled: doc != null,
          onChanged: (v) => doc?.title = v,
        ),
        const SizedBox(height: 9),
        _field(
          c,
          label: 'AUTHOR',
          controller: _author,
          focus: _authorFocus,
          hint: DocItem.unknownAuthor,
          enabled: doc != null,
          onChanged: (v) => doc?.author = v,
        ),
      ],
    );
  }

  Widget _field(
    Ink0 c, {
    required String label,
    required TextEditingController controller,
    required FocusNode focus,
    required String hint,
    required bool enabled,
    required ValueChanged<String> onChanged,
  }) {
    final focused = focus.hasFocus;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: SizedBox(
            width: 64,
            child: Text(
              label,
              style: press(
                size: 9.5,
                color: enabled ? c.inkMid : c.inkFaint,
                tracking: 1.3,
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            // A form is a ruled line you write on, not a filled box.
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: focused ? c.ink : (enabled ? c.rule : c.ruleFaint),
                  width: focused ? 1.6 : 1,
                ),
              ),
            ),
            padding: const EdgeInsets.only(bottom: 4),
            child: TextField(
              key: ValueKey('${label.toLowerCase()}-field'),
              controller: controller,
              focusNode: focus,
              enabled: enabled,
              onChanged: onChanged,
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.done,
              cursorWidth: 1.4,
              cursorRadius: Radius.zero,
              style: typed(size: 13, color: c.ink),
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: typed(size: 13, color: c.inkFaint),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// One box holds every destination: the devices, and the library copy that
  /// is also a destination. Folding the old fifth section in here is what keeps
  /// a three-document label on one screen.
  Widget _deliverTo(Ink0 c) {
    final total = state.devices.length;
    final on = state.selectedSerials.length;
    final allOn = total > 0 && on == total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Legend(
          letter: 'C',
          name: 'DELIVER TO',
          tally: state.signedIn && total > 0 ? '$on OF $total' : null,
          trailing: state.signedIn && total > 0
              ? PressButton(
                  label: allOn ? 'NONE' : 'ALL',
                  cap: 'A',
                  dense: true,
                  onPressed: () => state.setAllDevices(!allOn),
                )
              : null,
        ),
        Well(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!state.signedIn)
                _signedOut(c)
              else if (total == 0)
                _lanesLoading(c)
              else
                _lanes(c),
              if (state.signedIn) ...[const Rule(strong: true), _archive(c)],
            ],
          ),
        ),
      ],
    );
  }

  Widget _signedOut(Ink0 c) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Sign in with your Amazon account to list the devices '
              'registered to it.',
              style: typed(size: 12.5, color: c.inkMid, height: 1.45),
            ),
          ),
          const SizedBox(width: 14),
          PressButton(
            label: 'SIGN IN',
            cap: 'ENTER',
            onPressed: () => showLoginDialog(context, state),
          ),
        ],
      ),
    );
  }

  Widget _lanesLoading(Ink0 c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            SizedBox(
              height: laneHeight,
              child: Row(
                children: [
                  const SizedBox(width: 30),
                  Container(
                    height: 10,
                    width: 11.0 * (12 - i * 2),
                    color: c.ruleFaint,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _lanes(Ink0 c) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final devices = state.devices;
        final twoUp = constraints.maxWidth >= 520 && devices.length > 1;
        final split = twoUp ? (devices.length / 2).ceil() : devices.length;
        Widget column(int from, int to) =>
            Column(children: [for (var i = from; i < to; i++) _lane(c, i)]);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: column(0, math.min(split, devices.length))),
              if (twoUp) ...[
                Container(
                  width: 1,
                  height: laneHeight * split,
                  color: c.ruleFaint,
                ),
                Expanded(child: column(split, devices.length)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _lane(Ink0 c, int i) {
    final device = state.devices[i];
    final on = state.selectedSerials.contains(device.deviceSerialNumber);
    // 1-9 then 0; past the tenth the lane has no key, only a tick.
    final key = i < 9
        ? '${i + 1}'
        : i == 9
        ? '0'
        : '';
    return Semantics(
      checked: on,
      label: device.deviceName,
      child: _HoverRow(
        height: laneHeight,
        onTap: () => state.toggleDevice(device.deviceSerialNumber, !on),
        child: Row(
          children: [
            const SizedBox(width: 8),
            SizedBox(
              width: 12,
              child: Text(
                key,
                textAlign: TextAlign.right,
                style: typed(
                  size: 11,
                  color: on ? c.ink : c.inkFaint,
                  weight: on ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 9),
            TickBox(on: on),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                device.deviceName,
                overflow: TextOverflow.ellipsis,
                style: typed(size: 13, color: on ? c.ink : c.inkMid),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _archive(Ink0 c) {
    return _HoverRow(
      height: laneHeight + 6,
      onTap: () => state.setArchive(!state.archive),
      child: Row(
        children: [
          const SizedBox(width: 29),
          TickBox(on: state.archive),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Also keep a copy in your Kindle Library',
              style: typed(size: 13, color: state.archive ? c.ink : c.inkMid),
            ),
          ),
          if (!touchLayout)
            Text('E', style: press(size: 9, color: c.inkFaint, tracking: 1.2)),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _noticeBand(Ink0 c) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.ink, width: 1.2)),
        color: c.well,
      ),
      padding: const EdgeInsets.fromLTRB(Metrics.gutter, 9, 10, 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              state.notice!,
              style: typed(size: 12, color: c.ink, height: 1.4),
            ),
          ),
          _IconTap(
            tooltip: 'Dismiss',
            onTap: state.clearNotice,
            builder: (hover) => CrossMark(strong: hover, size: 11),
          ),
        ],
      ),
    );
  }

  ({Frank mark, String line, String note}) _frankState() {
    final doc = state.selectedDoc;
    final devices = state.selectedSerials.length;
    switch (state.phase) {
      case SendPhase.sending:
        return (mark: Frank.sending, line: state.statusMessage, note: '');
      case SendPhase.done:
        return (
          mark: Frank.delivered,
          line: state.statusMessage,
          note: state.closeOnSuccess ? 'CLOSING THIS WINDOW' : '',
        );
      case SendPhase.error:
        return (
          mark: Frank.held,
          line: state.statusMessage,
          note: touchLayout ? 'TAP RETRY' : 'PRESS ENTER TO TRY AGAIN',
        );
      case SendPhase.idle:
        break;
    }
    if (doc == null) {
      return (mark: Frank.idle, line: 'Nothing to send yet.', note: '');
    }
    if (state.converting) {
      return (
        mark: Frank.idle,
        line: 'Converting ${doc.name} for your Kindle…',
        note: '',
      );
    }
    if (!state.signedIn) {
      return (
        mark: Frank.idle,
        line: 'Not signed in.',
        note: touchLayout ? 'TAP SIGN IN' : 'PRESS ENTER TO SIGN IN',
      );
    }
    if (devices == 0) {
      return (
        mark: Frank.idle,
        line: 'No device ticked.',
        note: touchLayout
            ? 'TICK A DEVICE ABOVE'
            : 'PRESS A DEVICE NUMBER, OR A FOR ALL',
      );
    }
    final size = state.docs.fold<int>(0, (sum, d) => sum + d.size);
    final what = state.docs.length == 1
        ? doc.format.label.toUpperCase()
        : '${state.docs.length} DOCUMENTS';
    final note = [
      what,
      DocItem.humanSize(size).toUpperCase(),
      devices == 1 ? 'TO 1 DEVICE' : 'TO $devices DEVICES',
    ].join('  ·  ');
    return (mark: Frank.ready, line: 'Ready to send.', note: note);
  }

  Widget _franking(Ink0 c) {
    final f = _frankState();
    final sending = state.phase == SendPhase.sending;
    final failed = state.phase == SendPhase.error;

    final status = Row(
      children: [
        Postmark(state: f.mark, progress: state.progress),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.line,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: typed(size: 12.5, color: c.ink, height: 1.35),
              ),
              if (f.note.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  f.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: press(size: 9, color: c.inkFaint, tracking: 1.3),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final clear = PressButton(
      label: state.docs.isEmpty ? 'CLOSE' : 'CLEAR',
      cap: 'ESC',
      onPressed: sending ? null : _cancel,
    );
    final send = PressButton(
      label: sending
          ? 'SENDING'
          : failed
          ? 'RETRY'
          : 'SEND',
      cap: state.canSend ? 'ENTER' : null,
      solid: true,
      onPressed: state.canSend ? _send : null,
    );

    final delivered = state.phase == SendPhase.done;
    return Column(
      children: [
        ProgressRule(value: state.progress, active: sending || delivered),
        Stack(
          children: [
            // A franking cancels what it stamps: on delivery the rule above
            // this row is joined by two more, struck across the whole label.
            if (delivered)
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Container(height: 2, color: c.ink),
                    const SizedBox(height: 3),
                    Container(height: 2, color: c.ink),
                  ],
                ),
              ),
            Container(
              color: Colors.transparent,
              padding: const EdgeInsets.fromLTRB(
                Metrics.gutter,
                16,
                Metrics.gutter,
                14,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Narrow enough that the sentence would be squeezed to nothing:
                  // the actions take their own line, at full width.
                  if (constraints.maxWidth < 520) {
                    return Column(
                      children: [
                        status,
                        const SizedBox(height: 13),
                        Row(
                          children: [
                            Expanded(child: clear),
                            const SizedBox(width: 9),
                            Expanded(child: send),
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: status),
                      const SizedBox(width: 14),
                      clear,
                      const SizedBox(width: 9),
                      send,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Both overlays are the same act: the window turns over and prints one
  /// instruction on its back.
  Widget _overlay(Ink0 c, Widget child) {
    final invert = Theme.of(context).brightness == Brightness.light;
    final bg = invert ? c.ink : c.ground;
    final fg = invert ? c.ground : c.ink;
    return Positioned.fill(
      child: Container(
        color: bg,
        padding: const EdgeInsets.all(14),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: fg, width: 1)),
          child: Center(
            child: DefaultTextStyle(
              style: typed(color: fg),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropSheet(Ink0 c) {
    final invert = Theme.of(context).brightness == Brightness.light;
    final fg = invert ? c.ground : c.ink;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'AFFIX DOCUMENT',
          style: press(
            size: 26,
            color: fg,
            weight: FontWeight.w700,
            tracking: 6,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'PDF  EPUB  MOBI  AZW3  DOC  DOCX  RTF  TXT  HTML  MD  IMAGES',
          textAlign: TextAlign.center,
          style: press(
            size: 9.5,
            color: fg.withValues(alpha: 0.7),
            tracking: 2,
          ),
        ),
      ],
    );
  }

  Widget _keySheet(Ink0 c) {
    final invert = Theme.of(context).brightness == Brightness.light;
    final fg = invert ? c.ground : c.ink;
    final rows = [
      ('ENTER', 'Send \u00B7 sign in when signed out'),
      ('ESC', 'Clear the queue, then close'),
      ('1 \u2026 9, 0', 'Tick the device on that line'),
      ('A', 'All devices, or none'),
      ('E', 'Keep a copy in your Kindle Library'),
      ('BACKSPACE', 'Drop the marked document'),
      ('${modKey}O', 'Add files'),
      ('$modKey,', 'Settings'),
      ('?', 'This card'),
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('KEYS', style: press(size: 15, color: fg, tracking: 6)),
          const SizedBox(height: 10),
          Container(height: 1, color: fg),
          const SizedBox(height: 14),
          for (final (key, what) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      key,
                      style: press(
                        size: 10.5,
                        color: fg,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(what, style: typed(size: 13, color: fg)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'PRESS ANY KEY',
            style: press(
              size: 9,
              color: fg.withValues(alpha: 0.6),
              tracking: 2,
            ),
          ),
        ],
      ),
    );
  }
}

/// A row that is entirely its own hit target, and says so by inking its ground.
class _HoverRow extends StatefulWidget {
  const _HoverRow({
    required this.child,
    required this.onTap,
    required this.height,
  });

  final Widget child;
  final VoidCallback onTap;
  final double height;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = Ink0.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: widget.height,
          color: _hover ? c.ruleFaint : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}

class _IconTap extends StatefulWidget {
  const _IconTap({
    required this.builder,
    required this.onTap,
    required this.tooltip,
  });

  final Widget Function(bool hover) builder;
  final VoidCallback onTap;
  final String tooltip;

  @override
  State<_IconTap> createState() => _IconTapState();
}

class _IconTapState extends State<_IconTap> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            width: touchLayout ? 48 : 26,
            height: touchLayout ? 48 : 26,
            child: Center(child: widget.builder(_hover)),
          ),
        ),
      ),
    );
  }
}
