import 'package:flutter/material.dart';

import '../services/admin_client_service.dart';
import 'admin_web_shell.dart';
import 'admin_user_details_web.dart';

const Color adminClientDetailsPrimaryGreen = Color(0xFF2F4F46);
const Color adminClientDetailsLightCream = Color(0xFFF5F1EB);
const Color adminClientDetailsSoftGreen = Color(0xFF3E6B5C);
const Color adminClientDetailsGold = Color(0xFFC9A84C);
const Color adminClientDetailsRed = Color(0xFFB84040);
const Color adminClientDetailsGrey = Color(0xFF8A8A8A);
const Color adminClientDetailsDarkText = Color(0xFF26352D);

class AdminClientDetailsWeb extends StatefulWidget {
  final int clientId;

  const AdminClientDetailsWeb({
    super.key,
    required this.clientId,
  });

  @override
  State<AdminClientDetailsWeb> createState() => _AdminClientDetailsWebState();
}

class _AdminClientDetailsWebState extends State<AdminClientDetailsWeb> {
  bool loading = true;
  bool actionLoading = false;

  Map<String, dynamic>? client;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (mounted) {
      setState(() => loading = true);
    }

    final result = await AdminClientService.getClientDetails(widget.clientId);

    if (!mounted) return;

    setState(() {
      client = result;
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

  Color _scoreColor(int score) {
    if (score >= 75) return adminClientDetailsSoftGreen;
    if (score >= 45) return adminClientDetailsGold;
    return adminClientDetailsRed;
  }

  String _riskLabel(String status) {
    switch (status) {
      case "reliable":
        return "Reliable Client";
      case "needs_review":
        return "Needs Review";
      case "risky":
        return "Risky Client";
      default:
        return "Normal Client";
    }
  }

  Color _riskColor(String status) {
    switch (status) {
      case "reliable":
        return adminClientDetailsSoftGreen;
      case "needs_review":
        return adminClientDetailsGold;
      case "risky":
        return adminClientDetailsRed;
      default:
        return adminClientDetailsPrimaryGreen;
    }
  }

  IconData _riskIcon(String status) {
    switch (status) {
      case "reliable":
        return Icons.verified_user_outlined;
      case "needs_review":
        return Icons.flag_outlined;
      case "risky":
        return Icons.warning_amber_rounded;
      default:
        return Icons.person_outline;
    }
  }

  Future<void> _toggleFlag() async {
    final c = client;
    if (c == null) return;

    final flagged = _boolValue(c["client_flagged"]);

    if (flagged) {
      final confirm = await _confirmDialog(
        title: "Remove Client Flag?",
        message: "This client will no longer be marked as needing admin review.",
        confirmText: "Remove Flag",
        confirmColor: adminClientDetailsSoftGreen,
        icon: Icons.outlined_flag_rounded,
      );

      if (confirm != true) return;

      setState(() => actionLoading = true);

      final ok = await AdminClientService.updateClientFlag(
        clientId: widget.clientId,
        flagged: false,
      );

      if (!mounted) return;

      setState(() => actionLoading = false);

      if (ok) {
        _showMessage("Client flag removed");
        _loadDetails();
      } else {
        _showMessage("Failed to remove flag");
      }

      return;
    }

    final reason = await _reasonDialog(
      title: "Flag Client",
      hint: "Reason, e.g. high cancellation rate...",
      icon: Icons.flag_outlined,
      color: adminClientDetailsGold,
      buttonText: "Flag",
    );

    if (reason == null || reason.trim().length < 3) return;

    setState(() => actionLoading = true);

    final ok = await AdminClientService.updateClientFlag(
      clientId: widget.clientId,
      flagged: true,
      reason: reason.trim(),
    );

    if (!mounted) return;

    setState(() => actionLoading = false);

    if (ok) {
      _showMessage("Client flagged");
      _loadDetails();
    } else {
      _showMessage("Failed to flag client");
    }
  }

  Future<void> _toggleRestriction() async {
    final c = client;
    if (c == null) return;

    final restricted = _boolValue(c["booking_restricted"]);

    if (restricted) {
      final confirm = await _confirmDialog(
        title: "Allow Booking Again?",
        message: "This client will be able to create new bookings again.",
        confirmText: "Allow Booking",
        confirmColor: adminClientDetailsSoftGreen,
        icon: Icons.event_available_outlined,
      );

      if (confirm != true) return;

      setState(() => actionLoading = true);

      final ok = await AdminClientService.updateBookingRestriction(
        clientId: widget.clientId,
        restricted: false,
      );

      if (!mounted) return;

      setState(() => actionLoading = false);

      if (ok) {
        _showMessage("Booking restriction removed");
        _loadDetails();
      } else {
        _showMessage("Failed to remove restriction");
      }

      return;
    }

    final reason = await _reasonDialog(
      title: "Restrict Booking",
      hint: "Reason, e.g. repeated unpaid bookings...",
      icon: Icons.block_outlined,
      color: adminClientDetailsRed,
      buttonText: "Restrict",
    );

    if (reason == null || reason.trim().length < 3) return;

    setState(() => actionLoading = true);

    final ok = await AdminClientService.updateBookingRestriction(
      clientId: widget.clientId,
      restricted: true,
      reason: reason.trim(),
    );

    if (!mounted) return;

    setState(() => actionLoading = false);

    if (ok) {
      _showMessage("Client booking restricted");
      _loadDetails();
    } else {
      _showMessage("Failed to restrict booking");
    }
  }

  Future<void> _openFullUserDetails() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserDetailsWeb(userId: widget.clientId),
      ),
    );

