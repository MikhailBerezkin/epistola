import 'dart:io';

import '../models/avatar_upload_request.dart';

class AvatarImageProcessor {
  Future<File> prepareForUpload(AvatarUploadRequest request) async {
    final safeFileName = request.fileName.isNotEmpty
        ? request.fileName
        : 'avatar.jpg';

    final tempPath = '${Directory.systemTemp.path}/$safeFileName';
    final file = File(tempPath);

    await file.writeAsBytes(request.bytes, flush: true);

    return file;
  }
}
