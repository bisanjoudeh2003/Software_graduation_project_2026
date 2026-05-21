import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/booking_gallery_service.dart';
import '../services/download_service.dart';

const _green = Color(0xFF2F4F46);
const _softGreen = Color(0xFF3E6B5C);
const _cream = Color(0xFFF6F4EE);
const _gold = Color(0xFFD8B56D);

class SharedGalleryWeb extends StatefulWidget {
  final String token;

  const SharedGalleryWeb({
    super.key,
    required this.token,
  });

  @override
  State<SharedGalleryWeb> createState() => _SharedGalleryWebState();
}

class _SharedGalleryWebState extends State<SharedGalleryWeb> {
  bool loading = true;
  bool downloading = false;
  String? error;

  Map<String, dynamic> gallery = {};
  Map<String, dynamic> share = {};
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await BookingGalleryService.getSharedGallery(widget.token);

      if (!mounted) return;

      setState(() {
        gallery = Map<String, dynamic>.from(data["gallery"] ?? {});
        share = Map<String, dynamic>.from(data["share"] ?? {});
        items = (data["items"] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString().replaceFirst("Exception: ", "");
        loading = false;
      });
    }
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  bool _toBool(dynamic value) {
    if (value == true) return true;
    if (value == false) return false;

    final parsed = (value ?? "").toString().trim().toLowerCase();
    return parsed == "1" || parsed == "true";
  }

  bool get _previewWatermarked => _toBool(gallery["preview_watermarked"]);

  bool get _allowDownload => _toBool(share["allow_download"]);

  bool _isVideo(Map<String, dynamic> item) {
    return (item["media_type"] ?? "image").toString() == "video";
  }

  int _rootItemId(Map<String, dynamic> item) {
    final parentId = _toInt(item["parent_item_id"]);
    return parentId == 0 ? _toInt(item["id"]) : parentId;
  }

  int _versionNumber(Map<String, dynamic> item) {
    final number = _toInt(item["version_number"]);
    return number == 0 ? 1 : number;
  }

  bool _isEditedVersion(Map<String, dynamic> item) {
    return (item["version_type"] ?? "original").toString() == "edited";
  }

  String _title(Map<String, dynamic> item, int index) {
    final title = (item["title"] ?? "").toString().trim();

    if (title.isNotEmpty) return title;

    return _isVideo(item) ? "Video ${index + 1}" : "Photo ${index + 1}";
  }

  String _description(Map<String, dynamic> item) {
    return (item["description"] ?? "").toString().trim();
  }

  String _mediaUrl(Map<String, dynamic> item) {
    final media = (item["media_url"] ?? "").toString();
    final original = (item["original_url"] ?? "").toString();

    if (media.isNotEmpty && media.startsWith("http")) return media;
    if (original.isNotEmpty && original.startsWith("http")) return original;

    return "";
  }

  String _overlayPublicId(String publicId) {
    return publicId.replaceAll("/", ":");
  }

  String _addLogoWatermarkToCloudinaryUrl(
    String url, {
    required bool isVideo,
  }) {
    if (url.isEmpty) return "";
    if (!url.contains("res.cloudinary.com")) return url;

    const publicId = "water_mark";
    final overlayId = _overlayPublicId(publicId);

    if (url.contains("l_$overlayId")) return url;

    const transformation =
        "l_water_mark,fl_relative,w_0.26,o_70/fl_layer_apply,g_north_west,x_0.03,y_0.03/";

    final uploadPart = isVideo ? "/video/upload/" : "/image/upload/";

    if (url.contains(uploadPart)) {
      return url.replaceFirst(uploadPart, "$uploadPart$transformation");
    }

    if (url.contains("/upload/")) {
      return url.replaceFirst("/upload/", "/upload/$transformation");
    }

    return url;
  }

