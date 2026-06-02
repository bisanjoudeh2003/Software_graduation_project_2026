import 'package:flutter/material.dart';

import '../services/admin_photographer_service.dart';

import 'admin_web_shell.dart';
import 'admin_user_details_web.dart';
import 'admin_photographer_portfolio_review_web.dart';

const Color adminPhotoDetailsPrimaryGreen = Color(0xFF2F4F46);
const Color adminPhotoDetailsLightCream = Color(0xFFF5F1EB);
const Color adminPhotoDetailsSoftGreen = Color(0xFF3E6B5C);
const Color adminPhotoDetailsGold = Color(0xFFC9A84C);
const Color adminPhotoDetailsRed = Color(0xFFB84040);
const Color adminPhotoDetailsGrey = Color(0xFF8A8A8A);
const Color adminPhotoDetailsDarkText = Color(0xFF26352D);

class AdminPhotographerDetailsWeb extends StatefulWidget {
  final int photographerId;

  const AdminPhotographerDetailsWeb({
    super.key,
    required this.photographerId,
  });

  @override
  State<AdminPhotographerDetailsWeb> createState() =>
      _AdminPhotographerDetailsWebState();
}

class _AdminPhotographerDetailsWebState
    extends State<AdminPhotographerDetailsWeb> {
  bool loading = true;
  bool actionLoading = false;

  Map<String, dynamic>? photographer;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (mounted) {
      setState(() => loading = true);
    }

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
    if (score >= 80) return adminPhotoDetailsSoftGreen;
    if (score >= 55) return adminPhotoDetailsGold;
    return adminPhotoDetailsRed;
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
        return adminPhotoDetailsSoftGreen;
      case "needs_review":
        return adminPhotoDetailsGold;
      default:
        return adminPhotoDetailsRed;
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
      title: next == "hidden" ? "Hide Photographer?" : "Show Photographer?",
      message: next == "hidden"
          ? "This photographer account will stay active, but it will not appear to clients in search or suggestions."
          : "This photographer will appear again to clients in search and suggestions.",
      confirmText: next == "hidden" ? "Hide" : "Show",
      confirmColor:
          next == "hidden" ? adminPhotoDetailsRed : adminPhotoDetailsSoftGreen,
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
      confirmColor:
          next ? adminPhotoDetailsSoftGreen : adminPhotoDetailsGold,
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
      _showMessage(next ? "Portfolio marked as reviewed" : "Portfolio review removed");
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
        confirmColor: adminPhotoDetailsSoftGreen,
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
        builder: (_) => AdminUserDetailsWeb(userId: userId),
      ),
    );

    if (!mounted) return;
    _loadDetails();
  }

  Future<void> _openPortfolioReview() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPhotographerPortfolioReviewWeb(
          photographerId: widget.photographerId,
        ),
      ),
    );

    if (!mounted) return;
    _loadDetails();
  }

  @override
  Widget build(BuildContext context) {
    final p = photographer;

    return AdminWebShell(
      selectedIndex: 2,
      showBackButton: true,
      pageTitle: "Photographer Details",
      child: Container(
        color: adminPhotoDetailsLightCream,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: adminPhotoDetailsPrimaryGreen,
                ),
              )
            : p == null
                ? _notFound()
                : RefreshIndicator(
                    color: adminPhotoDetailsPrimaryGreen,
                    onRefresh: _loadDetails,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 28,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1450),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _header(p),
                              if (actionLoading) ...[
                                const SizedBox(height: 18),
                                _actionLoadingBar(),
                              ],
                              const SizedBox(height: 24),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final wide = constraints.maxWidth >= 1120;

                                  if (wide) {
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Column(
                                            children: [
                                              _trustSection(p),
                                              const SizedBox(height: 18),
                                              _portfolioSection(p),
                                              const SizedBox(height: 18),
                                              _adminControlSection(p),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          flex: 7,
                                          child: Column(
                                            children: [
                                              _bookingSection(p),
                                              const SizedBox(height: 18),
                                              _ratingSection(p),
                                              const SizedBox(height: 18),
                                              _availabilitySection(p),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return Column(
                                    children: [
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
      ),
    );
  }

  Widget _notFound() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withOpacity(.045)),
        ),
        child: const Text(
          "Photographer not found",
          style: TextStyle(
            color: adminPhotoDetailsPrimaryGreen,
            fontFamily: "Montserrat",
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25463D), adminPhotoDetailsSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: adminPhotoDetailsPrimaryGreen.withOpacity(.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _avatar(image),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 7),
                if (email.isNotEmpty)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 13.5,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
          const SizedBox(width: 18),
          _headerActionButton(
            icon: Icons.refresh_rounded,
            label: "Refresh",
            onTap: _loadDetails,
          ),
        ],
      ),
    );
  }

  Widget _headerActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.18)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFamily: "Montserrat",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(String image) {
    return Container(
      width: 104,
      height: 104,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.85),
          width: 2,
        ),
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
      color: Colors.white.withOpacity(0.16),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.90),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
        ),
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
              fontWeight: FontWeight.w800,
              fontSize: 12,
              fontFamily: "Montserrat",
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionLoadingBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(.045)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: adminPhotoDetailsPrimaryGreen,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 10),
          Text(
            "Updating photographer...",
            style: TextStyle(
              color: adminPhotoDetailsPrimaryGreen,
              fontWeight: FontWeight.w800,
              fontFamily: "Montserrat",
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
      iconColor: color,
      child: Column(
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
                ? adminPhotoDetailsRed
                : adminPhotoDetailsSoftGreen,
          ),
          if (missing.isNotEmpty)
            _chipsBlock("Missing Requirements", missing, adminPhotoDetailsGold),
          if (warnings.isNotEmpty)
            _chipsBlock("Warnings", warnings, adminPhotoDetailsRed),
        ],
      ),
    );
  }

  Widget _portfolioSection(Map<String, dynamic> p) {
    final portfolio = Map<String, dynamic>.from(p["portfolio_summary"] ?? {});
    final reviewed = _boolValue(p["portfolio_reviewed"]);

    return _section(
      title: "Portfolio Review",
      icon: Icons.photo_library_outlined,
      iconColor: reviewed ? adminPhotoDetailsSoftGreen : adminPhotoDetailsGold,
      child: Column(
        children: [
          _statusHeader(
            title: reviewed ? "Portfolio Reviewed" : "Portfolio Not Reviewed",
            subtitle: reviewed
                ? "Admin has reviewed this photographer portfolio."
                : "Portfolio needs admin review before stronger trust.",
            icon: reviewed ? Icons.fact_check_outlined : Icons.pending_actions,
            color: reviewed ? adminPhotoDetailsSoftGreen : adminPhotoDetailsGold,
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  "Items",
                  _toInt(portfolio["total_items"]).toString(),
                  Icons.photo_outlined,
                  adminPhotoDetailsPrimaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  "Featured",
                  _toInt(portfolio["featured_items"]).toString(),
                  Icons.star_outline_rounded,
                  adminPhotoDetailsGold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  "Albums",
                  _toInt(portfolio["albums_count"]).toString(),
                  Icons.collections_bookmark_outlined,
                  adminPhotoDetailsSoftGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _plainInfo("Last Upload", _text(portfolio["last_upload_at"])),
          const SizedBox(height: 12),
          _actionRow(
            icon: Icons.photo_library_outlined,
            title: "Review Portfolio",
            subtitle: "Open photographer portfolio items and mark them as reviewed",
            color: adminPhotoDetailsPrimaryGreen,
            onTap: _openPortfolioReview,
          ),
        ],
      ),
    );
  }

  Widget _bookingSection(Map<String, dynamic> p) {
    final booking = Map<String, dynamic>.from(p["booking_summary"] ?? {});

    return _section(
      title: "Booking Performance",
      icon: Icons.event_note_outlined,
      iconColor: adminPhotoDetailsPrimaryGreen,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  "Total",
                  _toInt(booking["total"]).toString(),
                  Icons.all_inbox_outlined,
                  adminPhotoDetailsPrimaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  "Completed",
                  _toInt(booking["completed"]).toString(),
                  Icons.check_circle_outline,
                  adminPhotoDetailsSoftGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  "Rejected",
                  _toInt(booking["rejected"]).toString(),
                  Icons.cancel_outlined,
                  adminPhotoDetailsRed,
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
                  adminPhotoDetailsSoftGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  "Cancellation",
                  "${_toDouble(booking["cancellation_rate"]).toStringAsFixed(1)}%",
                  Icons.trending_down_rounded,
                  adminPhotoDetailsRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ratingSection(Map<String, dynamic> p) {
    final ratingAvg = _toDouble(p["rating_avg"]);
    final ratingCount = _toInt(p["rating_count"]);
    final lowRatingCount = _toInt(p["low_rating_count"]);

    return _section(
      title: "Rating Quality",
      icon: Icons.star_outline_rounded,
      iconColor: adminPhotoDetailsGold,
      child: Row(
        children: [
          Expanded(
            child: _metricBox(
              "Average",
              ratingCount == 0 ? "No reviews" : ratingAvg.toStringAsFixed(1),
              Icons.star_outline_rounded,
              adminPhotoDetailsGold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricBox(
              "Reviews",
              ratingCount.toString(),
              Icons.rate_review_outlined,
              adminPhotoDetailsPrimaryGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricBox(
              "Low",
              lowRatingCount.toString(),
              Icons.warning_amber_rounded,
              lowRatingCount > 0
                  ? adminPhotoDetailsRed
                  : adminPhotoDetailsSoftGreen,
            ),
          ),
        ],
      ),
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
      iconColor:
          hasAvailability ? adminPhotoDetailsSoftGreen : adminPhotoDetailsRed,
      child: Column(
        children: [
          _statusHeader(
            title: hasAvailability ? "Availability Set" : "No Availability",
            subtitle: hasAvailability
                ? "Photographer has weekly available days."
                : "Photographer is not useful for booking until availability is set.",
            icon: hasAvailability
                ? Icons.event_available_outlined
                : Icons.event_busy_outlined,
            color: hasAvailability
                ? adminPhotoDetailsSoftGreen
                : adminPhotoDetailsRed,
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  "Weekly Days",
                  _toInt(availability["weekly_days_count"]).toString(),
                  Icons.date_range_outlined,
                  adminPhotoDetailsPrimaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  "Blocked",
                  _toInt(availability["blocked_slots_count"]).toString(),
                  Icons.block_outlined,
                  adminPhotoDetailsGold,
                ),
              ),
            ],
          ),
        ],
      ),
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
      iconColor: adminPhotoDetailsPrimaryGreen,
      child: Column(
        children: [
          if (flagged && flagReason.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: adminPhotoDetailsGold.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                "Flag reason: $flagReason",
                style: const TextStyle(
                  color: adminPhotoDetailsGold,
                  fontWeight: FontWeight.w800,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
          _actionRow(
            icon: hidden
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            title: hidden ? "Show to Clients" : "Hide from Client Search",
            subtitle: hidden
                ? "Make this photographer visible to clients again"
                : "Keep account active but hide it from client discovery",
            color: hidden
                ? adminPhotoDetailsSoftGreen
                : adminPhotoDetailsRed,
            onTap: actionLoading ? () {} : _toggleVisibility,
          ),
          _smallDivider(),
          _actionRow(
            icon: reviewed
                ? Icons.pending_actions_outlined
                : Icons.fact_check_outlined,
            title: reviewed ? "Remove Portfolio Review" : "Mark Portfolio Reviewed",
            subtitle: reviewed
                ? "Remove reviewed status if portfolio needs checking again"
                : "Confirm that admin reviewed this portfolio",
            color:
                reviewed ? adminPhotoDetailsGold : adminPhotoDetailsSoftGreen,
            onTap: actionLoading ? () {} : _togglePortfolioReviewed,
          ),
          _smallDivider(),
          _actionRow(
            icon: flagged ? Icons.outlined_flag_rounded : Icons.flag_outlined,
            title: flagged ? "Remove Review Flag" : "Flag Photographer",
            subtitle: flagged
                ? "Remove internal review warning from this photographer"
                : "Mark this photographer as needing admin review",
            color:
                flagged ? adminPhotoDetailsSoftGreen : adminPhotoDetailsGold,
            onTap: actionLoading ? () {} : _toggleFlag,
          ),
          _smallDivider(),
          _actionRow(
            icon: Icons.account_circle_outlined,
            title: "Open Full User Details",
            subtitle: "Go to general account controls, notes, and activity logs",
            color: adminPhotoDetailsPrimaryGreen,
            onTap: _openFullUserDetails,
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.055),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _iconBox(icon, iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: adminPhotoDetailsDarkText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
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
                  value: (score.clamp(0, 100)) / 100,
                  strokeWidth: 6,
                  backgroundColor: color.withOpacity(0.15),
                  color: color,
                ),
                Text(
                  "$score%",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    fontFamily: "Montserrat",
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
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w500,
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
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.45),
                    fontSize: 12,
                    height: 1.25,
                    fontFamily: "Montserrat",
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
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
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
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: adminPhotoDetailsPrimaryGreen,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
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
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.42),
              fontSize: 10.5,
              fontFamily: "Montserrat",
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
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: items.map((item) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  item.toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: "Montserrat",
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
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
                        fontWeight: FontWeight.w900,
                        fontFamily: "Montserrat",
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.42),
                        fontSize: 12,
                        height: 1.25,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w500,
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
      ),
    );
  }

  Widget _smallDivider() {
    return Divider(
      height: 8,
      color: Colors.black.withOpacity(0.06),
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
                  color: adminPhotoDetailsPrimaryGreen,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
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
            fontFamily: "Montserrat",
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: adminPhotoDetailsGrey,
                fontFamily: "Montserrat",
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: TextStyle(
                color: confirmColor,
                fontWeight: FontWeight.w900,
                fontFamily: "Montserrat",
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
              Icon(Icons.flag_outlined, color: adminPhotoDetailsGold),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Flag Photographer",
                  style: TextStyle(
                    color: adminPhotoDetailsPrimaryGreen,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
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
              color: adminPhotoDetailsPrimaryGreen,
              fontFamily: "Montserrat",
            ),
            decoration: InputDecoration(
              hintText: "Reason, e.g. low rating, portfolio quality issue...",
              hintStyle: TextStyle(
                color: Colors.black.withOpacity(0.35),
                fontFamily: "Montserrat",
              ),
              filled: true,
              fillColor: adminPhotoDetailsLightCream,
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
                  color: adminPhotoDetailsGrey,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final cleaned = reason.trim();

                if (cleaned.length < 3) return;

                Navigator.of(dialogContext).pop(cleaned);
              },
              child: const Text(
                "Flag",
                style: TextStyle(
                  color: adminPhotoDetailsGold,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12.5,
          ),
        ),
        backgroundColor: adminPhotoDetailsPrimaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}