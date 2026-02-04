import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:cached_network_image/cached_network_image.dart';

class MermaidElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    if (text.isEmpty) return null;

    return _MermaidDiagramWidget(code: text);
  }
}

class _MermaidDiagramWidget extends StatelessWidget {
  final String code;

  const _MermaidDiagramWidget({required this.code});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Theme Awareness
    // mermaid.ink supports: ?theme=dark&bgColor=...
    final encoded = base64Encode(utf8.encode(code));
    final themeParam = isDark ? 'dark' : 'default';
    final bgColorParam = isDark ? '000000' : 'FFFFFF'; // Hex without #

    final imageUrl =
        'https://mermaid.ink/img/$encoded?theme=$themeParam&bgColor=$bgColorParam';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      height: 300, // Fixed height container for scrollable area
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey.shade100,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.schema,
                    size: 16,
                    color: isDark ? Colors.white70 : Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(
                  'Diagram',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                const Tooltip(
                  message: "Pinch to zoom",
                  child: Icon(Icons.zoom_in, size: 16, color: Colors.grey),
                ),
              ],
            ),
          ),

          // 2. Zoomable Content
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                boundaryMargin: const EdgeInsets.all(20),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: isDark ? Colors.white : null),
                    ),
                  ),
                  errorWidget: (context, url, error) =>
                      _buildErrorWidget(context, isDark),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined,
                color: Colors.redAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              'Failed to render diagram',
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey.shade600),
            ),
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Mermaid Source"),
                    content: SingleChildScrollView(child: SelectableText(code)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Close"))
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.code, size: 16),
              label: const Text("View Source"),
            )
          ],
        ),
      ),
    );
  }
}

class MermaidBlockSyntax extends md.BlockSyntax {
  @override
  md.Node parse(md.BlockParser parser) {
    // Determine the content logic
    // content should be everything between the fences
    // parser.details.lines includes the fences in some versions, but standard BlockSyntax might require handling.
    // However, for FencedCodeBlock, it's usually handled by the parser.
    // We want to capture the content.
    // Let's rely on standard current line consumption.

    // Actually, simpler implementation for a known block structure:
    var linesToConsume = <String>[];
    // consumed first line by pattern match
    parser.advance();

    while (!parser.isDone) {
      if (parser.current.content.startsWith('```')) {
        parser.advance();
        break;
      }
      linesToConsume.add(parser.current.content);
      parser.advance();
    }

    final content = linesToConsume.join('\n');
    return md.Element('mermaid', [md.Text(content)]);
  }

  @override
  RegExp get pattern => RegExp(r'^`{3,}mermaid$');
}
