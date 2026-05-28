import 'package:flutter/material.dart';

import '../services/admin_client_service.dart';
import 'admin_user_details_screen.dart';

const Color adminPrimaryGreen = Color(0xFF2F4F46);
const Color adminLightCream = Color(0xFFF5F1EB);
const Color adminSoftGreen = Color(0xFF3E6B5C);
const Color adminGold = Color(0xFFC9A84C);
const Color adminRed = Color(0xFFB84040);
const Color adminGrey = Color(0xFF8A8A8A);

class AdminClientDetailsScreen extends StatefulWidget {
  final int clientId;

  const AdminClientDetailsScreen({
    super.key,
    required this.clientId,
  });

  @override
  State<AdminClientDetailsScreen> createState() =>
      _AdminClientDetailsScreenState();
}

class _AdminClientDetailsScreenState extends State<AdminClientDetailsScreen> {
  bool loading = true;
  bool actionLoading = false;

  Map<String, dynamic>? client;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => loading = true);

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
    if (score >= 75) return adminSoftGreen;
    if (score >= 45) return adminGold;
    return adminRed;
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
        return adminSoftGreen;
      case "needs_review":
        return adminGold;
      case "risky":
        return adminRed;
      default:
        return adminPrimaryGreen;
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
        confirmColor: adminSoftGreen,
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
      color: adminGold,
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
        confirmColor: adminSoftGreen,
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
      color: adminRed,
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
        builder: (_) => AdminUserDetailsScreen(userId: widget.clientId),
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
            onChanged: (value) => reason = value,
            style: const TextStyle(
              color: adminPrimaryGreen,
              fontFamily: "Playfair",
            ),
            decoration: InputDecoration(
              hintText: hint,
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
                if (cleaned.length < 3) return;
                Navigator.of(dialogContext).pop(cleaned);
              },
              child: Text(
                buttonText,
                style: TextStyle(
                  color: color,
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
    final c = client;

    return Scaffold(
      backgroundColor: adminLightCream,
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: adminPrimaryGreen),
            )
          : c == null
              ? const Center(
                  child: Text("Client not found"),
                )
              : RefreshIndicator(
                  color: adminPrimaryGreen,
                  onRefresh: _loadDetails,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 285,
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
                          background: _header(c),
                        ),
                        bottom: _roundedBottom(),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            if (actionLoading) _actionLoadingBar(),
                            _statusSection(c),
                            const SizedBox(height: 18),
                            _bookingSection(c),
                            const SizedBox(height: 18),
                            _paymentSection(c),
                            const SizedBox(height: 18),
                            _printSection(c),
                            const SizedBox(height: 18),
                            _adminControlsSection(c),
                          ]),
                        ),
                      ),
                    ],
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
            _avatar(image, color),
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
      width: 98,
      height: 98,
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
            "Updating client...",
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

  Widget _statusSection(Map<String, dynamic> c) {
    final flagged = _boolValue(c["client_flagged"]);
    final restricted = _boolValue(c["booking_restricted"]);
    final flagReason = _text(c["client_flag_reason"], fallback: "");
    final restrictionReason =
        _text(c["booking_restriction_reason"], fallback: "");

    return _section(
      title: "Client Status",
      icon: Icons.admin_panel_settings_outlined,
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
              ? adminRed
              : flagged
                  ? adminGold
                  : adminSoftGreen,
        ),
        if (flagged && flagReason.isNotEmpty) ...[
          const SizedBox(height: 10),
          _reasonBox("Flag reason", flagReason, adminGold),
        ],
        if (restricted && restrictionReason.isNotEmpty) ...[
          const SizedBox(height: 10),
          _reasonBox("Restriction reason", restrictionReason, adminRed),
        ],
      ],
    );
  }

  Widget _bookingSection(Map<String, dynamic> c) {
    final booking = Map<String, dynamic>.from(c["booking_summary"] ?? {});

    return _section(
      title: "Booking Behavior",
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
                "Cancelled",
                _toInt(booking["cancelled"]).toString(),
                Icons.cancel_outlined,
                adminRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _plainInfo(
          "Cancellation Rate",
          "${_toDouble(booking["cancellation_rate"]).toStringAsFixed(1)}%",
        ),
      ],
    );
  }

  Widget _paymentSection(Map<String, dynamic> c) {
    final payment = Map<String, dynamic>.from(c["payment_summary"] ?? {});

    return _section(
      title: "Payment Reliability",
      icon: Icons.payments_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: _metricBox(
                "Paid",
                _toInt(payment["paid_deposits"]).toString(),
                Icons.check_circle_outline,
                adminSoftGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricBox(
                "Unpaid",
                _toInt(payment["unpaid_deposits"]).toString(),
                Icons.hourglass_empty_rounded,
                adminGold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _printSection(Map<String, dynamic> c) {
    final prints = Map<String, dynamic>.from(c["print_summary"] ?? {});

    return _section(
      title: "Print Requests",
      icon: Icons.local_printshop_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: _metricBox(
                "Total",
                _toInt(prints["total"]).toString(),
                Icons.local_printshop_outlined,
                adminPrimaryGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricBox(
                "Pending",
                _toInt(prints["pending"]).toString(),
                Icons.pending_actions_outlined,
                adminGold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricBox(
                "Done",
                _toInt(prints["completed"]).toString(),
                Icons.check_circle_outline,
                adminSoftGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _adminControlsSection(Map<String, dynamic> c) {
    final flagged = _boolValue(c["client_flagged"]);
    final restricted = _boolValue(c["booking_restricted"]);

    return _section(
      title: "Admin Controls",
      icon: Icons.admin_panel_settings_outlined,
      children: [
        _actionRow(
          icon: flagged ? Icons.outlined_flag_rounded : Icons.flag_outlined,
          title: flagged ? "Remove Client Flag" : "Flag Client",
          subtitle: flagged
              ? "Remove internal warning from this client"
              : "Mark client as needing admin review",
          color: flagged ? adminSoftGreen : adminGold,
          onTap: actionLoading ? () {} : _toggleFlag,
        ),
        _actionRow(
          icon: restricted
              ? Icons.event_available_outlined
              : Icons.block_outlined,
          title: restricted ? "Allow Booking" : "Restrict Booking",
          subtitle: restricted
              ? "Allow this client to create bookings again"
              : "Prevent this client from creating new bookings",
          color: restricted ? adminSoftGreen : adminRed,
          onTap: actionLoading ? () {} : _toggleRestriction,
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
          fontWeight: FontWeight.bold,
          height: 1.35,
          fontFamily: "Playfair",
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
            fontFamily: "Playfair",
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: adminPrimaryGreen,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: "Playfair",
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
}