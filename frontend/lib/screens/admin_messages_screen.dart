import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/message_service.dart';
import 'chat_page.dart';

const Color adminPrimaryGreen = Color(0xFF2F4F46);
const Color adminLightCream = Color(0xFFF5F1EB);
const Color adminSoftGreen = Color(0xFF3E6B5C);
const Color adminGold = Color(0xFFC9A84C);
const Color adminRed = Color(0xFFB84040);
const Color adminGrey = Color(0xFF8A8A8A);

class AdminMessagesScreen extends StatefulWidget {
  const AdminMessagesScreen({super.key});

  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen> {
  bool loading = true;
  bool searching = false;

  int currentUserId = 0;

  String selectedFilter = "all";

  List conversations = [];
  List searchResults = [];

  Timer? _timer;
  Timer? _debounce;

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitial();

    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (searchController.text.trim().isEmpty) {
        _loadConversations(showLoader: false);
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

  Future<void> _loadInitial() async {
    final me = await AuthService.getMe();

    currentUserId = _toInt(me?["id"]);

    await _loadConversations();
  }

  Future<void> _loadConversations({bool showLoader = true}) async {
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

    _debounce = Timer(const Duration(milliseconds: 420), () async {
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

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  String _text(dynamic value, {String fallback = ""}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty || text == "null") return fallback;
    return text;
  }

  String _formatTime(dynamic value) {
    final dateStr = _text(value);
    if (dateStr.isEmpty) return "";

    try {
      final d = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();

      if (d.day == now.day && d.month == now.month && d.year == now.year) {
        return DateFormat.jm().format(d);
      }

      if (now.difference(d).inDays < 7) {
        return DateFormat.E().format(d);
      }

      return DateFormat("MMM d").format(d);
    } catch (_) {
      return "";
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case "client":
        return "Client";
      case "photographer":
        return "Photographer";
      case "venue_owner":
        return "Venue Owner";
      case "warehouse_owner":
        return "Warehouse Owner";
      case "admin":
        return "Admin";
      default:
        return "User";
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case "client":
        return Icons.person_outline;
      case "photographer":
        return Icons.camera_alt_outlined;
      case "venue_owner":
        return Icons.location_city_outlined;
      case "warehouse_owner":
        return Icons.warehouse_outlined;
      case "admin":
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.person_outline;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case "photographer":
        return adminPrimaryGreen;
      case "venue_owner":
        return adminSoftGreen;
      case "warehouse_owner":
        return adminGold;
      case "client":
        return adminPrimaryGreen;
      default:
        return adminGrey;
    }
  }

  bool _matchesFilter(Map conv) {
    final role = _text(conv["other_user_role"]);
    final unread = _toInt(conv["unread_count"]);

    if (selectedFilter == "all") return true;
    if (selectedFilter == "unread") return unread > 0;

    return role == selectedFilter;
  }

  List get filteredConversations {
    return conversations.where((c) {
      final conv = Map<String, dynamic>.from(c);
      return _matchesFilter(conv);
    }).toList();
  }

  List get filteredSearchResults {
    if (selectedFilter == "all" || selectedFilter == "unread") {
      return searchResults;
    }

    return searchResults.where((u) {
      final user = Map<String, dynamic>.from(u);
      return _text(user["role"]) == selectedFilter;
    }).toList();
  }

  int _countByFilter(String filter) {
    if (filter == "all") return conversations.length;

    if (filter == "unread") {
      return conversations.where((c) {
        final conv = Map<String, dynamic>.from(c);
        return _toInt(conv["unread_count"]) > 0;
      }).length;
    }

    return conversations.where((c) {
      final conv = Map<String, dynamic>.from(c);
      return _text(conv["other_user_role"]) == filter;
    }).length;
  }

  Future<void> _openChatFromConversation(Map conv) async {
    final conversationId = _toInt(conv["id"]);
    final otherUserId = _toInt(conv["other_user_id"]);
    final otherName = _text(conv["other_user_name"], fallback: "User");
    final otherImage = _text(conv["other_user_image"]);
    final otherRole = _text(conv["other_user_role"], fallback: "client");

    if (conversationId <= 0 || otherUserId <= 0 || currentUserId <= 0) {
      _showMessage("Unable to open conversation");
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conversationId,
          otherUserId: otherUserId,
          otherUserName: otherName,
          otherUserImage: otherImage.isEmpty ? null : otherImage,
          currentUserId: currentUserId,
          otherUserRole: otherRole,
        ),
      ),
    );

    await _loadConversations(showLoader: false);
  }

  Future<void> _openChatFromUser(Map user) async {
    final otherUserId = _toInt(user["id"]);
    final otherName = _text(user["full_name"], fallback: "User");
    final otherImage = _text(user["profile_image"]);
    final otherRole = _text(user["role"], fallback: "client");

    if (otherUserId <= 0 || currentUserId <= 0) {
      _showMessage("Unable to open user conversation");
      return;
    }

    final conv = await MessageService.getOrCreateConversation(otherUserId);

    if (!mounted) return;

    if (conv == null) {
      _showMessage("Unable to create conversation");
      return;
    }

    final conversationId = _toInt(conv["id"]);

    if (conversationId <= 0) {
      _showMessage("Invalid conversation");
      return;
    }

    searchController.clear();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conversationId,
          otherUserId: otherUserId,
          otherUserName: otherName,
          otherUserImage: otherImage.isEmpty ? null : otherImage,
          currentUserId: currentUserId,
          otherUserRole: otherRole,
        ),
      ),
    );

