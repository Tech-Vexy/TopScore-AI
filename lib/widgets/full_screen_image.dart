import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  final bool isBase64;
  final Uint8List? base64Bytes;
  final String tag;

  const FullScreenImage({
    super.key,
    required this.imageUrl,
    this.isBase64 = false,
    this.base64Bytes,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareImage(context),
          ),
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _downloadImage(context),
            ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: tag,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: isBase64 && base64Bytes != null
                ? Image.memory(base64Bytes!, fit: BoxFit.contain)
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareImage(BuildContext context) async {
    try {
      if (isBase64 && base64Bytes != null) {
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sharing not supported on web for base64 yet'),
            ),
          );
          return;
        }
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/shared_image.png').create();
        await file.writeAsBytes(base64Bytes!);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Shared from TopScore AI',
          ),
        );
      } else {
        // Download first then share
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sharing not supported on web yet')),
          );
          return;
        }
        final response = await http.get(Uri.parse(imageUrl));
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/shared_image.png').create();
        await file.writeAsBytes(response.bodyBytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Shared from TopScore AI',
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing image: $e')));
      }
    }
  }

  Future<void> _downloadImage(BuildContext context) async {
    try {
      // Check permissions
      if (Platform.isAndroid && !kIsWeb) {
        // Basic sanity check, typically path_provider handles writing to app docs/cache without extra perms
        // But "Download" folder requires storage perm on older Android.
        // On Android 13 (SDK 33), WRITE_EXTERNAL_STORAGE is deprecated.
      }

      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }

      Uint8List bytes;
      if (isBase64 && base64Bytes != null) {
        bytes = base64Bytes!;
      } else {
        final response = await http.get(Uri.parse(imageUrl));
        bytes = response.bodyBytes;
      }

      // Save to Downloads directory (Android) or Documents (iOS)
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        final file = File(
          '${directory.path}/topscore_image_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(bytes);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Saved to ${file.path}')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error downloading image: $e')));
      }
    }
  }
}
