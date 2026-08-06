import 'package:flutter/material.dart';

import '../theme/aquila_theme.dart';

/// Lightweight markdown renderer matching the subset the web app's
/// `renderMarkdown` supports: `#`/`##`/`###` headings, `**bold**`, `*italic*`,
/// fenced & inline code, `- ` bullet lists, numbered lists, and `---` rules.
/// Chosen over `flutter_markdown` to keep the look pixel-consistent with web.
class MarkdownRenderer {
  const MarkdownRenderer();

  static List<InlineSpan> _parseInline(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'`([^`]+)`|\*\*(.+?)\*\*|\*([^*]+)\*');
    int start = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > start) {
        spans.add(TextSpan(text: text.substring(start, m.start), style: base));
      }
      final TextStyle style;
      if (m.group(1) != null) {
        style = base.copyWith(
          fontFamily: AquilaColors.fontMono,
          fontSize: (base.fontSize ?? 14) - 1,
          backgroundColor: AquilaColors.accent.withValues(alpha: 0.10),
        );
      } else if (m.group(2) != null) {
        style = base.copyWith(fontWeight: FontWeight.w700);
      } else {
        style = base.copyWith(fontStyle: FontStyle.italic);
      }
      spans.add(TextSpan(
        text: m.group(1) ?? m.group(2) ?? m.group(3) ?? '',
        style: style,
      ));
      start = m.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: base));
    }
    return spans;
  }

  Widget _codeBlock(String code, AquilaThemeExt ext) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ext.bgInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ext.border),
      ),
      child: Text(
        code.trim(),
        style: TextStyle(
          fontFamily: AquilaColors.fontMono,
          fontSize: 13,
          height: 1.5,
          color: ext.textPrimary,
        ),
      ),
    );
  }

  Widget _listRow(String marker, String content, TextStyle base, AquilaThemeExt ext) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(marker, style: ext.monoMicro(12, color: AquilaColors.accent)),
          ),
          Expanded(child: Text.rich(TextSpan(children: _parseInline(content, base)))),
        ],
      ),
    );
  }

  /// Renders the full markdown [text] into a column of styled blocks.
  Widget render(String text, BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    final base = TextStyle(
      fontFamily: AquilaColors.fontMain,
      fontSize: 14.5,
      height: 1.55,
      color: ext.textPrimary,
    );

    final lines = <Widget>[];
    var inFence = false;
    final fenceBuffer = StringBuffer();

    void flushFence() {
      if (!inFence) return;
      lines.add(_codeBlock(fenceBuffer.toString(), ext));
      fenceBuffer.clear();
      inFence = false;
    }

    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      final trimmed = line.trim();

      if (trimmed.startsWith('```')) {
        flushFence();
        inFence = !inFence;
        continue;
      }
      if (inFence) {
        fenceBuffer.writeln(line);
        continue;
      }
      if (trimmed.isEmpty) {
        flushFence();
        continue;
      }
      if (trimmed == '---') {
        flushFence();
        lines.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(color: AquilaColors.borderStrong),
        ));
        continue;
      }

      final h = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(trimmed);
      if (h != null) {
        flushFence();
        final size = h.group(1)!.length == 1
            ? 18.0
            : (h.group(1)!.length == 2 ? 16.0 : 15.0);
        lines.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text.rich(
            TextSpan(
              style: base.copyWith(fontSize: size, fontWeight: FontWeight.w700),
              children: _parseInline(h.group(2)!, base),
            ),
          ),
        ));
        continue;
      }

      final ol = RegExp(r'^\s*\d+\.\s+(.*)$').firstMatch(line);
      if (ol != null) {
        flushFence();
        lines.add(_listRow('${ol.group(0)!.trim().split('.')[0]}.', ol.group(1)!, base, ext));
        continue;
      }

      if (RegExp(r'^\s*[-*]\s+').hasMatch(line)) {
        flushFence();
        lines.add(_listRow('•', trimmed.replaceFirst(RegExp(r'^[-*]\s+'), ''), base, ext));
        continue;
      }

      flushFence();
      lines.add(Text.rich(TextSpan(children: _parseInline(trimmed, base))));
    }
    flushFence();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final l in lines) Padding(padding: const EdgeInsets.only(bottom: 3), child: l),
      ],
    );
  }
}