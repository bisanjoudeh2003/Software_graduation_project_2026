import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/community_service.dart';

class AddCommunityPostPage extends StatefulWidget {
  final bool defaultIsQuestion;

  const AddCommunityPostPage({
    super.key,
    this.defaultIsQuestion = false,
  });

  @override
  State<AddCommunityPostPage> createState() => _AddCommunityPostPageState();
}

class _AddCommunityPostPageState extends State<AddCommunityPostPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);
  static const Color blue = Color(0xFF1565C0);
  static const Color purple = Color(0xFF7C4DBC);

  final TextEditingController titleController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  bool posting = false;
  late bool isQuestion;

  String selectedCategory = "general";

  List<XFile> selectedMedia = [];

  final List<Map<String, dynamic>> categories = const [
    {
      "value": "general",
      "label": "General",
      "icon": Icons.forum_outlined,
    },
    {
      "value": "tips",
      "label": "Tips",
      "icon": Icons.lightbulb_outline_rounded,
    },
    {
      "value": "gear",
      "label": "Gear",
      "icon": Icons.camera_alt_outlined,
    },
    {
      "value": "editing",
      "label": "Editing",
      "icon": Icons.auto_fix_high_rounded,
    },
    {
      "value": "lighting",
      "label": "Lighting",
      "icon": Icons.flash_on_rounded,
    },
    {
      "value": "graduation",
      "label": "Graduation",
      "icon": Icons.school_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    isQuestion = widget.defaultIsQuestion;

    if (isQuestion) {
      selectedCategory = "general";
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  bool _isVideoFile(XFile file) {
    final name = file.name.toLowerCase();
    final path = file.path.toLowerCase();

    return name.endsWith(".mp4") ||
        name.endsWith(".mov") ||
        name.endsWith(".webm") ||
        name.endsWith(".avi") ||
        name.endsWith(".mkv") ||
        path.endsWith(".mp4") ||
        path.endsWith(".mov") ||
        path.endsWith(".webm") ||
        path.endsWith(".avi") ||
        path.endsWith(".mkv");
  }

  Future<void> _pickImages() async {
    try {
      final images = await picker.pickMultiImage(
        imageQuality: 85,
      );

      if (images.isEmpty) return;

      final remainingSlots = 10 - selectedMedia.length;

      if (remainingSlots <= 0) {
        _showMessageBox(
          title: "Limit Reached",
          message: "You can upload up to 10 photos/videos only.",
          isError: true,
        );
        return;
      }

      setState(() {
        selectedMedia.addAll(images.take(remainingSlots));
      });
    } catch (e) {
      _showMessageBox(
        title: "Error",
        message: "Failed to pick images.",
        isError: true,
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      if (selectedMedia.length >= 10) {
        _showMessageBox(
          title: "Limit Reached",
          message: "You can upload up to 10 photos/videos only.",
          isError: true,
        );
        return;
      }

      final video = await picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video == null) return;

      setState(() {
        selectedMedia.add(video);
      });
    } catch (e) {
      _showMessageBox(
        title: "Error",
        message: "Failed to pick video.",
        isError: true,
      );
    }
  }

  void _removeMedia(int index) {
    setState(() {
      selectedMedia.removeAt(index);
    });
  }

  Future<void> _createPost() async {
    final title = titleController.text.trim();
    final body = bodyController.text.trim();

    if (body.isEmpty) {
      _showMessageBox(
        title: "Missing Content",
        message: "Please write something before posting.",
        isError: true,
      );
      return;
    }

    setState(() => posting = true);

    try {
      List<Map<String, dynamic>> uploadedMedia = [];

      if (selectedMedia.isNotEmpty) {
        uploadedMedia = await CommunityService.uploadMedia(selectedMedia);
      }

      await CommunityService.createPost(
        title: title,
        body: body,
        category: selectedCategory,
        isQuestion: isQuestion,
        media: uploadedMedia,
      );

      if (!mounted) return;

      await _showMessageBox(
        title: "Posted",
        message: uploadedMedia.any((m) => m["media_type"] == "video")
            ? "Your post has been shared. Video posts will also appear in Reels."
            : "Your post has been shared successfully.",
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _showMessageBox(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }

    if (mounted) {
      setState(() => posting = false);
    }
  }

  Future<void> _showMessageBox({
    required String title,
    required String message,
    bool isError = false,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isError
                      ? softRed.withOpacity(.12)
                      : primaryGreen.withOpacity(.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: isError ? softRed : primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: isError ? softRed : primaryGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black54,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isError ? softRed : primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "OK",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      bottomSheet: _bottomButton(),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 130),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _postTypeSelector(),
                  const SizedBox(height: 18),
                  _sectionTitle("Category"),
                  const SizedBox(height: 10),
                  _categorySelector(),
                  const SizedBox(height: 20),
                  _sectionTitle("Title"),
                  const SizedBox(height: 10),
                  _inputBox(
                    controller: titleController,
                    hint: isQuestion
                        ? "Example: Best lens for graduation photos?"
                        : "Add a short title...",
                    maxLines: 1,
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle(isQuestion ? "Your Question" : "Post Content"),
                  const SizedBox(height: 10),
                  _inputBox(
                    controller: bodyController,
                    hint: isQuestion
                        ? "Explain your question so other photographers can help..."
                        : "Share your idea, tip, setup, experience, or advice...",
                    maxLines: 8,
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle("Photos / Reel"),
                  const SizedBox(height: 10),
                  _mediaPickerBox(),
                  if (selectedMedia.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _selectedMediaList(),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    selectedMedia.isEmpty
                        ? "You can publish text only, or add photos/videos. Videos will appear in the Reels page."
                        : "${selectedMedia.length}/10 selected",
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.black38,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: posting ? null : () => Navigator.pop(context, false),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                isQuestion ? "Ask a Question" : "Create Post",
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isQuestion
                    ? "Ask photographers about gear, settings, editing, or sessions."
                    : "Share tips, photos, videos, reels, setups and inspiration.",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white.withOpacity(.75),
                  fontSize: 13.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _postTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _typeBox(
            selected: !isQuestion,
            icon: Icons.article_outlined,
            title: "Post",
            subtitle: "Tip or experience",
            onTap: posting ? () {} : () => setState(() => isQuestion = false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _typeBox(
            selected: isQuestion,
            icon: Icons.help_outline_rounded,
            title: "Question",
            subtitle: "Ask for help",
            onTap: posting ? () {} : () => setState(() => isQuestion = true),
          ),
        ),
      ],
    );
  }

  Widget _typeBox({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 106,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? primaryGreen : lightGreen.withOpacity(.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.045),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : primaryGreen,
              size: 25,
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: selected ? Colors.white : primaryGreen,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: selected ? Colors.white70 : Colors.black45,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: "Montserrat",
        color: primaryGreen,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _categorySelector() {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: categories.map((item) {
        final value = item["value"] as String;
        final label = item["label"] as String;
        final icon = item["icon"] as IconData;
        final selected = selectedCategory == value;

        return GestureDetector(
          onTap: posting ? null : () => setState(() => selectedCategory = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? primaryGreen : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: selected ? primaryGreen : lightGreen.withOpacity(.6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: selected ? Colors.white : primaryGreen,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: selected ? Colors.white : primaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _inputBox({
    required TextEditingController controller,
    required String hint,
    required int maxLines,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: lightGreen.withOpacity(.45),
        ),
      ),
      child: TextField(
        enabled: !posting,
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
          fontFamily: "Montserrat",
          color: primaryGreen,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontFamily: "Montserrat",
            color: Colors.black38,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(15),
        ),
      ),
    );
  }

  Widget _mediaPickerBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: lightGreen.withOpacity(.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _mediaButton(
                  icon: Icons.photo_library_outlined,
                  title: "Add Photos",
                  subtitle: "Choose multiple images",
                  color: primaryGreen,
                  onTap: posting ? () {} : _pickImages,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _mediaButton(
                  icon: Icons.video_collection_outlined,
                  title: "Add Reel",
                  subtitle: "Choose one video",
                  color: purple,
                  onTap: posting ? () {} : _pickVideo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mediaButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withOpacity(.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black38,
                fontWeight: FontWeight.w600,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedMediaList() {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: selectedMedia.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final file = selectedMedia[index];
          final isVideo = _isVideoFile(file);

          return Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: lightGreen.withOpacity(.55)),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: isVideo
                      ? Container(
                          color: Colors.black87,
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                        )
                      : kIsWeb
                          ? FutureBuilder<Uint8List>(
                              future: file.readAsBytes(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: primaryGreen,
                                      strokeWidth: 2,
                                    ),
                                  );
                                }

                                return Image.memory(
                                  snapshot.data!,
                                  width: 104,
                                  height: 104,
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : Image.network(
                              file.path,
                              width: 104,
                              height: 104,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return const Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: primaryGreen,
                                  ),
                                );
                              },
                            ),
                ),
                Positioned(
                  left: 7,
                  bottom: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isVideo
                              ? Icons.videocam_rounded
                              : Icons.image_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isVideo ? "Reel" : "Photo",
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: posting ? null : () => _removeMedia(index),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: softRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _bottomButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: posting ? null : _createPost,
          icon: posting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.cloud_upload_rounded),
          label: Text(
            posting ? "Uploading & Publishing..." : "Publish",
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade600,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }
}