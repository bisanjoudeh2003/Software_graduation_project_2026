import 'dart:html' as html;

class DownloadService {
  static Future<String> downloadFile({
    required String url,
    required String fileName,
    void Function(int received, int total)? onProgress,
  }) async {
    if (url.trim().isEmpty) {
      throw Exception("Download URL is empty.");
    }

    final safeName = _safeFileName(fileName);

    try {
      final request = await html.HttpRequest.request(
        url,
        method: "GET",
        responseType: "blob",
      );

      final blob = request.response as html.Blob;
      final objectUrl = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement(href: objectUrl)
        ..download = safeName
        ..style.display = "none";

      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();

      html.Url.revokeObjectUrl(objectUrl);

      onProgress?.call(1, 1);

      return safeName;
    } catch (e) {
      final anchor = html.AnchorElement(href: url)
        ..target = "_blank"
        ..rel = "noopener"
        ..style.display = "none";

      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();

      onProgress?.call(1, 1);

      return "web_opened_in_new_tab";
    }
  }

  static Future<void> openDownloadedFile(String path) async {
    // On web, the browser handles downloaded files.
    return;
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