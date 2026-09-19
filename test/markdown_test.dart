import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kindbeamer/src/convert/markdown.dart';
import 'package:kindbeamer/src/state/documents.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kb_md');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  File writeMarkdown(String body) {
    final f = File('${tmp.path}/notes.md');
    f.writeAsStringSync(body);
    return f;
  }

  test('markdown is a supported drop that has to be converted', () {
    final format = DocFormat.forPath('/tmp/notes.md');
    expect(format, isNotNull);
    expect(format!.needsConversion, isTrue);
    expect(DocFormat.forPath('/tmp/paper.pdf')!.needsConversion, isFalse);
  });

  test('without external tools it becomes HTML the service accepts', () async {
    final source = writeMarkdown(
      '# Title\n\nSome *emphasis* and a [link](https://example.com).\n\n'
      '- one\n- two\n\n> quoted\n\n```dart\nvar x = 1;\n```\n',
    );
    final result = await MarkdownConverter.convert(
      source,
      tmp,
      allowExternalTools: false,
    );

    expect(result.format.inputFormat, 'HTML');
    expect(result.path, endsWith('notes.html'));
    expect(result.note, contains('HTML'));

    final html = await File(result.path).readAsString();
    expect(html, contains('>Title</h1>'), reason: 'heading survives');
    expect(html, contains('<em>emphasis</em>'));
    expect(html, contains('<a href="https://example.com">link</a>'));
    expect(html, contains('<blockquote>'));
    expect(html, contains('<li>one</li>'));
    expect(html, contains('<code class="language-dart">'));
    expect(html, contains('font-family'), reason: 'carries reader styling');
  });

  test(
    'whatever the toolchain, the result is a format the service takes',
    () async {
      final source = writeMarkdown('# Heading\n\nBody text.\n');
      final result = await MarkdownConverter.convert(source, tmp);
      expect(['PDF', 'HTML'], contains(result.format.inputFormat));
      expect(result.format.needsConversion, isFalse);
      expect(await File(result.path).length(), greaterThan(0));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('the converted file is written beside the work directory', () async {
    final source = writeMarkdown('# Hi\n');
    final result = await MarkdownConverter.convert(
      source,
      tmp,
      allowExternalTools: false,
    );
    expect(result.path, startsWith('${tmp.path}/converted/'));
    expect(File(result.path).existsSync(), isTrue);
  });

  test('a markdown title in the document is escaped, not injected', () async {
    final source = File('${tmp.path}/a<b>.md')..writeAsStringSync('# x\n');
    final result = await MarkdownConverter.convert(
      source,
      tmp,
      allowExternalTools: false,
    );
    final html = await File(result.path).readAsString();
    expect(html, contains('<title>a&lt;b&gt;</title>'));
  });
}
