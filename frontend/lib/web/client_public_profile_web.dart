import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';

class ClientPublicProfileWebPage extends StatefulWidget {
  final int clientId;
  final String clientName;
  final String? clientImage;

  const ClientPublicProfileWebPage({
    super.key,
    required this.clientId,
    required this.clientName,
    this.clientImage,
  });

  @override
  State<ClientPublicProfileWebPage> createState() =>
      _ClientPublicProfileVenueWebPageState();
}

class _ClientPublicProfileVenueWebPageState
    extends State<ClientPublicProfileWebPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF6F4EE);

  bool loadingProfile = true;
  Map profileData = {};

  String? clientBio;
  Map<String, String> clientLinks = {};

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bg => _isDark ? Theme.of(context).scaffoldBackgroundColor : cream;

  Color get _card => Theme.of(context).cardColor;

  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

  Color get _border =>
      _isDark ? Colors.white10 : primaryGreen.withOpacity(0.08);

  Future<void> loadProfile() async {
    try {
      final token = await AuthService.getToken();

      if (token == null) {
        if (!mounted) return;
        setState(() => loadingProfile = false);
        return;
      }

      final res = await http.get(
        Uri.parse("${AuthService.apiBase}/users/${widget.clientId}/profile"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);

        final raw = decoded["social_links"];
        Map<String, dynamic> links = {};

        if (raw is String && raw.isNotEmpty && raw != "null") {
          try {
            links = Map<String, dynamic>.from(jsonDecode(raw));
          } catch (_) {
            links = {};
          }
        } else if (raw is Map) {
          links = Map<String, dynamic>.from(raw);
        }

        setState(() {
          profileData = decoded;
          clientBio = decoded["bio"]?.toString();
          clientLinks = links.map((key, value) {
            return MapEntry(key.toString(), value.toString());
          });
          loadingProfile = false;
        });
      } else {
        setState(() => loadingProfile = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingProfile = false);
    }
  }

  String _formatJoinDate(String? d) {
    if (d == null || d.isEmpty || d == "null") return "Unknown";

    final dt = DateTime.tryParse(d);

    if (dt == null) return "Unknown";

    return DateFormat("MMM yyyy").format(dt);
  }

  Future<void> _openLink(String url) async {
    String finalUrl = url.trim();

    if (finalUrl.isEmpty) return;

    if (!finalUrl.startsWith("http://") &&
        !finalUrl.startsWith("https://")) {
      finalUrl = "https://$finalUrl";
    }

    final uri = Uri.parse(finalUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawJoinDate = profileData["created_at"]?.toString();
    final joinDate = _formatJoinDate(rawJoinDate);
    final bookingsCount = profileData["bookings_count"]?.toString() ?? "0";

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: loadingProfile
            ? const Center(
                child: CircularProgressIndicator(color: primaryGreen),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
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
                                      joinDate: joinDate,
                                      bookingsCount: bookingsCount,
                                    ),
                                    const SizedBox(height: 18),
                                    _statsGrid(
                                      joinDate: joinDate,
                                      bookingsCount: bookingsCount,
                                    ),
                                    const SizedBox(height: 18),
                                    if (clientBio != null &&
                                        clientBio!.trim().isNotEmpty)
                                      _aboutCard(),
                                    if (clientBio != null &&
                                        clientBio!.trim().isNotEmpty)
                                      const SizedBox(height: 18),
                                    if (clientLinks.isNotEmpty) _linksCard(),
                                    if (clientLinks.isNotEmpty)
                                      const SizedBox(height: 18),
                                    _infoCard(
                                      joinDate: joinDate,
                                      bookingsCount: bookingsCount,
                                    ),
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
                                          joinDate: joinDate,
                                          bookingsCount: bookingsCount,
                                        ),
                                        const SizedBox(height: 18),
                                        _statsGrid(
                                          joinDate: joinDate,
                                          bookingsCount: bookingsCount,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: ListView(
                                      children: [
                                        if (clientBio != null &&
                                            clientBio!.trim().isNotEmpty)
                                          _aboutCard(),
                                        if (clientBio != null &&
                                            clientBio!.trim().isNotEmpty)
                                          const SizedBox(height: 18),
                                        if (clientLinks.isNotEmpty) _linksCard(),
                                        if (clientLinks.isNotEmpty)
                                          const SizedBox(height: 18),
                                        _infoCard(
                                          joinDate: joinDate,
                                          bookingsCount: bookingsCount,
                                        ),
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
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: primaryGreen,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Client Profile",
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  color: _text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "View client details, booking history, bio, and public links.",
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
        const SizedBox(width: 12),
        IconButton(
          onPressed: loadProfile,
          icon: const Icon(Icons.refresh_rounded),
          color: primaryGreen,
          tooltip: "Refresh",
        ),
      ],
    );
  }

  Widget _heroCard({
    required String joinDate,
    required String bookingsCount,
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
          _clientAvatar(size: 92),
          const SizedBox(height: 18),
          Text(
            widget.clientName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.16),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(.20)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: Colors.white,
                  size: 15,
                ),
                SizedBox(width: 6),
                Text(
                  "Client",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "Member since $joinDate • $bookingsCount booking${bookingsCount != '1' ? 's' : ''}",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              color: Colors.white.withOpacity(.78),
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid({
    required String joinDate,
    required String bookingsCount,
  }) {
    final stats = [
      _ProfileStat(
        icon: Icons.calendar_today_rounded,
        label: "Bookings",
        value: bookingsCount,
        color: primaryGreen,
      ),
      _ProfileStat(
        icon: Icons.date_range_rounded,
        label: "Member Since",
        value: joinDate,
        color: const Color(0xFFD4A853),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        mainAxisSpacing: 14,
        childAspectRatio: 3.7,
      ),
      itemBuilder: (_, index) {
        final stat = stats[index];

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: stat.color.withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: stat.color.withOpacity(.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  stat.icon,
                  color: stat.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: stat.color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stat.label,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _sub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _aboutCard() {
    return _sectionCard(
      icon: Icons.info_outline_rounded,
      title: "About",
      subtitle: "Client profile bio and personal description.",
      child: Text(
        clientBio!,
        style: TextStyle(
          fontFamily: "Montserrat",
          fontSize: 14,
          color: _text,
          height: 1.8,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _linksCard() {
    return _sectionCard(
      icon: Icons.link_rounded,
      title: "Social Links",
      subtitle: "Public links added by the client.",
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: clientLinks.entries.map((entry) {
          return _socialChip(entry.key, entry.value);
        }).toList(),
      ),
    );
  }

  Widget _infoCard({
    required String joinDate,
    required String bookingsCount,
  }) {
    return _sectionCard(
      icon: Icons.badge_outlined,
      title: "Client Information",
      subtitle: "Main profile details for this client.",
      child: Column(
        children: [
          _infoRow(
            Icons.person_outline_rounded,
            "Full Name",
            widget.clientName,
          ),
          _divider(),
          _infoRow(
            Icons.calendar_today_rounded,
            "Bookings",
            "$bookingsCount booking${bookingsCount != '1' ? 's' : ''}",
          ),
          _divider(),
          _infoRow(
            Icons.date_range_rounded,
            "Member Since",
            joinDate,
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(28),
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
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: primaryGreen,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: _sub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }

  Widget _socialChip(String platform, String url) {
    final normalizedPlatform = platform.toLowerCase();

    final Map<String, Map<String, dynamic>> config = {
      "instagram": {
        "icon": Icons.camera_alt_outlined,
        "color": const Color(0xFFE1306C),
      },
      "facebook": {
        "icon": Icons.facebook,
        "color": const Color(0xFF1877F2),
      },
      "twitter": {
        "icon": Icons.alternate_email,
        "color": const Color(0xFF1DA1F2),
      },
      "linkedin": {
        "icon": Icons.business_center,
        "color": const Color(0xFF0077B5),
      },
      "website": {
        "icon": Icons.language,
        "color": primaryGreen,
      },
    };

    final meta = config[normalizedPlatform] ??
        {
          "icon": Icons.link,
          "color": Colors.grey,
        };

    final color = meta["color"] as Color;
    final icon = meta["icon"] as IconData;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openLink(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 7),
            Text(
              normalizedPlatform.isEmpty
                  ? "Link"
                  : normalizedPlatform[0].toUpperCase() +
                      normalizedPlatform.substring(1),
              style: TextStyle(
                fontFamily: "Montserrat",
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 10,
                    letterSpacing: .8,
                    color: _sub,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: _border,
    );
  }

  Widget _clientAvatar({
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: widget.clientImage != null &&
                widget.clientImage!.trim().isNotEmpty &&
                widget.clientImage != "null"
            ? Image.network(
                widget.clientImage!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatar(),
              )
            : _avatar(),
      ),
    );
  }

  Widget _avatar() {
    return Container(
      color: lightGreen,
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 44,
      ),
    );
  }
}

class _ProfileStat {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ProfileStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}