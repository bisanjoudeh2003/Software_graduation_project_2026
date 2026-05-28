import 'package:flutter/material.dart';

import '../services/photographer_review_service.dart';

import 'client_web_shell.dart';

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
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color cream = Color(0xFFF6F4EE);

  int _selectedRating = 0;
  bool _submitting = false;

  final TextEditingController _commentController = TextEditingController();

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bg => _isDark ? Theme.of(context).scaffoldBackgroundColor : cream;

  Color get _card => Theme.of(context).cardColor;

  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

  Color get _primary => Theme.of(context).colorScheme.primary;

  Color get _border => _isDark ? Colors.white10 : Colors.grey.shade300;

  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF7F4EC);

  int get _bookingId {
    return int.tryParse(widget.booking["id"]?.toString() ?? "") ?? 0;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: Colors.white,
            fontWeight: FontWeight.w700,
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
    } catch (_) {
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
        size: 42,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photographerName =
        widget.booking["photographer_name"]?.toString() ?? "Photographer";
    final photographerImg =
        widget.booking["photographer_image"]?.toString() ?? "";
    final sessionType = widget.booking["session_type"]?.toString() ?? "Session";

    return ClientWebShell(
      selectedIndex: 3,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 26, 30, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _topBar(),
                    const SizedBox(height: 24),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 1050;

                          if (!isWide) {
                            return ListView(
                              children: [
                                _heroCard(
                                  photographerName: photographerName,
                                  photographerImg: photographerImg,
                                  sessionType: sessionType,
                                ),
                                const SizedBox(height: 18),
                                _reviewCard(),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 390,
                                child: ListView(
                                  children: [
                                    _heroCard(
                                      photographerName: photographerName,
                                      photographerImg: photographerImg,
                                      sessionType: sessionType,
                                    ),
                                    const SizedBox(height: 18),
                                    _hintCard(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: ListView(
                                  children: [
                                    _reviewCard(),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.045),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: _primary,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Leave Photographer Review",
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  color: _text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Rate your session experience and share optional feedback.",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _sub,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroCard({
    required String photographerName,
    required String photographerImg,
    required String sessionType,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.30),
                width: 3,
              ),
            ),
            child: ClipOval(
              child: photographerImg.isNotEmpty && photographerImg != "null"
                  ? Image.network(
                      photographerImg,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallback(),
                    )
                  : _avatarFallback(),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            photographerName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: "Playfair_Display",
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sessionType,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white.withOpacity(.78),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hintCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? .10 : .04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.rate_review_outlined,
            color: _primary,
            size: 30,
          ),
          const SizedBox(height: 14),
          Text(
            "Review Tips",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              color: _text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Choose a rating from 1 to 5 stars. You can also add a short comment about the photographer, session quality, and delivery.",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _sub,
              fontSize: 12,
              height: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.12 : 0.045),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.star_outline_rounded,
            title: "Rate Your Experience",
            subtitle: "How was your session with this photographer?",
          ),
          const SizedBox(height: 24),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: List.generate(5, (index) {
                return _buildStar(index + 1);
              }),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Comment",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: _text,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _commentController,
            maxLines: 8,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _text,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: "Share your experience with the photographer...",
              hintStyle: TextStyle(
                fontFamily: "Montserrat",
                color: _sub,
              ),
              filled: true,
              fillColor: _softSurface,
              contentPadding: const EdgeInsets.all(18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 260,
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
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: _primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: _text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: _sub,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: _softSurface,
      child: Icon(
        Icons.person_rounded,
        color: _primary,
        size: 34,
      ),
    );
  }
}