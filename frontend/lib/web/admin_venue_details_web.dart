import 'package:flutter/material.dart';

import '../services/admin_venue_service.dart';
import 'admin_web_shell.dart';
import 'admin_user_details_web.dart';

const Color adminVenueDetailsPrimaryGreen = Color(0xFF2F4F46);
const Color adminVenueDetailsLightCream = Color(0xFFF5F1EB);
const Color adminVenueDetailsSoftGreen = Color(0xFF3E6B5C);
const Color adminVenueDetailsGold = Color(0xFFC9A84C);
const Color adminVenueDetailsRed = Color(0xFFB84040);
const Color adminVenueDetailsGrey = Color(0xFF8A8A8A);
const Color adminVenueDetailsDarkText = Color(0xFF26352D);

class AdminVenueDetailsWeb extends StatefulWidget {
  final int venueId;

  const AdminVenueDetailsWeb({
    super.key,
    required this.venueId,
  });

  @override
  State<AdminVenueDetailsWeb> createState() => _AdminVenueDetailsWebState();
}

class _AdminVenueDetailsWebState extends State<AdminVenueDetailsWeb> {
  bool loading = true;
  bool actionLoading = false;

  Map<String, dynamic>? venue;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (mounted) {
      setState(() => loading = true);
    }

    final result = await AdminVenueService.getVenueDetails(widget.venueId);

    if (!mounted) return;

