import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart';

import '../theme.dart';
import '../services/auth_service.dart';

import 'all_albums_screen.dart';
import 'album_details_screen.dart';

const _amber = Color(0xFFC49A3C);
const _red = Color(0xFFB84040);
const _green2 = Color(0xFF3E6B5C);

const String _lensiaWatermarkPublicId = "water_mark";

bool _portfolioUsesWatermark(Map item) {
  final value = item["use_watermark"] ??
      item["watermark_enabled"] ??
      item["has_watermark"];

  return value == true ||
      value == 1 ||
      value?.toString() == "1" ||
      value?.toString().toLowerCase() == "true";
}

String _portfolioBaseMediaUrl(Map item) {
  return (item["original_media_url"] ??
          item["media_url"] ??
          item["secure_url"] ??
          item["url"] ??
          "")
      .toString()
      .trim();
}

String _portfolioCloudinaryVideoThumbnail(String videoUrl) {
  if (videoUrl.trim().isEmpty) return "";
  if (!videoUrl.contains("res.cloudinary.com")) return "";
  if (!videoUrl.contains("/video/upload/")) return "";

  final thumbnailUrl = videoUrl.replaceFirst(
    "/video/upload/",
    "/video/upload/so_1,w_900,h_900,c_fill,f_jpg/",
  );

  final dotIndex = thumbnailUrl.lastIndexOf(".");
  if (dotIndex == -1) return "$thumbnailUrl.jpg";

  return "${thumbnailUrl.substring(0, dotIndex)}.jpg";
}

String _portfolioOverlayPublicId(String publicId) {
  return publicId.replaceAll("/", ":");
}

String _portfolioAddCloudinaryWatermark(
  String url, {
  required bool isVideo,
}) {
  if (url.trim().isEmpty) return "";
  if (!url.contains("res.cloudinary.com")) return url;

  final overlayId = _portfolioOverlayPublicId(_lensiaWatermarkPublicId);

  if (url.contains("l_$overlayId")) return url;

  const watermarkTransformation =
        "l_water_mark,fl_relative,w_0.26,o_70/fl_layer_apply,g_north_west,x_0.03,y_0.03/";

  final uploadPart = isVideo ? "/video/upload/" : "/image/upload/";

  if (url.contains(uploadPart)) {
    return url.replaceFirst(uploadPart, "$uploadPart$watermarkTransformation");
  }

  if (url.contains("/upload/")) {
    return url.replaceFirst("/upload/", "/upload/$watermarkTransformation");
  }

  return url;
}

String _portfolioDisplayImageUrl(Map item) {
  final baseUrl = _portfolioBaseMediaUrl(item);
  if (baseUrl.isEmpty) return "";

  return _portfolioUsesWatermark(item)
      ? _portfolioAddCloudinaryWatermark(baseUrl, isVideo: false)
      : baseUrl;
}

String _portfolioDisplayVideoPreviewUrl(Map item) {
  final baseUrl = _portfolioBaseMediaUrl(item);
  final thumbnailUrl = (item["thumbnail_url"] ?? "").toString().trim();
  final previewUrl = thumbnailUrl.isNotEmpty
      ? thumbnailUrl
      : _portfolioCloudinaryVideoThumbnail(baseUrl);

  if (previewUrl.isEmpty) return "";

  return _portfolioUsesWatermark(item)
      ? _portfolioAddCloudinaryWatermark(previewUrl, isVideo: false)
      : previewUrl;
}

String _portfolioDisplayVideoUrl(Map item) {
  final baseUrl = _portfolioBaseMediaUrl(item);
  if (baseUrl.isEmpty) return "";

  return _portfolioUsesWatermark(item)
      ? _portfolioAddCloudinaryWatermark(baseUrl, isVideo: true)
      : baseUrl;
}

String _portfolioDisplayMediaUrl(Map item) {
  final mediaType = (item["media_type"] ?? "image").toString();
  final isVideo = mediaType == "video";

  return isVideo ? _portfolioDisplayVideoPreviewUrl(item) : _portfolioDisplayImageUrl(item);
}


class PortfolioManagementScreen extends StatefulWidget {
  const PortfolioManagementScreen({super.key});

  @override
  State<PortfolioManagementScreen> createState() =>
      _PortfolioManagementScreenState();
}

