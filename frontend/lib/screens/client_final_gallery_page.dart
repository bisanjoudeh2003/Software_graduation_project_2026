import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../services/booking_gallery_service.dart';
import '../services/download_service.dart';
import 'remaining_balance_payment_page.dart';
import 'ClientCreatePrintRequestPage.dart';

const _green = Color(0xFF2F4F46);
const _softGreen = Color(0xFF3E6B5C);
const _cream = Color(0xFFF6F4EE);
const _gold = Color(0xFFD8B56D);
const _blue = Color(0xFF2F6B9A);
const _red = Color(0xFFE53935);

class ClientFinalGalleryPage extends StatefulWidget {
  final Map<String, dynamic> gallery;
  final List<Map<String, dynamic>> items;
  final String photographerName;
  final String sessionType;

  const ClientFinalGalleryPage({
    super.key,
    required this.gallery,
    required this.items,
    required this.photographerName,
    required this.sessionType,
  });

  @override
  State<ClientFinalGalleryPage> createState() => _ClientFinalGalleryPageState();
}

class _ClientFinalGalleryPageState extends State<ClientFinalGalleryPage> {
  late Map<String, dynamic> gallery;

  bool creatingShareLink = false;
  bool downloading = false;
  bool selecting = false;
  bool downloadingSelected = false;

  final Set<int> selectedIds = {};

