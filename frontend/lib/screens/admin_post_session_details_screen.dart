import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/admin_post_session_service.dart';

const Color detailsPrimaryGreen = Color(0xFF2F4F46);
const Color detailsLightCream = Color(0xFFF5F1EB);
const Color detailsSoftGreen = Color(0xFF3E6B5C);
const Color detailsGold = Color(0xFFC9A84C);
const Color detailsRed = Color(0xFFB84040);
const Color detailsBlue = Color(0xFF2F80ED);
const Color detailsPurple = Color(0xFF7C4DFF);
const Color detailsOrange = Color(0xFFF2994A);

class AdminPostSessionDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> session;

  const AdminPostSessionDetailsScreen({
    super.key,
    required this.session,
  });

  @override
  State<AdminPostSessionDetailsScreen> createState() =>
      _AdminPostSessionDetailsScreenState();
}

class _AdminPostSessionDetailsScreenState
    extends State<AdminPostSessionDetailsScreen> {
  bool showFullReport = false;

  bool sendingDeliveryReminder = false;
  bool sendingPhotographerReviewReminder = false;
  bool sendingVenueReviewReminder = false;

  bool deliveryReminderSent = false;
  bool photographerReviewReminderSent = false;
  bool venueReviewReminderSent = false;

  Map<String, dynamic> get session => widget.session;

  String _text(dynamic value, {String fallback = "Not set"}) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return fallback;

    return text;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();

    return int.tryParse(value.toString()) ?? 0;
  }

  double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();

    return double.tryParse(value.toString());
  }

  bool _asBool(dynamic value) {
    return value == true ||
        value == 1 ||
        value == "1" ||
        value == "true" ||
        value == "TRUE";
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString() ?? "";

    if (raw.trim().isEmpty || raw == "null") return "Not set";

    try {
      final date = DateTime.parse(raw).toLocal();
      return DateFormat("MMM d, yyyy").format(date);
    } catch (_) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
  }

  int _bookingId() {
    return _toInt(session["booking_id"]);
  }

  String _statusText() {
    return _text(
      session["status_text"] ?? session["overall_status_text"],
      fallback: "Unknown",
    );
  }

  bool _hasSystemVenue() {
    return _asBool(session["has_system_venue"]);
  }

  bool _canSendDeliveryReminder() {
    return _asBool(session["can_send_delivery_reminder"]);
  }

  bool _needsPhotographerReviewReminder() {
    return !_asBool(session["photographer_review_submitted"]);
  }

  bool _needsVenueReviewReminder() {
    return _hasSystemVenue() && !_asBool(session["venue_review_submitted"]);
  }

  bool _hasAnyClientReviewReminder() {
    return _needsPhotographerReviewReminder() || _needsVenueReviewReminder();
  }

  Color _statusColor() {
    final status = _statusText();
    final photographerRating = _toNullableDouble(session["photographer_rating"]);
    final venueRating = _toNullableDouble(session["venue_rating"]);

    if (status.contains("Low") ||
        (photographerRating != null && photographerRating < 3) ||
        (venueRating != null && venueRating < 3)) {
      return detailsRed;
    }

    if (status == "Completed") return detailsSoftGreen;
    if (status.contains("Revision")) return detailsPurple;
    if (status.contains("External")) return detailsBlue;

    return detailsGold;
  }

  String _sessionTitle() {
    final sessionType = _text(session["session_type"], fallback: "");
    final title = _text(session["title"], fallback: "");

    if (sessionType.isNotEmpty && sessionType != "Not set") {
      return sessionType;
    }

    if (title.isNotEmpty && title != "Not set") {
      return title;
    }

    return "Photography Session";
  }

  int _qualityScore() {
    return _toInt(session["quality_score"]);
  }

  String _priorityLabel() {
    return _text(session["priority_label"], fallback: "Priority not set");
  }

  String _priorityLevel() {
    return _text(session["priority_level"], fallback: "low");
  }

  String _qualityReason() {
    return _text(
      session["quality_reason"],
      fallback: "Post-session flow looks good.",
    );
  }

  Color _qualityColor() {
    final level = _priorityLevel();

    if (level == "high") return detailsRed;
    if (level == "medium") return detailsGold;
    if (level == "completed") return detailsSoftGreen;

    return detailsBlue;
  }

  IconData _qualityIcon() {
    final level = _priorityLevel();

    if (level == "high") return Icons.priority_high_rounded;
    if (level == "medium") return Icons.report_problem_outlined;
    if (level == "completed") return Icons.verified_rounded;

    return Icons.insights_outlined;
  }

  String _adminAction() {
    final status = _statusText();

    switch (status) {
      case "Completed":
        return "Post-session flow looks complete. No urgent action is required.";
      case "External Location":
        return "Venue follow-up is not required because this session used an external location.";
      case "Gallery Missing":
        return "Photographer still needs to create the session album.";
      case "Not Delivered":
        return "Gallery exists but has not been delivered to the client.";
      case "Revision Pending":
        return "There are active client edit requests that need follow-up.";
      case "Clean Copy Pending":
        return "Clean copy request is waiting for photographer response.";
      case "Access Locked":
        return "Final download access is still locked.";
      case "No Photographer Review":
        return "Client has not reviewed the photographer yet.";
      case "Low Photographer Rating":
        return "Photographer received a low rating and may need review.";
      case "Venue Booking Missing":
        return "System venue exists, but no matching venue booking was found.";
      case "Venue Deposit Unpaid":
        return "Venue deposit still needs follow-up.";
      case "Venue Not Completed":
        return "Venue booking has not been completed yet.";
      case "No Venue Review":
        return "Client has not reviewed the venue yet.";
      case "Low Venue Rating":
        return "Venue received a low rating and may need review.";
      default:
        return "Review this post-session case if needed.";
    }
  }

  int _photoDoneCount() {
    int value = 1;

    if (_asBool(session["gallery_created"])) value++;
    if (_asBool(session["delivered"])) value++;
    if (_asBool(session["revisions_done"])) value++;
    if (_asBool(session["final_access"])) value++;
    if (_asBool(session["photographer_review_submitted"])) value++;

    return value;
  }

  int _venueDoneCount() {
    if (!_hasSystemVenue()) return 0;

    int value = 1;

    if (_asBool(session["venue_booking_exists"])) value++;
    if (_asBool(session["venue_deposit_paid"])) value++;
    if (_asBool(session["venue_completed"])) value++;
    if (_asBool(session["venue_review_submitted"])) value++;

    return value;
  }

  String _deliveryStatus() {
    return _text(
      session["delivery_commitment_status"],
      fallback: "no_expected_date",
    );
  }

  String _deliveryLabel() {
    return _text(
      session["delivery_commitment_label"],
      fallback: "No expected date",
    );
  }

  Color _deliveryColor() {
    switch (_deliveryStatus()) {
      case "on_time":
        return detailsSoftGreen;
      case "late":
        return detailsOrange;
      case "overdue":
        return detailsRed;
      case "within_time":
        return detailsBlue;
      case "no_expected_date":
      default:
        return detailsGold;
    }
  }

  IconData _deliveryIcon() {
    switch (_deliveryStatus()) {
      case "on_time":
        return Icons.task_alt_rounded;
      case "late":
        return Icons.schedule_rounded;
      case "overdue":
        return Icons.warning_amber_rounded;
      case "within_time":
        return Icons.timelapse_rounded;
      case "no_expected_date":
      default:
        return Icons.event_busy_outlined;
    }
  }

  String _deliveryHelpText() {
    switch (_deliveryStatus()) {
      case "on_time":
        return "Delivered on time.";
      case "late":
        return "Delivered late. No reminder needed now.";
      case "overdue":
        return "Overdue and not delivered yet.";
      case "within_time":
        return "Still within expected delivery time.";
      case "no_expected_date":
      default:
        return "No expected delivery date was set.";
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? detailsRed : detailsPrimaryGreen,
        content: Text(
          message,
          style: const TextStyle(fontFamily: "Montserrat"),
        ),
      ),
    );
  }

  Future<void> _sendDeliveryReminder() async {
    final bookingId = _bookingId();

    if (bookingId <= 0) {
      _showMessage("Invalid booking id.", isError: true);
      return;
    }

    setState(() => sendingDeliveryReminder = true);

    try {
      final data = await AdminPostSessionService.sendDeliveryReminder(bookingId);

      if (!mounted) return;

      setState(() {
        sendingDeliveryReminder = false;
        deliveryReminderSent = true;
      });

      _showMessage(
        _text(
          data["message"],
          fallback: "Delivery reminder sent to photographer.",
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => sendingDeliveryReminder = false);

      _showMessage(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  Future<void> _sendPhotographerReviewReminder() async {
    final bookingId = _bookingId();

    if (bookingId <= 0) {
      _showMessage("Invalid booking id.", isError: true);
      return;
    }

    setState(() => sendingPhotographerReviewReminder = true);

    try {
      final data =
          await AdminPostSessionService.sendPhotographerReviewReminder(
        bookingId,
      );

      if (!mounted) return;

      setState(() {
        sendingPhotographerReviewReminder = false;
        photographerReviewReminderSent = true;
      });

      _showMessage(
        _text(
          data["message"],
          fallback: "Photographer review reminder sent to client.",
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => sendingPhotographerReviewReminder = false);

      _showMessage(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  Future<void> _sendVenueReviewReminder() async {
    final bookingId = _bookingId();

    if (bookingId <= 0) {
      _showMessage("Invalid booking id.", isError: true);
      return;
    }

    setState(() => sendingVenueReviewReminder = true);

    try {
      final data = await AdminPostSessionService.sendVenueReviewReminder(
        bookingId,
      );

      if (!mounted) return;

      setState(() {
        sendingVenueReviewReminder = false;
        venueReviewReminderSent = true;
      });

      _showMessage(
        _text(
          data["message"],
          fallback: "Venue review reminder sent to client.",
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => sendingVenueReviewReminder = false);

      _showMessage(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();

    return Scaffold(
      backgroundColor: detailsLightCream,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header(context, color)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _summaryOnlyCard(),
                const SizedBox(height: 12),
                _showFullReportButton(),
                if (showFullReport) ...[
                  const SizedBox(height: 12),
                  _reportSummaryCard(color),
                  const SizedBox(height: 12),
                  _deliveryReportCard(),
                  if (_hasAnyClientReviewReminder()) ...[
                    const SizedBox(height: 12),
                    _clientReminderReportCard(),
                  ],
                  const SizedBox(height: 12),
                  _checklistReportCard(),
                  const SizedBox(height: 12),
                  _qualityNotesCard(),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, Color color) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF25463D), detailsSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context, true),
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
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(.22)),
                    ),
                    child: const Icon(
                      Icons.article_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sessionTitle(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(.25),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withOpacity(.18),
                            ),
                          ),
                          child: Text(
                            _statusText(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: "Montserrat",
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryOnlyCard() {
    final qualityColor = _qualityColor();
    final deliveryColor = _deliveryColor();
    final score = _qualityScore();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: qualityColor.withOpacity(.18)),
        boxShadow: [
          BoxShadow(
            color: qualityColor.withOpacity(.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: qualityColor.withOpacity(.11),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Center(
                  child: Text(
                    "$score",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: qualityColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Quality Summary",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        color: detailsPrimaryGreen,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(_qualityIcon(), color: qualityColor, size: 17),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _priorityLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              color: qualityColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _summaryMiniRow(
            icon: Icons.camera_alt_outlined,
            label: "Photographer",
            value: _text(
              session["photographer_name"],
              fallback: "Unknown photographer",
            ),
          ),
          _summaryMiniRow(
            icon: Icons.person_outline_rounded,
            label: "Client",
            value: _text(session["client_name"], fallback: "Unknown client"),
          ),
          _summaryMiniRow(
            icon: Icons.calendar_today_outlined,
            label: "Session date",
            value: _formatDate(session["completed_at"]),
          ),
          _summaryMiniRow(
            icon: _hasSystemVenue()
                ? Icons.location_city_outlined
                : Icons.map_outlined,
            label: "Venue",
            value: _hasSystemVenue()
                ? _text(session["venue_name"], fallback: "System venue")
                : "External location",
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: qualityColor.withOpacity(.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: qualityColor.withOpacity(.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.insights_outlined, color: qualityColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _qualityReason(),
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.black54,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip(
                icon: Icons.fact_check_outlined,
                label: "Photo ${_photoDoneCount()}/6",
                color: _photoDoneCount() == 6 ? detailsSoftGreen : detailsGold,
              ),
              if (_hasSystemVenue())
                _summaryChip(
                  icon: Icons.location_city_outlined,
                  label: "Venue ${_venueDoneCount()}/5",
                  color:
                      _venueDoneCount() == 5 ? detailsSoftGreen : detailsGold,
                )
              else
                _summaryChip(
                  icon: Icons.map_outlined,
                  label: "External venue",
                  color: detailsBlue,
                ),
              _summaryChip(
                icon: _deliveryIcon(),
                label: _deliveryLabel(),
                color: deliveryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _showFullReportButton() {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() => showFullReport = !showFullReport);
        },
        icon: Icon(
          showFullReport
              ? Icons.keyboard_arrow_up_rounded
              : Icons.article_outlined,
          size: 20,
        ),
        label: Text(
          showFullReport ? "Hide Full Report" : "View Full Report",
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: detailsPrimaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _summaryMiniRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        children: [
          Icon(icon, color: detailsPrimaryGreen.withOpacity(.72), size: 15),
          const SizedBox(width: 7),
          Text(
            "$label: ",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black.withOpacity(.45),
              fontSize: 11.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: detailsPrimaryGreen,
                fontSize: 12.2,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withOpacity(.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: color,
              fontSize: 10.4,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportSummaryCard(Color color) {
    final hasVenue = _hasSystemVenue();

    return _reportCard(
      title: "Report Summary",
      icon: Icons.summarize_outlined,
      color: detailsPrimaryGreen,
      child: Column(
        children: [
          _reportLine(
            icon: Icons.camera_alt_outlined,
            label: "Photographer",
            value: _text(
              session["photographer_name"],
              fallback: "Unknown photographer",
            ),
          ),
          _reportLine(
            icon: Icons.person_outline_rounded,
            label: "Client",
            value: _text(session["client_name"], fallback: "Unknown client"),
          ),
          _reportLine(
            icon: Icons.calendar_today_outlined,
            label: "Session date",
            value: _formatDate(session["completed_at"]),
          ),
          _reportLine(
            icon: hasVenue ? Icons.location_city_outlined : Icons.map_outlined,
            label: "Venue",
            value: hasVenue
                ? _text(session["venue_name"], fallback: "System venue")
                : "External location",
          ),
          const SizedBox(height: 10),
          _reportNote(
            icon: Icons.task_alt_outlined,
            color: color,
            text: _adminAction(),
          ),
        ],
      ),
    );
  }

  Widget _deliveryReportCard() {
    final color = _deliveryColor();
    final canSendReminder = _canSendDeliveryReminder();
    final expectedDate = _formatDate(session["estimated_delivery_date"]);
    final actualDate = _formatDate(session["delivered_at"]);
    final daysLate = _toInt(session["delivery_days_late"]);

    return _reportCard(
      title: "Delivery Commitment",
      icon: _deliveryIcon(),
      color: color,
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _deliveryStatusBox(color),
          const SizedBox(height: 10),
          _reportLine(
            icon: Icons.event_outlined,
            label: "Expected",
            value: expectedDate,
          ),
          _reportLine(
            icon: Icons.outbox_outlined,
            label: "Actual",
            value: actualDate,
          ),
          if (daysLate > 0)
            _reportLine(
              icon: Icons.schedule_rounded,
              label: "Days late",
              value: "$daysLate",
              valueColor: color,
            ),
          const SizedBox(height: 8),
          Text(
            _deliveryHelpText(),
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black54,
              fontSize: 11.8,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (canSendReminder) ...[
            const SizedBox(height: 10),
            _smallActionButton(
              label: deliveryReminderSent ? "Reminder sent" : "Send reminder",
              icon: deliveryReminderSent
                  ? Icons.check_circle_outline_rounded
                  : Icons.notifications_active_outlined,
              color: color,
              loading: sendingDeliveryReminder,
              disabled: deliveryReminderSent,
              onTap: _sendDeliveryReminder,
            ),
          ],
        ],
      ),
    );
  }

  Widget _deliveryStatusBox(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(.11),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Row(
        children: [
          Icon(_deliveryIcon(), color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _deliveryLabel(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientReminderReportCard() {
    return _reportCard(
      title: "Client Review Reminder",
      icon: Icons.rate_review_outlined,
      color: detailsBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Missing client reviews only:",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black54,
              fontSize: 11.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_needsPhotographerReviewReminder())
                _smallActionButton(
                  label: photographerReviewReminderSent
                      ? "Photographer sent"
                      : "Rate photographer",
                  icon: photographerReviewReminderSent
                      ? Icons.check_circle_outline_rounded
                      : Icons.camera_alt_outlined,
                  color: detailsBlue,
                  loading: sendingPhotographerReviewReminder,
                  disabled: photographerReviewReminderSent,
                  onTap: _sendPhotographerReviewReminder,
                ),
              if (_needsVenueReviewReminder())
                _smallActionButton(
                  label: venueReviewReminderSent ? "Venue sent" : "Rate venue",
                  icon: venueReviewReminderSent
                      ? Icons.check_circle_outline_rounded
                      : Icons.location_city_outlined,
                  color: detailsSoftGreen,
                  loading: sendingVenueReviewReminder,
                  disabled: venueReviewReminderSent,
                  onTap: _sendVenueReviewReminder,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _checklistReportCard() {
    return _reportCard(
      title: "Checklist Report",
      icon: Icons.checklist_rounded,
      color: detailsPrimaryGreen,
      child: Column(
        children: [
          _miniProgressHeader(
            title: "Photography",
            value: "${_photoDoneCount()}/6",
            color: _photoDoneCount() == 6 ? detailsSoftGreen : detailsGold,
          ),
          const SizedBox(height: 8),
          _compactCheckGrid(_photographyChecks()),
          const SizedBox(height: 14),
          if (_hasSystemVenue()) ...[
            _miniProgressHeader(
              title: "Venue",
              value: "${_venueDoneCount()}/5",
              color: _venueDoneCount() == 5 ? detailsSoftGreen : detailsGold,
            ),
            const SizedBox(height: 8),
            _compactCheckGrid(_venueChecks()),
          ] else
            _externalVenueNote(),
        ],
      ),
    );
  }

  Widget _qualityNotesCard() {
    final photographerRating = _toNullableDouble(session["photographer_rating"]);
    final venueRating = _toNullableDouble(session["venue_rating"]);

    return _reportCard(
      title: "Quality Notes",
      icon: Icons.insights_outlined,
      color: detailsPrimaryGreen,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _signalChip(
            Icons.edit_note_rounded,
            "${_toInt(session["active_revision_count"])} active edits",
            _toInt(session["active_revision_count"]) > 0
                ? detailsPurple
                : detailsSoftGreen,
          ),
          _signalChip(
            Icons.branding_watermark_outlined,
            "Clean copy: ${_text(session["clean_copy_status"], fallback: "none")}",
            session["clean_copy_status"] == "pending"
                ? detailsGold
                : detailsSoftGreen,
          ),
          _signalChip(
            Icons.star_rate_rounded,
            photographerRating == null
                ? "Photographer: no rating"
                : "Photographer: ${photographerRating.toStringAsFixed(1)}",
            photographerRating != null && photographerRating < 3
                ? detailsRed
                : detailsBlue,
          ),
          if (_hasSystemVenue())
            _signalChip(
              Icons.location_city_outlined,
              venueRating == null
                  ? "Venue: no rating"
                  : "Venue: ${venueRating.toStringAsFixed(1)}",
              venueRating != null && venueRating < 3
                  ? detailsRed
                  : detailsBlue,
            ),
        ],
      ),
    );
  }

  List<_ReportCheck> _photographyChecks() {
    return [
      _ReportCheck(
        label: "Completed",
        done: true,
        value: _formatDate(session["completed_at"]),
      ),
      _ReportCheck(
        label: "Album",
        done: _asBool(session["gallery_created"]),
        value: _text(session["gallery_status"], fallback: "not_created"),
      ),
      _ReportCheck(
        label: "Delivered",
        done: _asBool(session["delivered"]),
        value: _formatDate(session["delivered_at"]),
      ),
      _ReportCheck(
        label: "Edits",
        done: _asBool(session["revisions_done"]),
        value: "${_toInt(session["active_revision_count"])} active",
      ),
      _ReportCheck(
        label: "Access",
        done: _asBool(session["final_access"]),
        value: _asBool(session["final_access"]) ? "Enabled" : "Locked",
      ),
      _ReportCheck(
        label: "Review",
        done: _asBool(session["photographer_review_submitted"]),
        value: session["photographer_rating"] == null
            ? "No rating"
            : "${session["photographer_rating"]}/5",
      ),
    ];
  }

  List<_ReportCheck> _venueChecks() {
    return [
      _ReportCheck(
        label: "System",
        done: true,
        value: _text(session["venue_name"], fallback: "System venue"),
      ),
      _ReportCheck(
        label: "Booking",
        done: _asBool(session["venue_booking_exists"]),
        value: _asBool(session["venue_booking_exists"]) ? "Found" : "Missing",
      ),
      _ReportCheck(
        label: "Deposit",
        done: _asBool(session["venue_deposit_paid"]),
        value: _asBool(session["venue_deposit_paid"]) ? "Paid" : "Unpaid",
      ),
      _ReportCheck(
        label: "Done",
        done: _asBool(session["venue_completed"]),
        value: _text(session["venue_booking_status"], fallback: "Not set"),
      ),
      _ReportCheck(
        label: "Review",
        done: _asBool(session["venue_review_submitted"]),
        value: session["venue_rating"] == null
            ? "No rating"
            : "${session["venue_rating"]}/5",
      ),
    ];
  }

  Widget _reportCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    bool highlighted = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: highlighted ? Border.all(color: color.withOpacity(.22)) : null,
        boxShadow: [
          BoxShadow(
            color: highlighted
                ? color.withOpacity(.08)
                : detailsPrimaryGreen.withOpacity(.045),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: detailsPrimaryGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _reportLine({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.5),
      child: Row(
        children: [
          Icon(
            icon,
            color: detailsPrimaryGreen.withOpacity(.72),
            size: 15,
          ),
          const SizedBox(width: 7),
          Text(
            "$label: ",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black.withOpacity(.45),
              fontSize: 11.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: valueColor ?? detailsPrimaryGreen,
                fontSize: 12.2,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportNote({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black54,
                fontSize: 11.8,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniProgressHeader({
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: detailsPrimaryGreen,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _compactCheckGrid(List<_ReportCheck> checks) {
    return Column(
      children: checks.map((item) => _compactCheckRow(item)).toList(),
    );
  }

  Widget _compactCheckRow(_ReportCheck item) {
    final color = item.done ? detailsSoftGreen : detailsGold;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: detailsLightCream,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            item.done ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: detailsPrimaryGreen,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              item.value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _externalVenueNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: detailsBlue.withOpacity(.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: detailsBlue.withOpacity(.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.map_outlined, color: detailsBlue, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "External location: ${_text(session["venue_location"], fallback: "No system venue")}. Venue report is not required.",
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: detailsBlue,
                fontSize: 11.8,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool loading,
    required bool disabled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 34,
      child: ElevatedButton.icon(
        onPressed: loading || disabled ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 14),
        label: Text(
          loading ? "Sending" : label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 10.7,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: disabled ? detailsSoftGreen : color,
          disabledBackgroundColor: detailsSoftGreen.withOpacity(.80),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }

  Widget _signalChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withOpacity(.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: color,
              fontSize: 10.4,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCheck {
  final String label;
  final bool done;
  final String value;

  _ReportCheck({
    required this.label,
    required this.done,
    required this.value,
  });
}