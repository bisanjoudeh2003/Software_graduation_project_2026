import 'package:flutter/material.dart';
import '../services/photographer_review_service.dart';

class LeavePhotographerReviewPage extends StatefulWidget {
  final Map booking;

  const LeavePhotographerReviewPage({
    super.key,
    required this.booking,
  });

  @override
  State<LeavePhotographerReviewPage> createState() =>
      _LeavePhotographerReviewPageState();
}

class _LeavePhotographerReviewPageState
    extends State<LeavePhotographerReviewPage> {
  int _selectedRating = 0;
  bool _submitting = false;
  final TextEditingController _commentController = TextEditingController();

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _card => Theme.of(context).cardColor;
  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get _primary => Theme.of(context).colorScheme.primary;
  Color get _border => _isDark ? Colors.white10 : Colors.grey.shade300;
  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF7F4EC);

  int get _bookingId =>
      int.tryParse(widget.booking["id"]?.toString() ?? "") ?? 0;

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: Colors.white,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _submitReview() async {
    if (_bookingId == 0) {
      _snack("Invalid booking id", Colors.red);
      return;
    }

    if (_selectedRating < 1 || _selectedRating > 5) {
      _snack("Please select a rating first", Colors.red);
      return;
    }

    setState(() => _submitting = true);

    try {
      final result = await PhotographerReviewService.createReview(
        bookingId: _bookingId,
        rating: _selectedRating,
        comment: _commentController.text,
      );

      if (!mounted) return;

      if (result["statusCode"] == 201 || result["statusCode"] == 200) {
        _snack(
          result["data"]["message"] ?? "Review submitted successfully",
          _primary,
        );
        Navigator.pop(context, true);
      } else {
        _snack(
          result["data"]["message"] ?? "Failed to submit review",
          Colors.red,
        );
      }
    } catch (e) {
      _snack("Failed to submit review", Colors.red);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _buildStar(int index) {
    final selected = index <= _selectedRating;
    return IconButton(
      onPressed: () {
        setState(() {
          _selectedRating = index;
        });
      },
      icon: Icon(
        selected ? Icons.star_rounded : Icons.star_border_rounded,
        color: selected ? Colors.amber : _sub,
        size: 36,
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photographerName =
        widget.booking["photographer_name"]?.toString() ?? "Photographer";
    final photographerImg =
        widget.booking["photographer_image"]?.toString() ?? "";
    final sessionType =
        widget.booking["session_type"]?.toString() ?? "Session";

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Leave Review",
          style: TextStyle(
            fontFamily: "Playfair_Display",
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isDark ? 0.12 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _primary.withOpacity(0.15),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: photographerImg.isNotEmpty
                        ? Image.network(
                            photographerImg,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _avatarFallback(),
                          )
                        : _avatarFallback(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        photographerName,
                        style: TextStyle(
                          fontFamily: "Playfair_Display",
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sessionType,
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          color: _sub,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isDark ? 0.10 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Rate Your Experience",
                  style: TextStyle(
                    fontFamily: "Playfair_Display",
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "How was your session with this photographer?",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13,
                    color: _sub,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: List.generate(5, (i) => _buildStar(i + 1)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Comment",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _commentController,
                  maxLines: 5,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: _text,
                  ),
                  decoration: InputDecoration(
                    hintText: "Share your experience with the photographer...",
                    hintStyle: TextStyle(
                      fontFamily: "Montserrat",
                      color: _sub,
                    ),
                    filled: true,
                    fillColor: _softSurface,
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _submitting ? null : _submitReview,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Submit Review",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: _softSurface,
      child: Icon(
        Icons.person_rounded,
        color: _primary,
        size: 28,
      ),
    );
  }
}