    await _loadConversations(showLoader: false);
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch = searchController.text.trim().isNotEmpty;
    final visibleSearch = filteredSearchResults;
    final visibleConversations = filteredConversations;

    return Scaffold(
      backgroundColor: adminLightCream,
      body: RefreshIndicator(
        color: adminPrimaryGreen,
        onRefresh: () => _loadConversations(showLoader: false),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 285,
              pinned: true,
              elevation: 0,
              backgroundColor: adminPrimaryGreen,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                background: _header(),
              ),
              bottom: _roundedBottom(),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _summaryCard(),
                  const SizedBox(height: 16),
                  _searchBox(),
                  const SizedBox(height: 16),
                  _filters(),
                  const SizedBox(height: 20),
                  if (hasSearch)
                    _sectionTitle(
                      title: "Search Results",
                      count: visibleSearch.length,
                    )
                  else
                    _sectionTitle(
                      title: "Conversations",
                      count: visibleConversations.length,
                    ),
                  const SizedBox(height: 12),
                  if (hasSearch)
                    if (searching)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: adminPrimaryGreen,
                          ),
                        ),
                      )
                    else if (visibleSearch.isEmpty)
                      _emptyCard("No users found")
                    else
                      ...visibleSearch.map((u) {
                        return _userCard(Map<String, dynamic>.from(u));
                      })
                  else if (loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: adminPrimaryGreen,
                        ),
                      ),
                    )
                  else if (visibleConversations.isEmpty)
                    _emptyCard("No conversations found")
                  else
                    ...visibleConversations.map((c) {
                      return _conversationCard(Map<String, dynamic>.from(c));
                    }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF25463D), adminSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 42),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.mark_unread_chat_alt_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Admin Messages",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Manage conversations with clients, photographers, venues, and warehouse owners",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 13,
                  height: 1.3,
                  fontFamily: "Playfair",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSize _roundedBottom() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(24),
      child: Container(
        height: 26,
        decoration: const BoxDecoration(
          color: adminLightCream,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final totalUnread = conversations.fold<int>(0, (sum, c) {
      final conv = Map<String, dynamic>.from(c);
      return sum + _toInt(conv["unread_count"]);
    });

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: adminPrimaryGreen.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem(
              title: "Total",
              value: conversations.length.toString(),
              icon: Icons.forum_outlined,
              color: adminPrimaryGreen,
            ),
          ),
          _summaryDivider(),
          Expanded(
            child: _summaryItem(
              title: "Unread",
              value: totalUnread.toString(),
              icon: Icons.mark_chat_unread_outlined,
              color: adminRed,
            ),
          ),
          _summaryDivider(),
          Expanded(
            child: _summaryItem(
              title: "Users",
              value: _countUniqueUsers().toString(),
              icon: Icons.groups_outlined,
              color: adminSoftGreen,
            ),
          ),
        ],
      ),
    );
  }

  int _countUniqueUsers() {
    final ids = <int>{};

    for (final c in conversations) {
      final conv = Map<String, dynamic>.from(c);
      final id = _toInt(conv["other_user_id"]);
      if (id > 0) ids.add(id);
    }

    return ids.length;
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 44,
      color: Colors.black.withOpacity(0.06),
    );
  }

  Widget _summaryItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 7),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 21,
            fontWeight: FontWeight.bold,
            fontFamily: "Playfair",
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            color: Colors.black.withOpacity(0.43),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: "Playfair",
          ),
        ),
      ],
    );
  }

  Widget _searchBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: adminPrimaryGreen.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        style: const TextStyle(
          color: adminPrimaryGreen,
          fontFamily: "Playfair",
          fontSize: 14,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: const Icon(Icons.search_rounded, color: adminPrimaryGreen),
          hintText: "Search user to message...",
          hintStyle: TextStyle(
            color: Colors.black.withOpacity(0.35),
            fontFamily: "Playfair",
            fontSize: 13,
          ),
          suffixIcon: searchController.text.trim().isEmpty
              ? IconButton(
                  onPressed: () => _loadConversations(showLoader: false),
                  icon: const Icon(Icons.refresh_rounded),
                  color: adminGrey,
                )
              : IconButton(
                  onPressed: () {
                    searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded),
                  color: adminGrey,
                ),
        ),
      ),
    );
  }

  Widget _filters() {
    final filters = [
      _MessageFilter(
        value: "all",
        label: "All",
        icon: Icons.all_inbox_outlined,
      ),
      _MessageFilter(
        value: "unread",
        label: "Unread",
        icon: Icons.mark_chat_unread_outlined,
      ),
      _MessageFilter(
        value: "client",
        label: "Clients",
        icon: Icons.person_outline,
      ),
      _MessageFilter(
        value: "photographer",
        label: "Photographers",
        icon: Icons.camera_alt_outlined,
      ),
      _MessageFilter(
        value: "venue_owner",
        label: "Venues",
        icon: Icons.location_city_outlined,
      ),
      _MessageFilter(
        value: "warehouse_owner",
        label: "Warehouse",
        icon: Icons.warehouse_outlined,
      ),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final f = filters[index];
          final selected = selectedFilter == f.value;
          final count = _countByFilter(f.value);

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedFilter = f.value;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: selected ? adminPrimaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? adminPrimaryGreen
                      : adminPrimaryGreen.withOpacity(0.12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    f.icon,
                    size: 16,
                    color: selected ? Colors.white : adminPrimaryGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    f.label,
                    style: TextStyle(
                      color: selected ? Colors.white : adminPrimaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Playfair",
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withOpacity(0.18)
                            : adminPrimaryGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        count > 99 ? "99+" : count.toString(),
                        style: TextStyle(
                          color: selected ? Colors.white : adminPrimaryGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Playfair",
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle({
    required String title,
    required int count,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 19,
            fontWeight: FontWeight.bold,
            fontFamily: "Playfair",
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: adminPrimaryGreen.withOpacity(0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "$count results",
            style: const TextStyle(
              color: adminPrimaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
        ),
      ],
    );
  }

  Widget _conversationCard(Map conv) {
    final otherName = _text(conv["other_user_name"], fallback: "User");
    final otherImage = _text(conv["other_user_image"]);
    final otherRole = _text(conv["other_user_role"], fallback: "client");
    final lastMessage = _text(
      conv["last_message"],
      fallback: "No messages yet",
    );
    final lastTime = _formatTime(conv["last_message_time"]);
    final unread = _toInt(conv["unread_count"]);
    final roleColor = _roleColor(otherRole);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _openChatFromConversation(conv),
      child: Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread > 0 ? adminSoftGreen.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: unread > 0
                ? adminPrimaryGreen.withOpacity(0.18)
                : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: roleColor.withOpacity(0.06),
              blurRadius: 13,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                _avatar(
                  image: otherImage,
                  name: otherName,
                  role: otherRole,
                  color: roleColor,
                ),
                if (unread > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: const BoxDecoration(
                        color: adminRed,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          unread > 9 ? "9+" : unread.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
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
                            color: adminPrimaryGreen,
                            fontSize: 15.5,
                            fontWeight:
                                unread > 0 ? FontWeight.bold : FontWeight.w700,
                            fontFamily: "Playfair",
                          ),
                        ),
                      ),
                      if (lastTime.isNotEmpty)
                        Text(
                          lastTime,
                          style: TextStyle(
                            color: unread > 0 ? adminPrimaryGreen : adminGrey,
                            fontSize: 11,
                            fontWeight:
                                unread > 0 ? FontWeight.bold : FontWeight.w500,
                            fontFamily: "Playfair",
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _roleBadge(otherRole),
                  const SizedBox(height: 6),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unread > 0
                          ? Colors.black.withOpacity(0.70)
                          : Colors.black.withOpacity(0.42),
                      fontSize: 12.5,
                      fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                      fontFamily: "Playfair",
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.black.withOpacity(0.24),
              size: 15,
            ),
          ],
        ),
      ),
    );
  }

  Widget _userCard(Map user) {
    final name = _text(user["full_name"], fallback: "User");
    final image = _text(user["profile_image"]);
    final role = _text(user["role"], fallback: "client");
    final email = _text(user["email"]);
    final roleColor = _roleColor(role);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _openChatFromUser(user),
      child: Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: roleColor.withOpacity(0.06),
              blurRadius: 13,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            _avatar(
              image: image,
              name: name,
              role: role,
              color: roleColor,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: adminPrimaryGreen,
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Playfair",
                    ),
                  ),
                  const SizedBox(height: 5),
                  _roleBadge(role),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.42),
                        fontSize: 12,
                        fontFamily: "Playfair",
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: adminPrimaryGreen.withOpacity(0.09),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Text(
                "Message",
                style: TextStyle(
                  color: adminPrimaryGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar({
    required String image,
    required String name,
    required String role,
    required Color color,
  }) {
    final cleanImage = image.trim();

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.10),
        border: Border.all(
          color: color.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: cleanImage.isNotEmpty && cleanImage != "null"
            ? Image.network(
                cleanImage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarFallback(name, role, color),
              )
            : _avatarFallback(name, role, color),
      ),
    );
  }

  Widget _avatarFallback(String name, String role, Color color) {
    return Container(
      color: color.withOpacity(0.08),
      child: Center(
        child: role.isNotEmpty
            ? Icon(
                _roleIcon(role),
                color: color,
                size: 24,
              )
            : Text(
                name.isNotEmpty ? name[0].toUpperCase() : "U",
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
      ),
    );
  }

  Widget _roleBadge(String role) {
    final color = _roleColor(role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _roleIcon(role),
            color: color,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            _roleLabel(role),
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              fontFamily: "Playfair",
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black.withOpacity(0.45),
          fontFamily: "Playfair",
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: adminPrimaryGreen,
        content: Text(message),
      ),
    );
  }
}

class _MessageFilter {
  final String value;
  final String label;
  final IconData icon;

  _MessageFilter({
    required this.value,
    required this.label,
    required this.icon,
  });
}