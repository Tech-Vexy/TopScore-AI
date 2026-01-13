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

    // 1. Encode diagram to Base64 for generic mermaid.ink usage
    // Format: https://mermaid.ink/img/<base64>
    // Note: mermaid.ink expects specific encoding, usually simple base64 works for standard logic
    // but complex chars might need uri encoding. Clean base64 is safest.
    final encoded = base64Encode(utf8.encode(text));
    final imageUrl = 'https://mermaid.ink/img/$encoded?bgColor=white';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.schema_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Diagram',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(8),
            ),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => Container(
                height: 150,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to render diagram',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      // Optional: Show source code on error
                      const SizedBox(height: 8),
                      ExpansionTile(
                        title: const Text(
                          "View Source",
                          style: TextStyle(fontSize: 12),
                        ),
                        children: [
                          SelectableText(
                            text,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
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
