import 'package:flutter/material.dart';
import '../services/photographer_service.dart';
import '../services/message_service.dart';
import '../services/auth_service.dart';
import '../screens/chat_page.dart';
import 'photographer_public_profile_web.dart';
import 'client_web_shell.dart';

class ClientPhotographersWebPage extends StatefulWidget {
  const ClientPhotographersWebPage({super.key});

  @override
  State<ClientPhotographersWebPage> createState() =>
      _ClientPhotographersWebPageState();
}

class _ClientPhotographersWebPageState extends State<ClientPhotographersWebPage>
    with SingleTickerProviderStateMixin {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color softGreen = Color(0xFFEAF3E8);
  static const Color cream = Color(0xFFF6F4EE);

  final TextEditingController _searchController = TextEditingController();

  List _photographers = [];
  List _filtered = [];
  Map? _topRated;

  bool _loading = true;
  int _currentUserId = 0;
  String _selectedCat = 'All';
  String _priceSort = 'none'; // none | asc | desc

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

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
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
      debugPrint('Error loading photographers: $e');
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

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: softGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Sort by Price',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _sortOption('Default', 'No sorting applied', 'none'),
              const SizedBox(height: 10),
              _sortOption('Price: Low to High', 'Cheapest first', 'asc'),
              const SizedBox(height: 10),
              _sortOption('Price: High to Low', 'Most expensive first', 'desc'),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _priceSort = 'none');
                        _applyFilters();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _applyFilters();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
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

  Widget _sortOption(String title, String subtitle, String value) {
    final selected = _priceSort == value;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() => _priceSort = value);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? primaryGreen.withOpacity(0.08) : cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primaryGreen : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? primaryGreen : Colors.transparent,
                border: Border.all(
                  color: selected ? primaryGreen : Colors.grey.shade300,
                  width: 1.6,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? primaryGreen : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
      debugPrint('Error opening chat: $e');
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
        builder: (_) => PhotographerPublicProfileWebPage(
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
    return ClientWebShell(
      selectedIndex: 2,
      child: Container(
        color: cream,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: primaryGreen),
              )
            : FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroHeader(),
                          const SizedBox(height: 18),
                          _buildToolbar(),
                          if (_topRated != null) ...[
                            const SizedBox(height: 18),
                            _buildTopRatedBanner(_topRated!),
                          ],
                          const SizedBox(height: 20),
                          _buildSectionHeader(),
                          const SizedBox(height: 14),
                          _filtered.isEmpty
                              ? _buildEmpty()
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    int crossAxisCount = 3;
                                    if (constraints.maxWidth < 1150) {
                                      crossAxisCount = 2;
                                    }
                                    if (constraints.maxWidth < 760) {
                                      crossAxisCount = 1;
                                    }

                                    return GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: _filtered.length,
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 18,
                                        mainAxisSpacing: 18,
                                        childAspectRatio: 1.18,
                                      ),
                                      itemBuilder: (_, i) =>
                                          _buildCard(_filtered[i]),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, Color(0xFF3D6B54)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Photographers',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_photographers.length} available',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.24)),
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
          hintText: 'Search by name, specialty, location...',
          hintStyle: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 13,
            color: Colors.white.withOpacity(0.6),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withOpacity(0.75),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    final bool isActive = _priceSort != 'none';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = _selectedCat == cat;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedCat = cat);
                      _applyFilters();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? primaryGreen : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color:
                              selected ? primaryGreen : Colors.grey.shade300,
                          width: 1.4,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _showSortDialog,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isActive ? primaryGreen : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive ? primaryGreen : Colors.grey.shade300,
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isActive
                      ? (_priceSort == 'asc'
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded)
                      : Icons.tune_rounded,
                  size: 16,
                  color: isActive ? Colors.white : Colors.black54,
                ),
                const SizedBox(width: 6),
                Text(
                  'Price',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2F4F3E), Color(0xFF3D6B54)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.24),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: image.isNotEmpty
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _bannerInitials(name),
                      )
                    : _bannerInitials(name),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.star_rounded,
                          color: Color(0xFFFFD66E), size: 14),
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
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (spec.isNotEmpty)
                    Text(
                      spec,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.72),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$$price',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'per hour',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.65),
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
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Text(
          'ALL PHOTOGRAPHERS',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(color: Colors.grey.shade300, thickness: 0.8),
        ),
        const SizedBox(width: 8),
        if (_priceSort != 'none')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.08),
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
              color: Colors.grey.shade600,
            ),
          ),
      ],
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(image, name, rating),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildCardBody(
                    name,
                    specialty,
                    location,
                    experience,
                    price,
                    p,
                  ),
                ),
              ],
            ),
          ],
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: softGreen,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: lightGreen, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18.5),
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
                  border: Border.all(color: Colors.white, width: 2),
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
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: primaryGreen,
          ),
        ),
      );

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
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: softGreen,
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
        const SizedBox(height: 8),
        if (specialty.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: softGreen,
              borderRadius: BorderRadius.circular(7),
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
        if (specialty.isNotEmpty) const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on_rounded, size: 13, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.access_time_rounded,
                size: 13, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              '$experience yrs experience',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  side: const BorderSide(color: primaryGreen, width: 1.5),
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
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 11),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          const Text(
            'No photographers found',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a different search or category',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}