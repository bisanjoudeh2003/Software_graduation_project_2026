import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/message_service.dart';
import '../services/auth_service.dart';
import '../screens/chat_page.dart';

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
      _ClientPublicProfileWebPageState();
}

class _ClientPublicProfileWebPageState
    extends State<ClientPublicProfileWebPage> {
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
      } else {
        setState(() => loadingProfile = false);
      }
    } catch (e) {
      setState(() => loadingProfile = false);
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
      body: loadingProfile
          ? const Center(
              child: CircularProgressIndicator(color: primaryGreen),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHero(joinDate, bookingsCount),
                  Transform.translate(
                    offset: const Offset(0, -36),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1320),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  children: [
                                    _buildIdentityCard(joinDate, bookingsCount),
                                    const SizedBox(height: 20),
                                    _buildActionCard(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 8,
                                child: Column(
                                  children: [
                                    if (clientBio != null &&
                                        clientBio!.trim().isNotEmpty)
                                      _buildSectionCard(
                                        title: "About",
                                        child: Text(
                                          clientBio!,
                                          style: const TextStyle(
                                            fontFamily: "Montserrat",
                                            fontSize: 14,
                                            color: Colors.black87,
                                            height: 1.8,
                                          ),
                                        ),
                                      ),
                                    if (clientBio != null &&
                                        clientBio!.trim().isNotEmpty)
                                      const SizedBox(height: 20),
                                    if (clientLinks.isNotEmpty)
                                      _buildSectionCard(
                                        title: "Social Links",
                                        child: Wrap(
                                          spacing: 12,
                                          runSpacing: 12,
                                          children: clientLinks.entries
                                              .map((e) =>
                                                  _socialChip(e.key, e.value))
                                              .toList(),
                                        ),
                                      ),
                                    if (clientLinks.isNotEmpty)
                                      const SizedBox(height: 20),
                                    _buildSectionCard(
                                      title: "Client Information",
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
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHero(String joinDate, String bookingsCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 80),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.18),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(55),
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
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.clientName,
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.18),
                            borderRadius: BorderRadius.circular(20),
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
                                  fontWeight: FontWeight.w600,
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
                            fontSize: 14,
                            color: Colors.white.withOpacity(.82),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primaryGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: loadingMsg
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: primaryGreen,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text(
                        "Send Message",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: loadingMsg ? null : openChat,
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

  Widget _buildIdentityCard(String joinDate, String bookingsCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          _statTile(
            icon: Icons.calendar_today_rounded,
            value: "$bookingsCount",
            label: "Bookings",
          ),
          const SizedBox(height: 18),
          _statTile(
            icon: Icons.date_range_rounded,
            value: joinDate,
            label: "Member Since",
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Action",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Start a direct conversation with this client.",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              color: Colors.black54,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
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
                      width: 18,
                      height: 18,
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
                "Message Client",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: loadingMsg ? null : openChat,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          child,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(.25)),
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

  Widget _statTile({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: lightGreen.withOpacity(.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
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
                  const SizedBox(height: 2),
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
        color: Colors.grey.shade100,
      );

  Widget _avatar() => Container(
        color: lightGreen,
        child: const Icon(Icons.person, color: Colors.white, size: 44),
      );
}