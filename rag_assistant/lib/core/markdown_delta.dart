import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Safely convert markdown string → Quill Document.
/// Falls back to plain text document if parsing fails.
Document markdownToDocument(String markdown) {
  try {
    return _parseMarkdown(markdown);
  } catch (_) {
    // Fallback: treat entire content as plain text
    final delta = Delta()..insert('$markdown\n');
    return Document.fromDelta(delta);
  }
}

Document _parseMarkdown(String markdown) {
  final delta = Delta();
  if (markdown.trim().isEmpty) {
    delta.insert('\n');
    return Document.fromDelta(delta);
  }

  final lines = markdown.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Heading
    final headingMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
    if (headingMatch != null) {
      final level = headingMatch.group(1)!.length;
      final text = headingMatch.group(2)!;
      _insertInline(delta, text);
      delta.insert('\n', {'header': level});
      continue;
    }

    // Unordered list
    final ulMatch = RegExp(r'^[\s]*[-*+]\s+(.*)$').firstMatch(line);
    if (ulMatch != null) {
      _insertInline(delta, ulMatch.group(1)!);
      delta.insert('\n', {'list': 'bullet'});
      continue;
    }

    // Ordered list
    final olMatch = RegExp(r'^[\s]*\d+\.\s+(.*)$').firstMatch(line);
    if (olMatch != null) {
      _insertInline(delta, olMatch.group(1)!);
      delta.insert('\n', {'list': 'ordered'});
      continue;
    }

    // Blockquote
    if (line.startsWith('>')) {
      final text = line.replaceFirst(RegExp(r'^>\s*'), '');
      _insertInline(delta, text);
      delta.insert('\n', {'blockquote': true});
      continue;
    }

    // Fenced code block
    if (line.trimLeft().startsWith('```')) {
      final codeLines = <String>[];
      i++;
      while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
        codeLines.add(lines[i]);
        i++;
      }
      for (final codeLine in codeLines) {
        delta.insert(codeLine);
        delta.insert('\n', {'code-block': true});
      }
      continue;
    }

    // Horizontal rule
    if (RegExp(r'^-{3,}$|^\*{3,}$|^_{3,}$').hasMatch(line.trim())) {
      delta.insert('---\n');
      continue;
    }

    // Regular line
    _insertInline(delta, line);
    delta.insert('\n');
  }

  // Ensure proper ending
  final ops = delta.toList();
  if (ops.isEmpty) {
    delta.insert('\n');
  }

  return Document.fromDelta(delta);
}

/// Insert text with inline bold/italic/code formatting.
void _insertInline(Delta delta, String text) {
  if (text.isEmpty) return;

  final regex = RegExp(
    r'(\*\*\*(.+?)\*\*\*)|(\*\*(.+?)\*\*)|(\*(.+?)\*)|(`(.+?)`)',
  );

  var lastEnd = 0;
  for (final match in regex.allMatches(text)) {
    if (match.start > lastEnd) {
      delta.insert(text.substring(lastEnd, match.start));
    }

    if (match.group(2) != null) {
      delta.insert(match.group(2)!, {'bold': true, 'italic': true});
    } else if (match.group(4) != null) {
      delta.insert(match.group(4)!, {'bold': true});
    } else if (match.group(6) != null) {
      delta.insert(match.group(6)!, {'italic': true});
    } else if (match.group(8) != null) {
      delta.insert(match.group(8)!, {'code': true});
    }

    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    delta.insert(text.substring(lastEnd));
  }
}

/// Convert Quill Document → markdown string for storage.
String documentToMarkdown(Document document) {
  try {
    return _deltaToMarkdown(document.toDelta());
  } catch (_) {
    return document.toPlainText();
  }
}

String _deltaToMarkdown(Delta delta) {
  final buffer = StringBuffer();
  final ops = delta.toList();

  // Collect text segments, then apply line-level formatting on \n
  final lineBuffer = StringBuffer();

  for (final op in ops) {
    final data = op.value;
    final attrs = op.attributes ?? {};

    if (data is! String) continue;

    for (var j = 0; j < data.length; j++) {
      if (data[j] == '\n') {
        // Apply line-level formatting
        final lineText = lineBuffer.toString();
        lineBuffer.clear();

        if (attrs.containsKey('header')) {
          final level = attrs['header'] as int;
          buffer.writeln('${'#' * level} $lineText');
        } else if (attrs.containsKey('list')) {
          final listType = attrs['list'];
          if (listType == 'bullet') {
            buffer.writeln('- $lineText');
          } else {
            buffer.writeln('1. $lineText');
          }
        } else if (attrs.containsKey('blockquote')) {
          buffer.writeln('> $lineText');
        } else if (attrs.containsKey('code-block')) {
          if (lineText.isNotEmpty) {
            buffer.writeln('```');
            buffer.writeln(lineText);
            buffer.writeln('```');
          }
        } else {
          buffer.writeln(lineText);
        }
      } else {
        // Accumulate inline text with formatting
        var char = data[j];
        // For multi-char segments, we handle the whole segment at once
        // but since we're iterating char by char for \n detection,
        // we need to buffer and apply formatting later
        lineBuffer.write(char);
      }
    }

    // If the entire op is non-\n text with formatting, apply inline markdown
    if (!data.contains('\n') && data.isNotEmpty) {
      // The text was already written to lineBuffer above.
      // We need to wrap it with formatting markers.
      // Remove what we just wrote and re-add with formatting.
      final rawText = lineBuffer.toString();
      if (attrs.isNotEmpty && rawText.isNotEmpty) {
        // Remove the raw text we just added
        final currentLen = lineBuffer.length;
        final rawLen = data.length;
        if (currentLen >= rawLen) {
          // Rebuild lineBuffer without the last `rawLen` chars, then add formatted
          final prefix = rawText.substring(0, currentLen - rawLen);
          lineBuffer.clear();
          lineBuffer.write(prefix);

          var formatted = data;
          if (attrs.containsKey('bold') && attrs.containsKey('italic')) {
            formatted = '***$data***';
          } else if (attrs.containsKey('bold')) {
            formatted = '**$data**';
          } else if (attrs.containsKey('italic')) {
            formatted = '*$data*';
          } else if (attrs.containsKey('code')) {
            formatted = '`$data`';
          }
          lineBuffer.write(formatted);
        }
      }
    }
  }

  // Flush remaining buffer
  final remaining = lineBuffer.toString();
  if (remaining.isNotEmpty) {
    buffer.write(remaining);
  }

  return buffer.toString().trimRight();
}
