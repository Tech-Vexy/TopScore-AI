import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// 1. Custom Syntax Parser for LaTeX (supports $ and \(...\) / \[...\] delimiters)
class LatexSyntax extends md.InlineSyntax {
  // Updated Regex to support both $ and \( \) / \[ \] delimiters
  // Matches: $$...$$ (block), $...$ (inline), \[...\] (block), \(...\) (inline)
  LatexSyntax()
      : super(
            r'(\$\$[\s\S]*?\$\$)|(\\\[[\s\S]*?\\\])|(\$[^$\n]+\$)|(\\\([\s\S]*?\\\))');

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
    } else if (matchText.startsWith(r'\[') && matchText.endsWith(r'\]')) {
      // Block: \[...\]
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

/// 3. Pre-processor to handle HTML tags like <u>
/// Flutter Markdown strips HTML by default. We map <u> to simple Bold or Italic.
String cleanContent(String input) {
  // Replace <u>text</u> with **text** (Bold) or similar.
  // Underlines are often bad in chat apps (look like links).
  return input
          .replaceAll('<u>', '') // Option A: Just remove the tag (cleanest)
          .replaceAll('</u>', '')
      // Option B: Map to bold -> .replaceAll('<u>', '**').replaceAll('</u>', '**')
      ;
}
