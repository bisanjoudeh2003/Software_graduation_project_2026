import 'package:flutter/material.dart';
import '../services/photographer_service.dart';
import '../services/message_service.dart';
import '../services/auth_service.dart';
import 'chat_page.dart';
import 'photographer_public_profile_page.dart';
import 'client_bottom_nav.dart';

class AllPhotographersPage extends StatefulWidget {
  const AllPhotographersPage({super.key});

  @override
  State<AllPhotographersPage> createState() => _AllPhotographersPageState();
}

class _AllPhotographersPageState extends State<AllPhotographersPage>
    with SingleTickerProviderStateMixin {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color softGreen = Color(0xFFEAF3E8);

  final TextEditingController _searchController = TextEditingController();

  List _photographers = [];
  List _filtered = [];
  Map? _topRated;

  bool _loading = true;
  int _currentUserId = 0;
  String _selectedCat = 'All';

  // 'none' | 'asc' | 'desc'
  String _priceSort = 'none';

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final List<String> _categories = [
    'All',
    'Wedding',
    'Studio',
    'Outdoor',
    'Graduation',
    'Indoor',
    'Family',
  ];

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardColor => Theme.of(context).cardColor;
  Color get _textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get _softBorder => _isDark ? Colors.white12 : Colors.grey.shade300;
  Color get _chipBg =>
      _isDark ? Colors.white.withOpacity(0.06) : _cardColor;
  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.08) : softGreen;
  Color get _avatarFallbackBg =>
      _isDark ? Colors.white.withOpacity(0.06) : softGreen;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final me = await AuthService.getMe();
      final data = await PhotographerService.getAllPhotographers();
      if (!mounted) return;

      Map? top;
      double topRating = -1;
      for (final p in data) {
        final r = double.tryParse(p['rating_avg']?.toString() ?? '0') ?? 0;
        if (r > topRating) {
          topRating = r;
          top = p;
        }
      }

      setState(() {
        _currentUserId = me?['id'] ?? 0;
        _photographers = data;
        _filtered = data;
        _topRated = top;
        _loading = false;
      });

      _fadeCtrl.forward();
    } catch (e) {
      debugPrint('❌ Error loading photographers: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();

    List results = _photographers.where((p) {
      final name = (p['full_name'] ?? '').toString().toLowerCase();
      final specialty = (p['specialties'] ?? '').toString().toLowerCase();
      final location = (p['location'] ?? '').toString().toLowerCase();

      final matchSearch = q.isEmpty ||
          name.contains(q) ||
          specialty.contains(q) ||
          location.contains(q);

      final matchCat = _selectedCat == 'All' ||
          specialty.contains(_selectedCat.toLowerCase());

      return matchSearch && matchCat;
    }).toList();

    if (_priceSort == 'asc') {
      results.sort((a, b) {
        final aP =
            double.tryParse(a['price_per_hour']?.toString() ?? '0') ?? 0;
        final bP =
            double.tryParse(b['price_per_hour']?.toString() ?? '0') ?? 0;
        return aP.compareTo(bP);
      });
    } else if (_priceSort == 'desc') {
      results.sort((a, b) {
        final aP =
            double.tryParse(a['price_per_hour']?.toString() ?? '0') ?? 0;
        final bP =
            double.tryParse(b['price_per_hour']?.toString() ?? '0') ?? 0;
        return bP.compareTo(aP);
      });
    }

    setState(() => _filtered = results);
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildSortSheet(),
    );
  }

  int _getUserId(Map photographer) {
    final id = photographer['user_id'] ?? photographer['id'] ?? 0;
    return int.tryParse(id.toString()) ?? 0;
  }

  Future<void> _openChat(Map photographer) async {
    try {
      final otherId = _getUserId(photographer);
      if (otherId == 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid photographer ID')),
        );
        return;
      }
      final conv = await MessageService.getOrCreateConversation(otherId);
      if (conv == null || !mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conv['id'],
            otherUserId: otherId,
            otherUserName: photographer['full_name'] ?? 'Photographer',
            otherUserImage: photographer['profile_image'],
            currentUserId: _currentUserId,
            otherUserRole: 'photographer',
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error opening chat: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open chat')),
      );
    }
  }

  void _openProfile(Map photographer) {
    final userId = _getUserId(photographer);
    final name = photographer['full_name']?.toString() ?? 'Photographer';
    final image = photographer['profile_image']?.toString();
    if (userId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid photographer ID')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotographerPublicProfilePage(
          photographerId: userId,
          photographerName: name,
          photographerImage: image,
        ),
      ),
    );
  }

  String _formatPrice(dynamic raw) {
    final v = double.tryParse(raw?.toString() ?? '0') ?? 0;
    return v == v.truncateToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(0);
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
        bottomNavigationBar: const ClientBottomNav(currentIndex: 2),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: primaryGreen),
            )
          : FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(child: _buildCategoryAndSortRow()),
                  if (_topRated != null)
                    SliverToBoxAdapter(
                        child: _buildTopRatedBanner(_topRated!)),
                  SliverToBoxAdapter(child: _buildSectionLabel()),
                  _filtered.isEmpty
                      ? SliverFillRemaining(child: _buildEmpty())
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _buildCard(_filtered[i]),
                              childCount: _filtered.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 130,
      pinned: true,
      elevation: 0,
      backgroundColor: primaryGreen,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          color: primaryGreen,
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Photographers',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_photographers.length} available',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildSearchBar(),
            ],
          ),
        ),
      ),
      title: const Text(
        'Photographers',
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.white,
          selectionColor: Colors.white24,
          selectionHandleColor: Colors.white,
        ),
      ),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: TextField(
          controller: _searchController,
          cursorColor: Colors.white,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 13,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.transparent,
            hintText: 'Search by name, location...',
            hintStyle: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              color: Colors.white.withOpacity(0.55),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 20,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryAndSortRow() {
    final bool isActive = _priceSort != 'none';

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                padding: const EdgeInsets.only(left: 14),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final selected = _selectedCat == cat;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCat = cat);
                      _applyFilters();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? primaryGreen : _chipBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? primaryGreen : _softBorder,
                          width: 1.5,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: primaryGreen.withOpacity(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [],
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : _subTextColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 14),
            child: GestureDetector(
              onTap: _showSortSheet,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 40,
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 0),
                decoration: BoxDecoration(
                  color: isActive ? primaryGreen : _chipBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? primaryGreen : _softBorder,
                    width: 1.5,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: primaryGreen.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive
                          ? (_priceSort == 'asc'
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded)
                          : Icons.tune_rounded,
                      size: 15,
                      color: isActive ? Colors.white : _subTextColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Price',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : _subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _softBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: softGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.attach_money_rounded,
                        color: primaryGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Sort by Price',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _textColor,
                      ),
                    ),
                    const Spacer(),
                    if (_priceSort != 'none')
                      GestureDetector(
                        onTap: () {
                          setState(() => _priceSort = 'none');
                          setSheetState(() {});
                          _applyFilters();
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Reset',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _buildSortOption(
                label: 'Default',
                subtitle: 'No sorting applied',
                icon: Icons.sort_rounded,
                value: 'none',
                onTap: () => setSheetState(() => _priceSort = 'none'),
              ),
              _buildSortOption(
                label: 'Price: Low to High',
                subtitle: 'Cheapest photographers first',
                icon: Icons.arrow_upward_rounded,
                value: 'asc',
                onTap: () => setSheetState(() => _priceSort = 'asc'),
              ),
              _buildSortOption(
                label: 'Price: High to Low',
                subtitle: 'Most expensive first',
                icon: Icons.arrow_downward_rounded,
                value: 'desc',
                onTap: () => setSheetState(() => _priceSort = 'desc'),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Apply',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption({
    required String label,
    required String subtitle,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    final bool selected = _priceSort == value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? primaryGreen.withOpacity(0.07)
              : (_isDark ? Colors.white.withOpacity(0.04) : softGreen),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primaryGreen : Colors.transparent,
            width: 1.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? primaryGreen : _chipBg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: selected ? primaryGreen : _softBorder,
                  width: 1.2,
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : _subTextColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? primaryGreen : _textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      color: _subTextColor,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? primaryGreen : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? primaryGreen : _softBorder,
                  width: 1.8,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRatedBanner(Map p) {
    final name = p['full_name']?.toString() ?? 'Photographer';
    final spec = p['specialties']?.toString() ?? '';
    final price = _formatPrice(p['price_per_hour']);
    final image = p['profile_image']?.toString() ?? '';

    return GestureDetector(
      onTap: () => _openProfile(p),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2F4F3E), Color(0xFF3D6B54)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: image.isNotEmpty
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _bannerInitials(name),
                      )
                    : _bannerInitials(name),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.star_rounded,
                          color: Color(0xFFFFD66E), size: 13),
                      SizedBox(width: 4),
                      Text(
                        'TOP RATED',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFC1D9CC),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (spec.isNotEmpty)
                    Text(
                      spec,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.65),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$$price',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'per hour',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerInitials(String name) => Center(
        child: Text(
          _initials(name),
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );

  Widget _buildSectionLabel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: Row(
        children: [
          Text(
            'All Photographers'.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _subTextColor,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: _softBorder, thickness: 0.8)),
          const SizedBox(width: 8),
          if (_priceSort != 'none')
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.09),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _priceSort == 'asc'
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 11,
                    color: primaryGreen,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _priceSort == 'asc' ? 'Low → High' : 'High → Low',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              '${_filtered.length} results',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 11,
                color: _subTextColor.withOpacity(0.8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(Map p) {
    final image = p['profile_image']?.toString() ?? '';
    final name = p['full_name']?.toString() ?? 'Photographer';
    final specialty = p['specialties']?.toString() ?? '';
    final location = (p['location']?.toString().trim().isNotEmpty ?? false)
        ? p['location'].toString()
        : 'Unknown location';
    final price = _formatPrice(p['price_per_hour']);
    final rating =
        (double.tryParse(p['rating_avg']?.toString() ?? '0') ?? 0)
            .toStringAsFixed(1);
    final experience = p['experience_years']?.toString() ?? '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 3.5, color: lightGreen),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAvatar(image, name, rating),
                      const SizedBox(width: 13),
                      Expanded(
                        child: _buildCardBody(
                            name, specialty, location, experience, price, p),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String image, String name, String rating) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _avatarFallbackBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: lightGreen, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.5),
                child: image.isNotEmpty
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _avatarPlaceholder(name),
                      )
                    : _avatarPlaceholder(name),
              ),
            ),
            Positioned(
              bottom: -6,
              right: -6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _bgColor, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFFFD66E), size: 10),
                    const SizedBox(width: 2),
                    Text(
                      rating,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _avatarPlaceholder(String name) => Center(
        child: Text(
          _initials(name),
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: primaryGreen,
          ),
        ),
      );

  /// ─── Card body: View Portfolio + Message only (Check Availability removed) ───
  Widget _buildCardBody(
    String name,
    String specialty,
    String location,
    String experience,
    String price,
    Map p,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _textColor,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: _softSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '\$$price/hr',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: primaryGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        if (specialty.isNotEmpty) ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _softSurface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              specialty,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Icon(Icons.location_on_rounded, size: 12, color: _subTextColor),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11,
                  color: _subTextColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.access_time_rounded,
                size: 12, color: _subTextColor),
            const SizedBox(width: 3),
            Text(
              '$experience yrs',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 11,
                color: _subTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // ── View Portfolio + Message (Check Availability removed) ──
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  side:
                      const BorderSide(color: primaryGreen, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _openProfile(p),
                child: const Text(
                  'View Portfolio',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primaryGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_rounded,
                    size: 14, color: Colors.white),
                label: const Text(
                  'Message',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                onPressed: () => _openChat(p),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 52, color: _subTextColor.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text(
            'No photographers found',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _subTextColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different search or category',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              color: _subTextColor.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}