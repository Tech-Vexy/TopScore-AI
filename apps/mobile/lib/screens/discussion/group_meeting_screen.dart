import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/auth_provider.dart';
import '../../services/discussion_service.dart';

class GroupMeetingScreen extends StatefulWidget {
  final String meetingId;
  final String meetingTopic;

  const GroupMeetingScreen({
    super.key,
    required this.meetingId,
    required this.meetingTopic,
  });

  @override
  State<GroupMeetingScreen> createState() => _GroupMeetingScreenState();
}

class _GroupMeetingScreenState extends State<GroupMeetingScreen>
    with WidgetsBindingObserver {
  final DiscussionService _service = DiscussionService();
  final TextEditingController _chatController = TextEditingController();

  bool _isMicOn = false;
  bool _isCamOn = false;
  bool _isHandRaised = false;
  bool _showChat = false;
  bool _hasPermissions = false;
  Timer? _meetingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionsAndJoin();
    _startLocalTimer();
  }

  Future<void> _checkPermissionsAndJoin() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    bool cameraGranted = statuses[Permission.camera]!.isGranted;
    bool micGranted = statuses[Permission.microphone]!.isGranted;

    if (cameraGranted && micGranted) {
      if (mounted) {
        setState(() {
          _hasPermissions = true;
          _isMicOn = true;
        });
        _joinMeeting();
      }
    } else {
      if (mounted) {
        _showPermissionDeniedDialog();
      }
    }
  }

  void _joinMeeting() {
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user != null) {
      _service.joinMeeting(widget.meetingId, user);
      _service.updateMediaState(
        widget.meetingId,
        user.uid,
        isMicOn: _isMicOn,
        isCamOn: _isCamOn,
      );
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Permissions Required"),
        content: const Text(
          "To participate, we need access to your camera and microphone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  void _startLocalTimer() {
    _meetingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _meetingTimer?.cancel();
    _chatController.dispose();
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user != null) {
      _service.leaveMeeting(widget.meetingId, user.uid);
    }
    super.dispose();
  }

  String _formatTimeLeft(int endTimeMillis) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = endTimeMillis - now;
    if (diff <= 0) {
      return "00:00";
    }
    final duration = Duration(milliseconds: diff);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  void _toggleMic() {
    if (!_hasPermissions) {
      _checkPermissionsAndJoin();
      return;
    }
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user == null) {
      return;
    }
    setState(() => _isMicOn = !_isMicOn);
    _service.updateMediaState(widget.meetingId, user.uid, isMicOn: _isMicOn);
  }

  void _toggleCam() {
    if (!_hasPermissions) {
      _checkPermissionsAndJoin();
      return;
    }
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user == null) {
      return;
    }
    setState(() => _isCamOn = !_isCamOn);
    _service.updateMediaState(widget.meetingId, user.uid, isCamOn: _isCamOn);
  }

  void _toggleHand() {
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user == null) {
      return;
    }
    setState(() => _isHandRaised = !_isHandRaised);
    _service.toggleHandRaise(widget.meetingId, user.uid, _isHandRaised);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isHandRaised ? "You raised your hand ✋" : "Hand lowered",
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _sendMessage() {
    if (_chatController.text.trim().isEmpty) {
      return;
    }
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user == null) {
      return;
    }
    _service.sendMessage(
      widget.meetingId,
      user.uid,
      user.displayName,
      _chatController.text.trim(),
    );
    _chatController.clear();
  }

  void _showInviteSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C), // Dark theme match
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Invite Participants",
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Topic: ${widget.meetingTopic}",
              style: GoogleFonts.nunito(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.meetingId,
                      style: GoogleFonts.robotoMono(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Color(0xFF6C63FF)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.meetingId));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Code copied!")),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  SharePlus.instance.share(
                    ShareParams(
                      text: "Join my study session: ${widget.meetingTopic}\nCode: ${widget.meetingId}",
                    ),
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text("Share Invite Link"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF202124),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: StreamBuilder<Map<String, dynamic>?>(
          stream: _service.streamMeeting(widget.meetingId),
          builder: (context, snapshot) {
            String timeDisplay = "--:--";
            if (snapshot.hasData && snapshot.data != null) {
              final endTime = snapshot.data!['endsAt'] as int? ?? 0;
              timeDisplay = _formatTimeLeft(endTime);
            }
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.meetingTopic,
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "Code: ${widget.meetingId}",
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        timeDisplay,
                        style: GoogleFonts.robotoMono(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
            onPressed: _showInviteSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: !_hasPermissions
                ? const Center(
                    child: Text(
                      "Camera/Mic access required",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : StreamBuilder<Map<String, dynamic>?>(
                    stream: _service.streamMeeting(widget.meetingId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data == null) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }
                      final participantsMap =
                          snapshot.data!['participants']
                              as Map<dynamic, dynamic>? ??
                          {};
                      final participants = participantsMap.values.toList();
                      if (participants.isEmpty) {
                        return const Center(
                          child: Text(
                            "Waiting...",
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 100.0),
                        child: _buildParticipantGrid(participants),
                      );
                    },
                  ),
          ),
          if (_showChat)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showChat = false),
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    onTap: () {},
                    child: _buildChatPanel(),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(child: _buildControlBar()),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantGrid(List<dynamic> participants) {
    int count = participants.length;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: count <= 2 ? 1 : 2,
        childAspectRatio: count <= 2 ? 1.3 : 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: count,
      itemBuilder: (context, index) =>
          _buildParticipantTile(participants[index]),
    );
  }

  Widget _buildParticipantTile(dynamic participant) {
    bool isMicOn = participant['isMicOn'] ?? false;
    bool isHandRaised = participant['isHandRaised'] ?? false;
    String name = participant['name'] ?? 'User';
    String id = participant['id'] ?? '';
    bool isAi = id == 'ai_tutor_bot';

    return Container(
      decoration: BoxDecoration(
        color: isAi ? const Color(0xFF2D1A4E) : const Color(0xFF3C4043),
        borderRadius: BorderRadius.circular(16),
        border: isAi || isMicOn
            ? Border.all(color: const Color(0xFF6C63FF), width: 2)
            : null,
      ),
      child: Stack(
        children: [
          Center(
            child: isAi
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        FontAwesomeIcons.robot,
                        size: 40,
                        color: Color(0xFF6C63FF),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "MODERATOR",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                : CircleAvatar(
                    radius: 35,
                    backgroundColor:
                        Colors.primaries[name.length % Colors.primaries.length],
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.nunito(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          if (isHandRaised)
            const Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 14,
                child: Text("✋", style: TextStyle(fontSize: 16)),
              ),
            ),
          // OVERFLOW FIX: Added right: 12 to prevent RenderFlex errors
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                if (!isMicOn)
                  Container(
                    padding: const EdgeInsets.all(4),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_off,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        const Shadow(color: Colors.black, blurRadius: 2),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _controlButton(
            icon: _isMicOn ? Icons.mic : Icons.mic_off,
            color: _isMicOn ? Colors.grey[800]! : Colors.redAccent,
            iconColor: Colors.white,
            onTap: _toggleMic,
          ),
          _controlButton(
            icon: _isCamOn ? Icons.videocam : Icons.videocam_off,
            color: _isCamOn ? Colors.grey[800]! : Colors.redAccent,
            iconColor: Colors.white,
            onTap: _toggleCam,
          ),
          _controlButton(
            icon: Icons.back_hand,
            color: _isHandRaised ? const Color(0xFF8AB4F8) : Colors.grey[800]!,
            iconColor: _isHandRaised ? Colors.black : Colors.white,
            onTap: _toggleHand,
          ),
          _controlButton(
            icon: Icons.chat_bubble_outline,
            color: Colors.grey[800]!,
            iconColor: Colors.white,
            onTap: () => setState(() => _showChat = !_showChat),
          ),
          _controlButton(
            icon: Icons.call_end,
            color: Colors.red,
            iconColor: Colors.white,
            width: 60,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    double width = 50,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: width,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
      ),
    );
  }

  // THEME FIX: Dark background for chat panel to match meeting dark theme
  Widget _buildChatPanel() {
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "In-Call Messages",
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => setState(() => _showChat = false),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _service.streamChat(widget.meetingId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      "No messages yet",
                      style: GoogleFonts.nunito(color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['senderId'] == user?.uid;
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFF6C63FF)
                              : const Color(0xFF3C4043),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg['senderName'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isMe ? Colors.white70 : Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              msg['text'] ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // SafeArea padding to avoid keyboard overlap
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Send a message...",
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF6C63FF),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
