import 'package:flutter/material.dart';

import '../services/admin_photographer_service.dart';
import 'admin_user_details_screen.dart';
import 'admin_photographer_portfolio_review_screen.dart';
const Color adminPrimaryGreen = Color(0xFF2F4F46);
const Color adminLightCream = Color(0xFFF5F1EB);
const Color adminSoftGreen = Color(0xFF3E6B5C);
const Color adminGold = Color(0xFFC9A84C);
const Color adminRed = Color(0xFFB84040);
const Color adminGrey = Color(0xFF8A8A8A);

class AdminPhotographerDetailsScreen extends StatefulWidget {
  final int photographerId;

  const AdminPhotographerDetailsScreen({
    super.key,
    required this.photographerId,
  });

  @override
  State<AdminPhotographerDetailsScreen> createState() =>
      _AdminPhotographerDetailsScreenState();
}

class _AdminPhotographerDetailsScreenState
    extends State<AdminPhotographerDetailsScreen> {
  bool loading = true;
  bool actionLoading = false;

  Map<String, dynamic>? photographer;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => loading = true);

    final result = await AdminPhotographerService.getPhotographerDetails(
      widget.photographerId,
    );

    if (!mounted) return;

    setState(() {
      photographer = result;
      loading = false;
    });
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _text(dynamic value, {String fallback = "Not set"}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty || text == "null") return fallback;
    return text;
  }

  String _image(dynamic value) {
    if (value == null) return "";
    final text = value.toString().trim();
    if (text.isEmpty || text == "null") return "";
    return text;
  }

  bool _boolValue(dynamic value) {
    return value == true ||
        value == 1 ||
        value == "1" ||
        value?.toString() == "true";
  }

  Color _trustColor(int score) {
    if (score >= 80) return adminSoftGreen;
    if (score >= 55) return adminGold;
    return adminRed;
  }

  String _verificationLabel(String status) {
    switch (status) {
      case "verified":
        return "Verified";
      case "needs_review":
        return "Needs Review";
      default:
        return "Not Verified";
    }
  }

  Color _verificationColor(String status) {
    switch (status) {
      case "verified":
        return adminSoftGreen;
      case "needs_review":
        return adminGold;
      default:
        return adminRed;
    }
  }

  IconData _verificationIcon(String status) {
    switch (status) {
      case "verified":
        return Icons.verified_outlined;
      case "needs_review":
        return Icons.flag_outlined;
      default:
        return Icons.cancel_outlined;
    }
  }

  Future<void> _toggleVisibility() async {
    final p = photographer;
    if (p == null) return;

    final current = _text(p["admin_visibility"], fallback: "visible");
    final next = current == "hidden" ? "visible" : "hidden";

    final confirm = await _confirmDialog(
      title: next == "hidden"
          ? "Hide Photographer?"
          : "Show Photographer?",
      message: next == "hidden"
          ? "This photographer account will stay active, but it will not appear to clients in search or suggestions."
          : "This photographer will appear again to clients in search and suggestions.",
      confirmText: next == "hidden" ? "Hide" : "Show",
      confirmColor: next == "hidden" ? adminRed : adminSoftGreen,
      icon: next == "hidden"
          ? Icons.visibility_off_outlined
          : Icons.visibility_outlined,
    );

    if (confirm != true) return;

    setState(() => actionLoading = true);

    final ok = await AdminPhotographerService.updateVisibility(
      photographerId: widget.photographerId,
      visibility: next,
    );

    if (!mounted) return;

    setState(() => actionLoading = false);

    if (ok) {
      _showMessage(
        next == "hidden"
            ? "Photographer hidden from clients"
            : "Photographer is now visible to clients",
      );
      _loadDetails();
    } else {
      _showMessage("Failed to update visibility");
    }
  }

  Future<void> _togglePortfolioReviewed() async {
    final p = photographer;
    if (p == null) return;

    final reviewed = _boolValue(p["portfolio_reviewed"]);
    final next = !reviewed;

    final confirm = await _confirmDialog(
      title: next ? "Mark Portfolio Reviewed?" : "Remove Portfolio Review?",
      message: next
          ? "This marks the photographer's portfolio as reviewed by admin."
          : "This removes the reviewed status from the photographer's portfolio.",
      confirmText: next ? "Mark Reviewed" : "Remove",
      confirmColor: next ? adminSoftGreen : adminGold,
      icon: next ? Icons.fact_check_outlined : Icons.pending_actions_outlined,
    );

    if (confirm != true) return;

    setState(() => actionLoading = true);

    final ok = await AdminPhotographerService.updatePortfolioReviewed(
      photographerId: widget.photographerId,
      reviewed: next,
    );

    if (!mounted) return;

    setState(() => actionLoading = false);

    if (ok) {
      _showMessage(
        next
            ? "Portfolio marked as reviewed"
            : "Portfolio review removed",
      );
      _loadDetails();
    } else {
      _showMessage("Failed to update portfolio review");
    }
  }

  Future<void> _toggleFlag() async {
    final p = photographer;
    if (p == null) return;

    final flagged = _boolValue(p["admin_flagged"]);

    if (flagged) {
      final confirm = await _confirmDialog(
        title: "Remove Flag?",
        message: "This photographer will no longer be marked as needing review.",
        confirmText: "Remove Flag",
        confirmColor: adminSoftGreen,
        icon: Icons.outlined_flag_rounded,
      );

      if (confirm != true) return;

      setState(() => actionLoading = true);

      final ok = await AdminPhotographerService.updateFlag(
        photographerId: widget.photographerId,
        flagged: false,
      );

      if (!mounted) return;

      setState(() => actionLoading = false);

      if (ok) {
        _showMessage("Flag removed");
        _loadDetails();
      } else {
        _showMessage("Failed to remove flag");
      }

      return;
    }

    final reason = await _flagReasonDialog();

    if (reason == null || reason.trim().length < 3) return;

    setState(() => actionLoading = true);

    final ok = await AdminPhotographerService.updateFlag(
      photographerId: widget.photographerId,
      flagged: true,
      reason: reason.trim(),
    );

    if (!mounted) return;

    setState(() => actionLoading = false);

    if (ok) {
      _showMessage("Photographer flagged for review");
      _loadDetails();
    } else {
      _showMessage("Failed to flag photographer");
    }
  }

  Future<void> _openFullUserDetails() async {
    final p = photographer;
    if (p == null) return;

    final userId = _toInt(p["user_id"]);

    if (userId <= 0) {
      _showMessage("Invalid user id");
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserDetailsScreen(userId: userId),
      ),
    );

    if (!mounted) return;

    _loadDetails();
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
    required IconData icon,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Row(
          children: [
            Icon(icon, color: confirmColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: adminPrimaryGreen,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: Colors.black.withOpacity(0.62),
            height: 1.35,
            fontFamily: "Playfair",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: adminGrey,
                fontFamily: "Playfair",
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: TextStyle(
                color: confirmColor,
                fontWeight: FontWeight.bold,
                fontFamily: "Playfair",
              ),
            ),
          ),
        ],
      ),
    );
  }