  String _cloudinaryVideoThumbnail(
    String videoUrl, {
    required bool withWatermark,
  }) {
    if (videoUrl.isEmpty) return "";
    if (!videoUrl.contains("res.cloudinary.com")) return "";
    if (!videoUrl.contains("/video/upload/")) return "";

    const watermarkTransformation =
        "l_water_mark,fl_relative,w_0.26,o_70/fl_layer_apply,g_north_west,x_0.03,y_0.03/";

    final transformation = withWatermark
        ? "so_1,w_900,h_900,c_fill,f_jpg/$watermarkTransformation"
        : "so_1,w_900,h_900,c_fill,f_jpg/";

    final thumbnailUrl = videoUrl.replaceFirst(
      "/video/upload/",
      "/video/upload/$transformation",
    );

    final dotIndex = thumbnailUrl.lastIndexOf(".");
    if (dotIndex == -1) return "$thumbnailUrl.jpg";

    return "${thumbnailUrl.substring(0, dotIndex)}.jpg";
  }

  String _displayMediaUrl(Map<String, dynamic> item) {
    final media = _mediaUrl(item);
    if (media.isEmpty) return "";

    if (!_previewWatermarked) return media;

    return _addLogoWatermarkToCloudinaryUrl(
      media,
      isVideo: _isVideo(item),
    );
  }

  String _downloadUrl(Map<String, dynamic> item) {
    final media = _mediaUrl(item);
    if (media.isEmpty) return "";

    if (_previewWatermarked) {
      return _addLogoWatermarkToCloudinaryUrl(
        media,
        isVideo: _isVideo(item),
      );
    }

    return media;
  }

  String _previewUrl(Map<String, dynamic> item) {
    final thumbnail = (item["thumbnail_url"] ?? "").toString();
    final media = _mediaUrl(item);
    final isVideo = _isVideo(item);

    if (_previewWatermarked) {
      if (isVideo && media.isNotEmpty) {
        return _cloudinaryVideoThumbnail(
          media,
          withWatermark: true,
        );
      }

      if (!isVideo && media.isNotEmpty) {
        return _addLogoWatermarkToCloudinaryUrl(
          media,
          isVideo: false,
        );
      }

      if (thumbnail.isNotEmpty && thumbnail.startsWith("http")) {
        return _addLogoWatermarkToCloudinaryUrl(
          thumbnail,
          isVideo: false,
        );
      }

      return "";
    }

    if (thumbnail.isNotEmpty && thumbnail.startsWith("http")) {
      return thumbnail;
    }

    if (isVideo && media.isNotEmpty) {
      return _cloudinaryVideoThumbnail(
        media,
        withWatermark: false,
      );
    }

    if (!isVideo && media.isNotEmpty) return media;

    return "";
  }

  List<Map<String, dynamic>> get _finalItems {
    final rootIds = <int>{};

    for (final item in items) {
      final rootId = _rootItemId(item);
      if (rootId > 0) rootIds.add(rootId);
    }

    final result = <Map<String, dynamic>>[];

    for (final rootId in rootIds) {
      final group = items.where((item) => _rootItemId(item) == rootId).toList();

      group.sort((a, b) {
        final aVersion = _versionNumber(a);
        final bVersion = _versionNumber(b);

        if (aVersion == bVersion) {
          return _toInt(a["id"]).compareTo(_toInt(b["id"]));
        }

        return aVersion.compareTo(bVersion);
      });

      final edited = group.where((item) => _isEditedVersion(item)).toList();

      if (edited.isNotEmpty) {
        result.add(edited.last);
      } else if (group.isNotEmpty) {
        result.add(group.first);
      }
    }

    result.sort((a, b) => _toInt(b["id"]).compareTo(_toInt(a["id"])));
    return result;
  }

  int get _photoCount => _finalItems.where((item) => !_isVideo(item)).length;

  int get _videoCount => _finalItems.where((item) => _isVideo(item)).length;

  String _prettyDate(dynamic raw) {
    final value = (raw ?? "").toString();
    if (value.isEmpty || value == "null") return "Not set";

    try {
      final date = DateTime.parse(value);
      const months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      return "${months[date.month - 1]} ${date.day}, ${date.year}";
    } catch (_) {
      return value;
    }
  }

  String _fileExtensionFromUrl(String url, Map<String, dynamic> item) {
    final lowerUrl = url.toLowerCase();

    if (_isVideo(item)) {
      if (lowerUrl.contains(".mov")) return "mov";
      if (lowerUrl.contains(".webm")) return "webm";
      return "mp4";
    }

    if (lowerUrl.contains(".png")) return "png";
    if (lowerUrl.contains(".webp")) return "webp";
    if (lowerUrl.contains(".jpeg")) return "jpeg";

    return "jpg";
  }

