
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/community_service.dart';

class AddCommunityPostPageWeb extends StatefulWidget {
  final bool defaultIsQuestion;

  const AddCommunityPostPageWeb({
    super.key,
    this.defaultIsQuestion = false,
  });

  @override
  State<AddCommunityPostPageWeb> createState() => _AddCommunityPostPageWebState();
}

class _AddCommunityPostPageWebState extends State<AddCommunityPostPageWeb> {
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
    {"value": "general", "label": "General", "icon": Icons.forum_outlined},
    {"value": "tips", "label": "Tips", "icon": Icons.lightbulb_outline_rounded},
    {"value": "gear", "label": "Gear", "icon": Icons.camera_alt_outlined},
    {"value": "editing", "label": "Editing", "icon": Icons.auto_fix_high_rounded},
    {"value": "lighting", "label": "Lighting", "icon": Icons.flash_on_rounded},
    {"value": "graduation", "label": "Graduation", "icon": Icons.school_outlined},
  ];

  @override
  void initState() {
    super.initState();
    isQuestion = widget.defaultIsQuestion;
    if (isQuestion) selectedCategory = "general";
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
      final images = await picker.pickMultiImage(imageQuality: 85);
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

      setState(() => selectedMedia.addAll(images.take(remainingSlots)));
    } catch (_) {
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

      final video = await picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;

      setState(() => selectedMedia.add(video));
    } catch (_) {
      _showMessageBox(
        title: "Error",
        message: "Failed to pick video.",
        isError: true,
      );
    }
  }

  void _removeMedia(int index) {
    setState(() => selectedMedia.removeAt(index));
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

    if (mounted) setState(() => posting = false);
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
                  isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  String get _postTypeText => isQuestion ? "Question" : "Post";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 26, 30, 34),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _webHeader(),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 980;

                      if (!isWide) {
                        return Column(
                          children: [
                            _editorCard(),
                            const SizedBox(height: 18),
                            _sidePanel(),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: _editorCard()),
                          const SizedBox(width: 24),
                          Expanded(flex: 4, child: _sidePanel()),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _webHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: posting ? null : () => Navigator.pop(context, false),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.16),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(.16)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isQuestion ? "Ask a Question" : "Create Community Post",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isQuestion
                      ? "Ask photographers about gear, settings, editing, or sessions."
                      : "Share tips, photos, videos, reels, setups and inspiration.",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white.withOpacity(.76),
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _desktopPublishButton(compact: true),
        ],
      ),
    );
  }

  Widget _editorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Post Type"),
          const SizedBox(height: 12),
          _postTypeSelector(),
          const SizedBox(height: 24),
          _sectionTitle("Category"),
          const SizedBox(height: 12),
          _categorySelector(),
          const SizedBox(height: 24),
          _sectionTitle("Title"),
          const SizedBox(height: 10),
          _inputBox(
            controller: titleController,
            hint: isQuestion
                ? "Example: Best lens for graduation photos?"
                : "Add a short title...",
            maxLines: 1,
          ),
          const SizedBox(height: 22),
          _sectionTitle(isQuestion ? "Your Question" : "Post Content"),
          const SizedBox(height: 10),
          _inputBox(
            controller: bodyController,
            hint: isQuestion
                ? "Explain your question so other photographers can help..."
                : "Share your idea, tip, setup, experience, or advice...",
            maxLines: 10,
          ),
        ],
      ),
    );
  }

  Widget _sidePanel() {
    return Column(
      children: [
        _summaryCard(),
        const SizedBox(height: 18),
        _mediaCard(),
        const SizedBox(height: 18),
        _desktopPublishButton(),
      ],
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Quick Summary"),
          const SizedBox(height: 14),
          _summaryRow("Type", _postTypeText),
          _summaryRow("Category", selectedCategory),
          _summaryRow("Media", "${selectedMedia.length}/10 selected"),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: paleGreen,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: lightGreen.withOpacity(.45)),
            ),
            child: Text(
              selectedMedia.isEmpty
                  ? "You can publish text only, or add photos/videos. Videos will appear in the Reels page."
                  : "Selected media will be uploaded after you press Publish.",
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
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

  Widget _mediaCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Photos / Reel"),
          const SizedBox(height: 12),
          _mediaPickerBox(),
          if (selectedMedia.isNotEmpty) ...[
            const SizedBox(height: 16),
            _selectedMediaGrid(),
          ],
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: lightGreen.withOpacity(.35)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.045),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _postTypeSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 520;
        final children = [
          Expanded(
            child: _typeBox(
              selected: !isQuestion,
              icon: Icons.article_outlined,
              title: "Post",
              subtitle: "Tip, setup, story or experience",
              onTap: posting ? () {} : () => setState(() => isQuestion = false),
            ),
          ),
          SizedBox(width: isWide ? 14 : 0, height: isWide ? 0 : 12),
          Expanded(
            child: _typeBox(
              selected: isQuestion,
              icon: Icons.help_outline_rounded,
              title: "Question",
              subtitle: "Ask photographers for help",
              onTap: posting ? () {} : () => setState(() => isQuestion = true),
            ),
          ),
        ];

        return isWide
            ? Row(children: children)
            : Column(children: children.map((w) => w is Expanded ? SizedBox(height: 106, child: w.child) : w).toList());
      },
    );
  }

  Widget _typeBox({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 106,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? primaryGreen : paleGreen,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? primaryGreen : lightGreen.withOpacity(.55),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected ? Colors.white.withOpacity(.16) : Colors.white,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : primaryGreen,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: selected ? Colors.white : primaryGreen,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: selected ? Colors.white70 : Colors.black45,
                      fontSize: 11.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
      spacing: 10,
      runSpacing: 10,
      children: categories.map((item) {
        final value = item["value"] as String;
        final label = item["label"] as String;
        final icon = item["icon"] as IconData;
        final selected = selectedCategory == value;

        return InkWell(
          onTap: posting ? null : () => setState(() => selectedCategory = value),
          borderRadius: BorderRadius.circular(30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? primaryGreen : paleGreen,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: selected ? primaryGreen : lightGreen.withOpacity(.6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: selected ? Colors.white : primaryGreen, size: 17),
                const SizedBox(width: 7),
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
    return TextField(
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
        filled: true,
        fillColor: paleGreen.withOpacity(.75),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: lightGreen.withOpacity(.45)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: lightGreen.withOpacity(.45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primaryGreen, width: 1.4),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _mediaPickerBox() {
    return Row(
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
        const SizedBox(width: 12),
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
    );
  }

  Widget _mediaButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 106,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 3),
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

  Widget _selectedMediaGrid() {
    return GridView.builder(
      itemCount: selectedMedia.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 112,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final file = selectedMedia[index];
        final isVideo = _isVideoFile(file);

        return Container(
          decoration: BoxDecoration(
            color: paleGreen,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: lightGreen.withOpacity(.55)),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: SizedBox.expand(
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
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : Image.network(
                              file.path,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return const Center(
                                  child: Icon(Icons.image_outlined, color: primaryGreen),
                                );
                              },
                            ),
                ),
              ),
              Positioned(
                left: 7,
                bottom: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isVideo ? Icons.videocam_rounded : Icons.image_rounded,
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
                child: InkWell(
                  onTap: posting ? null : () => _removeMedia(index),
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: softRed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black45,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: primaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopPublishButton({bool compact = false}) {
    return SizedBox(
      width: compact ? 170 : double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: posting ? null : _createPost,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryGreen.withOpacity(.45),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: posting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.3,
                ),
              )
            : const Text(
                "Publish",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}