    if (!mounted) return;

    _loadDetails();
  }

  @override
  Widget build(BuildContext context) {
    final c = client;

    return AdminWebShell(
      selectedIndex: 3,
      showBackButton: true,
      pageTitle: "Client Details",
      child: Container(
        color: adminClientDetailsLightCream,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: adminClientDetailsPrimaryGreen,
                ),
              )
            : c == null
                ? _notFound()
                : RefreshIndicator(
                    color: adminClientDetailsPrimaryGreen,
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
                              _header(c),
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
                                              _statusSection(c),
                                              const SizedBox(height: 18),
                                              _paymentSection(c),
                                              const SizedBox(height: 18),
                                              _adminControlsSection(c),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          flex: 7,
                                          child: Column(
                                            children: [
                                              _bookingSection(c),
                                              const SizedBox(height: 18),
                                              _printSection(c),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return Column(
                                    children: [
                                      _statusSection(c),
                                      const SizedBox(height: 18),
                                      _bookingSection(c),
                                      const SizedBox(height: 18),
                                      _paymentSection(c),
                                      const SizedBox(height: 18),
                                      _printSection(c),
                                      const SizedBox(height: 18),
                                      _adminControlsSection(c),
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
          "Client not found",
          style: TextStyle(
            color: adminClientDetailsPrimaryGreen,
            fontFamily: "Montserrat",
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _header(Map<String, dynamic> c) {
    final name = _text(c["full_name"], fallback: "Client");
    final email = _text(c["email"], fallback: "");
    final image = _image(c["profile_image"]);
    final score = _toInt(c["trust_score"]);
    final riskStatus = _text(c["risk_status"], fallback: "normal");
    final color = _riskColor(riskStatus);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25463D), adminClientDetailsSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: adminClientDetailsPrimaryGreen.withOpacity(.16),
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
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 7),
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
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _topBadge(
                      label: "Trust $score%",
                      icon: Icons.shield_outlined,
                      color: _scoreColor(score),
                    ),
                    _topBadge(
                      label: _riskLabel(riskStatus),
                      icon: _riskIcon(riskStatus),
                      color: color,
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
        Icons.person_outline,
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
        border: Border.all(color: Colors.white.withOpacity(0.25)),
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
              color: adminClientDetailsPrimaryGreen,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 10),
          Text(
            "Updating client...",
            style: TextStyle(
              color: adminClientDetailsPrimaryGreen,
              fontWeight: FontWeight.w800,
              fontFamily: "Montserrat",
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusSection(Map<String, dynamic> c) {
    final flagged = _boolValue(c["client_flagged"]);
    final restricted = _boolValue(c["booking_restricted"]);
    final flagReason = _text(c["client_flag_reason"], fallback: "");
    final restrictionReason = _text(
      c["booking_restriction_reason"],
      fallback: "",
    );

    return _section(
      title: "Client Status",
      icon: Icons.admin_panel_settings_outlined,
      iconColor: restricted
          ? adminClientDetailsRed
          : flagged
              ? adminClientDetailsGold
              : adminClientDetailsSoftGreen,
      child: Column(
        children: [
          _statusHeader(
            title: restricted
                ? "Booking Restricted"
                : flagged
                    ? "Flagged for Review"
                    : "Normal Client",
            subtitle: restricted
                ? "This client cannot create new bookings."
                : flagged
                    ? "This client is marked for admin attention."
                    : "No active admin warning on this client.",
            icon: restricted
                ? Icons.block_outlined
                : flagged
                    ? Icons.flag_outlined
                    : Icons.check_circle_outline,
            color: restricted
                ? adminClientDetailsRed
                : flagged
                    ? adminClientDetailsGold
                    : adminClientDetailsSoftGreen,
          ),
          if (flagged && flagReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            _reasonBox("Flag reason", flagReason, adminClientDetailsGold),
          ],
          if (restricted && restrictionReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            _reasonBox(
              "Restriction reason",
              restrictionReason,
              adminClientDetailsRed,
            ),
          ],
        ],
      ),
    );
  }

  Widget _bookingSection(Map<String, dynamic> c) {
    final booking = Map<String, dynamic>.from(c["booking_summary"] ?? {});

    return _section(
      title: "Booking Behavior",
      icon: Icons.event_note_outlined,
      iconColor: adminClientDetailsPrimaryGreen,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  "Total",
                  _toInt(booking["total"]).toString(),
                  Icons.all_inbox_outlined,
                  adminClientDetailsPrimaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  "Completed",
                  _toInt(booking["completed"]).toString(),
                  Icons.check_circle_outline,
                  adminClientDetailsSoftGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  "Cancelled",
                  _toInt(booking["cancelled"]).toString(),
                  Icons.cancel_outlined,
                  adminClientDetailsRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _plainInfo(
            "Cancellation Rate",
            "${_toDouble(booking["cancellation_rate"]).toStringAsFixed(1)}%",
          ),
        ],
      ),
    );
  }

  Widget _paymentSection(Map<String, dynamic> c) {
    final payment = Map<String, dynamic>.from(c["payment_summary"] ?? {});

    return _section(
      title: "Payment Reliability",
      icon: Icons.payments_outlined,
      iconColor: adminClientDetailsSoftGreen,
      child: Row(
        children: [
          Expanded(
            child: _metricBox(
              "Paid",
              _toInt(payment["paid_deposits"]).toString(),
              Icons.check_circle_outline,
              adminClientDetailsSoftGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricBox(
              "Unpaid",
              _toInt(payment["unpaid_deposits"]).toString(),
              Icons.hourglass_empty_rounded,
              adminClientDetailsGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _printSection(Map<String, dynamic> c) {
    final prints = Map<String, dynamic>.from(c["print_summary"] ?? {});

    return _section(
      title: "Print Requests",
      icon: Icons.local_printshop_outlined,
      iconColor: adminClientDetailsPrimaryGreen,
      child: Row(
        children: [
          Expanded(
            child: _metricBox(
              "Total",
              _toInt(prints["total"]).toString(),
              Icons.local_printshop_outlined,
              adminClientDetailsPrimaryGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricBox(
              "Pending",
              _toInt(prints["pending"]).toString(),
              Icons.pending_actions_outlined,
              adminClientDetailsGold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricBox(
              "Done",
              _toInt(prints["completed"]).toString(),
              Icons.check_circle_outline,
              adminClientDetailsSoftGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminControlsSection(Map<String, dynamic> c) {
    final flagged = _boolValue(c["client_flagged"]);
    final restricted = _boolValue(c["booking_restricted"]);

    return _section(
      title: "Admin Controls",
      icon: Icons.admin_panel_settings_outlined,
      iconColor: adminClientDetailsPrimaryGreen,
      child: Column(
        children: [
          _actionRow(
            icon: flagged ? Icons.outlined_flag_rounded : Icons.flag_outlined,
            title: flagged ? "Remove Client Flag" : "Flag Client",
            subtitle: flagged
                ? "Remove internal warning from this client"
                : "Mark client as needing admin review",
            color: flagged
                ? adminClientDetailsSoftGreen
                : adminClientDetailsGold,
            onTap: actionLoading ? () {} : _toggleFlag,
          ),
          _smallDivider(),
          _actionRow(
            icon: restricted
                ? Icons.event_available_outlined
                : Icons.block_outlined,
            title: restricted ? "Allow Booking" : "Restrict Booking",
            subtitle: restricted
                ? "Allow this client to create bookings again"
                : "Prevent this client from creating new bookings",
            color: restricted
                ? adminClientDetailsSoftGreen
                : adminClientDetailsRed,
            onTap: actionLoading ? () {} : _toggleRestriction,
          ),
          _smallDivider(),
          _actionRow(
            icon: Icons.account_circle_outlined,
            title: "Open Full User Details",
            subtitle: "Go to general account controls, notes, and activity logs",
            color: adminClientDetailsPrimaryGreen,
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
                    color: adminClientDetailsDarkText,
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
        Text(
          value,
          style: const TextStyle(
            color: adminClientDetailsPrimaryGreen,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
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
                  color: adminClientDetailsPrimaryGreen,
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
                color: adminClientDetailsGrey,
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
                    color: adminClientDetailsPrimaryGreen,
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
              color: adminClientDetailsPrimaryGreen,
              fontFamily: "Montserrat",
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.black.withOpacity(0.35),
                fontFamily: "Montserrat",
              ),
              filled: true,
              fillColor: adminClientDetailsLightCream,
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
                  color: adminClientDetailsGrey,
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
        backgroundColor: adminClientDetailsPrimaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}