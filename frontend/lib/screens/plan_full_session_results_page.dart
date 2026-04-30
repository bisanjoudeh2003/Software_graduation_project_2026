import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/photographer_service.dart';
import '../services/venue_service.dart';
import 'photographer_public_profile_page.dart';
import 'client_venue_details_page.dart';
import 'plan_full_session_review_page.dart';

class PlanFullSessionResultsPage extends StatefulWidget {
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final double durationHours;
  final String sessionType;

  const PlanFullSessionResultsPage({
    super.key,
    required this.selectedDate,
    required this.selectedTime,
    required this.durationHours,
    required this.sessionType,
  });

  @override
  State<PlanFullSessionResultsPage> createState() =>
      _PlanFullSessionResultsPageState();
}

class _PlanFullSessionResultsPageState
    extends State<PlanFullSessionResultsPage> {
  bool _loading = true;
  bool _loadingPhotographers = true;
  bool _loadingVenues = true;

  List<dynamic> _photographers = [];
  List<dynamic> _venues = [];

  String? _errorMessage;

  Map<String, dynamic>? _selectedPhotographer;
  Map<String, dynamic>? _selectedVenue;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _card => Theme.of(context).cardColor;
  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get _primary => Theme.of(context).colorScheme.primary;
  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF7F4EC);
  Color get _border => _isDark ? Colors.white10 : Colors.grey.shade200;
  Color get _successGreen => const Color(0xFF2E7D5A);

  bool get _canContinue =>
      _selectedPhotographer != null && _selectedVenue != null;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  String _apiDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _apiTime(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm:00';
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEE, MMM d, yyyy').format(date);
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt);
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

  Future<void> _loadResults() async {
    setState(() {
      _loading = true;
      _loadingPhotographers = true;
      _loadingVenues = true;
      _errorMessage = null;
    });

    final date = _apiDate(widget.selectedDate);
    final time = _apiTime(widget.selectedTime);

    try {
      final futures = await Future.wait([
        PhotographerService.getAvailablePhotographersForSession(
          date: date,
          time: time,
          durationHours: widget.durationHours,
          sessionType: widget.sessionType,
        ),
        VenueService.getAvailableVenuesForSession(
          date: date,
          time: time,
          durationHours: widget.durationHours,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _photographers = futures[0];
        _venues = futures[1];
        _loading = false;
        _loadingPhotographers = false;
        _loadingVenues = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _loadingPhotographers = false;
        _loadingVenues = false;
        _errorMessage = 'Failed to load available options. Please try again.';
      });
    }
  }
void _continueNext() {
  if (_selectedPhotographer == null || _selectedVenue == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please select both a photographer and a venue to continue.',
        ),
      ),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PlanFullSessionReviewPage(
        selectedDate: widget.selectedDate,
        selectedTime: widget.selectedTime,
        durationHours: widget.durationHours,
        sessionType: widget.sessionType,
        selectedPhotographer:
            Map<String, dynamic>.from(_selectedPhotographer!),
        selectedVenue: Map<String, dynamic>.from(_selectedVenue!),
      ),
    ),
  );
}

  void _openPhotographerProfile(Map<String, dynamic> photographer) {
    final dynamic rawId = photographer['user_id'] ?? photographer['id'];

    final int? userId =
        rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

    if (userId == null || userId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open photographer portfolio.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotographerPublicProfilePage(
          photographerId: userId,
          photographerName:
              photographer['full_name']?.toString() ?? 'Photographer',
          photographerImage: photographer['profile_image']?.toString(),
        ),
      ),
    );
  }

  void _openVenueDetails(Map<String, dynamic> venue) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientVenueDetailsPage(venue: venue),
      ),
    );
  }

  Widget _buildTopSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.12 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Session',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow(
            Icons.calendar_today_rounded,
            'Date',
            _formatDate(widget.selectedDate),
          ),
          _divider(),
          _summaryRow(
            Icons.access_time_rounded,
            'Time',
            _formatTime(widget.selectedTime),
          ),
          _divider(),
          _summaryRow(
            Icons.timelapse_rounded,
            'Duration',
            _durationLabel(widget.durationHours),
          ),
          _divider(),
          _summaryRow(
            Icons.camera_alt_outlined,
            'Session Type',
            widget.sessionType,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _primary),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              color: _sub,
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
                color: _text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      color: _border,
      thickness: 0.6,
      height: 10,
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Playfair_Display',
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: _text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 12,
            height: 1.5,
            color: _sub,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotographerCard(Map<String, dynamic> photographer) {
    final id = photographer['photographer_id'];
    final selected =
        _selectedPhotographer != null &&
        _selectedPhotographer!['photographer_id'] == id;

    final image = photographer['profile_image']?.toString() ?? '';
    final name = photographer['full_name']?.toString() ?? 'Photographer';
    final specialties = photographer['specialties']?.toString() ?? '';
    final price = _money(photographer['price_per_hour']);
    final rating = _ratingValue(photographer['rating_avg']).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: selected ? _softSurface : _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? _primary : _border,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.12 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _primary.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(29),
                    child: image.isNotEmpty
                        ? Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _avatarPlaceholder(),
                          )
                        : _avatarPlaceholder(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specialties.isNotEmpty ? specialties : 'No specialties',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          height: 1.5,
                          color: _sub,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF2E7D5A),
                    size: 22,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _miniInfo(
                  Icons.payments_outlined,
                  '\$$price/hr',
                ),
                const SizedBox(width: 10),
                _miniInfo(
                  Icons.star_rounded,
                  rating,
                  iconColor: Colors.amber,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _primary.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _openPhotographerProfile(photographer),
                    child: const Text(
                      'View Portfolio',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selected ? _successGreen : _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedPhotographer = photographer;
                      });
                    },
                    child: Text(
                      selected ? 'Selected' : 'Select',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (selected) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.withOpacity(0.35)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedPhotographer = null;
                    });
                  },
                  child: const Text(
                    'Remove Photographer',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVenueCard(Map<String, dynamic> venue) {
    final id = venue['id'];
    final selected = _selectedVenue != null && _selectedVenue!['id'] == id;

    final image = venue['image_url']?.toString() ?? '';
    final name = venue['name']?.toString() ?? 'Venue';
    final location = venue['location']?.toString() ?? '';
    final price = _money(venue['price_per_hour']);
    final rating = _ratingValue(venue['rating_avg']).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: selected ? _softSurface : _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? _primary : _border,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.12 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: image.isNotEmpty
                      ? Image.network(
                          image,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location.isNotEmpty ? location : 'No location',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          height: 1.5,
                          color: _sub,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _miniInfo(
                            Icons.payments_outlined,
                            '\$$price/hr',
                          ),
                          const SizedBox(width: 10),
                          _miniInfo(
                            Icons.star_rounded,
                            rating,
                            iconColor: Colors.amber,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF2E7D5A),
                    size: 22,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _primary.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _openVenueDetails(venue),
                    child: const Text(
                      'View Venue',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selected ? _successGreen : _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedVenue = venue;
                      });
                    },
                    child: Text(
                      selected ? 'Selected' : 'Select',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedVenue != null && selected) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.withOpacity(0.35)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedVenue = null;
                    });
                  },
                  child: const Text(
                    'Remove Venue',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniInfo(IconData icon, String value, {Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor ?? _primary),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBox({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: _sub),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              height: 1.6,
              color: _sub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 28,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              height: 1.6,
              color: _text,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _loadResults,
            child: const Text(
              'Try Again',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: _softSurface,
      child: Icon(
        Icons.person_rounded,
        color: _primary,
        size: 28,
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 72,
      height: 72,
      color: _softSurface,
      child: Icon(
        Icons.image_outlined,
        color: _primary,
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: _bg,
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
          if (_selectedPhotographer != null || _selectedVenue != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _softSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Summary',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Photographer: ${_selectedPhotographer?['full_name'] ?? 'Not selected'}',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      color: _sub,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Venue: ${_selectedVenue?['name'] ?? 'Not selected'}',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      color: _sub,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A full session requires both a photographer and a venue.',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _primary,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _canContinue
                    ? _primary
                    : _sub.withOpacity(0.3),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _canContinue ? _continueNext : null,
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: _primary),
      );
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _buildErrorBox(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadResults,
      color: _primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        children: [
          _buildTopSummary(),
          const SizedBox(height: 22),
          _sectionTitle(
            'Available Photographers',
            'Choose one photographer available for your selected date, time, duration, and session type.',
          ),
          const SizedBox(height: 12),
          if (_loadingPhotographers)
            const Center(child: CircularProgressIndicator())
          else if (_photographers.isEmpty)
            _buildEmptyBox(
              title: 'No photographers found',
              subtitle:
                  'No photographers are currently available for this selected session time and type.',
              icon: Icons.camera_alt_outlined,
            )
          else
            ..._photographers.map(
              (p) => _buildPhotographerCard(Map<String, dynamic>.from(p)),
            ),
          const SizedBox(height: 24),
          _sectionTitle(
            'Available Venues',
            'Choose one venue available for the same selected date, time, and duration. Venue selection is required for a full session.',
          ),
          const SizedBox(height: 12),
          if (_loadingVenues)
            const Center(child: CircularProgressIndicator())
          else if (_venues.isEmpty)
            _buildEmptyBox(
              title: 'No venues found',
              subtitle:
                  'No venues are currently available for this selected session time. Please change the date or time to continue with a full session.',
              icon: Icons.location_city_outlined,
            )
          else
            ..._venues.map(
              (v) => _buildVenueCard(Map<String, dynamic>.from(v)),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Available Options',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _buildContent(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
}