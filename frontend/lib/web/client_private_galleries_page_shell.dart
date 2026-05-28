import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/booking_gallery_service.dart';
import '../web/client_web_shell.dart';
import '../web/client_session_gallery_page_web.dart';

const Color _primaryGreen = Color(0xFF2F4F46);
const Color _softGreen = Color(0xFF3E6B5C);
const Color _cream = Color(0xFFF6F4EE);
const Color _danger = Color(0xFFB84040);
const Color _blue = Color(0xFF2F6B9A);
const Color _gold = Color(0xFFC9A84C);

class ClientPrivateGalleriesPage extends StatefulWidget {
  const ClientPrivateGalleriesPage({super.key});

  @override
  State<ClientPrivateGalleriesPage> createState() =>
      _ClientPrivateGalleriesPageState();
}

class _ClientPrivateGalleriesPageState
    extends State<ClientPrivateGalleriesPage> {
  bool loading = true;
  String selectedStatus = "all";
  String searchQuery = "";

  List<Map<String, dynamic>> galleries = [];

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bg => Theme.of(context).scaffoldBackgroundColor;

  Color get _card => Theme.of(context).cardColor;

  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

  Color get _border =>
      _isDark ? Colors.white10 : _primaryGreen.withOpacity(0.10);

  Color get _surface => _isDark ? Colors.white.withOpacity(0.05) : _cream;

  @override
  void initState() {
    super.initState();
    _loadGalleries();
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  String _value(dynamic value, {String fallback = ""}) {
    final text = (value ?? "").toString().trim();
    if (text.isEmpty || text == "null") return fallback;
    return text;
  }

  String _prettyDate(dynamic raw) {
    final value = (raw ?? "").toString();

    if (value.trim().isEmpty || value == "null") return "Not set";

    try {
      return DateFormat("MMM d, yyyy").format(DateTime.parse(value));
    } catch (_) {
      return value;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case "draft":
        return "Preparing";
      case "delivered":
        return "Ready";
      case "revision_requested":
        return "Edits";
      case "finalized":
        return "Finalized";
      case "archived":
        return "Archived";
      default:
        return "Unknown";
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case "draft":
        return _gold;
      case "delivered":
        return _primaryGreen;
      case "revision_requested":
        return _blue;
      case "finalized":
        return _softGreen;
      case "archived":
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case "draft":
        return Icons.hourglass_top_rounded;
      case "delivered":
        return Icons.photo_library_rounded;
      case "revision_requested":
        return Icons.edit_note_rounded;
      case "finalized":
        return Icons.verified_rounded;
      case "archived":
        return Icons.archive_rounded;
      default:
        return Icons.photo_library_outlined;
    }
  }

  String _actionText(Map<String, dynamic> gallery) {
    final status = _value(gallery["status"], fallback: "draft");

    if (status == "draft") {
      return "Your gallery is being prepared.";
    }

    if (status == "delivered") {
      return "Ready to review.";
    }

    if (status == "revision_requested") {
      return "Edits are in progress.";
    }

    if (status == "finalized") {
      return "Final gallery is ready.";
    }

    if (status == "archived") {
      return "This gallery is archived.";
    }

    return "Open gallery.";
  }

  bool _canOpenGallery(Map<String, dynamic> gallery) {
    final status = _value(gallery["status"], fallback: "draft");
    return status != "draft" && status != "archived";
  }

  Future<void> _loadGalleries() async {
    setState(() => loading = true);

    try {
      final data = await BookingGalleryService.getClientGalleries();
      final raw = data["galleries"];

      if (!mounted) return;

      setState(() {
        if (raw is List) {
          galleries = raw.map((item) {
            return Map<String, dynamic>.from(item as Map);
          }).toList();
        } else {
          galleries = [];
        }

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        galleries = [];
        loading = false;
      });

      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
    }
  }

  List<Map<String, dynamic>> get _filteredGalleries {
    final query = searchQuery.trim().toLowerCase();

    return galleries.where((gallery) {
      final status = _value(gallery["status"]);

      if (selectedStatus != "all" && status != selectedStatus) {
        return false;
      }

      if (query.isEmpty) return true;

      final title = _value(gallery["title"]).toLowerCase();
      final photographer = _value(gallery["photographer_name"]).toLowerCase();
      final session = _value(gallery["session_type"]).toLowerCase();

      return title.contains(query) ||
          photographer.contains(query) ||
          session.contains(query);
    }).toList();
  }

  int _countByStatus(String status) {
    if (status == "all") return galleries.length;
    return galleries.where((g) => _value(g["status"]) == status).length;
  }

  int get _readyCount {
    return galleries.where((gallery) {
      final status = _value(gallery["status"]);
      return status == "delivered" ||
          status == "revision_requested" ||
          status == "finalized";
    }).length;
  }

  void _openGallery(Map<String, dynamic> gallery) async {
    if (!_canOpenGallery(gallery)) {
      _snack("This gallery is still being prepared.", _gold);
      return;
    }

    final bookingId = _toInt(gallery["booking_id"]);

    if (bookingId == 0) {
      _snack("Invalid booking id.", _danger);
      return;
    }

    try {
      final data = await BookingGalleryService.getGalleryByBooking(bookingId);

      final rawGallery = data["gallery"];
      final rawItems = data["items"];

      if (rawGallery is! Map) {
        _snack("Gallery data is not available.", _danger);
        return;
      }
final loadedGallery = {
  ...gallery,
  ...Map<String, dynamic>.from(rawGallery),
};

      final loadedItems = rawItems is List
          ? rawItems.map((item) {
              return Map<String, dynamic>.from(item as Map);
            }).toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClientSessionGalleryPageWeb(
            gallery: loadedGallery,
            items: loadedItems,
            photographerName:
                _value(gallery["photographer_name"], fallback: "Photographer"),
            sessionType: _value(gallery["session_type"], fallback: "Session"),
          ),
        ),
      );

      if (!mounted) return;
      _loadGalleries();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
    }
  }

  void _snack(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = loading
        ? const Center(
            child: CircularProgressIndicator(color: _primaryGreen),
          )
        : RefreshIndicator(
            color: _primaryGreen,
            onRefresh: _loadGalleries,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 26, 28, 46),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _webHeader(),
                            const SizedBox(height: 22),
                            _topOverview(),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final wide = constraints.maxWidth >= 850;

                                if (!wide) {
                                  return Column(
                                    children: [
                                      _searchBox(),
                                      const SizedBox(height: 12),
                                      _statusFilters(),
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: _searchBox(),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      flex: 7,
                                      child: Container(
                                        height: 56,
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _surface,
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          border: Border.all(color: _border),
                                        ),
                                        child: _statusFilters(),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            _listHeader(),
                            const SizedBox(height: 14),
                            if (_filteredGalleries.isEmpty)
                              _emptyState()
                            else
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final crossAxisCount =
                                      constraints.maxWidth >= 1120
                                          ? 3
                                          : constraints.maxWidth >= 760
                                              ? 2
                                              : 1;

                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _filteredGalleries.length,
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: 18,
                                      mainAxisSpacing: 18,
                                      childAspectRatio:
                                          crossAxisCount == 3 ? 1.35 : 1.42,
                                    ),
                                    itemBuilder: (_, index) {
                                      return _galleryTile(
                                        _filteredGalleries[index],
                                      );
                                    },
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );

    return ClientWebShell(
      selectedIndex: 0,
      child: Scaffold(
        backgroundColor: _bg,
        body: content,
      ),
    );
  }

  Widget _webHeader() {
    return Row(
      children: [
        _backButton(),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "My Galleries",
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: _text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Review your delivered galleries and final session files.",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _sub,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: "Refresh",
          onPressed: _loadGalleries,
          icon: const Icon(Icons.refresh_rounded),
          color: _primaryGreen,
        ),
      ],
    );
  }

  Widget _backButton() {
    return InkWell(
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
            if (!_isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: _primaryGreen,
        ),
      ),
    );
  }

  Widget _topOverview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          if (!_isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _primaryGreen.withOpacity(0.10),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.photo_library_outlined,
              color: _primaryGreen,
              size: 26,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Your private galleries",
                  style: TextStyle(
                    color: _text,
                    fontFamily: "Montserrat",
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${galleries.length} total • $_readyCount ready",
                  style: TextStyle(
                    color: _sub,
                    fontFamily: "Montserrat",
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _smallCounter(
            label: "Final",
            value: "${_countByStatus("finalized")}",
          ),
        ],
      ),
    );
  }

  Widget _smallCounter({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _primaryGreen,
              fontFamily: "Montserrat",
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return TextField(
      onChanged: (value) {
        setState(() => searchQuery = value);
      },
      style: TextStyle(
        color: _text,
        fontFamily: "Montserrat",
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: "Search photographer or session...",
        hintStyle: TextStyle(
          color: _sub,
          fontFamily: "Montserrat",
          fontSize: 12,
        ),
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _primaryGreen, width: 1.4),
        ),
      ),
    );
  }

  Widget _statusFilters() {
    final filters = [
      ["all", "All"],
      ["draft", "Preparing"],
      ["delivered", "Ready"],
      ["revision_requested", "Edits"],
      ["finalized", "Final"],
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final key = filter[0];
          final label = filter[1];
          final active = selectedStatus == key;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: active,
              selectedColor: _primaryGreen,
              backgroundColor: _surface,
              label: Text(label),
              labelStyle: TextStyle(
                color: active ? Colors.white : _text,
                fontFamily: "Montserrat",
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              onSelected: (_) {
                setState(() => selectedStatus = key);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _listHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            "Recent Galleries",
            style: TextStyle(
              color: _text,
              fontFamily: "Playfair_Display",
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          "${_filteredGalleries.length} shown",
          style: TextStyle(
            color: _sub,
            fontFamily: "Montserrat",
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 46,
            color: _sub.withOpacity(0.65),
          ),
          const SizedBox(height: 12),
          Text(
            "No galleries yet",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Your private session galleries will appear here after your photographer creates them.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _sub,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _galleryTile(Map<String, dynamic> gallery) {
    final status = _value(gallery["status"], fallback: "draft");
    final statusColor = _statusColor(status);

    final photographerName =
        _value(gallery["photographer_name"], fallback: "Photographer");
    final sessionType = _value(gallery["session_type"], fallback: "Session");
    final sessionDate = _prettyDate(gallery["session_date"]);
    final filesCount = _toInt(gallery["files_count"]);
    final canOpen = _canOpenGallery(gallery);

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: canOpen ? () => _openGallery(gallery) : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [
              if (!_isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.025),
                  blurRadius: 12,
                  offset: const Offset(0, 7),
                ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      _statusIcon(status),
                      color: statusColor,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          photographerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _text,
                            fontFamily: "Montserrat",
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$sessionType • $sessionDate",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _sub,
                            fontFamily: "Montserrat",
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(
                    label: _statusText(status),
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _infoItem(
                      icon: Icons.photo_library_outlined,
                      text: "$filesCount files",
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _infoItem(
                      icon: Icons.info_outline_rounded,
                      text: _actionText(gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: canOpen ? () => _openGallery(gallery) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _primaryGreen.withOpacity(0.22),
                    disabledForegroundColor: Colors.white70,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(
                    canOpen
                        ? Icons.open_in_new_rounded
                        : Icons.hourglass_top_rounded,
                    size: 17,
                  ),
                  label: Text(
                    canOpen ? "View Gallery" : "Being Prepared",
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _primaryGreen, size: 15),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _text,
                fontFamily: "Montserrat",
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: "Montserrat",
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}