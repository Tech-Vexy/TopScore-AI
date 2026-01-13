import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String? videoUrl;
  final File? videoFile;
  final String title;

  const VideoPlayerScreen({
    super.key,
    this.videoUrl,
    this.videoFile,
    required this.title,
  }) : assert(videoUrl != null || videoFile != null, "Provide a URL or a File");

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      if (widget.videoFile != null) {
        _videoController = VideoPlayerController.file(widget.videoFile!);
      } else {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl!),
        );
      }

      await _videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
        // Customize the UI colors
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF6C63FF),
          handleColor: const Color(0xFF6C63FF),
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white24,
        ),
      );

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Could not play video: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadAndShare() async {
    // 1. If it's already a local file, share it directly
    if (widget.videoFile != null) {
      await Share.shareXFiles([
        XFile(widget.videoFile!.path),
      ], text: 'Sharing ${widget.title}');
      return;
    }

    // 2. If Web, standard download is complex, show toast
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Download not supported on Web yet")),
      );
      return;
    }

    // 3. Download from URL to Temp
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Downloading video...")));

      final response = await http.get(Uri.parse(widget.videoUrl!));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final safeTitle = widget.title.replaceAll(RegExp(r'[^\w\s\.]'), '_');
        final fileName = safeTitle.endsWith('.mp4')
            ? safeTitle
            : '$safeTitle.mp4';
        final file = File('${tempDir.path}/$fileName');

        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          await Share.shareXFiles([
            XFile(file.path),
          ], text: 'Sharing ${widget.title}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Download failed: $e")));
      }
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: GoogleFonts.nunito(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: "Share/Download",
            onPressed: _downloadAndShare,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Color(0xFF6C63FF))
              : _errorMessage != null
              ? Text(_errorMessage!, style: const TextStyle(color: Colors.red))
              : Chewie(controller: _chewieController!),
        ),
      ),
    );
  }
}
