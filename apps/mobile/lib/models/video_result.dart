class VideoResult {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String videoUrl;
  final String duration;
  final String source; // e.g., "YouTube", "Khan Academy"

  VideoResult({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.duration,
    required this.source,
  });

  factory VideoResult.fromJson(Map<String, dynamic> json) {
    return VideoResult(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
      duration: json['duration'] ?? '',
      source: json['source'] ?? 'Unknown',
    );
  }
}