  Future<void> _downloadFile(Map<String, dynamic> item) async {
    if (!_allowDownload) {
      _snack("Downloads are disabled for this shared link.");
      return;
    }

    final url = _downloadUrl(item);

    if (url.trim().isEmpty) {
      _snack("Download link is not available.");
      return;
    }

    if (downloading) return;

    setState(() => downloading = true);

    try {
      final itemId = _toInt(item["id"]);
      final extension = _fileExtensionFromUrl(url, item);
      final fileName =
          "lensia_shared_${itemId == 0 ? DateTime.now().millisecondsSinceEpoch : itemId}.$extension";

      final path = await DownloadService.downloadFile(
        url: url,
        fileName: fileName,
      );

      if (!mounted) return;

      _snack(
        _previewWatermarked
            ? "Watermarked file downloaded successfully."
            : "File downloaded successfully.",
      );

      await DownloadService.openDownloadedFile(path);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  void _openItem(Map<String, dynamic> item, int index) {
    final mediaUrl = _displayMediaUrl(item);

    if (mediaUrl.isEmpty) {
      _snack("File is not available.");
      return;
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.88),
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(22),
          child: _ViewerDialog(
            title: _title(item, index),
            description: _description(item),
            isVideo: _isVideo(item),
            mediaUrl: mediaUrl,
            allowDownload: _allowDownload,
            downloading: downloading,
            onDownload: () => _downloadFile(item),
          ),
        );
      },
    );
  }

  void _snack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        title: const Text(
          "Shared Gallery",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: _green),
            )
          : error != null
              ? _errorView()
              : _finalItems.isEmpty
                  ? _emptyView()
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _header()),
                        SliverToBoxAdapter(child: _stats()),
                        SliverToBoxAdapter(child: _infoBanner()),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                          sliver: SliverLayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.crossAxisExtent;

                              int count = 2;
                              if (width > 1200) {
                                count = 4;
                              } else if (width > 850) {
                                count = 3;
                              }

                              return SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final item = _finalItems[index];
                                    return _galleryCard(item, index);
                                  },
                                  childCount: _finalItems.length,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: count,
                                  crossAxisSpacing: 18,
                                  mainAxisSpacing: 18,
                                  childAspectRatio: _allowDownload ? 0.68 : 0.76,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _header() {
    final title = (gallery["title"] ?? "Final Gallery").toString();
    final description = (gallery["description"] ?? "").toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF172E28),
              Color(0xFF2F4F46),
              Color(0xFF5F7E70),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _green.withOpacity(0.20),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(
                      icon: Icons.verified_rounded,
                      text: "Shared Final Gallery",
                    ),
                    if (_previewWatermarked)
                      _chip(
                        icon: Icons.lock_outline_rounded,
                        text: "Watermarked",
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: "Playfair_Display",
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _smallInfo(
                      icon: Icons.photo_library_rounded,
                      text: "${_finalItems.length} final files",
                    ),
                    _smallInfo(
                      icon: Icons.event_available_rounded,
                      text: "Expires ${_prettyDate(share["expires_at"])}",
                    ),
                    _smallInfo(
                      icon: _allowDownload
                          ? Icons.download_rounded
                          : Icons.visibility_rounded,
                      text: _allowDownload ? "Download allowed" : "View only",
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              icon: Icons.image_rounded,
              label: "Photos",
              value: "$_photoCount",
              color: _green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              icon: Icons.videocam_rounded,
              label: "Videos",
              value: "$_videoCount",
              color: _softGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              icon: _allowDownload
                  ? Icons.download_rounded
                  : Icons.visibility_rounded,
              label: "Access",
              value: _allowDownload ? "Download" : "View",
              color: _gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _green.withOpacity(0.10)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (_previewWatermarked ? _gold : _green).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _previewWatermarked
                    ? Icons.lock_outline_rounded
                    : Icons.public_rounded,
                color: _previewWatermarked ? _gold : _green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _previewWatermarked
                    ? _allowDownload
                        ? "This shared gallery is protected with a watermark. Downloads are enabled for this link."
                        : "This shared gallery is protected with a watermark."
                    : _allowDownload
                        ? "This is a shared final gallery link. Downloads are enabled for this link."
                        : "This is a shared final gallery link. Only finalized files are visible.",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.black.withOpacity(0.60),
                  fontSize: 12,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _galleryCard(Map<String, dynamic> item, int index) {
    final preview = _previewUrl(item);
    final isVideo = _isVideo(item);
    final desc = _description(item);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _openItem(item, index),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: _green.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (preview.isNotEmpty)
                    Image.network(
                      preview,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(isVideo),
                    )
                  else
                    _fallback(isVideo),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.05),
                            Colors.black.withOpacity(0.50),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  if (_previewWatermarked)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _darkBadge(
                        icon: Icons.lock_outline_rounded,
                        text: "Protected",
                      ),
                    ),
                  if (isVideo)
                    Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: _darkBadge(
                      icon: isVideo
                          ? Icons.videocam_rounded
                          : Icons.image_rounded,
                      text: isVideo ? "Video" : "Photo",
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(item, index),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: _green,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        color: Colors.black.withOpacity(0.55),
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (_allowDownload) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: ElevatedButton.icon(
                        onPressed: downloading
                            ? null
                            : () {
                                _downloadFile(item);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _green.withOpacity(0.35),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: downloading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_rounded, size: 17),
                        label: Text(
                          downloading ? "Downloading..." : "Download",
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(bool isVideo) {
    return Container(
      color: const Color(0xFFE3E3E0),
      child: Center(
        child: Icon(
          isVideo ? Icons.videocam_rounded : Icons.broken_image_outlined,
          color: _green,
          size: 36,
        ),
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _gold, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallInfo({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.82), size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white.withOpacity(0.86),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _darkBadge({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: "Montserrat",
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black.withOpacity(0.55),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          error ?? "This link is not available.",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: _green,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _emptyView() {
    return const Center(
      child: Text(
        "No files available",
        style: TextStyle(
          fontFamily: "Montserrat",
          color: _green,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ViewerDialog extends StatelessWidget {
  final String title;
  final String description;
  final bool isVideo;
  final String mediaUrl;
  final bool allowDownload;
  final bool downloading;
  final VoidCallback onDownload;

  const _ViewerDialog({
    required this.title,
    required this.description,
    required this.isVideo,
    required this.mediaUrl,
    required this.allowDownload,
    required this.downloading,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 1000,
        maxHeight: 760,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Center(
                  child: isVideo
                      ? _SharedVideoPlayer(videoUrl: mediaUrl)
                      : InteractiveViewer(
                          child: Image.network(
                            mediaUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) {
                              return const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white,
                                  size: 44,
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.black,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontFamily: "Montserrat",
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              description,
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                color: Colors.white.withOpacity(0.70),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (allowDownload) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: downloading ? null : onDownload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: downloading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_rounded, size: 18),
                        label: Text(
                          downloading ? "Downloading..." : "Download",
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 12,
            right: 12,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(50),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const _SharedVideoPlayer({
    required this.videoUrl,
  });

  @override
  State<_SharedVideoPlayer> createState() => _SharedVideoPlayerState();
}

class _SharedVideoPlayerState extends State<_SharedVideoPlayer> {
  VideoPlayerController? controller;
  bool loading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final videoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

      await videoController.initialize();

      if (!mounted) {
        await videoController.dispose();
        return;
      }

      setState(() {
        controller = videoController;
        loading = false;
      });

      await videoController.play();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        hasError = true;
      });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = controller;
    if (c == null) return;

    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  String _durationText(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, "0");
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, "0");
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;

    if (loading) {
      return const SizedBox(
        height: 420,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (hasError || c == null) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: Text(
            "Unable to play this video.",
            style: TextStyle(
              color: Colors.white,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
        if (!c.value.isPlaying)
          IconButton(
            onPressed: _togglePlay,
            iconSize: 72,
            icon: const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
            ),
          ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Row(
            children: [
              Text(
                _durationText(c.value.position),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: "Montserrat",
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: _togglePlay,
                icon: Icon(
                  c.value.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              Expanded(
                child: VideoProgressIndicator(
                  c,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: _green,
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _durationText(c.value.duration),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: "Montserrat",
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}