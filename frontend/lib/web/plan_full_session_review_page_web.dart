import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/photographer_booking_service_for_client.dart';
import 'client_web_shell.dart';
import 'client_bookings_page_web.dart';

class PlanFullSessionReviewPageWeb extends StatefulWidget {
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final double durationHours;
  final String sessionType;
  final Map<String, dynamic> selectedPhotographer;
  final Map<String, dynamic> selectedVenue;

  const PlanFullSessionReviewPageWeb({
    super.key,
    required this.selectedDate,
    required this.selectedTime,
    required this.durationHours,
    required this.sessionType,
    required this.selectedPhotographer,
    required this.selectedVenue,
  });

  @override
  State<PlanFullSessionReviewPageWeb> createState() =>
      _PlanFullSessionReviewPageWebWebState();
}

class _PlanFullSessionReviewPageWebWebState
    extends State<PlanFullSessionReviewPageWeb> {
  bool _submitting = false;

  String _formatDate(DateTime date) {
    return DateFormat('EEE, MMM d, yyyy').format(date);
  }

  String _apiDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt);
  }

  String _apiTime(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm:00';
  }

  String _durationLabel(double value) {
    if (value == value.toInt()) {
      return '${value.toInt()} hour${value == 1 ? '' : 's'}';
    }
    return '$value hours';
  }

  String _money(dynamic raw) {
    final value = double.tryParse(raw?.toString() ?? '0') ?? 0;
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(0);
  }

  double _ratingValue(dynamic raw) {
    return double.tryParse(raw?.toString() ?? '0') ?? 0;
  }

  Future<void> _goToMyBookings() async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ClientBookingsPageWeb(),
      ),
    );
  }

  Future<void> _confirmFullSession() async {
    final rawPhotographerId = widget.selectedPhotographer['photographer_id'];
    final rawVenueId = widget.selectedVenue['id'];

    final photographerId = rawPhotographerId is int
        ? rawPhotographerId
        : int.tryParse(rawPhotographerId?.toString() ?? '');

    final venueId = rawVenueId is int
        ? rawVenueId
        : int.tryParse(rawVenueId?.toString() ?? '');

    if (photographerId == null || venueId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid photographer or venue selection.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final result =
          await PhotographerBookingServiceForClient.createBooking(
        photographerId: photographerId,
        sessionType: widget.sessionType,
        date: _apiDate(widget.selectedDate),
        time: _apiTime(widget.selectedTime),
        durationHours: widget.durationHours,
        venueId: venueId,
        location: widget.selectedVenue['location']?.toString(),
        note: 'Full session booking',
      );

      if (!mounted) return;

      final statusCode = result['statusCode'] ?? 500;
      final data = result['data'];

      if (statusCode == 201 || statusCode == 200) {
        final message =
            data is Map && data['message'] != null
                ? data['message'].toString()
                : 'Full session booking created successfully.';

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final text = Theme.of(context).textTheme.bodyLarge?.color ??
                Colors.black87;
            final sub = Theme.of(context).textTheme.bodyMedium?.color ??
                Colors.grey;
            final primary = Theme.of(context).colorScheme.primary;
            final card = Theme.of(context).cardColor;

            return AlertDialog(
              backgroundColor: card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Full Session Created',
                style: TextStyle(
                  fontFamily: 'Playfair_Display',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: text,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      height: 1.6,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Go to My Bookings to pay the photographer deposit and the venue deposit.',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      height: 1.6,
                      color: sub,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Stay Here',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ClientBookingsPageWeb(),
                      ),
                      (route) => route.isFirst,
                    );
                  },
                  child: const Text(
                    'View My Bookings',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        final message = data is Map && data['message'] != null
            ? data['message'].toString()
            : 'Failed to create full session booking.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create full session booking.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final card = Theme.of(context).cardColor;
    final text =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final sub =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final primary = Theme.of(context).colorScheme.primary;
    final border = isDark ? Colors.white10 : Colors.grey.shade200;
    final softSurface =
        isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF7F4EC);

    final photographerName =
        widget.selectedPhotographer['full_name']?.toString() ?? 'Photographer';
    final photographerImage =
        widget.selectedPhotographer['profile_image']?.toString() ?? '';
    final photographerSpecialties =
        widget.selectedPhotographer['specialties']?.toString() ?? '';
    final photographerPrice =
        _money(widget.selectedPhotographer['price_per_hour']);
    final photographerRating =
        _ratingValue(widget.selectedPhotographer['rating_avg'])
            .toStringAsFixed(1);

    final venueName = widget.selectedVenue['name']?.toString() ?? 'Venue';
    final venueImage = widget.selectedVenue['image_url']?.toString() ?? '';
    final venueLocation =
        widget.selectedVenue['location']?.toString() ?? '';
    final venuePrice = _money(widget.selectedVenue['price_per_hour']);
    final venueRating =
        _ratingValue(widget.selectedVenue['rating_avg']).toStringAsFixed(1);

    return ClientWebShell(
      selectedIndex: 0,
      child: Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text(
          'Review Full Session',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.12 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session Summary',
                  style: TextStyle(
                    fontFamily: 'Playfair_Display',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                ),
                const SizedBox(height: 12),
                _infoRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: _formatDate(widget.selectedDate),
                  primary: primary,
                  sub: sub,
                  text: text,
                ),
                _divider(border),
                _infoRow(
                  icon: Icons.access_time_rounded,
                  label: 'Time',
                  value: _formatTime(widget.selectedTime),
                  primary: primary,
                  sub: sub,
                  text: text,
                ),
                _divider(border),
                _infoRow(
                  icon: Icons.timelapse_rounded,
                  label: 'Duration',
                  value: _durationLabel(widget.durationHours),
                  primary: primary,
                  sub: sub,
                  text: text,
                ),
                _divider(border),
                _infoRow(
                  icon: Icons.camera_alt_outlined,
                  label: 'Session Type',
                  value: widget.sessionType,
                  primary: primary,
                  sub: sub,
                  text: text,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _selectionCard(
            title: 'Selected Photographer',
            imageUrl: photographerImage,
            titleText: photographerName,
            subtitleText: photographerSpecialties.isNotEmpty
                ? photographerSpecialties
                : 'No specialties',
            chips: [
              '\$$photographerPrice/hr',
              '⭐ $photographerRating',
            ],
            card: card,
            border: border,
            text: text,
            sub: sub,
            softSurface: softSurface,
            primary: primary,
            isDark: isDark,
          ),
          const SizedBox(height: 18),
          _selectionCard(
            title: 'Selected Venue',
            imageUrl: venueImage,
            titleText: venueName,
            subtitleText:
                venueLocation.isNotEmpty ? venueLocation : 'No location',
            chips: [
              '\$$venuePrice/hr',
              '⭐ $venueRating',
            ],
            card: card,
            border: border,
            text: text,
            sub: sub,
            softSurface: softSurface,
            primary: primary,
            isDark: isDark,
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: softSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'After creating the full session request, go to My Bookings to pay the photographer deposit and the venue deposit.',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      height: 1.6,
                      color: sub,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          14 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: bg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _submitting ? null : _confirmFullSession,
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
                        'Confirm Full Session',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primary.withOpacity(0.35)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _goToMyBookings,
                child: Text(
                  'View My Bookings',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primary.withOpacity(0.18)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Back',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color primary,
    required Color sub,
    required Color text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 16, color: primary),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              color: sub,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(Color border) {
    return Divider(
      color: border,
      thickness: 0.6,
      height: 10,
    );
  }

  Widget _selectionCard({
    required String title,
    required String imageUrl,
    required String titleText,
    required String subtitleText,
    required List<String> chips,
    required Color card,
    required Color border,
    required Color text,
    required Color sub,
    required Color softSurface,
    required Color primary,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.12 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Playfair_Display',
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _imagePlaceholder(softSurface, primary),
                      )
                    : _imagePlaceholder(softSurface, primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleText,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 11,
                        height: 1.5,
                        color: sub,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: chips
                          .map(
                            (chip) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: softSurface,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                chip,
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: text,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

 Widget _imagePlaceholder(Color softSurface, Color primary) {
  return Container(
    width: 76,
    height: 76,
    color: softSurface,
    child: Icon(
      Icons.image_outlined,
      color: primary,
    ),
  );
}}
    