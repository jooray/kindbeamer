import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../amazon/oauth.dart';
import '../state/app_state.dart';
import 'label_parts.dart';
import 'theme.dart';

bool get _webviewSupported =>
    !kIsWeb &&
    (Platform.isMacOS ||
        Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isWindows);

/// Amazon serves a degraded sign-in page to unknown user agents, so present the
/// platform's stock browser instead of the bare WebKit default.
String get _userAgent => Platform.isAndroid
    ? 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/126.0.0.0 Mobile Safari/537.36'
    : 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
          '(KHTML, like Gecko) Version/17.4 Safari/605.1.15';

Future<void> showLoginDialog(BuildContext context, AppState state) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => LoginDialog(state: state),
  );
}

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key, required this.state});

  final AppState state;

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  late String _signinUrl;
  InAppWebViewController? _controller;
  final TextEditingController _paste = TextEditingController();
  bool _busy = false;
  bool _showPaste = false;
  late bool _useWebview = _webviewSupported;
  String? _error;

  @override
  void initState() {
    super.initState();
    _signinUrl = widget.state.beginLogin();
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  bool _isRedirect(String url) => OAuth2.isRedirectUrl(url);

  /// A failed exchange burns the authorization code, so a retry needs a fresh
  /// sign-in URL, not a reload of the old one.
  Future<void> _startOver() async {
    final url = widget.state.beginLogin();
    setState(() {
      _signinUrl = url;
      _error = null;
      _busy = false;
    });
    await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  Future<void> _scanHistory(InAppWebViewController controller) async {
    if (_busy) return;
    try {
      final list = await controller.getCopyBackForwardList();
      for (final item in list?.list ?? <dynamic>[]) {
        final u = item.url.toString();
        if (_isRedirect(u)) {
          await _complete(u);
          return;
        }
      }
    } catch (_) {}
  }

  void _checkUrl(String? url) {
    if (url != null && !_busy && _isRedirect(url)) _complete(url);
  }

  Future<void> _complete(String url) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await widget.state.completeLogin(url);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = widget.state.notice;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Ink0.of(context);
    // A phone needs the whole screen for a sign-in page; a desktop window does
    // not, and a 640x600 slip sits better inside it.
    final media = MediaQuery.of(context);
    final compact = media.size.width < 600;
    return Dialog(
      backgroundColor: c.ground,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 34,
        vertical: compact ? 10 : 22,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: compact
              ? media.size.height
              : math.min(600, media.size.height - 44),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: c.ink, width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BarredEdge(),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SIGN IN TO AMAZON',
                        style: press(
                          size: 12,
                          color: c.ink,
                          weight: FontWeight.w700,
                          tracking: 3,
                        ),
                      ),
                    ),
                    if (_busy)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          'WORKING',
                          style: press(size: 9, color: c.inkMid, tracking: 1.6),
                        ),
                      ),
                    PressButton(
                      label: 'CLOSE',
                      dense: true,
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: c.ink, width: 1.2),
                      color: c.well,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 96),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _error!,
                              style: typed(
                                size: 12,
                                color: c.ink,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        PressButton(
                          label: 'START OVER',
                          dense: true,
                          onPressed: _busy ? null : _startOver,
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(border: Border.all(color: c.rule)),
                  child: _useWebview
                      ? Stack(
                          children: [
                            InAppWebView(
                              initialUrlRequest: URLRequest(
                                url: WebUri(_signinUrl),
                              ),
                              initialSettings: InAppWebViewSettings(
                                // The landing page bounces to `sendtokindle://…`;
                                // without this the navigation is swallowed.
                                useShouldOverrideUrlLoading: true,
                                javaScriptCanOpenWindowsAutomatically: false,
                                supportZoom: false,
                                userAgent: _userAgent,
                              ),
                              onWebViewCreated: (controller) =>
                                  _controller = controller,
                              shouldOverrideUrlLoading:
                                  (controller, action) async {
                                    final u = action.request.url?.toString();
                                    if (u != null && _isRedirect(u)) {
                                      _complete(u);
                                      return NavigationActionPolicy.CANCEL;
                                    }
                                    return NavigationActionPolicy.ALLOW;
                                  },
                              onLoadStart: (controller, url) =>
                                  _checkUrl(url?.toString()),
                              onLoadStop: (controller, url) async {
                                _checkUrl(url?.toString());
                                if (_busy) return;
                                // The code can sit in a URL the navigation
                                // callbacks never reported (server-side redirect).
                                final href = await controller
                                    .evaluateJavascript(
                                      source: 'window.location.href',
                                    );
                                if (href is String) _checkUrl(href);
                                if (_busy) return;
                                await _scanHistory(controller);
                              },
                              onUpdateVisitedHistory: (controller, url, _) =>
                                  _checkUrl(url?.toString()),
                              onReceivedError: (controller, request, error) {
                                final u = request.url.toString();
                                if (_isRedirect(u)) {
                                  _complete(u);
                                }
                              },
                            ),
                            if (_busy)
                              Container(
                                color: c.ground.withValues(alpha: 0.92),
                                child: Center(
                                  child: Text(
                                    'COMPLETING SIGN-IN',
                                    style: press(
                                      size: 11,
                                      color: c.ink,
                                      tracking: 3,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : _browserPanel(c),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_useWebview)
                      Row(
                        children: [
                          // The embedded browser is not always able to take the
                          // keyboard, so the way out through the real one is on
                          // screen rather than something to find out about.
                          PressButton(
                            label: 'OPEN IN BROWSER',
                            dense: true,
                            onPressed: () {
                              setState(() => _showPaste = true);
                              launchUrl(
                                Uri.parse(_signinUrl),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          PressButton(
                            label: _showPaste
                                ? 'HIDE REDIRECT URL'
                                : 'PASTE REDIRECT URL INSTEAD',
                            dense: true,
                            onPressed: () =>
                                setState(() => _showPaste = !_showPaste),
                          ),
                        ],
                      ),
                    if (_showPaste && _useWebview)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Finish signing in over there, then paste the address '
                          'the browser ends on — it starts sendtokindle:// or '
                          'amazon.com/sendtokindle/maplanding.',
                          style: typed(
                            size: 11.5,
                            color: c.inkMid,
                            height: 1.5,
                          ),
                        ),
                      ),
                    if (_showPaste && _useWebview)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: c.rule),
                                  ),
                                ),
                                padding: const EdgeInsets.only(bottom: 4),
                                child: TextField(
                                  controller: _paste,
                                  cursorWidth: 1.4,
                                  cursorRadius: Radius.zero,
                                  style: typed(size: 12, color: c.ink),
                                  decoration: InputDecoration.collapsed(
                                    hintText:
                                        'https://www.amazon.com/sendtokindle/'
                                        'maplanding?…',
                                    hintStyle: typed(
                                      size: 12,
                                      color: c.inkFaint,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            PressButton(
                              label: 'CONTINUE',
                              solid: true,
                              onPressed: _busy
                                  ? null
                                  : () {
                                      if (_paste.text.trim().isNotEmpty) {
                                        _complete(_paste.text.trim());
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const BarredEdge(flip: true),
            ],
          ),
        ),
      ),
    );
  }

  /// The sign-in without a webview in it: the page opens in the browser the
  /// reader already trusts, and comes back as the address it lands on.
  Widget _browserPanel(Ink0 c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1.  Open the Amazon sign-in page in your browser.',
            style: typed(size: 13, color: c.ink, height: 1.5),
          ),
          const SizedBox(height: 10),
          PressButton(
            label: 'OPEN SIGN-IN PAGE',
            cap: 'ENTER',
            solid: true,
            onPressed: () => launchUrl(
              Uri.parse(_signinUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '2.  Sign in there. The page ends on an address starting '
            'sendtokindle:// or amazon.com/sendtokindle/maplanding — your '
            'browser may refuse to open it, which is fine. Copy it from the '
            'address bar.',
            style: typed(size: 13, color: c.ink, height: 1.5),
          ),
          const SizedBox(height: 20),
          Text(
            '3.  Paste it here.',
            style: typed(size: 13, color: c.ink, height: 1.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.rule)),
                  ),
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TextField(
                    controller: _paste,
                    autofocus: true,
                    cursorWidth: 1.4,
                    cursorRadius: Radius.zero,
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) _complete(v.trim());
                    },
                    style: typed(size: 12, color: c.ink),
                    decoration: InputDecoration.collapsed(
                      hintText:
                          'https://www.amazon.com/sendtokindle/maplanding?…',
                      hintStyle: typed(size: 12, color: c.inkFaint),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              PressButton(
                label: 'CONTINUE',
                solid: true,
                onPressed: _busy
                    ? null
                    : () {
                        if (_paste.text.trim().isNotEmpty) {
                          _complete(_paste.text.trim());
                        }
                      },
              ),
            ],
          ),
          if (_webviewSupported) ...[
            const SizedBox(height: 22),
            Text(
              'The embedded browser is available, but on some machines it '
              'draws the Amazon page and then takes no clicks.',
              style: typed(size: 11.5, color: c.inkFaint, height: 1.5),
            ),
            const SizedBox(height: 8),
            PressButton(
              label: 'TRY THE EMBEDDED BROWSER',
              dense: true,
              onPressed: () => setState(() => _useWebview = true),
            ),
          ],
        ],
      ),
    );
  }
}
