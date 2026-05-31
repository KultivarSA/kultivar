import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/error_reporter.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MarkdownView
//
// A purposefully small markdown renderer for the legal docs (privacy
// policy, terms of service).  We don't depend on `flutter_markdown`
// because:
//
//   • Our content is constrained — H1/H2/H3, paragraphs, bullet
//     lists, **bold**, *italic*, `inline code`, [links](url), and
//     `---` horizontal rules.  No tables, no images, no code blocks.
//   • Pulling in `flutter_markdown` would add ~70 KB and a transitive
//     `markdown` package; we'd then have to fight its TextStyle
//     theming to use AppTypography tokens.
//   • Owning the renderer lets every paragraph + heading flow from
//     `AppTypography.*` directly, so the legal doc reads in the same
//     font + colour as the rest of the app.
//
// Parsing strategy is line-by-line — the supported subset doesn't
// need a full lexer.  Inline spans (bold, italic, code, links) are
// handled per-paragraph by [_parseInline].
// ─────────────────────────────────────────────────────────────────────────────

class MarkdownView extends StatelessWidget {
  /// The raw markdown source.  Multi-line strings are fine.
  final String source;

  /// Padding around the rendered content.  Defaults to the page
  /// padding token so legal screens line up with the rest of the app.
  final EdgeInsetsGeometry padding;

