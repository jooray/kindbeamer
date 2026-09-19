import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../amazon/oauth.dart';
import '../state/app_state.dart';
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
  late final String _signinUrl;
  final TextEditingController _paste = TextEditingController();
  bool _busy = false;
  bool _showPaste = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _signinUrl = widget.state.beginLogin();
  }

  bool _isRedirect(String url) => OAuth2.isRedirectUrl(url);

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
    return Dialog(
      backgroundColor: StkColors.background,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Text(
                    'Sign in to Amazon',
                    style: TextStyle(
                      color: StkColors.textPrimary,
                      fontSize: 17,
                    ),
                  ),
                  const Spacer(),
                  if (_busy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                    color: StkColors.textSecondary,
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            Expanded(
              child: _webviewSupported
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
                          shouldOverrideUrlLoading: (controller, action) async {
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
                            final href = await controller.evaluateJavascript(
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
                            color: StkColors.background.withValues(alpha: 0.85),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Completing sign-in…',
                                    style: TextStyle(
                                      color: StkColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : _browserFallback(),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showPaste = !_showPaste),
                    child: const Text(
                      'Paste the redirect URL instead',
                      style: TextStyle(
                        color: StkColors.link,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  if (_showPaste)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _paste,
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText:
                                    'https://www.amazon.com/sendtokindle/maplanding?…',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    if (_paste.text.trim().isNotEmpty) {
                                      _complete(_paste.text.trim());
                                    }
                                  },
                            child: const Text('Continue'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _browserFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Embedded browser is not available on this platform.\n'
              'Open the sign-in page in your browser, then paste the final\n'
              'redirect URL (from the address bar) below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: StkColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => launchUrl(
                Uri.parse(_signinUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Open sign-in page'),
            ),
          ],
        ),
      ),
    );
  }
}
