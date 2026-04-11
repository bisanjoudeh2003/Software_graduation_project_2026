import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/message_service.dart';
import '../services/auth_service.dart';
import 'venue_owner_bottom_nav.dart';
import 'chat_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color lightGreen   = Color(0xFFC1D9CC);
  static const Color cream        = Color(0xFFF6F4EE);

  List conversations = [];
  List searchResults = [];
  bool loading       = true;
  bool searching     = false;
  int? currentUserId;
  Timer? _timer;
  Timer? _debounce;

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
    _timer = Timer.periodic(
        const Duration(seconds: 5), (_) {
      if (searchController.text.isEmpty) loadConversations();
    });
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future loadData() async {
    final user = await AuthService.getMe();
    currentUserId = user?["id"];
    await loadConversations();
  }

  Future loadConversations() async {
    final data = await MessageService.getUserConversations();
    if (mounted) setState(() { conversations = data; loading = false; });
  }

  void _onSearchChanged() {
    final q = searchController.text.trim();
    if (q.isEmpty) {
      setState(() { searchResults = []; searching = false; });
      return;
    }
    if (q.length < 2) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => searching = true);
      final results = await MessageService.searchUsers(q);
      if (mounted) setState(() { searchResults = results; searching = false; });
    });
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return "";
    try {
      final d = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      if (d.day == now.day) return DateFormat.jm().format(d);
      if (now.difference(d).inDays < 7) return DateFormat.E().format(d);
      return DateFormat("MM/dd").format(d);
    } catch (_) { return ""; }
  }

  @override
  Widget build(BuildContext context) {
    final showSearch = searchController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: cream,
      bottomNavigationBar: const VenueOwnerBottomNav(currentIndex: 3),
      body: CustomScrollView(
        slivers: [

          // ── HEADER ──
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text("Messages",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 26, fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        loading ? "" :
                            "${conversations.length} conversation${conversations.length != 1 ? 's' : ''}",
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TextField(
                          controller: searchController,
                          style: const TextStyle(
                              fontFamily: "Montserrat", fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Search people to message...",
                            hintStyle: TextStyle(fontFamily: "Montserrat",
                                color: Colors.grey.shade400, fontSize: 14),
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: primaryGreen, size: 20),
                            suffixIcon: showSearch
                                ? GestureDetector(
                                    onTap: () => searchController.clear(),
                                    child: const Icon(Icons.close_rounded,
                                        color: Colors.grey, size: 18))
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── SEARCH RESULTS ──
          if (showSearch)
            searching
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(
                        color: primaryGreen)))
                : searchResults.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_search_rounded,
                                  size: 56, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              const Text("No users found",
                                  style: TextStyle(fontFamily: "Montserrat",
                                      fontSize: 15, color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _userSearchCard(searchResults[i]),
                            childCount: searchResults.length,
                          ),
                        ),
                      )

          // ── CONVERSATIONS ──
          else if (loading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(
                    color: primaryGreen)))
          else if (conversations.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        color: lightGreen.withOpacity(.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chat_bubble_outline_rounded,
                          color: primaryGreen, size: 40),
                    ),
                    const SizedBox(height: 16),
                    const Text("No conversations yet",
                        style: TextStyle(fontFamily: "Montserrat",
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text("Clients will contact you here",
                        style: TextStyle(fontFamily: "Montserrat",
                            color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _conversationCard(conversations[i]),
                  childCount: conversations.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _userSearchCard(Map user) {
    final name  = user["full_name"]?.toString() ?? "";
    final image = user["profile_image"]?.toString() ?? "";
    final role  = user["role"]?.toString() ?? "";
    final id    = user["id"];

    return GestureDetector(
      onTap: () async {
        final conv = await MessageService.getOrCreateConversation(id);
        if (conv == null || !mounted) return;
        searchController.clear();
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conv["id"],
            otherUserId: id,
            otherUserName: name,
            otherUserImage: image.isNotEmpty ? image : null,
            currentUserId: currentUserId ?? 0,
            otherUserRole: role,
          ),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04),
              blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: lightGreen, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: image.isNotEmpty
                    ? Image.network(image, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _avatar(name))
                    : _avatar(name),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontFamily: "Montserrat",
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(
                    role == "venue_owner" ? "Venue Owner"
                        : role == "photographer" ? "Photographer"
                        : "Client",
                    style: const TextStyle(fontFamily: "Montserrat",
                        fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text("Message",
                  style: TextStyle(fontFamily: "Montserrat",
                      fontSize: 11, color: primaryGreen,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conversationCard(Map conv) {
    final otherName   = conv["other_user_name"]?.toString() ?? "User";
    final otherImage  = conv["other_user_image"]?.toString() ?? "";
    final otherRole   = conv["other_user_role"]?.toString() ?? "";
    final lastMsg     = conv["last_message"]?.toString() ?? "No messages yet";
    final lastTime    = _formatTime(conv["last_message_time"]?.toString());
    final unread      = int.tryParse(
        conv["unread_count"]?.toString() ?? "0") ?? 0;
    final convId      = conv["id"];
    final otherUserId = conv["other_user_id"];

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: convId,
            otherUserId: otherUserId,
            otherUserName: otherName,
            otherUserImage: otherImage,
            currentUserId: currentUserId ?? 0,
            otherUserRole: otherRole,
          ),
        ));
        loadConversations();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: lightGreen, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: otherImage.isNotEmpty
                        ? Image.network(otherImage, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _avatar(otherName))
                        : _avatar(otherName),
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      width: 18, height: 18,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          unread > 9 ? "9+" : "$unread",
                          style: const TextStyle(color: Colors.white,
                              fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(otherName,
                            style: TextStyle(fontFamily: "Montserrat",
                                fontWeight: unread > 0
                                    ? FontWeight.bold : FontWeight.w600,
                                fontSize: 15, color: Colors.black87)),
                      ),
                      Text(lastTime,
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 11,
                              color: unread > 0
                                  ? primaryGreen : Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (otherRole.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: lightGreen.withOpacity(.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        otherRole == "venue_owner" ? "Venue Owner"
                            : otherRole == "photographer"
                                ? "Photographer" : "Client",
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontSize: 10, color: primaryGreen,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  Text(lastMsg,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: "Montserrat",
                          fontSize: 12,
                          color: unread > 0 ? Colors.black87 : Colors.grey,
                          fontWeight: unread > 0
                              ? FontWeight.w500 : FontWeight.normal)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String name) => Container(
        color: lightGreen,
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : "U",
            style: const TextStyle(fontFamily: "Montserrat",
                color: primaryGreen, fontWeight: FontWeight.bold,
                fontSize: 20),
          ),
        ));
}