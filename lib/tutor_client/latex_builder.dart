import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_math_fork/flutter_math.dart';

class LatexElementBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    if (text.isEmpty) return const SizedBox();

    final isDisplay = element.attributes['style'] == 'display';

    return Math.tex(
      text,
      textStyle: preferredStyle,
      mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
    );
  }
}

class LatexInlineSyntax extends md.InlineSyntax {
  LatexInlineSyntax() : super(r'(\$\$?)([^$]+?)\1');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final delimiter = match.group(1);
    final latex = match.group(2) ?? '';
    final element = md.Element('latex', [md.Text(latex)]);
    if (delimiter == r'$$') {
      element.attributes['style'] = 'display';
    }
    parser.addNode(element);
    return true;
  }
}