Future<String?> _flagReasonDialog() async {
  String reason = "";

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Row(
          children: [
            Icon(Icons.flag_outlined, color: adminGold),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Flag Photographer",
                style: TextStyle(
                  color: adminPrimaryGreen,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
            ),
          ],
        ),
        content: TextField(
          maxLines: 4,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onChanged: (value) {
            reason = value;
          },
          style: const TextStyle(
            color: adminPrimaryGreen,
            fontFamily: "Playfair",
          ),
          decoration: InputDecoration(
            hintText: "Reason, e.g. low rating, portfolio quality issue...",
            hintStyle: TextStyle(
              color: Colors.black.withOpacity(0.35),
              fontFamily: "Playfair",
            ),
            filled: true,
            fillColor: adminLightCream,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: adminGrey,
                fontFamily: "Playfair",
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final cleaned = reason.trim();

              if (cleaned.length < 3) {
                return;
              }

              Navigator.of(dialogContext).pop(cleaned);
            },
            child: const Text(
              "Flag",
              style: TextStyle(
                color: adminGold,
                fontWeight: FontWeight.bold,
                fontFamily: "Playfair",
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
    final p = photographer;

    return Scaffold(
      backgroundColor: adminLightCream,
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: adminPrimaryGreen),
            )
          : p == null
              ? const Center(
                  child: Text("Photographer not found"),
                )
              : RefreshIndicator(
                  color: adminPrimaryGreen,
                  onRefresh: _loadDetails,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 305,
                        pinned: true,
                        elevation: 0,
                        backgroundColor: adminPrimaryGreen,
                        iconTheme: const IconThemeData(color: Colors.white),
                        actions: [
                          IconButton(
                            onPressed: _loadDetails,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                        flexibleSpace: FlexibleSpaceBar(
                          background: _header(p),
                        ),
                        bottom: _roundedBottom(),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            if (actionLoading) _actionLoadingBar(),
                            _trustSection(p),
                            const SizedBox(height: 18),
                            _portfolioSection(p),
                            const SizedBox(height: 18),
                            _bookingSection(p),
                            const SizedBox(height: 18),
                            _ratingSection(p),
                            const SizedBox(height: 18),
                            _availabilitySection(p),
                            const SizedBox(height: 18),
                            _adminControlSection(p),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _header(Map<String, dynamic> p) {
    final name = _text(p["full_name"], fallback: "Photographer");
    final email = _text(p["email"], fallback: "");
    final image = _image(p["profile_image"]);
    final score = _toInt(p["trust_score"]);
    final trustColor = _trustColor(score);
    final verificationStatus =
        _text(p["verification_status"], fallback: "not_verified");

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF25463D), adminSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _avatar(image, trustColor),
            const SizedBox(height: 13),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
            ),
            const SizedBox(height: 5),
            if (email.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 13,
                    fontFamily: "Playfair",
                  ),
                ),
              ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _topBadge(
                  label: "Trust $score%",
                  icon: Icons.shield_outlined,
                  color: trustColor,
                ),
                _topBadge(
                  label: _verificationLabel(verificationStatus),
                  icon: _verificationIcon(verificationStatus),
                  color: _verificationColor(verificationStatus),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PreferredSize _roundedBottom() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(24),
      child: Container(
        height: 26,
        decoration: const BoxDecoration(
          color: adminLightCream,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
      ),
    );
  }

  Widget _avatar(String image, Color color) {
    return Container(
      width: 102,
      height: 102,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.85), width: 2),
      ),
      child: ClipOval(
        child: image.isNotEmpty
            ? Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultAvatar(),
              )
            : _defaultAvatar(),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: Colors.white.withOpacity(0.17),
      child: const Icon(
        Icons.camera_alt_outlined,
        color: Colors.white,
        size: 42,
      ),
    );
  }

  Widget _topBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.92),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionLoadingBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: adminPrimaryGreen,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 10),
          Text(
            "Updating photographer...",
            style: TextStyle(
              color: adminPrimaryGreen,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
        ],
      ),
    );
  }

  Widget _trustSection(Map<String, dynamic> p) {
    final score = _toInt(p["trust_score"]);
    final color = _trustColor(score);
    final verificationStatus =
        _text(p["verification_status"], fallback: "not_verified");
    final missing = List.from(p["missing_requirements"] ?? []);
    final warnings = List.from(p["warnings"] ?? []);

    return _section(
      title: "Trust & Verification",
      icon: Icons.verified_user_outlined,
      children: [
        _bigTrustBox(score, color),
        const SizedBox(height: 12),
        _infoRow(
          "Verification",
          _verificationLabel(verificationStatus),
          _verificationIcon(verificationStatus),
          _verificationColor(verificationStatus),
        ),
        _infoRow(
          "Visibility",
          _text(p["admin_visibility"], fallback: "visible") == "hidden"
              ? "Hidden from clients"
              : "Visible to clients",
          _text(p["admin_visibility"], fallback: "visible") == "hidden"
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          _text(p["admin_visibility"], fallback: "visible") == "hidden"
              ? adminRed
              : adminSoftGreen,
        ),
        if (missing.isNotEmpty) _chipsBlock("Missing Requirements", missing, adminGold),
        if (warnings.isNotEmpty) _chipsBlock("Warnings", warnings, adminRed),
      ],
    );
  }

  Widget _portfolioSection(Map<String, dynamic> p) {
    final portfolio = Map<String, dynamic>.from(p["portfolio_summary"] ?? {});
    final reviewed = _boolValue(p["portfolio_reviewed"]);

    return _section(
      title: "Portfolio Review",
      icon: Icons.photo_library_outlined,
      children: [
        _statusHeader(
          title: reviewed ? "Portfolio Reviewed" : "Portfolio Not Reviewed",
          subtitle: reviewed
              ? "Admin has reviewed this photographer portfolio."
              : "Portfolio needs admin review before stronger trust.",
          icon: reviewed ? Icons.fact_check_outlined : Icons.pending_actions,
          color: reviewed ? adminSoftGreen : adminGold,
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: _metricBox(
                "Items",
                _toInt(portfolio["total_items"]).toString(),
                Icons.photo_outlined,
                adminPrimaryGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricBox(
                "Featured",
                _toInt(portfolio["featured_items"]).toString(),
                Icons.star_outline_rounded,
                adminGold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricBox(
                "Albums",
                _toInt(portfolio["albums_count"]).toString(),
                Icons.collections_bookmark_outlined,
                adminSoftGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _plainInfo("Last Upload", _text(portfolio["last_upload_at"])),
const SizedBox(height: 12),
_actionRow(
  icon: Icons.photo_library_outlined,
  title: "Review Portfolio",
  subtitle: "Open photographer portfolio items and mark them as reviewed",
  color: adminPrimaryGreen,
  onTap: _openPortfolioReview,
),
      ],
    );
  }

  Widget _bookingSection(Map<String, dynamic> p) {
    final booking = Map<String, dynamic>.from(p["booking_summary"] ?? {});

    return _section(
      title: "Booking Performance",
      icon: Icons.event_note_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: _metricBox(
                "Total",
                _toInt(booking["total"]).toString(),
                Icons.all_inbox_outlined,
                adminPrimaryGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricBox(
                "Completed",
                _toInt(booking["completed"]).toString(),
                Icons.check_circle_outline,
                adminSoftGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricBox(
                "Rejected",
                _toInt(booking["rejected"]).toString(),
                Icons.cancel_outlined,
                adminRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _metricBox(
                "Completion",
                "${_toDouble(booking["completion_rate"]).toStringAsFixed(1)}%",
                Icons.trending_up_rounded,
                adminSoftGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricBox(
                "Cancellation",
                "${_toDouble(booking["cancellation_rate"]).toStringAsFixed(1)}%",
                Icons.trending_down_rounded,
                adminRed,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _ratingSection(Map<String, dynamic> p) {
    final ratingAvg = _toDouble(p["rating_avg"]);
    final ratingCount = _toInt(p["rating_count"]);
    final lowRatingCount = _toInt(p["low_rating_count"]);

    return _section(
      title: "Rating Quality",
      icon: Icons.star_outline_rounded,
      children: [
        Row(
          children: [
            Expanded(
              child: _metricBox(
                "Average",
                ratingCount == 0 ? "No reviews" : ratingAvg.toStringAsFixed(1),
                Icons.star_outline_rounded,
                adminGold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricBox(
                "Reviews",
                ratingCount.toString(),
                Icons.rate_review_outlined,
                adminPrimaryGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricBox(
                "Low",
                lowRatingCount.toString(),
                Icons.warning_amber_rounded,
                lowRatingCount > 0 ? adminRed : adminSoftGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _availabilitySection(Map<String, dynamic> p) {
    final availability = Map<String, dynamic>.from(
      p["availability_summary"] ?? {},
    );

    final hasAvailability = _boolValue(availability["has_availability"]);

    return _section(
      title: "Availability Status",
      icon: Icons.calendar_month_outlined,
      children: [
        _statusHeader(
          title: hasAvailability ? "Availability Set" : "No Availability",
          subtitle: hasAvailability
              ? "Photographer has weekly available days."
              : "Photographer is not useful for booking until availability is set.",
          icon: hasAvailability
              ? Icons.event_available_outlined
              : Icons.event_busy_outlined,
          color: hasAvailability ? adminSoftGreen : adminRed,
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: _metricBox(
                "Weekly Days",
                _toInt(availability["weekly_days_count"]).toString(),
                Icons.date_range_outlined,
                adminPrimaryGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricBox(
                "Blocked",
                _toInt(availability["blocked_slots_count"]).toString(),
                Icons.block_outlined,
                adminGold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _adminControlSection(Map<String, dynamic> p) {
    final visibility = _text(p["admin_visibility"], fallback: "visible");
    final hidden = visibility == "hidden";
    final reviewed = _boolValue(p["portfolio_reviewed"]);
    final flagged = _boolValue(p["admin_flagged"]);
    final flagReason = _text(p["admin_flag_reason"], fallback: "");

    return _section(
      title: "Photographer Admin Controls",
      icon: Icons.admin_panel_settings_outlined,
      children: [
        if (flagged && flagReason.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: adminGold.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              "Flag reason: $flagReason",
              style: const TextStyle(
                color: adminGold,
                fontWeight: FontWeight.bold,
                fontFamily: "Playfair",
              ),
            ),
          ),
        _actionRow(
          icon: hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          title: hidden ? "Show to Clients" : "Hide from Client Search",
          subtitle: hidden
              ? "Make this photographer visible to clients again"
              : "Keep account active but hide it from client discovery",
          color: hidden ? adminSoftGreen : adminRed,
          onTap: actionLoading ? () {} : _toggleVisibility,
        ),
        _actionRow(
          icon: reviewed ? Icons.pending_actions_outlined : Icons.fact_check_outlined,
          title: reviewed ? "Remove Portfolio Review" : "Mark Portfolio Reviewed",
          subtitle: reviewed
              ? "Remove reviewed status if portfolio needs checking again"
              : "Confirm that admin reviewed this portfolio",
          color: reviewed ? adminGold : adminSoftGreen,
          onTap: actionLoading ? () {} : _togglePortfolioReviewed,
        ),
        _actionRow(
          icon: flagged ? Icons.outlined_flag_rounded : Icons.flag_outlined,
          title: flagged ? "Remove Review Flag" : "Flag Photographer",
          subtitle: flagged
              ? "Remove internal review warning from this photographer"
              : "Mark this photographer as needing admin review",
          color: flagged ? adminSoftGreen : adminGold,
          onTap: actionLoading ? () {} : _toggleFlag,
        ),
        _actionRow(
          icon: Icons.account_circle_outlined,
          title: "Open Full User Details",
          subtitle: "Go to general account controls, notes, messages and logs",
          color: adminPrimaryGreen,
          onTap: _openFullUserDetails,
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: adminPrimaryGreen, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: adminPrimaryGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: adminPrimaryGreen.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _bigTrustBox(int score, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 6,
                  backgroundColor: color.withOpacity(0.15),
                  color: color,
                ),
                Text(
                  "$score%",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: "Playfair",
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              score >= 80
                  ? "Strong photographer profile with good trust indicators."
                  : score >= 55
                      ? "This photographer is acceptable but needs some improvements."
                      : "This photographer needs review before being trusted strongly.",
              style: TextStyle(
                color: Colors.black.withOpacity(0.58),
                fontSize: 13,
                height: 1.35,
                fontFamily: "Playfair",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          _iconBox(icon, color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Playfair",
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.45),
                    fontSize: 12,
                    height: 1.25,
                    fontFamily: "Playfair",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          _iconBox(icon, color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black.withOpacity(0.42),
                fontSize: 13,
                fontFamily: "Playfair",
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
        ],
      ),
    );
  }

  Widget _plainInfo(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.black.withOpacity(0.42),
            fontSize: 13,
            fontFamily: "Playfair",
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: adminPrimaryGreen,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricBox(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.42),
              fontSize: 10.5,
              fontFamily: "Playfair",
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipsBlock(String title, List items, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$title:",
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  item.toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: "Playfair",
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _iconBox(icon, color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Playfair",
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.42),
                      fontSize: 12,
                      height: 1.25,
                      fontFamily: "Playfair",
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.black.withOpacity(0.25),
              size: 15,
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: adminPrimaryGreen,
      ),
    );
  }
  Future<void> _openPortfolioReview() async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AdminPhotographerPortfolioReviewScreen(
        photographerId: widget.photographerId,
      ),
    ),
  );

  if (!mounted) return;

  _loadDetails();
}
}

