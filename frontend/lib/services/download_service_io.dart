import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadService {
  static Future<String> downloadFile({
    required String url,
    required String fileName,
    void Function(int received, int total)? onProgress,
  }) async {
    if (url.trim().isEmpty) {
      throw Exception("Download URL is empty.");
    }

    final hasPermission = await _requestStoragePermission();

    if (!hasPermission) {
      throw Exception("Storage permission was denied.");
    }

    final safeName = _safeFileName(fileName);
    final dir = await _downloadDirectory();

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final savePath = "${dir.path}/$safeName";

    final dio = Dio();

    await dio.download(
      url,
      savePath,
      onReceiveProgress: onProgress,
      options: Options(
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 3),
        sendTimeout: const Duration(minutes: 3),
      ),
    );

    return savePath;
  }

  static Future<void> openDownloadedFile(String path) async {
    if (path.trim().isEmpty) return;
    await OpenFilex.open(path);
  }

  static Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final photosStatus = await Permission.photos.request();
    final videosStatus = await Permission.videos.request();
    final storageStatus = await Permission.storage.request();

    return photosStatus.isGranted ||
        videosStatus.isGranted ||
        storageStatus.isGranted ||
        photosStatus.isLimited;
  }

  static Future<Directory> _downloadDirectory() async {
    if (Platform.isAndroid) {
      final downloadsDir = Directory("/storage/emulated/0/Download/Lensia");

      try {
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }

        return downloadsDir;
      } catch (_) {
        final externalDir = await getExternalStorageDirectory();

        if (externalDir != null) {
          final fallbackDir = Directory("${externalDir.path}/LensiaDownloads");

          if (!await fallbackDir.exists()) {
            await fallbackDir.create(recursive: true);
          }

          return fallbackDir;
        }
      }
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final fallbackDir = Directory("${docsDir.path}/LensiaDownloads");

    if (!await fallbackDir.exists()) {
      await fallbackDir.create(recursive: true);
    }

    return fallbackDir;
  }

  static String _safeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), "_")
        .replaceAll(RegExp(r"\s+"), "_")
        .trim();

    if (cleaned.isEmpty) {
      return "lensia_file_${DateTime.now().millisecondsSinceEpoch}";
    }

    return cleaned;
  }
}