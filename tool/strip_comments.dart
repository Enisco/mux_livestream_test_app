// Temporary tool — deletes itself from the repo after use.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/token.dart';

/// Comments worth keeping regardless of anything else.
bool _keep(String text) {
  final t = text.toLowerCase();
  return t.contains('todo') ||
      t.contains('ignore:') ||
      t.contains('ignore_for_file') ||
      t.contains('coverage:') ||
      t.contains('dart format') ||
      t.startsWith('// @');
}

void main(List<String> args) {
  final files = <File>[];
  for (final root in args) {
    files.addAll(
      Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
    );
  }

  var removed = 0;
  var kept = 0;
  for (final file in files) {
    final source = file.readAsStringSync();
    final result = parseString(content: source, throwIfDiagnostics: false);
    if (result.errors.any((e) => e.severity.name == 'ERROR')) {
      stderr.writeln('SKIP (parse errors): ${file.path}');
      continue;
    }

    // Walk every token, collecting the comment ranges to cut.
    final cuts = <List<int>>[];
    var token = result.unit.beginToken;
    final seen = <int>{};
    while (true) {
      Token? comment = token.precedingComments;
      while (comment != null) {
        if (seen.add(comment.offset)) {
          if (_keep(comment.lexeme)) {
            kept++;
          } else {
            cuts.add([comment.offset, comment.end]);
            removed++;
          }
        }
        comment = comment.next;
      }
      if (token.type == TokenType.EOF) break;
      token = token.next!;
    }
    if (cuts.isEmpty) continue;

    // Cut back to front so earlier offsets stay valid. Take the whole line when
    // the comment is alone on it, otherwise just the trailing comment.
    final buffer = StringBuffer();
    var out = source;
    for (final cut in cuts.reversed) {
      var start = cut[0];
      var end = cut[1];
      var lineStart = start;
      while (lineStart > 0 && out[lineStart - 1] != '\n') {
        lineStart--;
      }
      final before = out.substring(lineStart, start);
      if (before.trim().isEmpty) {
        start = lineStart;
        if (end < out.length && out[end] == '\n') end++;
      } else {
        // Trailing comment: drop the whitespace ahead of it too.
        while (start > 0 && (out[start - 1] == ' ' || out[start - 1] == '\t')) {
          start--;
        }
      }
      out = out.substring(0, start) + out.substring(end);
    }
    buffer.write(out);
    file.writeAsStringSync(buffer.toString());
  }
  stdout.writeln('removed=$removed kept=$kept files=${files.length}');
}