  @override
  void initState() {
    super.initState();
    gallery = Map<String, dynamic>.from(widget.gallery);
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

  bool get _allowDownload => _toBool(gallery["allow_download"]);

double get _remainingAmount {
  final fromServer = double.tryParse(
        gallery["remaining_amount"]?.toString() ?? "",
      ) ??
      -1;

  if (fromServer > 0) return fromServer;

  final total =
      double.tryParse(gallery["total_price"]?.toString() ?? "0") ?? 0;

  final deposit =
      double.tryParse(gallery["deposit_amount"]?.toString() ?? "0") ?? 0;

  final calculated = total - deposit;

  return calculated > 0 ? calculated : 0;
}

  bool get _remainingPaid => _toBool(gallery["remaining_paid"]);

  bool get _hasRemainingPayment => _remainingAmount > 0;

  bool get _needsRemainingPayment => _hasRemainingPayment && !_remainingPaid;

  bool get _canDownloadFinalFiles {
    return _allowDownload && (!_hasRemainingPayment || _remainingPaid);
  }

  bool get _canRequestPrints {
    return !_needsRemainingPayment && _photoCount > 0;
  }

  List<Map<String, dynamic>> get _selectedPhotoItems {
    return _finalItems.where((item) {
      return selectedIds.contains(_toInt(item["id"])) && !_isVideo(item);
    }).toList();
  }

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

  String _mediaUrl(Map<String, dynamic> item) {
    return (item["media_url"] ?? "").toString();
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
    final isVideo = _isVideo(item);

    if (media.isEmpty) return "";

    if (!_previewWatermarked) {
      return media;
    }

    return _addLogoWatermarkToCloudinaryUrl(
      media,
      isVideo: isVideo,
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

      if (thumbnail.isNotEmpty) {
        return _addLogoWatermarkToCloudinaryUrl(
          thumbnail,
          isVideo: false,
        );
      }

      return "";
    }

    if (thumbnail.isNotEmpty) return thumbnail;

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

    for (final item in widget.items) {
      rootIds.add(_rootItemId(item));
    }

    final result = <Map<String, dynamic>>[];

    for (final rootId in rootIds) {
      final group =
          widget.items.where((item) => _rootItemId(item) == rootId).toList();

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

  int get _photoCount {
    return _finalItems.where((item) => !_isVideo(item)).length;
  }

  int get _videoCount {
    return _finalItems.where((item) => _isVideo(item)).length;
  }

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

  void _openFile(
    BuildContext context,
    Map<String, dynamic> item,
    int index,
  ) {
    final mediaUrl = _displayMediaUrl(item);

    if (mediaUrl.isEmpty) {
      _snack("File is not available.");
      return;
    }

    if (_isVideo(item)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _FinalVideoView(
            videoUrl: mediaUrl,
            allowDownload: _canDownloadFinalFiles,
            downloadUrl: _downloadUrl(item),
            previewWatermarked: _previewWatermarked,
            onDownload: _downloadFile,
            onRequestCleanCopy: _requestCleanCopyWithoutWatermark,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FinalPhotoView(
          imageUrl: mediaUrl,
          currentIndex: index + 1,
          totalCount: _finalItems.length,
          allowDownload: _canDownloadFinalFiles,
          downloadUrl: _downloadUrl(item),
          previewWatermarked: _previewWatermarked,
          onDownload: _downloadFile,
          onRequestCleanCopy: _requestCleanCopyWithoutWatermark,
        ),
      ),
    );
  }

  Future<void> _downloadFile(String url) async {
  if (!_canDownloadFinalFiles) {
    _snack(_needsRemainingPayment
        ? "Please pay the remaining balance before downloading."
        : "Downloads are disabled by the photographer.");
    return;
  }

  if (url.trim().isEmpty) {
    _snack("Download link is not available.");
    return;
  }

  if (downloading) return;

  setState(() => downloading = true);

  try {
    final lowerUrl = url.toLowerCase();

    final extension = lowerUrl.contains(".mp4")
        ? "mp4"
        : lowerUrl.contains(".mov")
            ? "mov"
            : lowerUrl.contains(".webm")
                ? "webm"
                : lowerUrl.contains(".png")
                    ? "png"
                    : lowerUrl.contains(".webp")
                        ? "webp"
                        : "jpg";

    final fileName =
        "lensia_${DateTime.now().millisecondsSinceEpoch}.$extension";

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

String _downloadName(Map<String, dynamic> item, int index) {
  final url = _downloadUrl(item);
  final extension = _fileExtensionFromUrl(url, item);
  final itemId = _toInt(item["id"]);

  return "lensia_final_${itemId == 0 ? index + 1 : itemId}.$extension";
}

bool _isSelected(Map<String, dynamic> item) {
  return selectedIds.contains(_toInt(item["id"]));
}

void _toggleSelection(Map<String, dynamic> item) {
  final id = _toInt(item["id"]);

  if (id == 0) return;

  setState(() {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }

    if (selectedIds.isEmpty) {
      selecting = false;
    }
  });
}

void _toggleSelectMode() {
  if (!_canDownloadFinalFiles) {
    _snack(_needsRemainingPayment
        ? "Please pay the remaining balance before downloading."
        : "Downloads are disabled by the photographer.");
    return;
  }

  setState(() {
    selecting = !selecting;
    if (!selecting) selectedIds.clear();
  });
}

void _selectAllFinal() {
  if (!_canDownloadFinalFiles) {
    _snack(_needsRemainingPayment
        ? "Please pay the remaining balance before downloading."
        : "Downloads are disabled by the photographer.");
    return;
  }

  setState(() {
    selecting = true;
    selectedIds
      ..clear()
      ..addAll(
        _finalItems
            .map((item) => _toInt(item["id"]))
            .where((id) => id > 0),
      );
  });
}

void _clearFinalSelection() {
  setState(() {
    selectedIds.clear();
    selecting = false;
  });
}

Future<void> _downloadSelectedFinal() async {
  if (!_canDownloadFinalFiles) {
    _snack(_needsRemainingPayment
        ? "Please pay the remaining balance before downloading."
        : "Downloads are disabled by the photographer.");
    return;
  }

  if (selectedIds.isEmpty) {
    _snack("Select at least one file.");
    return;
  }

  if (downloadingSelected) return;

  final selectedItems = _finalItems.where((item) {
    return selectedIds.contains(_toInt(item["id"]));
  }).toList();

  setState(() => downloadingSelected = true);

  int successCount = 0;

  try {
    for (int i = 0; i < selectedItems.length; i++) {
      final item = selectedItems[i];
      final url = _downloadUrl(item);

      if (url.trim().isEmpty) continue;

      await DownloadService.downloadFile(
        url: url,
        fileName: _downloadName(item, i),
      );

      successCount++;
    }

    if (!mounted) return;

    _snack(
      _previewWatermarked
          ? "$successCount watermarked files downloaded."
          : "$successCount files downloaded.",
    );

    setState(() {
      selectedIds.clear();
      selecting = false;
    });
  } catch (e) {
    if (!mounted) return;
    _snack(e.toString().replaceFirst("Exception: ", ""));
  } finally {
    if (mounted) {
      setState(() => downloadingSelected = false);
    }
  }
}

  Future<void> _requestCleanCopyWithoutWatermark() async {
    if (_needsRemainingPayment) {
      _snack("Please pay the remaining balance before requesting a clean copy.");
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final text =
            Theme.of(dialogContext).textTheme.bodyLarge?.color ?? Colors.black87;
        final sub =
            Theme.of(dialogContext).textTheme.bodyMedium?.color ?? Colors.grey;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.clean_hands_rounded,
                  color: _blue,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Request Clean Copy Without Watermark",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    color: text,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            "This means you want the photographer to provide this file without the Lensia watermark.",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: sub,
              height: 1.45,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                "Cancel",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: sub,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
          onPressed: () async {
  Navigator.pop(dialogContext);

  final galleryId = _toInt(gallery["id"]);

  if (galleryId == 0) {
    _snack("Invalid gallery id.");
    return;
  }

  try {
    final data = await BookingGalleryService.requestCleanCopy(
      galleryId: galleryId,
    );

    final updatedGallery = data["gallery"];

    if (updatedGallery is Map) {
      setState(() {
        gallery = Map<String, dynamic>.from(updatedGallery);
      });
    }

    _snack("Clean copy request sent to the photographer.");
  } catch (e) {
    _snack(e.toString().replaceFirst("Exception: ", ""));
  }
},
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text(
                "Request Clean Copy",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String get _cleanCopyStatus {
  final value = (gallery["clean_copy_status"] ?? "none").toString();
  if (value.trim().isEmpty || value == "null") return "none";
  return value;
}

bool get _canRequestCleanCopy {
  return _previewWatermarked &&
      !_needsRemainingPayment &&
      _cleanCopyStatus != "pending" &&
      _cleanCopyStatus != "approved";
}


Future<void> _openRemainingPaymentPage() async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RemainingBalancePaymentPage(
        gallery: gallery,
        photographerName: widget.photographerName,
        sessionType: widget.sessionType,
      ),
    ),
  );

  if (!mounted) return;

  if (result is Map && result["paid"] == true) {
    final updatedGallery = result["gallery"];

    if (updatedGallery is Map) {
      setState(() {
        gallery = Map<String, dynamic>.from(updatedGallery);
      });
    } else {
      setState(() {
        gallery["remaining_paid"] = 1;
        gallery["remaining_payment_status"] = "paid";
      });
    }
  }
}


Future<void> _openPrintRequestPage({
  List<Map<String, dynamic>>? initialItems,
}) async {
  if (!_canRequestPrints) {
    _snack(
      _needsRemainingPayment
          ? "Please pay the remaining balance before requesting prints."
          : "No printable photos are available.",
    );
    return;
  }

  final printable = (initialItems ?? _finalItems).where((item) {
    return !_isVideo(item) && _mediaUrl(item).trim().isNotEmpty;
  }).toList();

  if (printable.isEmpty) {
    _snack("Select at least one photo to request prints.");
    return;
  }

  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ClientPrintRequestPage(
        gallery: gallery,
        items: printable,
      ),
    ),
  );

  if (!mounted) return;

  if (result == true) {
    setState(() {
      selectedIds.clear();
      selecting = false;
    });

    _snack("Print request sent to the photographer.");
  }
}

Future<void> _showShareDialog() async {
  if (_needsRemainingPayment) {
    _snack("Please pay the remaining balance before sharing this gallery.");
    return;
  }

  bool allowDownload = _canDownloadFinalFiles;
  int expiresInDays = 7;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
      final card = Theme.of(dialogContext).cardColor;
      final text =
          Theme.of(dialogContext).textTheme.bodyLarge?.color ?? Colors.black87;
      final sub =
          Theme.of(dialogContext).textTheme.bodyMedium?.color ?? Colors.grey;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.ios_share_rounded,
                    color: _green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Share Final Gallery",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      color: text,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Create a secure link for this final gallery. The link will be copied, then you can send it on WhatsApp, Messenger, or anywhere.",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: sub,
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Link expires after",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            color: sub,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _expiryChip(
                              label: "7 days",
                              value: 7,
                              selectedValue: expiresInDays,
                              textColor: text,
                              onSelected: (value) {
                                setDialogState(() {
                                  expiresInDays = value;
                                });
                              },
                            ),
                            _expiryChip(
                              label: "14 days",
                              value: 14,
                              selectedValue: expiresInDays,
                              textColor: text,
                              onSelected: (value) {
                                setDialogState(() {
                                  expiresInDays = value;
                                });
                              },
                            ),
                            _expiryChip(
                              label: "30 days",
                              value: 30,
                              selectedValue: expiresInDays,
                              textColor: text,
                              onSelected: (value) {
                                setDialogState(() {
                                  expiresInDays = value;
                                });
                              },
                            ),
                            _expiryChip(
                              label: "60 days",
                              value: 60,
                              selectedValue: expiresInDays,
                              textColor: text,
                              onSelected: (value) {
                                setDialogState(() {
                                  expiresInDays = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _green.withOpacity(0.12)),
                    ),
                    child: SwitchListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10),
                      value: allowDownload,
                      activeColor: _green,
                      title: const Text(
                        "Allow download from shared link",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        _previewWatermarked
                            ? "If enabled, shared users can download the watermarked version."
                            : "Off means view only.",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          color: sub,
                          fontSize: 11,
                        ),
                      ),
                      onChanged: _canDownloadFinalFiles
                          ? (value) {
                              setDialogState(() => allowDownload = value);
                            }
                          : null,
                    ),
                  ),

