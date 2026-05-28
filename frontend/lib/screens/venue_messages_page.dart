import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/message_service.dart';
import '../services/auth_service.dart';
import 'chat_page.dart';
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF6F4EE);
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
    final user = await AuthService.getMe();
    currentUserId = int.tryParse(user?["id"]?.toString() ?? "");
    await loadConversations();
  }

  Future<void> loadConversations({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => loading = true);
    }

    final data = await MessageService.getUserConversations();

    if (!mounted) return;

    setState(() {
      conversations = data;
      loading = false;
    });
  }

  void _onSearchChanged() {
    final q = searchController.text.trim();

    if (q.isEmpty) {
      setState(() {
        searchResults = [];
        searching = false;
      });
      return;
    }

    if (q.length < 2) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;

      setState(() => searching = true);

      final results = await MessageService.searchUsers(q);

      if (!mounted) return;

      setState(() {
        searchResults = results;
        searching = false;
      });
    });
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == "null") return "";

    try {
      final d = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();

      if (d.day == now.day && d.month == now.month && d.year == now.year) {
        return DateFormat.jm().format(d);
      }

      if (now.difference(d).inDays < 7) {
        return DateFormat.E().format(d);
      }

      return DateFormat("MM/dd").format(d);
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
    if (role == "venue_owner") return "Venue Owner";
    if (role == "photographer") return "Photographer";
    if (role == "warehouse_owner") return "Warehouse Owner";
    if (role == "client") return "Client";
    return "User";
  }

  IconData _roleIcon(String role) {
    if (role == "admin") return Icons.admin_panel_settings_outlined;
    if (role == "venue_owner") return Icons.location_city_outlined;
    if (role == "photographer") return Icons.camera_alt_outlined;
    if (role == "warehouse_owner") return Icons.warehouse_outlined;
    return Icons.person_outline;
  }

  Future<void> _openChatFromUser(Map user) async {
    final id = user["id"];
    final name = user["full_name"]?.toString() ?? "User";
    final image = user["profile_image"]?.toString() ?? "";
    final role = user["role"]?.toString() ?? "";

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
            SliverToBoxAdapter(child: _header(showSearch)),

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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _userSearchCard(
                        Map<String, dynamic>.from(searchResults[i]),
                      ),
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _conversationCard(
                      Map<String, dynamic>.from(conversations[i]),
                    ),
                    childCount: conversations.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(bool showSearch) {
    return Container(
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
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Messages",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                loading
                    ? ""
                    : "${conversations.length} conversation${conversations.length != 1 ? 's' : ''}",
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 13,
                  color: Colors.white70,
                ),
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
                    fontFamily: "Montserrat",
                    fontSize: 14,
                    color: primaryGreen,
                  ),
                  decoration: InputDecoration(
                    hintText: "Search people to message...",
                    hintStyle: TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: primaryGreen,
                      size: 20,
                    ),
                    suffixIcon: showSearch
                        ? GestureDetector(
                            onTap: () => searchController.clear(),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.grey,
                              size: 18,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 4,
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

  Widget _emptySearchState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_search_rounded,
            size: 56,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          const Text(
            "No users found",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 15,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyConversationState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: lightGreen.withOpacity(.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: primaryGreen,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No conversations yet",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Search for someone to start chatting",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _userSearchCard(Map user) {
    final name = user["full_name"]?.toString() ?? "User";
    final image = user["profile_image"]?.toString() ?? "";
    final role = user["role"]?.toString() ?? "";

    final isAdmin = _isAdminRole(role);
    final displayName = _displayName(name: name, role: role);

    return GestureDetector(
      onTap: () => _openChatFromUser(user),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isAdmin
              ? Border.all(
                  color: officialBlue.withOpacity(.35),
                  width: 1.2,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            _avatarCircle(
              name: displayName,
              image: image,
              role: role,
              size: 46,
              isAdmin: isAdmin,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _userTextBlock(
                name: displayName,
                role: role,
                isAdmin: isAdmin,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isAdmin
                    ? officialBlue.withOpacity(.10)
                    : lightGreen.withOpacity(.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "Message",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 11,
                  color: isAdmin ? officialBlue : primaryGreen,
                  fontWeight: FontWeight.w700,
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

    final lastMsg = conv["last_message"]?.toString() ?? "No messages yet";
    final lastTime = _formatTime(conv["last_message_time"]?.toString());
    final unread = int.tryParse(conv["unread_count"]?.toString() ?? "0") ?? 0;

    return GestureDetector(
      onTap: () => _openChatFromConversation(conv),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread > 0 ? lightGreen.withOpacity(.28) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isAdmin
              ? Border.all(
                  color: officialBlue.withOpacity(.35),
                  width: 1.2,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _avatarCircle(
                  name: otherName,
                  image: otherImage,
                  role: otherRole,
                  size: 52,
                  isAdmin: isAdmin,
                ),
                if (unread > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          unread > 9 ? "9+" : "$unread",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
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
                        child: _nameWithVerified(
                          name: otherName,
                          isAdmin: isAdmin,
                          unread: unread,
                        ),
                      ),
                      Text(
                        lastTime,
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 11,
                          color: unread > 0 ? primaryGreen : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  _roleBadge(otherRole, isAdmin),
                  const SizedBox(height: 5),
                  Text(
                    lastMsg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      color: unread > 0 ? Colors.black87 : Colors.grey,
                      fontWeight:
                          unread > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarCircle({
    required String name,
    required String image,
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
                        errorBuilder: (_, __, ___) => _avatar(name),
                      )
                    : _avatar(name),
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

  Widget _avatar(String name) {
    return Container(
      color: lightGreen,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "U",
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: primaryGreen,
            fontWeight: FontWeight.bold,
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
              fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w700,
              fontSize: 15,
              color: Colors.black87,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAdmin
            ? officialBlue.withOpacity(.10)
            : lightGreen.withOpacity(.4),
        borderRadius: BorderRadius.circular(9),
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
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}