class _PortfolioManagementScreenState extends State<PortfolioManagementScreen>
    with SingleTickerProviderStateMixin {
  final String baseUrl =
      kIsWeb ? "http://localhost:3000/api" : "http://10.0.2.2:3000/api";

  Map? portfolio;
  List categories = [];
  List albums = [];
  List items = [];
  List featured = [];

  bool loading = true;
  bool isSaving = false;
  int? _selectedCategoryId;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  final picker = ImagePicker();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _bgColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardColor => Theme.of(context).cardColor;
  Color get _textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? darkText;
  Color get _subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? softGrey;
  Color get _inputFillColor =>
      _isDarkMode ? const Color(0xFF2A2A2A) : lightCream;
  Color get _sheetBgColor => _cardColor;
  Color get _softSurface =>
      _isDarkMode ? const Color(0xFF252525) : const Color(0xFFE8F0EE);

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  int? _nullableId(dynamic value) {
    final id = _toInt(value);
    return id == 0 ? null : id;
  }

  bool _isVideo(Map item) => item["media_type"]?.toString() == "video";

  bool _usesWatermark(Map item) {
    return _portfolioUsesWatermark(item);
  }

String _cacheBustedMediaUrl(Map item, String url) {
  if (url.isEmpty) return url;

  final watermarkValue = item["use_watermark"] ?? 0;
  final itemId = item["id"] ?? "";
  final separator = url.contains("?") ? "&" : "?";

  return "$url${separator}wm=$watermarkValue&id=$itemId";
}
  String _optionTitle(Map option, String fallback) {
    final title = (option["title"] ?? option["name"] ?? "").toString().trim();
    return title.isEmpty ? fallback : title;
  }

  String _overlayPublicId(String publicId) {
    return _portfolioOverlayPublicId(publicId);
  }

String _addLogoWatermarkToCloudinaryUrl(
  String url, {
  required bool isVideo,
}) {
  return _portfolioAddCloudinaryWatermark(url, isVideo: isVideo);
}


String _cloudinaryVideoThumbnail(String videoUrl) {
  return _portfolioCloudinaryVideoThumbnail(videoUrl);
}
String _portfolioPreviewUrl(Map item) {
  return _portfolioDisplayMediaUrl(item);
}
List get _filteredAlbums {
  if (_selectedCategoryId == null) return albums;

  return albums.where((a) {
    final cid = a["category_id"];
    return cid != null && cid.toString() == _selectedCategoryId.toString();
  }).toList();
}

List get _filteredItems {
  if (_selectedCategoryId == null) return items;

  return items.where((i) {
    final cid = i["category_id"];
    return cid != null && cid.toString() == _selectedCategoryId.toString();
  }).toList();
}

List get _filteredFeatured {
  if (_selectedCategoryId == null) return featured;

  return featured.where((i) {
    final cid = i["category_id"];
    return cid != null && cid.toString() == _selectedCategoryId.toString();
  }).toList();
}

List get _allVisibleItems => [...items, ...featured];

List get _featuredPhotos {
  return _filteredFeatured
      .where((i) => i["media_type"]?.toString() != "video")
      .toList();
}

List get _featuredVideos {
  return _filteredFeatured
      .where((i) => i["media_type"]?.toString() == "video")
      .toList();
}
@override
void initState() {
  super.initState();

  _titleCtrl = TextEditingController();
  _descCtrl = TextEditingController();

  _animCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  _fadeAnim = CurvedAnimation(
    parent: _animCtrl,
    curve: Curves.easeOut,
  );

  loadPortfolio();
}
  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> loadPortfolio() async {
    try {
      final token = await AuthService.getToken();

      final res1 = await http.get(
        Uri.parse("$baseUrl/portfolio/me"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res1.statusCode != 200) {
        if (mounted) setState(() => loading = false);
        return;
      }

      final portfolioId = jsonDecode(res1.body)["id"];

      final res2 = await http.get(
        Uri.parse("$baseUrl/portfolio/full/$portfolioId"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res2.statusCode == 200) {
        final data = jsonDecode(res2.body);
        final rawItems = List.from(data["items"] ?? []);
        final rawFeatured = List.from(data["featured"] ?? []);
        final featuredIds = rawFeatured.map((f) => f["id"].toString()).toSet();

        if (!mounted) return;

        setState(() {
          portfolio = data["portfolio"];
          categories = data["categories"] ?? [];
          albums = data["albums"] ?? [];
          featured = rawFeatured;
          items = rawItems.where((item) {
            return !featuredIds.contains(item["id"].toString());
          }).toList();
          loading = false;
          _titleCtrl.text = portfolio?["title"] ?? "";
          _descCtrl.text = portfolio?["description"] ?? "";
        });

        if (mounted) _animCtrl.forward(from: 0);
      } else {
        if (mounted) setState(() => loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _savePortfolio() async {
    if (!mounted) return;
    setState(() => isSaving = true);

    try {
      final token = await AuthService.getToken();

      if (portfolio?["id"] != null) {
        await http.put(
          Uri.parse("$baseUrl/portfolio/${portfolio?["id"]}"),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
            "title": _titleCtrl.text.trim(),
            "description": _descCtrl.text.trim(),
          }),
        );
      }

      _snack("Portfolio saved successfully ✓", primaryGreen);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      _snack("Failed to save portfolio", _red);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<Map<String, dynamic>?> _uploadPortfolioMedia(File file) async {
    try {
      final token = await AuthService.getToken();

      final req = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/upload-portfolio-media"),
      );

      req.headers["Authorization"] = "Bearer $token";
      req.files.add(await http.MultipartFile.fromPath("media", file.path));

      final streamed = await req.send();
      final response = await http.Response.fromStream(streamed);

      debugPrint("UPLOAD STATUS: ${response.statusCode}");
      debugPrint("UPLOAD BODY: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }

      return null;
    } catch (e) {
      debugPrint("Upload Portfolio Media Error: $e");
      return null;
    }
  }

Future<void> _createPortfolioItem({
  required File file,
  required String mediaType,
  required String title,
  required String description,
  int? albumId,
  int? categoryId,
  required bool useWatermark,
}) async {
  try {
    if (portfolio?["id"] == null) {
      _snack("Portfolio is not ready yet", _red);
      return;
    }

    final uploaded = await _uploadPortfolioMedia(file);

    if (!mounted) return;

    if (uploaded == null) {
      _snack("Upload failed", _red);
      return;
    }

    final mediaUrl = (uploaded["media_url"] ??
            uploaded["url"] ??
            uploaded["secure_url"] ??
            "")
        .toString();

    final uploadedType = (uploaded["media_type"] ?? mediaType).toString();

    final thumbnailUrl = uploaded["thumbnail_url"] ??
        (uploadedType == "video" ? _cloudinaryVideoThumbnail(mediaUrl) : null);

    if (mediaUrl.isEmpty) {
      _snack("Media URL is missing", _red);
      return;
    }

    final token = await AuthService.getToken();

    if (!mounted) return;

    final body = {
      "portfolio_id": portfolio?["id"],
      "album_id": albumId,
      "category_id": categoryId,
      "title": title.trim(),
      "description": description.trim(),
      "media_url": mediaUrl,
      "original_media_url": mediaUrl,
      "thumbnail_url": thumbnailUrl,
      "media_type": uploadedType,
      "use_watermark": useWatermark ? 1 : 0,
    };

    debugPrint("CREATE ITEM REQUEST BODY: ${jsonEncode(body)}");

    final res = await http.post(
      Uri.parse("$baseUrl/portfolio/item"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    debugPrint("CREATE ITEM STATUS: ${res.statusCode}");
    debugPrint("CREATE ITEM BODY: ${res.body}");

    if (!mounted) return;

    if (res.statusCode == 200 || res.statusCode == 201) {
      await loadPortfolio();
      if (!mounted) return;

      _snack(
        uploadedType == "video" ? "Reel added ✓" : "Photo added ✓",
        primaryGreen,
      );
    } else {
      String errorMessage = "Failed to add item";

      try {
        final decoded = jsonDecode(res.body);
        errorMessage = decoded["message"]?.toString() ??
            decoded["error"]?.toString() ??
            errorMessage;
      } catch (_) {}

      _snack(errorMessage, _red);
    }
  } catch (e) {
    debugPrint("Create Portfolio Item Error: $e");
    if (!mounted) return;
    _snack("Failed to add item", _red);
  }
}

  Future<void> _updatePortfolioItem({
    required Map item,
    required String title,
    required String description,
    int? albumId,
    int? categoryId,
    required bool useWatermark,
  }) async {
    try {
      final token = await AuthService.getToken();
      final itemId = item["id"];

      final originalMediaUrl =
          (item["original_media_url"] ?? item["media_url"] ?? "").toString();

      final res = await http.put(
        Uri.parse("$baseUrl/portfolio/item/$itemId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "title": title.trim(),
          "description": description.trim(),
          "album_id": albumId,
          "category_id": categoryId,
          "use_watermark": useWatermark ? 1 : 0,
          "media_url": originalMediaUrl,
          "original_media_url": originalMediaUrl,
          "media_type": item["media_type"],
          "thumbnail_url": item["thumbnail_url"],
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        await loadPortfolio();
        if (!mounted) return;
        _snack("Item updated ✓", primaryGreen);
      } else {
        debugPrint("Update item failed: ${res.statusCode}");
        debugPrint("Update item body: ${res.body}");
        _snack("Failed to update item", _red);
      }
    } catch (e) {
      debugPrint("Update Portfolio Item Error: $e");
      if (!mounted) return;
      _snack("Failed to update item", _red);
    }
  }

  Future<void> _deletePortfolioItem(Map item) async {
    final confirmed = await _confirmDialog(
      title: "Delete item?",
      message: "This item will be removed from your portfolio.",
      confirmLabel: "Delete",
      color: _red,
      icon: Icons.delete_outline_rounded,
    );

    if (confirmed != true) return;

    try {
      final token = await AuthService.getToken();
      final res = await http.delete(
        Uri.parse("$baseUrl/portfolio/item/${item['id']}"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        await loadPortfolio();
        _snack("Item deleted", primaryGreen);
      } else {
        _snack("Failed to delete item", _red);
      }
    } catch (_) {
      _snack("Failed to delete item", _red);
    }
  }

  Future<void> _makeFeatured(Map item) async {
    try {
      final token = await AuthService.getToken();
      final res = await http.put(
        Uri.parse("$baseUrl/portfolio/item/featured/${item['id']}"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        await loadPortfolio();
        _snack("Added to featured", primaryGreen);
      } else {
        _snack("Failed to feature item", _red);
      }
    } catch (_) {
      _snack("Failed to feature item", _red);
    }
  }

  Future<void> _removeFeatured(Map item) async {
    try {
      final token = await AuthService.getToken();
      final res = await http.put(
        Uri.parse("$baseUrl/portfolio/item/unfeatured/${item['id']}"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        await loadPortfolio();
        _snack("Removed from featured", primaryGreen);
      } else {
        _snack("Failed to update", _red);
      }
    } catch (_) {
      _snack("Failed to update", _red);
    }
  }

  Future<void> openAddMediaSheet() async {
    if (!mounted) return;

    await _showItemEditorSheet(
      mode: _ItemEditorMode.create,
      mediaType: "image",
    );
  }

  Future<void> openAddVideoSheet() async {
    if (!mounted) return;

    await _showItemEditorSheet(
      mode: _ItemEditorMode.create,
      mediaType: "video",
    );
  }

  Future<void> _showItemEditorSheet({
    required _ItemEditorMode mode,
    Map? item,
    File? file,
    String? mediaType,
  }) async {
    final isCreate = mode == _ItemEditorMode.create;
    final effectiveType = mediaType ?? item?["media_type"]?.toString() ?? "image";

    final titleCtrl = TextEditingController(
      text: isCreate
          ? (effectiveType == "video" ? "Portfolio Reel" : "Portfolio Photo")
          : (item?["title"] ?? "").toString(),
    );

    final descCtrl = TextEditingController(
      text: isCreate ? "" : (item?["description"] ?? "").toString(),
    );

    File? selectedFile = file;
    int? selectedAlbumId = isCreate ? null : _nullableId(item?["album_id"]);
    int? selectedCategoryId = isCreate ? null : _nullableId(item?["category_id"]);
    bool useWatermark = isCreate ? false : _usesWatermark(item ?? {});
    bool saving = false;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModal) {
            final isDark =
                Theme.of(modalContext).brightness == Brightness.dark;
            final textColor =
                Theme.of(modalContext).textTheme.bodyLarge?.color ?? darkText;
            final subTextColor =
                Theme.of(modalContext).textTheme.bodyMedium?.color ?? softGrey;
            final inputFillColor =
                isDark ? const Color(0xFF2A2A2A) : lightCream;
            final sheetBgColor = Theme.of(modalContext).cardColor;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 14,
                  right: 14,
                  bottom: MediaQuery.of(modalContext).viewInsets.bottom + 14,
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(modalContext).size.height * 0.88,
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: sheetBgColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _localSheetHandle(subTextColor),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: primaryGreen.withOpacity(0.10),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCreate
                                    ? Icons.add_photo_alternate_outlined
                                    : Icons.edit_outlined,
                                color: primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isCreate
                                    ? (effectiveType == "video"
                                        ? "Add Reel"
                                        : "Add Photo")
                                    : "Edit Portfolio Item",
                                style: TextStyle(
                                  color: textColor,
                                  fontFamily: "Playfair",
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (isCreate) ...[
                          GestureDetector(
                            onTap: saving
                                ? null
                                : () async {
                                    try {
                                      final picked = effectiveType == "video"
                                          ? await picker.pickVideo(
                                              source: ImageSource.gallery,
                                            )
                                          : await picker.pickImage(
                                              source: ImageSource.gallery,
                                            );

                                      if (picked == null) return;
                                      if (!modalContext.mounted) return;

                                      setModal(() {
                                        selectedFile = File(picked.path);
                                      });
                                    } catch (e) {
                                      debugPrint(
                                        "Pick portfolio media error: $e",
                                      );
                                      if (!mounted) return;
                                      _snack(
                                        effectiveType == "video"
                                            ? "Failed to pick video"
                                            : "Failed to pick image",
                                        _red,
                                      );
                                    }
                                  },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: inputFillColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selectedFile == null
                                      ? primaryGreen.withOpacity(0.16)
                                      : primaryGreen.withOpacity(0.45),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    effectiveType == "video"
                                        ? Icons.video_library_outlined
                                        : Icons.image_outlined,
                                    color: primaryGreen,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      selectedFile == null
                                          ? (effectiveType == "video"
                                              ? "Choose Reel / Video"
                                              : "Choose Photo")
                                          : "Media selected ✓",
                                      style: TextStyle(
                                        color: selectedFile == null
                                            ? textColor
                                            : primaryGreen,
                                        fontFamily: "Playfair",
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.upload_file_rounded,
                                    color: primaryGreen,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        _localTextField(
                          controller: titleCtrl,
                          label: "Title",
                          textColor: textColor,
                          subTextColor: subTextColor,
                          inputFillColor: inputFillColor,
                        ),
                        const SizedBox(height: 10),
                        _localTextField(
                          controller: descCtrl,
                          label: "Description",
                          maxLines: 3,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          inputFillColor: inputFillColor,
                        ),
                        const SizedBox(height: 14),
                        _localChipsSelector(
                          title: "Album",
                          noneLabel: "No Album",
                          selectedId: selectedAlbumId,
                          options: albums,
                          textColor: textColor,
                          onChanged: (id) {
                            setModal(() => selectedAlbumId = id);
                          },
                        ),
                        const SizedBox(height: 14),
                        _localChipsSelector(
                          title: "Category",
                          noneLabel: "No Category",
                          selectedId: selectedCategoryId,
                          options: categories,
                          textColor: textColor,
                          onChanged: (id) {
                            setModal(() => selectedCategoryId = id);
                          },
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(
                            color: inputFillColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primaryGreen.withOpacity(0.10),
                            ),
                          ),
                          child: CheckboxListTile(
                            value: useWatermark,
                            activeColor: primaryGreen,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            title: Text(
                              "Add Lensia watermark",
                              style: TextStyle(
                                color: textColor,
                                fontFamily: "Playfair",
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              isCreate
                                  ? "Apply watermark when this ${effectiveType == "video" ? "video" : "photo"} is added."
                                  : "Re-apply watermark if the backend supports updating it.",
                              style: TextStyle(
                                color: subTextColor,
                                fontFamily: "Playfair",
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                            onChanged: (value) {
                              setModal(() => useWatermark = value ?? false);
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: primaryGreen.withOpacity(0.35),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: saving
                                    ? null
                                    : () => Navigator.pop(modalContext),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: primaryGreen,
                                    fontFamily: "Playfair",
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: saving
                                    ? null
                                    : () {
                                        if (titleCtrl.text.trim().isEmpty) {
                                          if (mounted) {
                                            _snack("Title is required", _red);
                                          }
                                          return;
                                        }

                                        if (isCreate && selectedFile == null) {
                                          if (mounted) {
                                            _snack(
                                              effectiveType == "video"
                                                  ? "Please choose a video"
                                                  : "Please choose a photo",
                                              _red,
                                            );
                                          }
                                          return;
                                        }

                                        Navigator.of(modalContext).pop({
                                          "file": selectedFile,
                                          "title": titleCtrl.text.trim(),
                                          "description": descCtrl.text.trim(),
                                          "album_id": selectedAlbumId,
                                          "category_id": selectedCategoryId,
                                          "use_watermark": useWatermark,
                                        });
                                      },
                                icon: Icon(isCreate ? Icons.add : Icons.save),
                                label: Text(
                                  isCreate ? "Add" : "Save",
                                  style: const TextStyle(
                                    fontFamily: "Playfair",
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

   

    if (result == null) return;

    if (isCreate) {
      final pickedFile = result["file"] as File?;

      if (pickedFile == null) {
        _snack("Please choose media first", _red);
        return;
      }

      await _createPortfolioItem(
        file: pickedFile,
        mediaType: effectiveType,
        title: result["title"].toString(),
        description: result["description"].toString(),
        albumId: result["album_id"] as int?,
        categoryId: result["category_id"] as int?,
        useWatermark: result["use_watermark"] == true,
      );
    } else {
      if (item == null) return;

      await _updatePortfolioItem(
        item: item,
        title: result["title"].toString(),
        description: result["description"].toString(),
        albumId: result["album_id"] as int?,
        categoryId: result["category_id"] as int?,
        useWatermark: result["use_watermark"] == true,
      );
    }
  }

  Widget _localSheetHandle(Color color) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: color.withOpacity(0.25),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }

  Widget _localTextField({
    required TextEditingController controller,
    required String label,
    required Color textColor,
    required Color subTextColor,
    required Color inputFillColor,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: textColor, fontFamily: "Playfair"),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subTextColor, fontFamily: "Playfair"),
        filled: true,
        fillColor: inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryGreen.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryGreen, width: 1.2),
        ),
      ),
    );
  }

  Widget _localChipsSelector({
    required String title,
    required String noneLabel,
    required int? selectedId,
    required List options,
    required Color textColor,
    required ValueChanged<int?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontFamily: "Playfair",
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(noneLabel),
              selected: selectedId == null,
              selectedColor: primaryGreen,
              labelStyle: TextStyle(
                color: selectedId == null ? Colors.white : textColor,
                fontFamily: "Playfair",
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) => onChanged(null),
            ),
            ...options.map((option) {
              final id = _toInt(option["id"]);
              final active = selectedId == id;

              return ChoiceChip(
                label: Text(_optionTitle(option, "$title $id")),
                selected: active,
                selectedColor: primaryGreen,
                labelStyle: TextStyle(
                  color: active ? Colors.white : textColor,
                  fontFamily: "Playfair",
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (_) => onChanged(active ? null : id),
              );
            }),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: const Center(
          child: CircularProgressIndicator(color: primaryGreen),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: primaryGreen,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildSliverHeader(),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(0),
                child: Container(
                  height: 22,
                  decoration: BoxDecoration(
                    color: _bgColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildStatsRow(),
                  const SizedBox(height: 26),
                  _buildPortfolioInfoSection(),
                  const SizedBox(height: 26),
                  _sectionHeader("Quick Actions", Icons.bolt_rounded),
                  const SizedBox(height: 14),
                  _buildActionsRow(),
                  const SizedBox(height: 26),
                  _buildCategoriesSection(),
                  const SizedBox(height: 26),
                  _buildAlbumsSection(),
                  const SizedBox(height: 26),
                  _buildAllWorksSection(),
                  const SizedBox(height: 26),
                  _buildFeaturedSection(),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3B32), Color(0xFF3E6B5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Portfolio",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: "Playfair",
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "Manage your creative work",
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: "Playfair",
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: isSaving ? null : _savePortfolio,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.35),
                      width: 1,
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Save",
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: "Playfair",
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final all = _allVisibleItems;
    final photos = all.where((i) => i["media_type"] != "video").length;
    final videos = all.where((i) => i["media_type"] == "video").length;

    return Row(
      children: [
        Expanded(
          child: _statCard(
            photos.toString(),
            "Photos",
            Icons.photo_outlined,
            primaryGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            videos.toString(),
            "Videos",
            Icons.videocam_outlined,
            _green2,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            albums.length.toString(),
            "Albums",
            Icons.photo_album_outlined,
            _amber,
          ),
        ),
      ],
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              fontFamily: "Playfair",
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: _subTextColor,
              fontFamily: "Playfair",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryGreen.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Portfolio Info", Icons.edit_note_rounded),
          const SizedBox(height: 14),
          _sheetTextField(_titleCtrl, "Portfolio title"),
          const SizedBox(height: 10),
          _sheetTextField(_descCtrl, "Portfolio description", maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        _actionBtn(
          Icons.add_a_photo_outlined,
          "Add Photo",
          primaryGreen,
          openAddMediaSheet,
        ),
        const SizedBox(width: 12),
        _actionBtn(
          Icons.video_call_outlined,
          "Add Reel",
          _green2,
          openAddVideoSheet,
        ),
        const SizedBox(width: 12),
        _actionBtn(
          Icons.create_new_folder_outlined,
          "New Album",
          _amber,
          openCreateAlbumSheet,
        ),
      ],
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: "Playfair",
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionHeader("Categories", Icons.label_outline),
            const Spacer(),
            GestureDetector(
              onTap: _showAddCategoryDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primaryGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      "Add",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: "Playfair",
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectedCategoryId = null),
                child: _Chip("All", selected: _selectedCategoryId == null),
              ),
              ...categories.map((c) {
                final id = c["id"];
                final isActive =
                    _selectedCategoryId?.toString() == id?.toString();

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = isActive ? null : _toInt(id);
                    });
                  },
                  child: _Chip(
                    c["name"] ?? c["title"] ?? "",
                    selected: isActive,
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionHeader("Albums", Icons.photo_album_outlined),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AllAlbumsScreen(albums: albums),
                ),
              ),
              child: const Row(
                children: [
                  Text(
                    "See All",
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: "Playfair",
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 11,
                    color: primaryGreen,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _filteredAlbums.isEmpty
            ? _emptyState(
                _selectedCategoryId == null
                    ? "No albums yet"
                    : "No albums in this category",
                _selectedCategoryId == null
                    ? "Create your first album"
                    : "Try selecting a different category",
              )
            : SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _filteredAlbums.length,
                  itemBuilder: (_, i) {
                    final album = _filteredAlbums[i];

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AlbumDetailsScreen(albumId: album["id"]),
                        ),
                      ),
                      onLongPress: () => _showEditAlbumSheet(album),
                      child: _albumCard(
                        album["title"] ?? "",
                        (album["items_count"] ?? 0).toString(),
                        album["cover_image"],
                        onEdit: () => _showEditAlbumSheet(album),
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }

  Widget _albumCard(
    String title,
    String count,
    String? coverImage, {
    VoidCallback? onEdit,
  }) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 108,
                decoration: BoxDecoration(
                  color: _softSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryGreen.withOpacity(0.18),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  image: (coverImage != null && coverImage.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(coverImage),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (coverImage == null || coverImage.isEmpty)
                    ? Center(
                        child: Icon(
                          Icons.photo_album_outlined,
                          color: primaryGreen.withOpacity(0.4),
                          size: 34,
                        ),
                      )
                    : null,
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.58),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo, size: 9, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        count,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEdit,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: "Playfair",
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllWorksSection() {
    final data = _filteredItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionHeader("All Works", Icons.grid_view_rounded),
            const Spacer(),
            Text(
              "${data.length} items",
              style: TextStyle(
                color: _subTextColor,
                fontSize: 12,
                fontFamily: "Playfair",
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        data.isEmpty
            ? _emptyState(
                "No works found",
                _selectedCategoryId == null
                    ? "Add photos or reels to your portfolio"
                    : "No works in this category",
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (_, i) => _workCard(data[i], featuredCard: false),
              ),
      ],
    );
  }

  Widget _buildFeaturedSection() {
    final hasPhotos = _featuredPhotos.isNotEmpty;
    final hasVideos = _featuredVideos.isNotEmpty;
    final hasAny = hasPhotos || hasVideos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, color: _amber, size: 20),
            const SizedBox(width: 6),
            Text(
              "Featured Work",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: "Playfair",
                color: _textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Tap to view · use buttons to edit, delete, or unfeature",
          style: TextStyle(
            fontSize: 11,
            color: _subTextColor,
            fontFamily: "Playfair",
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        if (!hasAny)
          _emptyState("No featured work", "Star your best photos or videos")
        else ...[
          if (hasPhotos) ...[
            _subLabel(Icons.photo_outlined, "Photos"),
            const SizedBox(height: 10),
            _featuredGrid(_featuredPhotos),
          ],
          if (hasVideos) ...[
            if (hasPhotos) const SizedBox(height: 22),
            _subLabel(Icons.videocam_outlined, "Reels & Videos"),
            const SizedBox(height: 10),
            _featuredGrid(_featuredVideos),
          ],
        ],
      ],
    );
  }

  Widget _featuredGrid(List data) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (_, i) => _workCard(data[i], featuredCard: true),
    );
  }

  Widget _workCard(Map item, {required bool featuredCard}) {
    final url = _portfolioPreviewUrl(item);
    final isVideo = _isVideo(item);
    final title = (item["title"] ?? "").toString();
    final description = (item["description"] ?? "").toString();

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _openItemPreview(item),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  url.isNotEmpty
                      ? Image.network(
                          _cacheBustedMediaUrl(item, url),
                          fit: BoxFit.cover,
                          gaplessPlayback: false,
                          errorBuilder: (_, __, ___) => _imageFallback(isVideo),
                        )
                      : _imageFallback(isVideo),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.02),
                          Colors.black.withOpacity(0.55),
                        ],
                      ),
                    ),
                  ),
                  if (isVideo)
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        size: 48,
                        color: Color(0xC7FFFFFF),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _badge(
                      isVideo ? Icons.videocam : Icons.photo,
                      isVideo ? "Video" : "Photo",
                      isVideo ? Colors.blueGrey : primaryGreen,
                    ),
                  ),
if (featuredCard)
  Positioned(
    top: 8,
    right: 8,
    child: _badge(Icons.star_rounded, "Featured", _amber),
  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? "Untitled" : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textColor,
                    fontFamily: "Playfair",
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _subTextColor,
                      fontFamily: "Playfair",
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _miniIconButton(
                      icon: Icons.edit_outlined,
                      color: primaryGreen,
                      onTap: () => _showItemEditorSheet(
                        mode: _ItemEditorMode.edit,
                        item: item,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _miniIconButton(
                      icon: featuredCard
                          ? Icons.star_border_rounded
                          : Icons.star_rounded,
                      color: _amber,
                      onTap: () => featuredCard
                          ? _removeFeatured(item)
                          : _makeFeatured(item),
                    ),
                    const SizedBox(width: 6),
                    _miniIconButton(
                      icon: Icons.delete_outline_rounded,
                      color: _red,
                      onTap: () => _deletePortfolioItem(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback(bool isVideo) {
    return Container(
      color: _softSurface,
      child: Center(
        child: Icon(
          isVideo ? Icons.videocam_outlined : Icons.image_outlined,
          size: 36,
          color: _subTextColor.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _miniIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }

  void _openItemPreview(Map item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (_) => _isVideo(item)
          ? _VideoPlayerDialog(item: item)
          : _PhotoPreviewDialog(item: item),
    );
  }

  Widget _sectionHeader(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryGreen, size: 18),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            fontFamily: "Playfair",
            color: _textColor,
          ),
        ),
      ],
    );
  }

  Widget _subLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _green2),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: "Playfair",
            color: _textColor,
          ),
        ),
      ],
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGreen.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 32,
            color: _subTextColor.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: "Playfair",
              color: _textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Playfair",
              color: _subTextColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final textColor =
            Theme.of(dialogContext).textTheme.bodyLarge?.color ?? darkText;
        final subTextColor =
            Theme.of(dialogContext).textTheme.bodyMedium?.color ?? softGrey;
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final inputFillColor =
            isDark ? const Color(0xFF2A2A2A) : lightCream;
        final bgColor = Theme.of(dialogContext).cardColor;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: bgColor,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.folder_outlined,
                    color: primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Add Category",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Playfair",
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),
                _localTextField(
                  controller: ctrl,
                  label: "Category name",
                  textColor: textColor,
                  subTextColor: subTextColor,
                  inputFillColor: inputFillColor,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: primaryGreen.withOpacity(0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: primaryGreen,
                            fontFamily: "Playfair",
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final name = ctrl.text.trim();
                          if (name.isEmpty) return;

                          final token = await AuthService.getToken();
                          final res = await http.post(
                            Uri.parse("$baseUrl/portfolio/category"),
                            headers: {
                              "Content-Type": "application/json",
                              "Authorization": "Bearer $token",
                            },
                            body: jsonEncode({
                              "name": name,
                              "portfolio_id": portfolio?["id"],
                            }),
                          );
debugPrint("CREATE ITEM STATUS: ${res.statusCode}");
debugPrint("CREATE ITEM BODY: ${res.body}");
                          if (res.statusCode == 201) {
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            await loadPortfolio();
                            if (mounted) {
                              _snack("Category added ✓", primaryGreen);
                            }
                          } else {
                            if (mounted) {
                              _snack("Failed to add category", _red);
                            }
                          }
                        },
                        child: const Text(
                          "Add",
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: "Playfair",
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      ctrl.dispose();
    });
  }

 Future<void> openCreateAlbumSheet() async {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  int? selectedCategoryId;
  File? selectedCover;

  final result = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (modalContext, setModal) {
          final isDark = Theme.of(modalContext).brightness == Brightness.dark;
          final textColor =
              Theme.of(modalContext).textTheme.bodyLarge?.color ?? darkText;
          final subTextColor =
              Theme.of(modalContext).textTheme.bodyMedium?.color ?? softGrey;
          final inputFillColor =
              isDark ? const Color(0xFF2A2A2A) : lightCream;
          final sheetBgColor = Theme.of(modalContext).cardColor;

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 14,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(modalContext).size.height * 0.88,
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  color: sheetBgColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: subTextColor.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "Create Album",
                        style: TextStyle(
                          color: textColor,
                          fontFamily: "Playfair",
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: titleCtrl,
                        style: TextStyle(
                          color: textColor,
                          fontFamily: "Playfair",
                        ),
                        decoration: InputDecoration(
                          labelText: "Album title",
                          labelStyle: TextStyle(
                            color: subTextColor,
                            fontFamily: "Playfair",
                          ),
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: primaryGreen.withOpacity(0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: primaryGreen,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descCtrl,
                        maxLines: 3,
                        style: TextStyle(
                          color: textColor,
                          fontFamily: "Playfair",
                        ),
                        decoration: InputDecoration(
                          labelText: "Album description",
                          labelStyle: TextStyle(
                            color: subTextColor,
                            fontFamily: "Playfair",
                          ),
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: primaryGreen.withOpacity(0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: primaryGreen,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "Category",
                        style: TextStyle(
                          color: textColor,
                          fontFamily: "Playfair",
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text("No Category"),
                            selected: selectedCategoryId == null,
                            selectedColor: primaryGreen,
                            labelStyle: TextStyle(
                              color: selectedCategoryId == null
                                  ? Colors.white
                                  : textColor,
                              fontFamily: "Playfair",
                              fontWeight: FontWeight.w700,
                            ),
                            onSelected: (_) {
                              setModal(() => selectedCategoryId = null);
                            },
                          ),
                          ...categories.map((option) {
                            final id = _toInt(option["id"]);
                            final active = selectedCategoryId == id;

                            return ChoiceChip(
                              label: Text(
                                _optionTitle(option, "Category $id"),
                              ),
                              selected: active,
                              selectedColor: primaryGreen,
                              labelStyle: TextStyle(
                                color: active ? Colors.white : textColor,
                                fontFamily: "Playfair",
                                fontWeight: FontWeight.w700,
                              ),
                              onSelected: (_) {
                                setModal(() {
                                  selectedCategoryId = active ? null : id;
                                });
                              },
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () async {
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                          );

                          if (picked == null) return;
                          if (!modalContext.mounted) return;

                          setModal(() {
                            selectedCover = File(picked.path);
                          });
                        },
                        child: Container(
                          height: 92,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: inputFillColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primaryGreen.withOpacity(0.12),
                            ),
                          ),
                          child: selectedCover == null
                              ? const Center(
                                  child: Text(
                                    "Choose Cover Image",
                                    style: TextStyle(
                                      color: primaryGreen,
                                      fontFamily: "Playfair",
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    selectedCover!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: primaryGreen.withOpacity(0.35),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () => Navigator.pop(modalContext),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontFamily: "Playfair",
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                final title = titleCtrl.text.trim();

                                if (title.isEmpty) {
                                  if (mounted) {
                                    _snack("Album title is required", _red);
                                  }
                                  return;
                                }

                                Navigator.of(modalContext).pop({
                                  "title": title,
                                  "description": descCtrl.text.trim(),
                                  "category_id": selectedCategoryId,
                                  "cover": selectedCover,
                                });
                              },
                              icon: const Icon(
                                Icons.create_new_folder_outlined,
                              ),
                              label: const Text(
                                "Create Album",
                                style: TextStyle(
                                  fontFamily: "Playfair",
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  if (result == null) return;

  await createAlbum(
    result["title"].toString(),
    result["description"].toString(),
    result["category_id"] as int?,
    result["cover"] as File?,
  );
}

Future<void> createAlbum(
  String title,
  String description,
  int? categoryId,
  File? coverImage,
) async {
  try {
    final token = await AuthService.getToken();
    String? coverUrl;

    if (coverImage != null) {
      final uploaded = await _uploadPortfolioMedia(coverImage);

      if (uploaded == null) {
        _snack("Cover upload failed", _red);
        return;
      }

      coverUrl = (uploaded["media_url"] ?? uploaded["url"] ?? "").toString();

      if (coverUrl.isEmpty) {
        _snack("Cover URL is missing", _red);
        return;
      }
    }

    final res = await http.post(
      Uri.parse("$baseUrl/portfolio/album"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "portfolio_id": portfolio?["id"],
        "category_id": categoryId,
        "title": title,
        "description": description,
        "cover_image": coverUrl,
      }),
    );

    debugPrint("CREATE ALBUM STATUS: ${res.statusCode}");
    debugPrint("CREATE ALBUM BODY: ${res.body}");

    if (!mounted) return;

    if (res.statusCode == 200 || res.statusCode == 201) {
      await loadPortfolio();
      if (!mounted) return;
      _snack("Album created ✓", primaryGreen);
    } else if (res.statusCode == 400) {
      _snack("Album name already exists", Colors.orange);
    } else {
      String errorMessage = "Error creating album";

      try {
        final decoded = jsonDecode(res.body);
        errorMessage = decoded["message"]?.toString() ??
            decoded["error"]?.toString() ??
            errorMessage;
      } catch (_) {}

      _snack(errorMessage, _red);
    }
  } catch (e) {
    debugPrint("Create Album Error: $e");
    if (!mounted) return;
    _snack("Error creating album", _red);
  }
}
  void _showEditAlbumSheet(Map album) {
    final titleCtrl = TextEditingController(text: album["title"] ?? "");
    final descCtrl = TextEditingController(text: album["description"] ?? "");
    File? newCover;
    String? coverUrl = album["cover_image"];
    bool saving = false;
    int? selectedCatId = _nullableId(album["category_id"]);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModal) {
            final isDark =
                Theme.of(modalContext).brightness == Brightness.dark;
            final textColor =
                Theme.of(modalContext).textTheme.bodyLarge?.color ?? darkText;
            final subTextColor =
                Theme.of(modalContext).textTheme.bodyMedium?.color ?? softGrey;
            final inputFillColor =
                isDark ? const Color(0xFF2A2A2A) : lightCream;
            final sheetBgColor = Theme.of(modalContext).cardColor;

            Future<void> save() async {
              if (titleCtrl.text.trim().isEmpty) {
                if (mounted) _snack("Album name cannot be empty", _red);
                return;
              }

              setModal(() => saving = true);

              try {
                final token = await AuthService.getToken();

                if (newCover != null) {
                  final uploaded = await _uploadPortfolioMedia(newCover!);
                  coverUrl = uploaded?["media_url"] ?? uploaded?["url"];
                }

                final res = await http.put(
                  Uri.parse("$baseUrl/portfolio/album/${album['id']}"),
                  headers: {
                    "Content-Type": "application/json",
                    "Authorization": "Bearer $token",
                  },
                  body: jsonEncode({
                    "title": titleCtrl.text.trim(),
                    "description": descCtrl.text.trim(),
                    "cover_image": coverUrl,
                    "category_id": selectedCatId,
                  }),
                );

                if (res.statusCode == 200) {
                  if (modalContext.mounted) Navigator.pop(modalContext);
                  await loadPortfolio();
                  if (mounted) _snack("Album updated ✓", primaryGreen);
                } else {
                  if (mounted) _snack("Failed to update album", _red);
                }
              } catch (_) {
                if (mounted) _snack("Network error", _red);
              }

              if (modalContext.mounted) {
                setModal(() => saving = false);
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 14,
                  right: 14,
                  bottom: MediaQuery.of(modalContext).viewInsets.bottom + 14,
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(modalContext).size.height * 0.88,
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: sheetBgColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _localSheetHandle(subTextColor),
                        const SizedBox(height: 14),
                        Text(
                          "Edit Album",
                          style: TextStyle(
                            color: textColor,
                            fontFamily: "Playfair",
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _localTextField(
                          controller: titleCtrl,
                          label: "Album title",
                          textColor: textColor,
                          subTextColor: subTextColor,
                          inputFillColor: inputFillColor,
                        ),
                        const SizedBox(height: 10),
                        _localTextField(
                          controller: descCtrl,
                          label: "Description",
                          maxLines: 3,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          inputFillColor: inputFillColor,
                        ),
                        const SizedBox(height: 14),
                        _localChipsSelector(
                          title: "Category",
                          noneLabel: "No Category",
                          selectedId: selectedCatId,
                          options: categories,
                          textColor: textColor,
                          onChanged: (id) {
                            setModal(() => selectedCatId = id);
                          },
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () async {
                            final picked = await picker.pickImage(
                              source: ImageSource.gallery,
                            );

                            if (picked != null && modalContext.mounted) {
                              setModal(() => newCover = File(picked.path));
                            }
                          },
                          child: Container(
                            height: 92,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: inputFillColor,
                              borderRadius: BorderRadius.circular(16),
                              image: (newCover == null &&
                                      coverUrl != null &&
                                      coverUrl!.isNotEmpty)
                                  ? DecorationImage(
                                      image: NetworkImage(coverUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                newCover == null ? "Change Cover" : "New cover ✓",
                                style: const TextStyle(
                                  color: primaryGreen,
                                  fontFamily: "Playfair",
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _localSaveButton(
                          loading: saving,
                          onTap: save,
                          label: "Save Album",
                          icon: Icons.save,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      titleCtrl.dispose();
      descCtrl.dispose();
    });
  }

  Widget _localSaveButton({
    required bool loading,
    required VoidCallback onTap,
    required String label,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
        onPressed: loading ? null : onTap,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: "Playfair",
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _chipsSelector({
    required String title,
    required String noneLabel,
    required int? selectedId,
    required List options,
    required ValueChanged<int?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _textColor,
            fontFamily: "Playfair",
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(noneLabel),
              selected: selectedId == null,
              selectedColor: primaryGreen,
              labelStyle: TextStyle(
                color: selectedId == null ? Colors.white : _textColor,
                fontFamily: "Playfair",
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) => onChanged(null),
            ),
            ...options.map((option) {
              final id = _toInt(option["id"]);
              final active = selectedId == id;

              return ChoiceChip(
                label: Text(_optionTitle(option, "$title $id")),
                selected: active,
                selectedColor: primaryGreen,
                labelStyle: TextStyle(
                  color: active ? Colors.white : _textColor,
                  fontFamily: "Playfair",
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (_) => onChanged(active ? null : id),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _sheetTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: _textColor, fontFamily: "Playfair"),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _subTextColor, fontFamily: "Playfair"),
        filled: true,
        fillColor: _inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryGreen.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryGreen, width: 1.2),
        ),
      ),
    );
  }

  Widget _sheetHandle() {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: _subTextColor.withOpacity(0.25),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }

  Widget _sheetContainer({required BuildContext ctx, required Widget child}) {
    final sheetBgColor = Theme.of(ctx).cardColor;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 14,
          right: 14,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 14,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: sheetBgColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  Widget _sheetSaveBtn(
    bool loading,
    VoidCallback onTap,
    String label, {
    IconData? icon,
  }) {
    return _localSaveButton(
      loading: loading,
      onTap: onTap,
      label: label,
      icon: icon,
    );
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color color,
    required IconData icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final textColor =
            Theme.of(dialogContext).textTheme.bodyLarge?.color ?? darkText;
        final subTextColor =
            Theme.of(dialogContext).textTheme.bodyMedium?.color ?? softGrey;
        final sheetBgColor = Theme.of(dialogContext).cardColor;

        return AlertDialog(
          backgroundColor: sheetBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontFamily: "Playfair",
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: subTextColor,
              fontFamily: "Playfair",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: "Playfair")),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

enum _ItemEditorMode { create, edit }

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;

  const _Chip(this.label, {required this.selected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? primaryGreen
            : (isDark ? const Color(0xFF252525) : Colors.white),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? primaryGreen : primaryGreen.withOpacity(0.15),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : primaryGreen,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: "Playfair",
        ),
      ),
    );
  }
}

class _PhotoPreviewDialog extends StatelessWidget {
  final Map item;

  const _PhotoPreviewDialog({required this.item});

  @override
  Widget build(BuildContext context) {


  final displayUrl = _portfolioDisplayImageUrl(item);

  final title = (item["title"] ?? "").toString();
  final description = (item["description"] ?? "").toString();


    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.black,
                child: displayUrl.isNotEmpty
                    ? InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4,
                        child: Image.network(
                          displayUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white30,
                              size: 56,
                            ),
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white30,
                          size: 56,
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
          if (title.isNotEmpty || description.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  22,
                  48,
                  22,
                  MediaQuery.of(context).padding.bottom + 26,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.88),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: "Playfair",
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontFamily: "Playfair",
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoPlayerDialog extends StatefulWidget {
  final Map item;

  const _VideoPlayerDialog({required this.item});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _error = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();

    final url = _portfolioDisplayVideoUrl(widget.item);

    _ctrl = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _ctrl.play();
        }
      }).catchError((_) {
        if (mounted) setState(() => _error = true);
      });

    _ctrl.setLooping(true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_initialized) return;

    setState(() {
      _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item["title"]?.toString() ?? "";
    final description = widget.item["description"]?.toString() ?? "";
    final hasInfo = title.isNotEmpty || description.isNotEmpty;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: _error
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.white30,
                                size: 48,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "Failed to load video",
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                  fontFamily: "Playfair",
                                ),
                              ),
                            ],
                          ),
                        )
                      : !_initialized
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white60,
                                strokeWidth: 2,
                              ),
                            )
                          : GestureDetector(
                              onTap: _togglePlay,
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: _ctrl.value.aspectRatio,
                                  child: VideoPlayer(_ctrl),
                                ),
                              ),
                            ),
                ),
              ),
              if (_initialized && !_ctrl.value.isPlaying)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      color: Colors.black26,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 72,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: safeTop + 12,
                right: 16,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (hasInfo)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_showControls,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(
                          22,
                          48,
                          22,
                          safeBottom + 26,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.88),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (title.isNotEmpty)
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: "Playfair",
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                description,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontFamily: "Playfair",
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}