                  if (!_canDownloadFinalFiles) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Downloads are locked until payment is completed and the photographer enables downloads.",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        color: sub,
                        fontSize: 11,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : const Color(0xFFF7F4EC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: _green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Anyone with this link can open the shared gallery until it expires.",
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              color: sub,
                              fontSize: 11,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: creatingShareLink
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: sub,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: creatingShareLink
                    ? null
                    : () async {
                        Navigator.pop(dialogContext);

                        await _createShareLink(
                          allowDownload: allowDownload,
                          expiresInDays: expiresInDays,
                        );
                      },
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text(
                  "Generate Link",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

  Widget _expiryChip({
    required String label,
    required int value,
    required int selectedValue,
    required Color textColor,
    required ValueChanged<int> onSelected,
  }) {
    final selected = selectedValue == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: _green,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withOpacity(0.06)
          : const Color(0xFFF7F4EC),
      labelStyle: TextStyle(
        color: selected ? Colors.white : textColor,
        fontFamily: "Montserrat",
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
      onSelected: (_) => onSelected(value),
    );
  }

Future<void> _createShareLink({
  required bool allowDownload,
  required int expiresInDays,
}) async {
  if (_needsRemainingPayment) {
    _snack("Please pay the remaining balance before sharing this gallery.");
    return;
  }

  final galleryId = _toInt(gallery["id"]);

  if (galleryId == 0) {
    _snack("Invalid gallery id.");
    return;
  }

  setState(() => creatingShareLink = true);

  try {
    final data = await BookingGalleryService.createShareLink(
      galleryId: galleryId,
      allowDownload: allowDownload && _canDownloadFinalFiles,
      expiresInDays: expiresInDays,
    );

    if (!mounted) return;

    final shareUrl = (data["share_url"] ?? "").toString();

    if (shareUrl.trim().isEmpty) {
      _snack("Share link was not returned from server.");
      return;
    }

    await Clipboard.setData(ClipboardData(text: shareUrl));

    if (!mounted) return;
    _showCreatedLinkDialog(shareUrl);
  } catch (e) {
    if (!mounted) return;
    _snack(e.toString().replaceFirst("Exception: ", ""));
  } finally {
    if (mounted) setState(() => creatingShareLink = false);
  }
}

  void _showCreatedLinkDialog(String link) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final text =
            Theme.of(dialogContext).textTheme.bodyLarge?.color ?? Colors.black87;
        final sub =
            Theme.of(dialogContext).textTheme.bodyMedium?.color ?? Colors.grey;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _softGreen.withOpacity(0.13),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: _softGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Share Link Ready",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    color: text,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "The link has been copied. You can send it to anyone you want.",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: sub,
                  height: 1.5,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : const Color(0xFFF7F4EC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SelectableText(
                  link,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                "Done",
                style: TextStyle(fontFamily: "Montserrat"),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (!mounted) return;
                Navigator.pop(dialogContext);
                _snack("Link copied.");
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text(
                "Copy Again",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
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
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final text = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final sub = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final card = Theme.of(context).cardColor;
    final border = Theme.of(context).brightness == Brightness.dark
        ? Colors.white12
        : _green.withOpacity(0.10);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          "Final Gallery",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_canDownloadFinalFiles)
            IconButton(
              tooltip: selecting ? "Cancel selection" : "Select files",
              onPressed: downloadingSelected ? null : _toggleSelectMode,
              icon: Icon(
                selecting ? Icons.close_rounded : Icons.checklist_rounded,
                color: _green,
              ),
            ),
          IconButton(
            onPressed: creatingShareLink || downloadingSelected || _needsRemainingPayment
                ? null
                : _showShareDialog,
            icon: creatingShareLink
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _green,
                    ),
                  )
                : const Icon(Icons.ios_share_rounded, color: _green),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: _heroCard(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _statCard(
                      context,
                      icon: Icons.image_rounded,
                      label: "Photos",
                      value: "$_photoCount",
                      color: _green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      context,
                      icon: Icons.videocam_rounded,
                      label: "Videos",
                      value: "$_videoCount",
                      color: _softGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      context,
                      icon: _canDownloadFinalFiles
                          ? Icons.download_done_rounded
                          : Icons.download_for_offline_outlined,
                      label: "Download",
                      value: _canDownloadFinalFiles ? "On" : "Locked",
                      color: _canDownloadFinalFiles ? _gold : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_hasRemainingPayment)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: _paymentStatusBanner(context),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: _quickActionsCard(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: (_previewWatermarked ? _blue : _green)
                            .withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _previewWatermarked
                            ? Icons.lock_outline_rounded
                            : Icons.lock_open_rounded,
                        color: _previewWatermarked ? _blue : _green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _previewWatermarked
                            ? "These final files are shown with a watermark for protection. You can request a clean copy without watermark from the photographer."
                            : "These are your finalized delivered files. Tap any item to view it in full screen, or share the final gallery with a secure link.",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 12,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: sub,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
         if (_canRequestCleanCopy || (_previewWatermarked && _cleanCopyStatus == "pending"))
  SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: _requestCleanCopyBanner(context),
    ),
  ),
          if (_finalItems.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _emptyState(context),
              ),
            )
          else ...[
            if (selecting)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: _finalSelectionBar(),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _finalItems[index];
                    return _galleryTile(
                      context,
                      item: item,
                      index: index,
                    );
                  },
                  childCount: _finalItems.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.70,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }


Widget _quickActionsCard(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final card = Theme.of(context).cardColor;
  final text = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  final sub = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  final border = isDark ? Colors.white12 : _green.withOpacity(0.10);

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _gold.withOpacity(isDark ? 0.16 : 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_printshop_rounded,
                color: _gold,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Need printed copies?",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: text,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "Select photos, size, and quantity. Pickup or delivery is arranged with the photographer.",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: sub,
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _canRequestPrints
                    ? () => _openPrintRequestPage()
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _gold.withOpacity(0.25),
                  elevation: 0,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: const Icon(Icons.local_printshop_rounded, size: 17),
                label: const Text(
                  "Request Prints",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _canDownloadFinalFiles && !downloadingSelected
                    ? _toggleSelectMode
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  disabledForegroundColor: _green.withOpacity(0.35),
                  side: BorderSide(color: _green.withOpacity(0.35)),
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: Icon(
                  selecting ? Icons.close_rounded : Icons.checklist_rounded,
                  size: 17,
                ),
                label: Text(
                  selecting ? "Cancel Select" : "Select Files",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _paymentStatusBanner(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final text = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  final sub = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

  if (_remainingPaid) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softGreen.withOpacity(isDark ? 0.13 : 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _softGreen.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: _softGreen, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _allowDownload
                  ? "Payment completed. Downloads are enabled by the photographer."
                  : "Payment completed. Waiting for the photographer to enable downloads.",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: text,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _gold.withOpacity(isDark ? 0.14 : 0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _gold.withOpacity(0.24)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.credit_card_rounded, color: _gold, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Remaining balance required",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: text,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Pay \$${_remainingAmount.toStringAsFixed(2)} to continue final delivery. Downloads, sharing, and clean copy requests stay locked until payment is completed.",
          style: TextStyle(
            fontFamily: "Montserrat",
            color: sub,
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onPressed: _openRemainingPaymentPage,
            icon: const Icon(Icons.credit_card_rounded, size: 18),
            label: const Text(
              "Pay Remaining Balance",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
Widget _finalSelectionBar() {
  final selectedPhotoCount = _selectedPhotoItems.length;

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _blue.withOpacity(0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _blue.withOpacity(0.14)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "${selectedIds.length} selected • $selectedPhotoCount printable",
                style: const TextStyle(
                  color: _green,
                  fontFamily: "Montserrat",
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: downloadingSelected ? null : _clearFinalSelection,
              child: const Text(
                "Clear",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: downloadingSelected ? null : _selectAllFinal,
                child: const Text(
                  "Select All",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: selectedPhotoCount == 0
                    ? null
                    : () => _openPrintRequestPage(
                          initialItems: _selectedPhotoItems,
                        ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _gold,
                  disabledForegroundColor: _gold.withOpacity(0.35),
                  side: BorderSide(color: _gold.withOpacity(0.45)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.local_printshop_rounded, size: 16),
                label: const Text(
                  "Print",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: selectedIds.isEmpty || downloadingSelected
                ? null
                : _downloadSelectedFinal,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _green.withOpacity(0.25),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: downloadingSelected
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded, size: 17),
            label: Text(
              downloadingSelected ? "Downloading..." : "Download Selected",
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _requestCleanCopyBanner(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final sub = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

  final isPending = _cleanCopyStatus == "pending";

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _blue.withOpacity(isDark ? 0.14 : 0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _blue.withOpacity(0.18)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isPending
                  ? Icons.hourglass_top_rounded
                  : Icons.clean_hands_rounded,
              color: _blue,
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isPending
                    ? "Clean copy request pending"
                    : "Need files without watermark?",
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  color: _blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isPending
              ? "Your clean copy request is waiting for the photographer's approval."
              : "Use the button below to ask the photographer for a clean copy without watermark.",
          style: TextStyle(
            fontFamily: "Montserrat",
            color: sub,
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (!isPending) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _blue,
                side: BorderSide(color: _blue.withOpacity(0.35)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: _requestCleanCopyWithoutWatermark,
              icon: const Icon(Icons.send_rounded, size: 17),
              label: const Text(
                "Request Clean Copy Without Watermark",
                style: TextStyle(
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
  );
}
  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
            color: _green.withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
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
          Positioned(
            right: 18,
            bottom: -35,
            child: Container(
              width: 95,
              height: 95,
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.13),
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
                  _heroChip(
                    icon: Icons.verified_rounded,
                    text: "Finalized Gallery",
                  ),
                  if (_previewWatermarked)
                    _heroChip(
                      icon: Icons.lock_outline_rounded,
                      text: "Watermarked Preview",
                    ),
                  if (_hasRemainingPayment)
                    _heroChip(
                      icon: _remainingPaid
                          ? Icons.paid_rounded
                          : Icons.credit_card_rounded,
                      text: _remainingPaid ? "Paid" : "Payment Due",
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                "${widget.sessionType} Final Gallery",
                style: const TextStyle(
                  fontFamily: "Playfair_Display",
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Delivered by ${widget.photographerName}",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.74),
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                    text:
                        "Finalized ${_prettyDate(gallery["finalized_at"])}",
                  ),
                  _smallInfo(
                    icon: _canDownloadFinalFiles
                        ? Icons.download_done_rounded
                        : Icons.download_for_offline_outlined,
                    text: _canDownloadFinalFiles ? "Download allowed" : "Download locked",
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip({
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

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = Theme.of(context).cardColor;
    final text = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final sub = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : color.withOpacity(0.12),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: sub,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _galleryTile(
    BuildContext context, {
    required Map<String, dynamic> item,
    required int index,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preview = _previewUrl(item);
    final isVideo = _isVideo(item);
    final selected = _isSelected(item);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : _cream,
            borderRadius: BorderRadius.circular(22),
            border: selecting && selected
                ? Border.all(color: _green, width: 2)
                : null,
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: _green.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: InkWell(
                  onTap: selecting
                      ? () => _toggleSelection(item)
                      : () => _openFile(context, item, index),
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
                                Colors.black.withOpacity(0.08),
                                Colors.black.withOpacity(0.55),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      if (_previewWatermarked)
                        Positioned(
                          top: 9,
                          left: 9,
                          child: _tileBadge(
                            icon: Icons.lock_outline_rounded,
                            text: "Protected",
                          ),
                        ),
                      if (isVideo)
                        Center(
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.35),
                              ),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        ),
                      Positioned(
                        top: 9,
                        right: 9,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.38),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isVideo
                                ? Icons.videocam_rounded
                                : Icons.image_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10,
                        child: Row(
                          children: [
                            Expanded(
                              child: _tileBadge(
                                icon: Icons.verified_rounded,
                                text: "Final",
                              ),
                            ),
                            const SizedBox(width: 7),
                            _indexBadge(index + 1),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!selecting) _tileActions(item),
            ],
          ),
        ),
        if (selecting)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => _toggleSelection(item),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? _green : Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  selected ? Icons.check_rounded : Icons.circle_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tileActions(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
      ),
      child: Row(
        children: [
          Expanded(
            child: _miniActionButton(
              label: "Open",
              icon: Icons.open_in_full_rounded,
              color: _green,
              onTap: () {
                final index = _finalItems.indexWhere(
                  (entry) => _toInt(entry["id"]) == _toInt(item["id"]),
                );

                _openFile(context, item, index < 0 ? 0 : index);
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _miniActionButton(
              label: _canDownloadFinalFiles ? "Download" : "Locked",
              icon: _canDownloadFinalFiles
                  ? Icons.download_rounded
                  : Icons.download_for_offline_outlined,
              color: _canDownloadFinalFiles ? _softGreen : Colors.grey,
              onTap: _canDownloadFinalFiles ? () => _downloadFile(_downloadUrl(item)) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: disabled ? 0.55 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tileBadge({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _gold, size: 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _indexBadge(int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.38),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        "$index",
        style: const TextStyle(
          fontFamily: "Montserrat",
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final card = Theme.of(context).cardColor;
    final text = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final sub = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: sub.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            "No final files available",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Final files will appear here after delivery is completed.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: sub,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(bool isVideo) {
    return Container(
      color: const Color(0xFFE9EDE8),
      child: Icon(
        isVideo ? Icons.play_circle_fill_rounded : Icons.image_outlined,
        size: 42,
        color: _green,
      ),
    );
  }
}

class _FinalPhotoView extends StatelessWidget {
  final String imageUrl;
  final int currentIndex;
  final int totalCount;
  final bool allowDownload;
  final String downloadUrl;
  final bool previewWatermarked;
  final Future<void> Function(String url) onDownload;
  final Future<void> Function() onRequestCleanCopy;

  const _FinalPhotoView({
    required this.imageUrl,
    required this.currentIndex,
    required this.totalCount,
    required this.allowDownload,
    required this.downloadUrl,
    required this.previewWatermarked,
    required this.onDownload,
    required this.onRequestCleanCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "$currentIndex / $totalCount",
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        centerTitle: true,
        actions: [
          if (allowDownload)
            IconButton(
              tooltip: previewWatermarked
                  ? "Download watermarked file"
                  : "Download file",
              onPressed: () => onDownload(downloadUrl),
              icon: const Icon(Icons.download_rounded),
            ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
          if (previewWatermarked)
            Positioned(
              left: 14,
              right: 14,
              bottom: 22,
              child: SafeArea(
                child: _CleanCopyButton(
                  onTap: onRequestCleanCopy,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FinalVideoView extends StatefulWidget {
  final String videoUrl;
  final bool allowDownload;
  final String downloadUrl;
  final bool previewWatermarked;
  final Future<void> Function(String url) onDownload;
  final Future<void> Function() onRequestCleanCopy;

  const _FinalVideoView({
    required this.videoUrl,
    required this.allowDownload,
    required this.downloadUrl,
    required this.previewWatermarked,
    required this.onDownload,
    required this.onRequestCleanCopy,
  });

  @override
  State<_FinalVideoView> createState() => _FinalVideoViewState();
}

class _FinalVideoViewState extends State<_FinalVideoView> {
  late VideoPlayerController controller;
  bool ready = false;

  @override
  void initState() {
    super.initState();

    controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => ready = true);
        controller.play();
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String _durationText(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, "0");
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, "0");
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final position =
        ready ? controller.value.position : const Duration(seconds: 0);
    final duration =
        ready ? controller.value.duration : const Duration(seconds: 0);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Final Video",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.allowDownload)
            IconButton(
              tooltip: widget.previewWatermarked
                  ? "Download watermarked video"
                  : "Download video",
              onPressed: () => widget.onDownload(widget.downloadUrl),
              icon: const Icon(Icons.download_rounded),
            ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: ready
                ? AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),
          if (widget.previewWatermarked)
            Positioned(
              left: 14,
              right: 14,
              bottom: 92,
              child: SafeArea(
                child: _CleanCopyButton(
                  onTap: widget.onRequestCleanCopy,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: ready
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Row(
                  children: [
                    Text(
                      _durationText(position),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: "Montserrat",
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Expanded(
                      child: VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        colors: VideoProgressColors(
                          playedColor: _softGreen,
                          bufferedColor: Colors.white.withOpacity(0.30),
                          backgroundColor: Colors.white.withOpacity(0.14),
                        ),
                      ),
                    ),
                    Text(
                      _durationText(duration),
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
            )
          : null,
      floatingActionButton: ready
          ? FloatingActionButton(
              backgroundColor: _green,
              onPressed: () {
                setState(() {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                });
              },
              child: Icon(
                controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}

class _CleanCopyButton extends StatelessWidget {
  final Future<void> Function() onTap;

  const _CleanCopyButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      onPressed: onTap,
      icon: const Icon(Icons.clean_hands_rounded, size: 18),
      label: const Text(
        "Request Clean Copy Without Watermark",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}