import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// 1. Custom Syntax Parser for LaTeX (supports $ and \(...\) / \[...\] delimiters)
class LatexSyntax extends md.InlineSyntax {
  // Updated Regex to support both $ and \( \) / \[ \] delimiters
  // Matches: $$...$$ (block), $...$ (inline), \[...\] (block), \(...\) (inline)
  LatexSyntax() : super(r'(\$\$[\s\S]*?\$\$)|(\$[^$\n]+\$)|(\\\([\s\S]*?\\\))');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final matchText = match[0]!;

    // Determine if block or inline based on delimiters
    bool isBlock;
    String content;

    if (matchText.startsWith(r'$$') && matchText.endsWith(r'$$')) {
      // Block: $$...$$
      isBlock = true;
      content = matchText.substring(2, matchText.length - 2);
    } else if (matchText.startsWith(r'\(') && matchText.endsWith(r'\)')) {
      // Inline: \(...\)
      isBlock = false;
      content = matchText.substring(2, matchText.length - 2);
    } else {
      // Inline: $...$
      isBlock = false;
      content = matchText.substring(1, matchText.length - 1);
    }

    // Clean up content
    final cleanContent = content.trim();

    md.Element el = md.Element.text('latex', cleanContent);
    el.attributes['type'] = isBlock ? 'block' : 'inline';
    parser.addNode(el);
    return true;
  }
}

/// 1b. Block Syntax for display LaTeX \[ ... \]
class LatexBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\s*\\\[');

  @override
  md.Node parse(md.BlockParser parser) {
    var lines = <String>[];
    parser.advance(); // consume the opening \[ line

    while (!parser.isDone) {
      var line = parser.current.content;
      if (line.trim().endsWith(r'\]')) {
        // Found the closing \]
        lines.add(line.substring(0, line.lastIndexOf(r'\]')));
        parser.advance();
        break;
      }
      lines.add(line);
      parser.advance();
    }

    final content = lines.join('\n').trim();
    md.Element el = md.Element.text('latex', content);
    el.attributes['type'] = 'block';
    return el;
  }
}

/// 2. Builder to render the LaTeX using flutter_math_fork
class LatexElementBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final content = element.textContent;
    final isBlock = element.attributes['type'] == 'block';

    try {
      if (isBlock) {
        return Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              content,
              textStyle: preferredStyle?.copyWith(
                fontSize: (preferredStyle.fontSize ?? 14) + 2,
              ),
              mathStyle: MathStyle.display,
            ),
          ),
        );
      } else {
        return Math.tex(
          content,
          textStyle: preferredStyle,
          mathStyle: MathStyle.text,
        );
      }
    } catch (e) {
      return Text(content, style: preferredStyle); // Fallback if TeX error
    }
  }
}

/// 3. Custom Syntax for Theories and Laws
/// Matches: :::theory ... :::
class TheorySyntax extends md.InlineSyntax {
  TheorySyntax() : super(r':::theory\s+([\s\S]*?)\s*:::');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final content = match[1]!.trim();
    md.Element el = md.Element.text('theory', content);
    parser.addNode(el);
    return true;
  }
}

/// 4. Custom Syntax for Laws
/// Matches: :::law ... :::
class LawSyntax extends md.InlineSyntax {
  LawSyntax() : super(r':::law\s+([\s\S]*?)\s*:::');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final content = match[1]!.trim();
    md.Element el = md.Element.text('law', content);
    parser.addNode(el);
    return true;
  }
}

/// 5. Custom Syntax for Important Facts
/// Matches: :::fact ... :::
class FactSyntax extends md.InlineSyntax {
  FactSyntax() : super(r':::fact\s+([\s\S]*?)\s*:::');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final content = match[1]!.trim();
    md.Element el = md.Element.text('fact', content);
    parser.addNode(el);
    return true;
  }
}

/// 5b. Custom Syntax for Important/Warning/Alert
/// Matches: :::important ... :::
class ImportantSyntax extends md.InlineSyntax {
  ImportantSyntax() : super(r':::important\s+([\s\S]*?)\s*:::');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final content = match[1]!.trim();
    md.Element el = md.Element.text('important', content);
    parser.addNode(el);
    return true;
  }
}

/// 6. Builder to render Theory/Law/Fact with premium styling
class TheoryElementBuilder extends MarkdownElementBuilder {
  final Color color;
  final String label;
  final IconData icon;

  TheoryElementBuilder({
    required this.color,
    required this.label,
    required this.icon,
  });

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final content = element.textContent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: (preferredStyle ?? const TextStyle()).copyWith(
              color: color.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
              fontSize: 16,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// 7. Pre-processor to handle HTML tags like <u> and escaped newlines
/// Flutter Markdown strips HTML by default. We map <u> to simple Bold or Italic.
String cleanContent(String input) {
  // Replace escaped newline characters with actual newlines
  // Handle both \\n (escaped in JSON) and \n (literal string)
  return input
      .replaceAll('\\n', '\n') // Convert escaped newlines to actual newlines
      .replaceAll('<u>', '') // Option A: Just remove the tag (cleanest)
      .replaceAll('</u>', '');
}
