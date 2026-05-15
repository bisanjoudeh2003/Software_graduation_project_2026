import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/message_service.dart';
import '../services/auth_service.dart';

import 'chat_page.dart';

class WarehouseMessagesPage extends StatefulWidget {
  const WarehouseMessagesPage({super.key});

  @override
  State<WarehouseMessagesPage> createState() => _WarehouseMessagesPageState();
}

class _WarehouseMessagesPageState extends State<WarehouseMessagesPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF7F3EA);
  static const Color cardWhite = Colors.white;
  static const Color softRed = Color(0xFFD9534F);

  List conversations = [];
  List searchResults = [];

  bool loading = true;
  bool searching = false;

  int? currentUserId;

  Timer? _timer;
  Timer? _debounce;

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    loadData();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (searchController.text.trim().isEmpty) {
        loadConversations(showLoader: false);
      }
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

  Future<void> loadData() async {
    try {
      final user = await AuthService.getMe();
      currentUserId = int.tryParse(user?["id"]?.toString() ?? "");

      await loadConversations();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
        conversations = [];
      });
    }
  }

  Future<void> loadConversations({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => loading = true);
    }

    try {
      final data = await MessageService.getUserConversations();

      if (!mounted) return;

      setState(() {
        conversations = data;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        conversations = [];
        loading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        searching = false;
      });
      return;
    }

    if (query.length < 2) return;

    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;

      setState(() => searching = true);

      try {
        final results = await MessageService.searchUsers(query);

        if (!mounted) return;

        setState(() {
          searchResults = results;
          searching = false;
        });
      } catch (_) {
        if (!mounted) return;

        setState(() {
          searchResults = [];
          searching = false;
        });
      }
    });
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == "null") return "";

    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();

      if (date.day == now.day &&
          date.month == now.month &&
          date.year == now.year) {
        return DateFormat.jm().format(date);
      }

      if (now.difference(date).inDays < 7) {
        return DateFormat.E().format(date);
      }

      return DateFormat("MM/dd").format(date);
    } catch (_) {
      return "";
    }
  }

  String _roleLabel(String role) {
    if (role == "warehouse_owner") return "Warehouse Owner";
    if (role == "venue_owner") return "Venue Owner";
    if (role == "photographer") return "Photographer";
    if (role == "client") return "Client";
    if (role == "admin") return "Admin";
    return "User";
  }

  Future<void> _openChatFromUser(Map user) async {
    final id = user["id"];
    final name = user["full_name"]?.toString() ?? "User";
    final image = user["profile_image"]?.toString() ?? "";
    final role = user["role"]?.toString() ?? "";

    try {
      final conv = await MessageService.getOrCreateConversation(id);

      if (conv == null || !mounted) return;

      searchController.clear();

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conv["id"],
            otherUserId: id,
            otherUserName: name,
            otherUserImage: image.isNotEmpty && image != "null" ? image : null,
            currentUserId: currentUserId ?? 0,
            otherUserRole: role,
          ),
        ),
      );

      await loadConversations(showLoader: false);
    } catch (_) {}
  }

  Future<void> _openChatFromConversation(Map conv) async {
    final convId = conv["id"];
    final otherUserId = conv["other_user_id"];
    final otherName = conv["other_user_name"]?.toString() ?? "User";
    final otherImage = conv["other_user_image"]?.toString() ?? "";
    final otherRole = conv["other_user_role"]?.toString() ?? "";

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: convId,
          otherUserId: otherUserId,
          otherUserName: otherName,
          otherUserImage:
              otherImage.isNotEmpty && otherImage != "null" ? otherImage : null,
          currentUserId: currentUserId ?? 0,
          otherUserRole: otherRole,
        ),
      ),
    );

    await loadConversations(showLoader: false);
  }

  @override
  Widget build(BuildContext context) {
    final showSearch = searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: cream,
      body: RefreshIndicator(
        color: primaryGreen,
        onRefresh: () => loadConversations(showLoader: false),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),

            if (showSearch)
              if (searching)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: primaryGreen),
                  ),
                )
              else if (searchResults.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptySearchState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final user =
                            Map<String, dynamic>.from(searchResults[index]);

                        return _userSearchCard(user);
                      },
                      childCount: searchResults.length,
                    ),
                  ),
                )
            else if (loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: primaryGreen),
                ),
              )
            else if (conversations.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyConversationState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final conv =
                          Map<String, dynamic>.from(conversations[index]);

                      return _conversationCard(conv);
                    },
                    childCount: conversations.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final showSearch = searchController.text.trim().isNotEmpty;

    return Container(
      width: double.infinity,
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
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                "Messages",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                loading
                    ? ""
                    : "${conversations.length} conversation${conversations.length == 1 ? "" : "s"}",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 14,
                  color: Colors.white.withOpacity(.75),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: searchController,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 14,
                    color: primaryGreen,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: "Search people to message...",
                    hintStyle: const TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.black38,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: primaryGreen,
                      size: 21,
                    ),
                    suffixIcon: showSearch
                        ? IconButton(
                            onPressed: () => searchController.clear(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.black45,
                              size: 20,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 6,
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

  Widget _emptyConversationState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: primaryGreen,
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "No conversations yet",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Clients and photographers can message you about products and orders here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black38,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptySearchState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_search_rounded,
                color: primaryGreen,
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "No users found",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Try searching by another name or email.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black38,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userSearchCard(Map user) {
    final name = user["full_name"]?.toString() ?? "User";
    final image = user["profile_image"]?.toString() ?? "";
    final role = user["role"]?.toString() ?? "";
    final id = user["id"];

    return GestureDetector(
      onTap: () => _openChatFromUser(user),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.045),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _avatarCircle(
              image: image,
              name: name,
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _roleLabel(role),
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 11,
                      color: Colors.black45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: paleGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Message",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 11,
                  color: primaryGreen,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conversationCard(Map conv) {
    final otherName = conv["other_user_name"]?.toString() ?? "User";
    final otherImage = conv["other_user_image"]?.toString() ?? "";
    final otherRole = conv["other_user_role"]?.toString() ?? "";
    final lastMessage = conv["last_message"]?.toString() ?? "No messages yet";
    final lastTime = _formatTime(conv["last_message_time"]?.toString());
    final unread = int.tryParse(conv["unread_count"]?.toString() ?? "0") ?? 0;

    return GestureDetector(
      onTap: () => _openChatFromConversation(conv),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread > 0 ? paleGreen : cardWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: unread > 0
                ? primaryGreen.withOpacity(.18)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(unread > 0 ? .06 : .04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _avatarCircle(
                  image: otherImage,
                  name: otherName,
                  size: 54,
                ),
                if (unread > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 19,
                        minHeight: 19,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: const BoxDecoration(
                        color: softRed,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          unread > 9 ? "9+" : unread.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontWeight:
                                unread > 0 ? FontWeight.w900 : FontWeight.w800,
                            fontSize: 15,
                            color: primaryGreen,
                          ),
                        ),
                      ),
                      if (lastTime.isNotEmpty)
                        Text(
                          lastTime,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 10.5,
                            color:
                                unread > 0 ? primaryGreen : Colors.black38,
                            fontWeight:
                                unread > 0 ? FontWeight.w900 : FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  if (otherRole.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: lightGreen.withOpacity(.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _roleLabel(otherRole),
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 10,
                          color: primaryGreen,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      color: unread > 0 ? Colors.black87 : Colors.black45,
                      fontWeight:
                          unread > 0 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: primaryGreen,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarCircle({
    required String image,
    required String name,
    required double size,
  }) {
    final cleanImage = image.trim();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: lightGreen,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: cleanImage.isNotEmpty && cleanImage != "null"
            ? Image.network(
                cleanImage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarPlaceholder(name),
              )
            : _avatarPlaceholder(name),
      ),
    );
  }

  Widget _avatarPlaceholder(String name) {
    return Container(
      color: paleGreen,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "U",
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: primaryGreen,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}