    setState(() {
      venue = result;
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

  bool _boolValue(dynamic value) {
    return value == true ||
        value == 1 ||
        value == "1" ||
        value?.toString() == "true";
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

  Future<void> _toggleVisibility() async {
    final v = venue;
    if (v == null) return;

    final current = _text(v["admin_visibility"], fallback: "hidden");
    final next = current == "visible" ? "hidden" : "visible";

    final confirm = await _confirmDialog(
      title: next == "visible" ? "Show Venue?" : "Hide Venue?",
      message: next == "visible"
          ? "This venue will be visible to clients if it is reviewed."
          : "This venue will be hidden from client search and booking.",
      confirmText: next == "visible" ? "Show" : "Hide",
      confirmColor:
          next == "visible" ? adminVenueDetailsSoftGreen : adminVenueDetailsGold,
      icon: next == "visible"
          ? Icons.visibility_outlined
          : Icons.visibility_off_outlined,
    );

    if (confirm != true) return;

    setState(() => actionLoading = true);

    final ok = await AdminVenueService.updateVisibility(
      venueId: widget.venueId,
      visibility: next,
    );

    if (!mounted) return;

    setState(() => actionLoading = false);

    if (ok) {
      _showMessage(next == "visible" ? "Venue is visible" : "Venue is hidden");
      _loadDetails();
    } else {
      _showMessage("Failed to update visibility");
    }
  }

  Future<void> _toggleReviewed() async {
    final v = venue;
    if (v == null) return;

    final reviewed = _boolValue(v["venue_reviewed"]);
    final next = !reviewed;

    final confirm = await _confirmDialog(
      title: next ? "Mark Venue Reviewed?" : "Remove Review Status?",
      message: next
          ? "This means admin reviewed this venue information, images, and availability."
          : "This will remove the reviewed status from this venue.",
      confirmText: next ? "Mark Reviewed" : "Remove",
      confirmColor:
          next ? adminVenueDetailsSoftGreen : adminVenueDetailsGold,
      icon: next ? Icons.fact_check_outlined : Icons.pending_actions_outlined,
    );

    if (confirm != true) return;

    setState(() => actionLoading = true);

    final ok = await AdminVenueService.updateReviewed(
      venueId: widget.venueId,
      reviewed: next,
    );

    if (!mounted) return;

    setState(() => actionLoading = false);

    if (ok) {
      _showMessage(next ? "Venue marked as reviewed" : "Review status removed");
      _loadDetails();
    } else {
      _showMessage("Failed to update review status");
    }
  }

  Future<void> _toggleFlag() async {
    final v = venue;
    if (v == null) return;

    final flagged = _boolValue(v["venue_flagged"]);

    if (flagged) {
      final confirm = await _confirmDialog(
        title: "Remove Venue Flag?",
        message: "This venue will no longer be marked as needing admin review.",
        confirmText: "Remove Flag",
        confirmColor: adminVenueDetailsSoftGreen,
        icon: Icons.outlined_flag_rounded,
      );

      if (confirm != true) return;

      setState(() => actionLoading = true);

      final ok = await AdminVenueService.updateFlag(
        venueId: widget.venueId,
        flagged: false,
      );

      if (!mounted) return;

      setState(() => actionLoading = false);

      if (ok) {
        _showMessage("Venue flag removed");
        _loadDetails();
      } else {
        _showMessage("Failed to remove flag");
      }

      return;
    }

    final reason = await _reasonDialog(
      title: "Flag Venue",
      hint: "Reason, e.g. missing images, unclear location...",
      icon: Icons.flag_outlined,
      color: adminVenueDetailsRed,
      buttonText: "Flag",
    );

    if (reason == null || reason.trim().length < 3) return;

    setState(() => actionLoading = true);

    final ok = await AdminVenueService.updateFlag(
      venueId: widget.venueId,
      flagged: true,
      reason: reason.trim(),
    );

    if (!mounted) return;

    setState(() => actionLoading = false);

    if (ok) {
      _showMessage("Venue flagged");
      _loadDetails();
    } else {
      _showMessage("Failed to flag venue");
    }
  }

  Future<void> _openOwnerDetails() async {
    final ownerId = _toInt(venue?["owner_id"]);

    if (ownerId <= 0) {
      _showMessage("Owner user not found");
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserDetailsWeb(userId: ownerId),
      ),
    );

    if (!mounted) return;

    _loadDetails();
  }

  @override
  Widget build(BuildContext context) {
    final v = venue;

    return AdminWebShell(
      selectedIndex: 4,
      showBackButton: true,
      pageTitle: "Venue Details",
      child: Container(
        color: adminVenueDetailsLightCream,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: adminVenueDetailsPrimaryGreen,
                ),
              )
            : v == null
                ? _notFound()
                : RefreshIndicator(
                    color: adminVenueDetailsPrimaryGreen,
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
                              _header(v),
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
                                              _statusSection(v),
                                              const SizedBox(height: 18),
                                              _readinessSection(v),
                                              const SizedBox(height: 18),
                                              _adminControlsSection(v),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          flex: 7,
                                          child: Column(
                                            children: [
                                              _imagesSection(v),
                                              const SizedBox(height: 18),
                                              _availabilitySection(v),
                                              const SizedBox(height: 18),
                                              _bookingSection(v),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return Column(
                                    children: [
                                      _statusSection(v),
                                      const SizedBox(height: 18),
                                      _readinessSection(v),
                                      const SizedBox(height: 18),
                                      _imagesSection(v),
                                      const SizedBox(height: 18),
                                      _availabilitySection(v),
                                      const SizedBox(height: 18),
                                      _bookingSection(v),
                                      const SizedBox(height: 18),
                                      _adminControlsSection(v),
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
          "Venue not found",
          style: TextStyle(
            color: adminVenueDetailsPrimaryGreen,
            fontFamily: "Montserrat",
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _header(Map<String, dynamic> v) {
    final name = _text(v["name"], fallback: "Venue");
    final owner = _text(v["owner_name"], fallback: "Owner");
    final location = _text(v["location"], fallback: "");
    final image = _image(v["image_url"]);

    final visible =
        _text(v["admin_visibility"], fallback: "hidden") == "visible";
    final reviewed = _boolValue(v["venue_reviewed"]);
    final flagged = _boolValue(v["venue_flagged"]);

    Color color = adminVenueDetailsSoftGreen;
    if (flagged) {
      color = adminVenueDetailsRed;
    } else if (!visible || !reviewed) {
      color = adminVenueDetailsGold;
    }

    return Container(
      width: double.infinity,
      height: 285,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: adminVenueDetailsPrimaryGreen.withOpacity(.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image.isNotEmpty
                ? Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: adminVenueDetailsPrimaryGreen),
                  )
                : Container(color: adminVenueDetailsPrimaryGreen),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.35),
                    adminVenueDetailsPrimaryGreen.withOpacity(0.94),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topBadge(
                    label: flagged
                        ? "Flagged"
                        : visible && reviewed
                            ? "Ready"
                            : "Needs Review",
                    icon: flagged
                        ? Icons.flag_outlined
                        : visible && reviewed
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_rounded,
                    color: color,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      fontFamily: "Montserrat",
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    owner,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 14,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (location.isNotEmpty && location != "Not set") ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: Colors.white.withOpacity(.70),
                          size: 17,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.70),
                              fontSize: 13,
                              fontFamily: "Montserrat",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: 24,
              right: 24,
              child: _headerActionButton(
                icon: Icons.refresh_rounded,
                label: "Refresh",
                onTap: _loadDetails,
              ),
            ),
          ],
        ),
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
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
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
              color: adminVenueDetailsPrimaryGreen,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 10),
          Text(
            "Updating venue...",
            style: TextStyle(
              color: adminVenueDetailsPrimaryGreen,
              fontWeight: FontWeight.w800,
              fontFamily: "Montserrat",
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusSection(Map<String, dynamic> v) {
    final visible =
        _text(v["admin_visibility"], fallback: "hidden") == "visible";
    final reviewed = _boolValue(v["venue_reviewed"]);
    final flagged = _boolValue(v["venue_flagged"]);
    final flagReason = _text(v["venue_flag_reason"], fallback: "");

    return _section(
      title: "Venue Status",
      icon: Icons.admin_panel_settings_outlined,
      iconColor: visible && reviewed
          ? adminVenueDetailsSoftGreen
          : flagged
              ? adminVenueDetailsRed
              : adminVenueDetailsGold,
      child: Column(
        children: [
          _statusHeader(
            title:
                visible && reviewed ? "Visible to Clients" : "Not Visible to Clients",
            subtitle: visible && reviewed
                ? "This venue can appear in client search and booking."
                : "Venue appears to clients only when it is reviewed and visible.",
            icon: visible && reviewed
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: visible && reviewed
                ? adminVenueDetailsSoftGreen
                : adminVenueDetailsGold,
          ),
          if (flagged && flagReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            _reasonBox("Flag reason", flagReason, adminVenueDetailsRed),
          ],
        ],
      ),
    );
  }

  Widget _readinessSection(Map<String, dynamic> v) {
    final missing = List<dynamic>.from(v["missing"] ?? []);

    final price = _text(v["price_per_hour"], fallback: "0");
    final location = _text(v["location"], fallback: "Not set");

    return _section(
      title: "Venue Readiness",
      icon: Icons.fact_check_outlined,
      iconColor:
          missing.isEmpty ? adminVenueDetailsSoftGreen : adminVenueDetailsGold,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  "Price/hr",
                  "\$$price",
                  Icons.payments_outlined,
                  adminVenueDetailsPrimaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  "Missing",
                  missing.length.toString(),
                  Icons.warning_amber_rounded,
                  missing.isEmpty
                      ? adminVenueDetailsSoftGreen
                      : adminVenueDetailsGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _plainInfo("Location", location),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 10),
            _reasonBox(
              "Missing",
              missing.join(", "),
              adminVenueDetailsGold,
            ),
          ],
        ],
      ),
    );
  }

  Widget _imagesSection(Map<String, dynamic> v) {
    final images = List<dynamic>.from(v["images"] ?? []);
    final imagesCount = _toInt(v["images_count"]);

    return _section(
      title: "Images",
      icon: Icons.image_outlined,
      iconColor:
          imagesCount > 0 ? adminVenueDetailsSoftGreen : adminVenueDetailsGold,
      child: Column(
        children: [
          _statusHeader(
            title: imagesCount > 0 ? "Images Available" : "No Images",
            subtitle: imagesCount > 0
                ? "$imagesCount image(s) uploaded for this venue."
                : "Venue should have at least one clear image before being visible.",
            icon: imagesCount > 0
                ? Icons.image_outlined
                : Icons.image_not_supported_outlined,
            color: imagesCount > 0
                ? adminVenueDetailsSoftGreen
                : adminVenueDetailsGold,
          ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 112,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (_, index) {
                  final img = Map<String, dynamic>.from(images[index]);
                  final url = _image(img["image_url"]);

                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: adminVenueDetailsLightCream,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withOpacity(.045)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: url.isNotEmpty
                          ? Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                color: adminVenueDetailsGrey,
                              ),
                            )
                          : const Icon(
                              Icons.image_outlined,
                              color: adminVenueDetailsGrey,
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _availabilitySection(Map<String, dynamic> v) {
    final availability = List<dynamic>.from(v["availability"] ?? []);
    final availabilityCount = _toInt(v["availability_count"]);

    return _section(
      title: "Availability",
      icon: Icons.event_available_outlined,
      iconColor: availabilityCount > 0
          ? adminVenueDetailsSoftGreen
          : adminVenueDetailsGold,
      child: Column(
        children: [
          _statusHeader(
            title:
                availabilityCount > 0 ? "Availability Added" : "No Availability",
            subtitle: availabilityCount > 0
                ? "$availabilityCount availability slot(s) found."
                : "Venue owner should add availability before this venue is useful for booking.",
            icon: availabilityCount > 0
                ? Icons.event_available_outlined
                : Icons.event_busy_outlined,
            color: availabilityCount > 0
                ? adminVenueDetailsSoftGreen
                : adminVenueDetailsGold,
          ),
          if (availability.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...availability.take(3).map((item) {
              final a = Map<String, dynamic>.from(item);
              final booked = _boolValue(a["is_booked"]);

              return _plainInfo(
                "${_text(a["date"])} · ${_text(a["start_time"])} - ${_text(a["end_time"])}",
                booked ? "Booked" : "Free",
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _bookingSection(Map<String, dynamic> v) {
    final booking = Map<String, dynamic>.from(v["booking_summary"] ?? {});
    final rating = Map<String, dynamic>.from(v["rating_summary"] ?? {});

    return _section(
      title: "Bookings & Ratings",
      icon: Icons.insights_outlined,
      iconColor: adminVenueDetailsPrimaryGreen,
      child: Row(
        children: [
          Expanded(
            child: _metricBox(
              "Bookings",
              _toInt(booking["total"]).toString(),
              Icons.event_note_outlined,
              adminVenueDetailsPrimaryGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricBox(
              "Completed",
              _toInt(booking["completed"]).toString(),
              Icons.check_circle_outline,
              adminVenueDetailsSoftGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricBox(
              "Rating",
              _toDouble(rating["average"]).toStringAsFixed(1),
              Icons.star_outline_rounded,
              adminVenueDetailsGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminControlsSection(Map<String, dynamic> v) {
    final visible =
        _text(v["admin_visibility"], fallback: "hidden") == "visible";
    final reviewed = _boolValue(v["venue_reviewed"]);
    final flagged = _boolValue(v["venue_flagged"]);

    return _section(
      title: "Admin Controls",
      icon: Icons.admin_panel_settings_outlined,
      iconColor: adminVenueDetailsPrimaryGreen,
      child: Column(
        children: [
          _actionRow(
            icon:
                visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            title: visible ? "Hide Venue" : "Show Venue",
            subtitle: visible
                ? "Hide this venue from client search and booking"
                : "Allow this venue to appear after review approval",
            color: visible ? adminVenueDetailsGold : adminVenueDetailsSoftGreen,
            onTap: actionLoading ? () {} : _toggleVisibility,
          ),
          _smallDivider(),
          _actionRow(
            icon: reviewed
                ? Icons.pending_actions_outlined
                : Icons.fact_check_outlined,
            title: reviewed ? "Remove Reviewed Status" : "Mark Venue Reviewed",
            subtitle: reviewed
                ? "Remove admin review approval from this venue"
                : "Confirm that venue info, images and availability were checked",
            color: reviewed ? adminVenueDetailsGold : adminVenueDetailsSoftGreen,
            onTap: actionLoading ? () {} : _toggleReviewed,
          ),
          _smallDivider(),
          _actionRow(
            icon: flagged ? Icons.outlined_flag_rounded : Icons.flag_outlined,
            title: flagged ? "Remove Venue Flag" : "Flag Venue",
            subtitle: flagged
                ? "Remove internal warning from this venue"
                : "Mark this venue as needing admin attention",
            color: flagged ? adminVenueDetailsSoftGreen : adminVenueDetailsRed,
            onTap: actionLoading ? () {} : _toggleFlag,
          ),
          _smallDivider(),
          _actionRow(
            icon: Icons.account_circle_outlined,
            title: "Open Owner Details",
            subtitle: "Go to owner account controls, notes, and activity logs",
            color: adminVenueDetailsPrimaryGreen,
            onTap: _openOwnerDetails,
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
                    color: adminVenueDetailsDarkText,
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

  Widget _reasonBox(String title, String reason, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        "$title: $reason",
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          height: 1.35,
          fontFamily: "Montserrat",
        ),
      ),
    );
  }

  Widget _plainInfo(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: adminVenueDetailsLightCream.withOpacity(0.60),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.black.withOpacity(0.42),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: "Montserrat",
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: const TextStyle(
              color: adminVenueDetailsPrimaryGreen,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              height: 1.35,
              fontFamily: "Montserrat",
            ),
          ),
        ],
      ),
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
                  color: adminVenueDetailsPrimaryGreen,
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
                color: adminVenueDetailsGrey,
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

  Future<String?> _reasonDialog({
    required String title,
    required String hint,
    required IconData icon,
    required Color color,
    required String buttonText,
  }) async {
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
          title: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: adminVenueDetailsPrimaryGreen,
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
            onChanged: (value) => reason = value,
            style: const TextStyle(
              color: adminVenueDetailsPrimaryGreen,
              fontFamily: "Montserrat",
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.black.withOpacity(0.35),
                fontFamily: "Montserrat",
              ),
              filled: true,
              fillColor: adminVenueDetailsLightCream,
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
                  color: adminVenueDetailsGrey,
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
              child: Text(
                buttonText,
                style: TextStyle(
                  color: color,
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
        backgroundColor: adminVenueDetailsPrimaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}