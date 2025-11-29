class DownloadTaskModel {
  final String id;
  final String resourceId;
  final String localPath;
  final int downloadedAt;
  final String filename;

  DownloadTaskModel({
    required this.id,
    required this.resourceId,
    required this.localPath,
    required this.downloadedAt,
    required this.filename,
  });

  factory DownloadTaskModel.fromJson(Map<String, dynamic> json) {
    return DownloadTaskModel(
      id: json['id'],
      resourceId: json['resourceId'],
      localPath: json['localPath'],
      downloadedAt: json['downloadedAt'],
      filename: json['filename'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'resourceId': resourceId,
      'localPath': localPath,
      'downloadedAt': downloadedAt,
      'filename': filename,
    };
  }
}
