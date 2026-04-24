import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/message_service.dart';
import '../services/auth_service.dart';
import 'chat_page.dart';

class ClientPublicProfilePage extends StatefulWidget {
  final int clientId;
  final String clientName;
  final String? clientImage;

  const ClientPublicProfilePage({
    super.key,
    required this.clientId,
    required this.clientName,
    this.clientImage,
  });

  @override
  State<ClientPublicProfilePage> createState() =>
      _ClientPublicProfilePageState();
}

class _ClientPublicProfilePageState extends State<ClientPublicProfilePage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF6F4EE);

  bool loadingMsg = false;
  bool loadingProfile = true;
  Map profileData = {};

  String? clientBio;
  Map<String, String> clientLinks = {};

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        setState(() => loadingProfile = false);
        return;
      }

      final res = await http.get(
        Uri.parse("${AuthService.apiBase}/users/${widget.clientId}/profile"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);

        final raw = decoded["social_links"];
        Map<String, dynamic> links = {};

        if (raw is String && raw.isNotEmpty) {
          try {
            links = Map<String, dynamic>.from(jsonDecode(raw));
          } catch (_) {}
        } else if (raw is Map) {
          links = Map<String, dynamic>.from(raw);
        }

        setState(() {
          profileData = decoded;
          clientBio = decoded["bio"]?.toString();
          clientLinks = links.map((k, v) => MapEntry(k, v.toString()));
          loadingProfile = false;
        });

        print("Profile loaded: $profileData");
      } else {
        setState(() => loadingProfile = false);
        print("Failed to load profile, status: ${res.statusCode}");
      }
    } catch (e) {
      setState(() => loadingProfile = false);
      print("Error loading profile: $e");
    }
    
  }

  String _formatJoinDate(String? d) {
    if (d == null || d.isEmpty) return "Unknown";
    final dt = DateTime.tryParse(d);
    if (dt == null) return "Unknown";
    return DateFormat("MMM yyyy").format(dt);
  }

  Future<void> openChat() async {
    setState(() => loadingMsg = true);

    final user = await AuthService.getMe();
    final currentUserId = user?["id"];

    if (currentUserId == null) {
      setState(() => loadingMsg = false);
      return;
    }

    final conv = await MessageService.getOrCreateConversation(widget.clientId);

    setState(() => loadingMsg = false);

    if (conv == null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conv["id"],
          otherUserId: widget.clientId,
          otherUserName: widget.clientName,
          otherUserImage: widget.clientImage,
          currentUserId: currentUserId,
          otherUserRole: "client",
        ),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    String finalUrl = url.trim();

    if (finalUrl.isEmpty) return;

    if (!finalUrl.startsWith("http://") && !finalUrl.startsWith("https://")) {
      finalUrl = "https://$finalUrl";
    }

    final uri = Uri.parse(finalUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawJoinDate = profileData["created_at"]?.toString();
    final joinDate = _formatJoinDate(rawJoinDate);
    final bookingsCount = profileData["bookings_count"]?.toString() ?? "0";

    return Scaffold(
      backgroundColor: cream,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryGreen, midGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.2),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(45),
                          child: widget.clientImage != null &&
                                  widget.clientImage!.isNotEmpty
                              ? Image.network(
                                  widget.clientImage!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _avatar(),
                                )
                              : _avatar(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.clientName,
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded,
                                color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text(
                              "Client",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!loadingProfile) ...[
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _statBadge(
                              bookingsCount,
                              "Bookings",
                              Icons.calendar_today_rounded,
                            ),
                            const SizedBox(width: 16),
                            _statBadge(
                              joinDate,
                              "Member Since",
                              Icons.date_range_rounded,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: loadingProfile
                ? const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: primaryGreen),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (clientBio != null && clientBio!.trim().isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "About",
                                  style: TextStyle(
                                    fontFamily: "Montserrat",
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  clientBio!,
                                  style: const TextStyle(
                                    fontFamily: "Montserrat",
                                    fontSize: 13,
                                    color: Colors.black87,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (clientLinks.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Social Links",
                                  style: TextStyle(
                                    fontFamily: "Montserrat",
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: clientLinks.entries
                                      .map((e) => _socialChip(e.key, e.value))
                                      .toList(),
                                ),
                              ],
                            ),
                          ),

                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 10),
                          child: Text(
                            "Client Info",
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
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
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: loadingMsg
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 20,
                                  ),
                            label: const Text(
                              "Send Message",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: loadingMsg ? null : openChat,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _socialChip(String platform, String url) {
    final Map<String, Map<String, dynamic>> config = {
      "instagram": {
        "icon": Icons.camera_alt_outlined,
        "color": const Color(0xFFE1306C)
      },
      "facebook": {
        "icon": Icons.facebook,
        "color": const Color(0xFF1877F2)
      },
      "twitter": {
        "icon": Icons.alternate_email,
        "color": const Color(0xFF1DA1F2)
      },
      "linkedin": {
        "icon": Icons.business_center,
        "color": const Color(0xFF0077B5)
      },
      "website": {
        "icon": Icons.language,
        "color": primaryGreen
      },
    };

    final meta = config[platform] ?? {"icon": Icons.link, "color": Colors.grey};
    final color = meta["color"] as Color;
    final icon = meta["icon"] as IconData;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openLink(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              platform[0].toUpperCase() + platform.substring(1),
              style: TextStyle(
                fontFamily: "Montserrat",
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBadge(String value, String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: primaryGreen, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _divider() => Divider(
        height: 1,
        indent: 56,
        endIndent: 20,
        color: Colors.grey.shade100,
      );

  Widget _avatar() => Container(
        color: lightGreen,
        child: const Icon(Icons.person, color: Colors.white, size: 40),
      );
}