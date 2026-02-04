import 'package:flutter/material.dart';
import '../tutor_client/audio_playback_queue.dart';

/// Speed control widget for audio playback
class PlaybackSpeedControl extends StatelessWidget {
  final AudioPlaybackQueue audioQueue;
  final VoidCallback? onSpeedChanged;

  const PlaybackSpeedControl({
    super.key,
    required this.audioQueue,
    this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AudioQueueState>(
      stream: audioQueue.stateStream,
      builder: (context, snapshot) {
        final currentSpeed = audioQueue.playbackSpeed;

        return PopupMenuButton<double>(
          icon: Icon(
            Icons.speed,
            color: Theme.of(context).primaryColor,
          ),
          tooltip: 'Playback Speed: ${currentSpeed}x',
          onSelected: (speed) {
            audioQueue.setSpeed(speed);
            onSpeedChanged?.call();
          },
          itemBuilder: (context) => [
            _buildSpeedItem(0.5, currentSpeed, 'Slow'),
            _buildSpeedItem(0.75, currentSpeed, 'Slower'),
            _buildSpeedItem(1.0, currentSpeed, 'Normal'),
            _buildSpeedItem(1.25, currentSpeed, 'Faster'),
            _buildSpeedItem(1.5, currentSpeed, 'Fast'),
            _buildSpeedItem(2.0, currentSpeed, 'Very Fast'),
          ],
        );
      },
    );
  }

  PopupMenuItem<double> _buildSpeedItem(
    double speed,
    double currentSpeed,
    String label,
  ) {
    final isSelected = (speed - currentSpeed).abs() < 0.01;

    return PopupMenuItem<double>(
      value: speed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${speed}x',
            style: TextStyle(
              color: Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.check, size: 16, color: Colors.green),
            ),
        ],
      ),
    );
  }
}

/// Compact speed selector with preset buttons
class CompactSpeedSelector extends StatelessWidget {
  final AudioPlaybackQueue audioQueue;
  final VoidCallback? onSpeedChanged;

  const CompactSpeedSelector({
    super.key,
    required this.audioQueue,
    this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AudioQueueState>(
      stream: audioQueue.stateStream,
      builder: (context, snapshot) {
        final currentSpeed = audioQueue.playbackSpeed;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            ...[0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
              final isSelected = (speed - currentSpeed).abs() < 0.01;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () {
                    audioQueue.setSpeed(speed);
                    onSpeedChanged?.call();
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${speed}x',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.grey,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

/// Slider-based speed control for fine-tuned adjustment
class SpeedSlider extends StatelessWidget {
  final AudioPlaybackQueue audioQueue;
  final VoidCallback? onSpeedChanged;

  const SpeedSlider({
    super.key,
    required this.audioQueue,
    this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AudioQueueState>(
      stream: audioQueue.stateStream,
      builder: (context, snapshot) {
        final currentSpeed = audioQueue.playbackSpeed;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Speed',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${currentSpeed.toStringAsFixed(2)}x',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: currentSpeed,
              min: 0.5,
              max: 2.0,
              divisions: 30,
              label: '${currentSpeed.toStringAsFixed(2)}x',
              onChanged: (value) {
                audioQueue.setSpeed(value);
              },
              onChangeEnd: (value) {
                onSpeedChanged?.call();
              },
            ),
          ],
        );
      },
    );
  }
}
