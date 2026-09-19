import 'dart:io';

import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;

import '../state/documents.dart';

/// What a Markdown file turns into before it is uploaded.
class ConvertedDoc {
  const ConvertedDoc({
    required this.path,
    required this.format,
    required this.note,
  });

  /// The file to upload — never the `.md` itself, which the service rejects.
  final String path;
  final DocFormat format;

  /// How it was produced, for the status line.
  final String note;
}

/// Turns Markdown into something Send to Kindle accepts.
///
/// A typeset PDF reads best, so a local toolchain is used when there is one:
/// `pandoc` with a TeX engine, else a headless Chrome printing pandoc's HTML.
/// Where no such tool can run, the Markdown is rendered to HTML in-process and
/// the service converts it on its side. The result is always a file the service
/// will take.
///
/// In practice the PDF path is a Linux one. Android has no subprocesses to
/// speak of, and the macOS build is sandboxed: it can *find* pandoc but the
/// sandbox denies the spawn, so it takes the HTML path too.
class MarkdownConverter {
  /// PDF pages sized for a 6" reader rather than A4, because a PDF does not
  /// reflow: a letter-sized page on a Kindle is a page of unreadable specks.
  static const _pandocPageArgs = [
    '-V',
    'geometry:papersize={6in,8in}',
    '-V',
    'geometry:margin=0.4in',
    '-V',
    'fontsize=12pt',
    '-V',
    'colorlinks=true',
    '-V',
    'linkcolor=black',
  ];

  static const _texEngines = ['xelatex', 'pdflatex', 'lualatex', 'tectonic'];
  static const _htmlEngines = ['typst', 'weasyprint', 'wkhtmltopdf', 'prince'];

  static const _chromePaths = [
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
    '/usr/bin/google-chrome',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
  ];

  /// [allowExternalTools] exists so tests can exercise the in-process path
  /// without depending on what happens to be installed.
  static Future<ConvertedDoc> convert(
    File source,
    Directory workDir, {
    bool allowExternalTools = true,
  }) async {
    final outDir = Directory(p.join(workDir.path, 'converted'));
    await outDir.create(recursive: true);
    final base = p.basenameWithoutExtension(source.path);
    final pdfPath = p.join(outDir.path, '$base.pdf');
    final htmlPath = p.join(outDir.path, '$base.html');

    // The macOS app is sandboxed: it may read a dropped file itself, but a child
    // process does not inherit that permission. Give the converter a copy inside
    // the container, where its descendants are allowed to read and write.
    final markdown = await source.readAsString();
    final localSource = File(p.join(outDir.path, '$base.md'));
    await localSource.writeAsString(markdown);

    if (allowExternalTools && _canRunTools) {
      final viaPandoc = await _pandocToPdf(localSource, pdfPath);
      if (viaPandoc != null) return viaPandoc;
    }
    await File(htmlPath).writeAsString(_renderHtml(base, markdown));

    if (allowExternalTools && _canRunTools && !_execBlocked) {
      final viaChrome = await _chromeToPdf(htmlPath, pdfPath);
      if (viaChrome != null) return viaChrome;
    }

    return ConvertedDoc(
      path: htmlPath,
      format: DocFormat.forExtension('html')!,
      note: _execBlocked
          ? 'converted to HTML — this build may not run pandoc'
          : 'converted to HTML',
    );
  }

  static bool get _canRunTools =>
      Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  /// Set when a converter was found on disk but could not be started, which on
  /// a sandboxed macOS build is every time: the sandbox denies executing
  /// binaries outside the app, so the HTML path is the only one available.
  static bool _execBlocked = false;

  static Future<ConvertedDoc?> _pandocToPdf(File source, String outPath) async {
    final pandoc = await _which('pandoc');
    if (pandoc == null) return null;
    for (final name in [..._texEngines, ..._htmlEngines]) {
      final engine = await _which(name);
      if (engine == null) continue;
      // Absolute paths throughout: pandoc resolves a bare engine name against
      // its own PATH, which is the impoverished one a GUI app inherits.
      final res = await _run(pandoc, [
        source.path,
        '-o',
        outPath,
        '--standalone',
        '--pdf-engine=$engine',
        ..._pandocPageArgs,
      ]);
      if (res == null) {
        // The sandbox refuses the spawn itself; another engine will fare no
        // better, so stop asking.
        _execBlocked = true;
        return null;
      }
      if (res.exitCode == 0 && await File(outPath).exists()) {
        return ConvertedDoc(
          path: outPath,
          format: DocFormat.forExtension('pdf')!,
          note: 'converted to PDF with pandoc + $name',
        );
      }
    }
    return null;
  }

