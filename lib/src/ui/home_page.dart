import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import '../state/documents.dart';
import 'login_dialog.dart';
import 'settings_dialog.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.state});

  final AppState state;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool _dragging = false;
  final TextEditingController _title = TextEditingController();
  final TextEditingController _author = TextEditingController();
  String? _boundTo;

  AppState get state => widget.state;

  void _syncControllers() {
    final doc = state.selectedDoc;
    if (_boundTo != doc?.path) {
      _boundTo = doc?.path;
      _title.text = doc?.title ?? '';
      _author.text = doc?.author ?? '';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      widget.state.refreshFromPlatform();
    }
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

  void _showNotice() {
    final msg = state.notice;
    if (msg == null) return;
    state.clearNotice();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showNotice();
          _syncControllers();
        });
        return Scaffold(
          backgroundColor: StkColors.background,
          body: DropTarget(
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() => _dragging = false),
            onDragDone: (details) {
              setState(() => _dragging = false);
              state.addFiles(details.files.map((f) => f.path).toList());
            },
            child: Stack(
              children: [
                Column(
                  children: [
                    _header(),
                    Expanded(child: _body()),
                    _statusStrip(),
                    _footer(),
                  ],
                ),
                if (_dragging) _dropOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [StkColors.headerTop, StkColors.headerBottom],
        ),
        border: Border(bottom: BorderSide(color: Color(0xFF1C1C1C))),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'kind',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: StkColors.accent,
                      ),
                    ),
                    TextSpan(
                      text: 'beamer',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w300,
                        color: StkColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _browse,
            style: OutlinedButton.styleFrom(
              foregroundColor: StkColors.textPrimary,
              side: const BorderSide(color: StkColors.borderLight),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            ),
            child: const Text('Add files…', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      children: [
        Text('Your document', style: heading()),
        const SizedBox(height: 8),
        if (state.docs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Drop files anywhere in this window, use “Add files…”, '
              'or share from another app.',
              style: TextStyle(color: StkColors.textFaint, fontSize: 12.5),
            ),
          )
        else
          _docList(),
        const SizedBox(height: 8),
        _metadataFields(),
        const SizedBox(height: 14),
        Text('Delivery options', style: heading()),
        const SizedBox(height: 12),
        _devicesBox(),
        const SizedBox(height: 10),
        _archiveBox(),
        const SizedBox(height: 6),
        if (state.selectedDoc != null)
          Text(
            DocItem.humanSize(state.selectedDoc!.size),
            style: const TextStyle(color: StkColors.textPrimary, fontSize: 15),
          ),
      ],
    );
  }

  Widget _docList() {
    return Container(
      decoration: BoxDecoration(
        color: StkColors.panel,
        border: Border.all(color: StkColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: state.docs.length,
        itemBuilder: (context, i) {
          final doc = state.docs[i];
          final selected = i == state.selectedIndex;
          return InkWell(
            onTap: () => state.selectDoc(i),
            child: Container(
              color: selected ? const Color(0xFF333333) : null,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                children: [
                  Icon(
                    doc.format.inputFormat == 'PDF'
                        ? Icons.picture_as_pdf_outlined
                        : Icons.menu_book_outlined,
                    size: 18,
                    color: StkColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      doc.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? StkColors.textPrimary
                            : StkColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    DocItem.humanSize(doc.size),
                    style: const TextStyle(
                      color: StkColors.textFaint,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => state.removeDoc(i),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: StkColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _metadataFields() {
    final doc = state.selectedDoc;
    return Column(
      children: [
        TextField(
          key: const ValueKey('title-field'),
          controller: _title,
          enabled: doc != null,
          onChanged: (v) => doc?.title = v,
          style: const TextStyle(color: StkColors.textPrimary, fontSize: 13.5),
          decoration: const InputDecoration(
            isDense: true,
            hintText: '<Document Title>',
            hintStyle: TextStyle(color: StkColors.textFaint),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('author-field'),
          controller: _author,
          enabled: doc != null,
          onChanged: (v) => doc?.author = v,
          style: const TextStyle(color: StkColors.textPrimary, fontSize: 13.5),
          decoration: const InputDecoration(
            isDense: true,
            hintText: '<Document Author>',
            hintStyle: TextStyle(color: StkColors.textFaint),
          ),
        ),
      ],
    );
  }

  Widget _devicesBox() {
    if (!state.signedIn) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: StkColors.panel,
          border: Border.all(color: StkColors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            const Text(
              'Sign in with your Amazon account to see your devices.',
              style: TextStyle(color: StkColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => showLoginDialog(context, state),
              style: FilledButton.styleFrom(
                backgroundColor: StkColors.accentDark,
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 168),
      decoration: BoxDecoration(
        color: StkColors.panel,
        border: Border.all(color: StkColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: state.devices.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final d in state.devices)
                  CheckboxListTile(
                    value: state.selectedSerials.contains(d.deviceSerialNumber),
                    onChanged: (v) =>
                        state.toggleDevice(d.deviceSerialNumber, v),
                    title: Text(
                      d.deviceName,
                      style: const TextStyle(
                        color: StkColors.textPrimary,
                        fontSize: 13.5,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
              ],
            ),
    );
  }

  Widget _archiveBox() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: StkColors.borderLight),
        borderRadius: BorderRadius.circular(6),
      ),
      child: CheckboxListTile(
        value: state.archive,
        onChanged: (v) => state.setArchive(v ?? true),
        title: const Text(
          'Archive document in your Kindle Library',
          style: TextStyle(color: StkColors.textPrimary, fontSize: 13.5),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      ),
    );
  }

  Widget _statusStrip() {
    final doc = state.selectedDoc;
    String text;
    if (state.phase == SendPhase.sending) {
      text = state.statusMessage;
    } else if (state.phase == SendPhase.done ||
        state.phase == SendPhase.error) {
      text = state.statusMessage;
    } else if (doc == null) {
      text = 'No valid document is selected to send.';
    } else if (doc.converting) {
      text = 'Converting ${doc.name} for your Kindle…';
    } else if (doc.conversionNote != null) {
      text =
          'Your document will be sent in ${doc.format.label} format '
          '(${doc.conversionNote}).';
    } else {
      text = 'Your document will be sent in ${doc.format.label} format.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: const BoxDecoration(
        color: StkColors.statusStrip,
        border: Border(
          top: BorderSide(color: Color(0xFF151B23)),
          left: BorderSide(color: StkColors.accent, width: 3),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: StkColors.textPrimary, fontSize: 13),
      ),
    );
  }

  Widget _footer() {
    final canSend = state.canSend;
    return Container(
      color: StkColors.footer,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 0,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _link('Settings', () => showSettingsDialog(context, state)),
                _sep(),
                _link(
                  'Need Help?',
                  () => _openUrl('https://github.com/jooray/kindbeamer'),
                ),
                _sep(),
                _link(
                  'Manage your Kindle',
                  () => _openUrl('https://www.amazon.com/hz/mycd/myx'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _pillButton(
            'Cancel',
            Colors.white,
            Colors.black87,
            state.phase == SendPhase.sending ? null : () => state.clearDocs(),
          ),
          const SizedBox(width: 10),
          _pillButton(
            state.phase == SendPhase.sending ? 'Sending…' : 'Send',
            canSend ? StkColors.accentDark : const Color(0xFFB9C2CC),
            canSend ? Colors.white : const Color(0xFF5A6472),
            canSend ? () => state.send() : null,
          ),
        ],
      ),
    );
  }

  Widget _link(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: StkColors.link,
          fontSize: 13,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _sep() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 10),
    child: Text('|', style: TextStyle(color: StkColors.textFaint)),
  );

  Widget _pillButton(String label, Color bg, Color fg, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _dropOverlay() {
    return Container(
      color: const Color(0xCC141A22),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.file_upload_rounded,
              size: 110,
              color: Color(0xFF93A3B5),
            ),
            SizedBox(height: 8),
            Text(
              'Drop files here',
              style: TextStyle(fontSize: 26, color: StkColors.accent),
            ),
            SizedBox(height: 6),
            Text(
              'to send to your Kindle',
              style: TextStyle(fontSize: 16, color: StkColors.accent),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