  const MarkdownView({
    super.key,
    required this.source,
    this.padding = const EdgeInsets.all(AppSpacing.pagePadding),
  });

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(source);
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final block in blocks) _renderBlock(context, block),
        ],
      ),
    );
  }

  // ── Block-level rendering ─────────────────────────────────────────

  Widget _renderBlock(BuildContext context, _Block block) {
    switch (block.kind) {
      case _BlockKind.h1:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            block.text,
            style: AppTypography.displayMedium(context).copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case _BlockKind.h2:
        return Padding(
          padding: const EdgeInsets.only(
              top: AppSpacing.lg, bottom: AppSpacing.sm),
          child: Text(
            block.text,
            style: AppTypography.headlineMedium(context)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        );
      case _BlockKind.h3:
        return Padding(
          padding: const EdgeInsets.only(
              top: AppSpacing.md, bottom: AppSpacing.xs),
          child: Text(
            block.text,
            style: AppTypography.headlineSmall(context),
          ),
        );
      case _BlockKind.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: SelectableText.rich(
            TextSpan(
              children: _parseInline(context, block.text),
            ),
            style: AppTypography.bodyMedium(context).copyWith(height: 1.55),
          ),
        );
      case _BlockKind.bullet:
        return Padding(
          padding: const EdgeInsets.only(
              left: AppSpacing.xs, bottom: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                // Vertical nudge keeps the bullet glyph aligned with
                // the cap height of the first line.
                padding: const EdgeInsets.only(top: 7, right: AppSpacing.sm),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: context.colTextSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: SelectableText.rich(
                  TextSpan(
                    children: _parseInline(context, block.text),
                  ),
                  style:
                      AppTypography.bodyMedium(context).copyWith(height: 1.55),
                ),
              ),
            ],
          ),
        );
      case _BlockKind.rule:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Divider(color: context.colBorderFaint, height: 1),
        );
    }
  }

  // ── Block-level parsing ───────────────────────────────────────────

  /// Splits [source] into a list of [_Block] entries.  Recognises:
  ///   • `# ` / `## ` / `### `      → heading levels
  ///   • `- ` / `* ` line prefix    → bullet item
  ///   • `---` on its own line       → horizontal rule
  ///   • blank line                  → paragraph break
  ///   • anything else               → wrapped into the current paragraph
  static List<_Block> _parseBlocks(String src) {
    final lines = src.split('\n');
    final blocks = <_Block>[];
    final paragraphBuf = StringBuffer();

    void flushParagraph() {
      final text = paragraphBuf.toString().trim();
      if (text.isNotEmpty) {
        blocks.add(_Block(_BlockKind.paragraph, text));
      }
      paragraphBuf.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();

      if (line.isEmpty) {
        flushParagraph();
        continue;
      }

      // Horizontal rule.
      if (line.trim() == '---' || line.trim() == '***') {
        flushParagraph();
        blocks.add(const _Block(_BlockKind.rule, ''));
        continue;
      }

      // Headings — H1/H2/H3 only.
      if (line.startsWith('### ')) {
        flushParagraph();
        blocks.add(_Block(_BlockKind.h3, line.substring(4)));
        continue;
      }
      if (line.startsWith('## ')) {
        flushParagraph();
        blocks.add(_Block(_BlockKind.h2, line.substring(3)));
        continue;
      }
      if (line.startsWith('# ')) {
        flushParagraph();
        blocks.add(_Block(_BlockKind.h1, line.substring(2)));
        continue;
      }

      // Bullet item.
      if (line.startsWith('- ') || line.startsWith('* ')) {
        flushParagraph();
        blocks.add(_Block(_BlockKind.bullet, line.substring(2)));
        continue;
      }

      // Continuation of a bullet (indented or extra-wrapped line that
      // begins the buffer mid-bullet) — merge into preceding paragraph
      // or appended to the previous bullet if the buffer is empty.
      if (paragraphBuf.isEmpty &&
          blocks.isNotEmpty &&
          blocks.last.kind == _BlockKind.bullet &&
          (raw.startsWith('  ') || raw.startsWith('\t'))) {
        blocks[blocks.length - 1] = _Block(
          _BlockKind.bullet,
          '${blocks.last.text} ${line.trim()}',
        );
        continue;
      }

      // Otherwise: accumulate into the current paragraph buffer.
      if (paragraphBuf.isNotEmpty) paragraphBuf.write(' ');
      paragraphBuf.write(line);
    }

    flushParagraph();
    return blocks;
  }

  // ── Inline parsing ────────────────────────────────────────────────

  /// Parses **bold**, *italic*, `inline code`, and `[label](url)`
  /// markers inside a single paragraph or bullet.  Returns a flat list
  /// of [TextSpan]s ready to drop into [SelectableText.rich].
  ///
  /// Deliberately not a full markdown parser — overlapping or nested
  /// markers are handled left-to-right with a single regex pass.
  static List<InlineSpan> _parseInline(BuildContext context, String text) {
    final spans = <InlineSpan>[];
    final baseStyle =
        AppTypography.bodyMedium(context).copyWith(height: 1.55);

    // Order matters: longest / most-specific patterns first.
    // Group 1 = bold, 2 = italic, 3 = code, 4 = link label, 5 = link url.
    final pattern = RegExp(
      r'\*\*(.+?)\*\*'
      r'|(?<!\*)\*([^*\s][^*]*?)\*(?!\*)'
      r'|`([^`]+?)`'
      r'|\[([^\]]+?)\]\(([^)]+?)\)',
    );

    var lastIndex = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }

      final boldGroup = match.group(1);
      final italicGroup = match.group(2);
      final codeGroup = match.group(3);
      final linkLabel = match.group(4);
      final linkUrl = match.group(5);

      if (boldGroup != null) {
        spans.add(TextSpan(
          text: boldGroup,
          style:
              baseStyle.copyWith(fontWeight: FontWeight.w700),
        ));
      } else if (italicGroup != null) {
        spans.add(TextSpan(
          text: italicGroup,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (codeGroup != null) {
        spans.add(TextSpan(
          text: codeGroup,
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            fontSize: (baseStyle.fontSize ?? 14) - 0.5,
            backgroundColor: context.colSurface2,
          ),
        ));
      } else if (linkLabel != null && linkUrl != null) {
        spans.add(TextSpan(
          text: linkLabel,
          style: baseStyle.copyWith(
            color: AppColors.primary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _openUrl(linkUrl),
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return spans;
  }

  /// Launches an external URL.  Wrapped in a try/catch + ErrorReporter
  /// so a malformed link in the markdown source can never crash the
  /// legal screen.
  static Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, stack) {
      ErrorReporter.report('MarkdownView._openUrl', e, stack,
          {'url': url});
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal block representation
// ─────────────────────────────────────────────────────────────────────────────

enum _BlockKind { h1, h2, h3, paragraph, bullet, rule }

class _Block {
  final _BlockKind kind;
  final String text;
  const _Block(this.kind, this.text);
}