  static Future<ConvertedDoc?> _chromeToPdf(
    String htmlPath,
    String outPath,
  ) async {
    final chrome = await _chrome();
    if (chrome == null) return null;
    final res = await _run(chrome, [
      '--headless=new',
      '--disable-gpu',
      '--no-pdf-header-footer',
      '--virtual-time-budget=4000',
      '--print-to-pdf=$outPath',
      Uri.file(htmlPath).toString(),
    ]);
    if (res != null && res.exitCode == 0 && await File(outPath).exists()) {
      return ConvertedDoc(
        path: outPath,
        format: DocFormat.forExtension('pdf')!,
        note: 'converted to PDF with headless Chrome',
      );
    }
    return null;
  }

  static Future<String?> _chrome() async {
    for (final path in _chromePaths) {
      if (await File(path).exists()) return path;
    }
    return await _which('chromium') ?? await _which('google-chrome');
  }

  /// Where a GUI app has to look for command line tools.
  ///
  /// An app launched from Finder inherits `PATH=/usr/bin:/bin:/usr/sbin:/sbin`,
  /// so `which pandoc` finds nothing even on a machine where the terminal finds
  /// it immediately. Ask `which` first — it is right when the app was started
  /// from a shell — then look where package managers actually install.
  static const _toolDirs = [
    '/opt/homebrew/bin', // Homebrew, Apple silicon
    '/usr/local/bin', // Homebrew on Intel, and most manual installs
    '/opt/local/bin', // MacPorts
    '/usr/bin',
    '/bin',
    '/snap/bin',
    '/var/lib/flatpak/exports/bin',
  ];

  static Future<String?> _which(String tool) async {
    final res = await _run(Platform.isWindows ? 'where' : 'which', [tool]);
    if (res != null && res.exitCode == 0) {
      final out = (res.stdout as String).trim();
      if (out.isNotEmpty) return out.split('\n').first;
    }
    if (Platform.isWindows) return null;
    for (final dir in [
      ..._toolDirs,
      p.join(_home, '.local/bin'),
      p.join(_home, 'bin'),
      p.join(_home, 'go/bin'),
    ]) {
      final candidate = p.join(dir, tool);
      if (await File(candidate).exists()) return candidate;
    }
    return null;
  }

  static String get _home =>
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';

  static Future<ProcessResult?> _run(
    String executable,
    List<String> args,
  ) async {
    try {
      return await Process.run(
        executable,
        args,
        environment: _toolEnvironment,
      ).timeout(const Duration(seconds: 90));
    } catch (_) {
      return null;
    }
  }

  /// A TeX engine shells out to its own siblings, so the child needs a PATH
  /// that covers the places those live — the GUI app's own PATH does not.
  static Map<String, String> get _toolEnvironment {
    if (Platform.isWindows) return const {};
    final existing = Platform.environment['PATH'] ?? '';
    final dirs = [
      ..._toolDirs,
      if (_home.isNotEmpty) p.join(_home, '.local/bin'),
      if (existing.isNotEmpty) existing,
    ];
    return {'PATH': dirs.join(':')};
  }

  /// Kindle-friendly HTML: one column, generous line height, no colour tricks
  /// that an e-ink screen will render as mud.
  static String _renderHtml(String title, String markdown) {
    final body = md.markdownToHtml(
      markdown,
      extensionSet: md.ExtensionSet.gitHubWeb,
    );
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>${_escape(title)}</title>
<style>
  body { font-family: Georgia, "Times New Roman", serif; line-height: 1.5;
         margin: 5%; font-size: 1em; }
  h1, h2, h3, h4 { font-family: Helvetica, Arial, sans-serif; line-height: 1.25;
         margin-top: 1.4em; }
  h1 { font-size: 1.6em; } h2 { font-size: 1.35em; } h3 { font-size: 1.15em; }
  code, pre { font-family: "Courier New", monospace; font-size: 0.9em; }
  pre { background: #f4f4f4; padding: 0.7em; white-space: pre-wrap;
        word-wrap: break-word; }
  blockquote { margin: 1em 0 1em 1em; padding-left: 1em;
               border-left: 3px solid #999; font-style: italic; }
  table { border-collapse: collapse; } td, th { border: 1px solid #999;
          padding: 0.3em 0.5em; }
  img { max-width: 100%; }
</style>
</head>
<body>
$body</body>
</html>
''';
  }

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
