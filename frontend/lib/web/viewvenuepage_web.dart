import 'package:flutter/material.dart';
import '../services/venue_service.dart';
import '../services/auth_service.dart';
import 'edit_venue_page_web.dart';
import 'edit_availability_page_venue_web.dart';
import 'venue_owner_web_shell.dart';

class ViewVenuePageWeb extends StatefulWidget {
  final Map venue;
  const ViewVenuePageWeb({super.key, required this.venue});

  @override
  State<ViewVenuePageWeb> createState() => _ViewVenuePageWebState();
}

class _ViewVenuePageWebState extends State<ViewVenuePageWeb> {
  Map venue = {};
  List images = [];
  List reviews = [];
  bool loading = true;
  int currentImage = 0;

  final PageController controller = PageController();

  @override
  void initState() {
    super.initState();
    loadVenue();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future loadVenue() async {
    final data = await VenueService.getVenueDetails(widget.venue["id"]);
    if (!mounted) return;
    setState(() {
      venue = data["venue"];
      images = data["images"];
      reviews = data["reviews"];
      loading = false;
    });
  }

  void nextImage() {
    if (currentImage < images.length - 1) {
      controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void prevImage() {
    if (currentImage > 0) {
      controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future deleteReview(int reviewId) async {
    final colors = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Delete Review",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        content: Text(
          "Are you sure you want to delete this review?",
          style: TextStyle(
            fontFamily: "Montserrat",
            color: colors.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Delete",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      await VenueService.deleteReview(token, reviewId);
      await loadVenue();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to delete review: $e",
            style: const TextStyle(fontFamily: "Montserrat"),
          ),
          backgroundColor: colors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (loading) {
      return VenueOwnerWebShell(
        selectedIndex: 1,
        child: Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    final previewReviews = reviews.take(4).toList();
    final hasMore = reviews.length > 4;

    return VenueOwnerWebShell(
      selectedIndex: 1,
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1450),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(colors),
                  const SizedBox(height: 24),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 1100;

                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (images.isNotEmpty) _buildGallery(colors),
                                  if (images.isNotEmpty) const SizedBox(height: 22),
                                  _buildDescriptionCard(colors),
                                  const SizedBox(height: 22),
                                  _buildReviewsCard(
                                    colors,
                                    previewReviews,
                                    hasMore,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  _buildInfoCard(colors),
                                  const SizedBox(height: 18),
                                  _buildActionsCard(colors),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (images.isNotEmpty) _buildGallery(colors),
                          if (images.isNotEmpty) const SizedBox(height: 22),
                          _buildInfoCard(colors),
                          const SizedBox(height: 18),
                          _buildDescriptionCard(colors),
                          const SizedBox(height: 18),
                          _buildActionsCard(colors),
                          const SizedBox(height: 18),
                          _buildReviewsCard(
                            colors,
                            previewReviews,
                            hasMore,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue["name"]?.toString() ?? "",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: colors.onPrimary,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Venue details, reviews, and management tools",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 14,
                    color: colors.onPrimary.withOpacity(.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallery(ColorScheme colors) {
    return Container(
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            PageView.builder(
              controller: controller,
              itemCount: images.length,
              onPageChanged: (i) => setState(() => currentImage = i),
              itemBuilder: (_, index) => Image.network(
                images[index]["image_url"],
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: colors.surfaceContainerLow,
                  child: Icon(
                    Icons.image_outlined,
                    size: 44,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(.28),
                    ],
                  ),
                ),
              ),
            ),
            if (images.length > 1) ...[
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _arrowBtn(
                    colors,
                    Icons.arrow_back_ios_new,
                    prevImage,
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _arrowBtn(
                    colors,
                    Icons.arrow_forward_ios,
                    nextImage,
                  ),
                ),
              ),
            ],
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: currentImage == i ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: currentImage == i
                          ? Colors.white
                          : Colors.white54,
                      borderRadius: BorderRadius.circular(20),
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

  Widget _buildInfoCard(ColorScheme colors) {
    final rating =
        double.tryParse(venue["rating_avg"]?.toString() ?? "0")?.toStringAsFixed(1) ??
            "0.0";
    final reviewsCount = venue["reviews_count"]?.toString() ?? "0";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            venue["name"]?.toString() ?? "",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: "Montserrat",
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 14),
          _infoRow(
            colors,
            Icons.location_on_rounded,
            venue["location"]?.toString() ?? "",
          ),
          const SizedBox(height: 10),
          _infoRow(
            colors,
            Icons.attach_money_rounded,
            "\$${venue["price_per_hour"]} / hour",
          ),
          const SizedBox(height: 10),
          _infoRow(
            colors,
            Icons.star_rounded,
            "$rating rating · $reviewsCount review(s)",
            iconColor: Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Description",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: "Montserrat",
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            venue["description"]?.toString() ?? "",
            style: TextStyle(
              fontSize: 14,
              fontFamily: "Montserrat",
              color: colors.onSurface,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick Actions",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              fontFamily: "Montserrat",
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.calendar_month_rounded, size: 20),
              label: const Text(
                "Manage Availability",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditAvailabilityPageVenueWeb(venue: venue),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.primary, width: 1.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text(
                "Edit Venue",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditVenuePageWeb(venue: venue),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsCard(
    ColorScheme colors,
    List previewReviews,
    bool hasMore,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Reviews",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: "Montserrat",
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withOpacity(.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${reviews.length}",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (hasMore)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _AllReviewsPageWeb(
                        reviews: reviews,
                        venueName: venue["name"]?.toString() ?? "",
                        onDelete: (id) async {
                          await deleteReview(id);
                        },
                      ),
                    ),
                  ),
                  child: Text(
                    "See all",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (reviews.isEmpty)
            Text(
              "No reviews yet",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.onSurfaceVariant,
              ),
            )
          else
            ...previewReviews.map(
              (r) => _reviewCard(
                context,
                r,
                onDelete: () => deleteReview(r["id"]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _reviewCard(
    BuildContext context,
    Map r, {
    VoidCallback? onDelete,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: colors.primaryContainer,
            child: Text(
              (r["full_name"]?.toString() ?? "U").isNotEmpty
                  ? r["full_name"].toString()[0].toUpperCase()
                  : "U",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                        r["full_name"]?.toString() ?? "",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: "Montserrat",
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          r["rating"].toString(),
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  r["comment"]?.toString() ?? "",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13,
                    color: colors.onSurface,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: colors.error.withOpacity(.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: colors.error,
                  size: 16,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(
    ColorScheme colors,
    IconData icon,
    String text, {
    Color? iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor ?? colors.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: colors.onSurfaceVariant,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _arrowBtn(
    ColorScheme colors,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.30),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _AllReviewsPageWeb extends StatefulWidget {
  final List reviews;
  final String venueName;
  final Function(int) onDelete;

  const _AllReviewsPageWeb({
    required this.reviews,
    required this.venueName,
    required this.onDelete,
  });

  @override
  State<_AllReviewsPageWeb> createState() => _AllReviewsPageWebState();
}

class _AllReviewsPageWebState extends State<_AllReviewsPageWeb> {
  late List reviews;

  @override
  void initState() {
    super.initState();
    reviews = List.from(widget.reviews);
  }

  Future deleteReview(int id) async {
    final colors = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Delete Review",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        content: Text(
          "Are you sure?",
          style: TextStyle(
            fontFamily: "Montserrat",
            color: colors.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Delete",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await widget.onDelete(id);
    setState(() => reviews.removeWhere((r) => r["id"] == id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    double avgRating = 0;
    if (reviews.isNotEmpty) {
      final sum = reviews.fold<double>(
        0,
        (acc, r) => acc + (double.tryParse(r["rating"].toString()) ?? 0),
      );
      avgRating = sum / reviews.length;
    }

    return VenueOwnerWebShell(
      selectedIndex: 1,
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1250),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
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
                          "All Reviews",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: colors.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.venueName,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 14,
                            color: colors.onPrimary.withOpacity(.8),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.onPrimary.withOpacity(.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.amber,
                                size: 30,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                avgRating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: colors.onPrimary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "from ${reviews.length} review${reviews.length != 1 ? 's' : ''}",
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontSize: 13,
                                  color: colors.onPrimary.withOpacity(.82),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (reviews.isEmpty)
                    SizedBox(
                      height: 280,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.rate_review_outlined,
                              size: 56,
                              color: colors.onSurfaceVariant.withOpacity(.35),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "No reviews yet",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                color: colors.onSurfaceVariant,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final crossCount = constraints.maxWidth > 900 ? 2 : 1;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: reviews.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 2.1,
                          ),
                          itemBuilder: (_, i) =>
                              _reviewCard(context, reviews[i]),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _reviewCard(BuildContext context, Map r) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: colors.primaryContainer,
            child: Text(
              (r["full_name"]?.toString() ?? "U").isNotEmpty
                  ? r["full_name"].toString()[0].toUpperCase()
                  : "U",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                        r["full_name"]?.toString() ?? "",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: "Montserrat",
                          fontSize: 14,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          r["rating"].toString(),
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    r["comment"]?.toString() ?? "",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 13,
                      color: colors.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => deleteReview(r["id"]),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: colors.error.withOpacity(.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: colors.error,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}