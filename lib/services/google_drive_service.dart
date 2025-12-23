import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleDriveService {
  final GoogleSignIn _googleSignIn;

  GoogleDriveService(this._googleSignIn);

  Future<List<drive.File>> searchFiles(String query) async {
    try {
      final client = await _googleSignIn.authenticatedClient();
      if (client == null) {
        debugPrint('User not authenticated with Google or client is null');
        return [];
      }

      final driveApi = drive.DriveApi(client);

      // Basic search: name contains query, not trashed, not a folder
      final q =
          "name contains '$query' and mimeType != 'application/vnd.google-apps.folder' and trashed = false";

      final fileList = await driveApi.files.list(
        q: q,
        $fields:
            'files(id, name, mimeType, webViewLink, thumbnailLink, iconLink)',
        pageSize: 20,
      );

      return fileList.files ?? [];
    } catch (e) {
      debugPrint('Error searching Drive files: $e');
      return [];
    }
  }
}
