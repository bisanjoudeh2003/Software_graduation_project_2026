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
  static const Color officialBlue = Color(0xFF2F80ED);

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

  bool _isAdminRole(String role) {
    return role == "admin";
  }

  bool _isAdminFromValue(dynamic value) {
    return value == 1 || value == true || value?.toString() == "1";
  }

  String _displayName({
    required String name,
    required String role,
  }) {
    return _isAdminRole(role) ? "Lensia Admin" : name;
  }

  String _roleLabel(String role) {
    if (role == "admin") return "Official Lensia Account";
    if (role == "warehouse_owner") return "Warehouse Owner";
    if (role == "venue_owner") return "Venue Owner";
    if (role == "photographer") return "Photographer";
    if (role == "client") return "Client";
    return "User";
  }

  IconData _roleIcon(String role) {
    if (role == "admin") return Icons.admin_panel_settings_outlined;
    if (role == "warehouse_owner") return Icons.warehouse_outlined;
    if (role == "venue_owner") return Icons.location_city_outlined;
    if (role == "photographer") return Icons.camera_alt_outlined;
    if (role == "client") return Icons.person_outline;
    return Icons.person_outline;
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
    final rawName = user["full_name"]?.toString() ?? "User";
    final image = user["profile_image"]?.toString() ?? "";
    final role = user["role"]?.toString() ?? "";

    final isAdmin = _isAdminRole(role);
    final name = _displayName(name: rawName, role: role);

    return GestureDetector(
      onTap: () => _openChatFromUser(user),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isAdmin ? officialBlue.withOpacity(.35) : Colors.grey.shade200,
            width: isAdmin ? 1.2 : 1,
          ),
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
              role: role,
              size: 48,
              isAdmin: isAdmin,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _userTextBlock(
                name: name,
                role: role,
                isAdmin: isAdmin,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: isAdmin ? officialBlue.withOpacity(.10) : paleGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Message",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 11,
                  color: isAdmin ? officialBlue : primaryGreen,
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
    final rawName = conv["other_user_name"]?.toString() ?? "User";
    final otherImage = conv["other_user_image"]?.toString() ?? "";
    final otherRole = conv["other_user_role"]?.toString() ?? "";

    final isAdmin = _isAdminRole(otherRole) ||
        _isAdminFromValue(conv["other_user_is_admin"]);

    final otherName = isAdmin ? "Lensia Admin" : rawName;

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
            color: isAdmin
                ? officialBlue.withOpacity(.35)
                : unread > 0
                    ? primaryGreen.withOpacity(.18)
                    : Colors.grey.shade200,
            width: isAdmin ? 1.2 : 1,
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
                  role: otherRole,
                  size: 54,
                  isAdmin: isAdmin,
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
                        child: _nameWithVerified(
                          name: otherName,
                          isAdmin: isAdmin,
                          unread: unread,
                        ),
                      ),
                      if (lastTime.isNotEmpty)
                        Text(
                          lastTime,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 10.5,
                            color: unread > 0 ? primaryGreen : Colors.black38,
                            fontWeight:
                                unread > 0 ? FontWeight.w900 : FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  _roleBadge(otherRole, isAdmin),
                  const SizedBox(height: 5),
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
            Icon(
              Icons.chevron_right_rounded,
              color: isAdmin ? officialBlue : primaryGreen,
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
    required String role,
    required double size,
    required bool isAdmin,
  }) {
    final cleanImage = image.trim();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isAdmin ? officialBlue.withOpacity(.8) : lightGreen,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size / 2),
            child: isAdmin
                ? _adminAvatar()
                : cleanImage.isNotEmpty && cleanImage != "null"
                    ? Image.network(
                        cleanImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _avatarPlaceholder(name),
                      )
                    : _avatarPlaceholder(name),
          ),
        ),
        if (isAdmin)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: officialBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _adminAvatar() {
    return Container(
      color: officialBlue.withOpacity(.12),
      child: const Center(
        child: Icon(
          Icons.admin_panel_settings_outlined,
          color: officialBlue,
          size: 24,
        ),
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

  Widget _userTextBlock({
    required String name,
    required String role,
    required bool isAdmin,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _nameWithVerified(
          name: name,
          isAdmin: isAdmin,
          unread: 0,
        ),
        const SizedBox(height: 4),
        _roleBadge(role, isAdmin),
      ],
    );
  }

  Widget _nameWithVerified({
    required String name,
    required bool isAdmin,
    required int unread,
  }) {
    return Row(
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: unread > 0 ? FontWeight.w900 : FontWeight.w800,
              fontSize: 15,
              color: primaryGreen,
            ),
          ),
        ),
        if (isAdmin) ...[
          const SizedBox(width: 5),
          const Icon(
            Icons.verified_rounded,
            color: officialBlue,
            size: 16,
          ),
        ],
      ],
    );
  }

  Widget _roleBadge(String role, bool isAdmin) {
    if (role.isEmpty && !isAdmin) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: isAdmin ? officialBlue.withOpacity(.10) : lightGreen.withOpacity(.5),
        borderRadius: BorderRadius.circular(10),
        border: isAdmin
            ? Border.all(color: officialBlue.withOpacity(.25))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAdmin ? Icons.shield_outlined : _roleIcon(role),
            size: 11,
            color: isAdmin ? officialBlue : primaryGreen,
          ),
          const SizedBox(width: 4),
          Text(
            _roleLabel(role),
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 10,
              color: isAdmin ? officialBlue : primaryGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}