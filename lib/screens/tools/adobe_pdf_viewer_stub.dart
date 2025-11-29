import 'package:flutter/material.dart';

class AdobePdfViewerWeb extends StatelessWidget {
  final String url;
  final String fileName;
  final String clientId;

  const AdobePdfViewerWeb({
    super.key,
    required this.url,
    required this.fileName,
    this.clientId = '',
  });

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Adobe PDF Viewer is only available on Web'));
  }
}
