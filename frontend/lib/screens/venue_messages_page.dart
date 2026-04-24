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
    if (mounted) {
      setState(() {
        conversations = data;
        loading = false;
      });
    }
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
      setState(() => searching = true);
      final results = await MessageService.searchUsers(q);
      if (mounted) {
        setState(() {
          searchResults = results;
          searching = false;
        });
      }
    });
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return "";
    try {
      final d = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      if (d.day == now.day &&
          d.month == now.month &&
          d.year == now.year) {
        return DateFormat.jm().format(d);
      }
      if (now.difference(d).inDays < 7) return DateFormat.E().format(d);
      return DateFormat("MM/dd").format(d);
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final showSearch = searchController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: const VenueOwnerBottomNav(currentIndex: 3),
      body: CustomScrollView(
        slivers: [
          // ── HEADER ──
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary,
                    colors.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
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
                            color: colors.onPrimary.withOpacity(.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: colors.onPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Messages",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loading
                            ? ""
                            : "${conversations.length} conversation${conversations.length != 1 ? 's' : ''}",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          color: colors.onPrimary.withOpacity(.8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TextField(
                          controller: searchController,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 14,
                            color: colors.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: "Search people to message...",
                            hintStyle: TextStyle(
                              fontFamily: "Montserrat",
                              color: colors.onSurfaceVariant,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: colors.primary,
                              size: 20,
                            ),
                            suffixIcon: showSearch
                                ? GestureDetector(
                                    onTap: () => searchController.clear(),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: colors.onSurfaceVariant,
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
            ),
          ),

          // ── SEARCH RESULTS ──
          if (showSearch)
            searching
                ? SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: colors.primary,
                      ),
                    ),
                  )
                : searchResults.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_search_rounded,
                                size: 56,
                                color: colors.onSurfaceVariant.withOpacity(.35),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "No users found",
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontSize: 15,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _userSearchCard(context, searchResults[i]),
                            childCount: searchResults.length,
                          ),
                        ),
                      )

          // ── CONVERSATIONS ──
          else if (loading)
            SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: colors.primary,
                ),
              ),
            )
          else if (conversations.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withOpacity(.45),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: colors.primary,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No conversations yet",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Clients will contact you here",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _conversationCard(context, conversations[i]),
                  childCount: conversations.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _userSearchCard(BuildContext context, Map user) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final name = user["full_name"]?.toString() ?? "";
    final image = user["profile_image"]?.toString() ?? "";
    final role = user["role"]?.toString() ?? "";
    final id = user["id"];

    return GestureDetector(
      onTap: () async {
        final conv = await MessageService.getOrCreateConversation(id);
        if (conv == null || !mounted) return;

        searchController.clear();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversationId: conv["id"],
              otherUserId: id,
              otherUserName: name,
              otherUserImage: image.isNotEmpty ? image : null,
              currentUserId: currentUserId ?? 0,
              otherUserRole: role,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.primaryContainer,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: image.isNotEmpty
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _avatar(context, name),
                      )
                    : _avatar(context, name),
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
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    role == "venue_owner"
                        ? "Venue Owner"
                        : role == "photographer"
                            ? "Photographer"
                            : "Client",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withOpacity(.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "Message",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 11,
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conversationCard(BuildContext context, Map conv) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final otherName = conv["other_user_name"]?.toString() ?? "User";
    final otherImage = conv["other_user_image"]?.toString() ?? "";
    final otherRole = conv["other_user_role"]?.toString() ?? "";
    final lastMsg = conv["last_message"]?.toString() ?? "No messages yet";
    final lastTime = _formatTime(conv["last_message_time"]?.toString());
    final unread = int.tryParse(conv["unread_count"]?.toString() ?? "0") ?? 0;
    final convId = conv["id"];
    final otherUserId = conv["other_user_id"];

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversationId: convId,
              otherUserId: otherUserId,
              otherUserName: otherName,
              otherUserImage: otherImage,
              currentUserId: currentUserId ?? 0,
              otherUserRole: otherRole,
            ),
          ),
        );
        loadConversations();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
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
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.primaryContainer,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: otherImage.isNotEmpty
                        ? Image.network(
                            otherImage,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _avatar(context, otherName),
                          )
                        : _avatar(context, otherName),
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: colors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          unread > 9 ? "9+" : "$unread",
                          style: TextStyle(
                            color: colors.onError,
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
                        child: Text(
                          otherName,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontWeight: unread > 0
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 15,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        lastTime,
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 11,
                          color: unread > 0
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (otherRole.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withOpacity(.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        otherRole == "venue_owner"
                            ? "Venue Owner"
                            : otherRole == "photographer"
                                ? "Photographer"
                                : "Client",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 10,
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    lastMsg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      color: unread > 0
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                      fontWeight: unread > 0
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colors.onSurfaceVariant,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(BuildContext context, String name) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      color: colors.primaryContainer,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "U",
          style: TextStyle(
            fontFamily: "Montserrat",
            color: colors.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}