import 'package:flutter/material.dart';
import '../theme.dart';
import 'album_details_screen.dart';

class AllAlbumsScreen extends StatelessWidget {
  final List albums;
  const AllAlbumsScreen({super.key, required this.albums});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightCream,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── SliverAppBar ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            floating: false,
            elevation: 0,
            backgroundColor: primaryGreen,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3B32), Color(0xFF3E6B5C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                    child: Row(children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              size: 16, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("All Albums",
                                style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold,
                                  fontFamily: 'Playfair', color: Colors.white,
                                )),
                            Text("Your creative collections",
                                style: TextStyle(
                                  fontSize: 12, fontFamily: 'Playfair',
                                  color: Colors.white70,
                                )),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0),
              child: Container(
                height: 22,
                decoration: const BoxDecoration(
                  color: lightCream,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(22)),
                ),
              ),
            ),
          ),

          // ── Count strip ──────────────────────────────────────────────────
          if (albums.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(children: [
                  Container(
                    width: 4, height: 16,
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${albums.length} Album${albums.length != 1 ? 's' : ''}",
                    style: const TextStyle(
                      fontFamily: 'Playfair', fontSize: 13,
                      fontWeight: FontWeight.w600, color: softGrey,
                    ),
                  ),
                ]),
              ),
            ),

          // ── Grid ─────────────────────────────────────────────────────────
          albums.isEmpty
              ? SliverFillRemaining(child: _emptyState())
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final album = albums[i];
                        return TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 250 + i * 50),
                          tween: Tween(begin: 0.88, end: 1),
                          curve: Curves.easeOutBack,
                          builder: (_, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AlbumDetailsScreen(albumId: album["id"]),
                              ),
                            ),
                            child: _albumCard(album),
                          ),
                        );
                      },
                      childCount: albums.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ── Album Card ────────────────────────────────────────────────────────────
  Widget _albumCard(Map album) {
    final String  title    = (album["title"] ?? "").toString();
    final int     count    = int.tryParse(
            (album["items_count"] ?? "0").toString()) ?? 0;
    final String? cover    = album["cover_image"]?.toString();
    final bool    hasCover = cover != null && cover.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: primaryGreen.withOpacity(0.13), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: primaryGreen.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Cover ───────────────────────────────────────────────────────
          Expanded(
            child: Stack(children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(17)),
                child: hasCover
                    ? Image.network(
                        cover!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),

              // Gradient overlay
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(0)),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.38),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Count badge
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.perm_media,
                        size: 10, color: Colors.white),
                    const SizedBox(width: 4),
                    Text("$count",
                        style: const TextStyle(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Playfair',
                        )),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Title + arrow ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(children: [
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Playfair',
                      fontSize: 13,
                      color: darkText,
                    )),
              ),
              const SizedBox(width: 4),
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_ios,
                    size: 11, color: primaryGreen),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity, height: double.infinity,
      color: const Color(0xFFE8EDE9),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.photo_album_outlined,
            size: 36, color: primaryGreen.withOpacity(0.35)),
        const SizedBox(height: 6),
        Text("No Cover",
            style: TextStyle(
              fontSize: 11, fontFamily: 'Playfair',
              color: primaryGreen.withOpacity(0.45),
            )),
      ]),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 96, height: 96,
          decoration: BoxDecoration(
            color: primaryGreen.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.photo_album_outlined,
              size: 46, color: primaryGreen.withOpacity(0.45)),
        ),
        const SizedBox(height: 18),
        const Text("No Albums Yet",
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold,
              fontFamily: 'Playfair', color: darkText,
            )),
        const SizedBox(height: 8),
        const Text("Start by creating your first album 📸",
            style: TextStyle(
                fontSize: 13, color: softGrey, fontFamily: 'Playfair')),
      ]),
    );
  }
}