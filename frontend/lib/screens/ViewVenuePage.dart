import 'package:flutter/material.dart';
import '../services/venue_service.dart';
import '../services/auth_service.dart';
import 'edit_venue_page.dart';
import 'edit_availability_page_venue.dart';

class ViewVenuePage extends StatefulWidget {
  final Map venue;
  const ViewVenuePage({super.key, required this.venue});

  @override
  State<ViewVenuePage> createState() => _ViewVenuePageState();
}

class _ViewVenuePageState extends State<ViewVenuePage> {
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
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    final previewReviews = reviews.take(3).toList();
    final hasMore = reviews.length > 3;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.secondary],
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
                      const SizedBox(height: 14),
                      Text(
                        venue["name"]?.toString() ?? "",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Manage your venue details",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          color: colors.onPrimary.withOpacity(.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (images.isNotEmpty)
                    Container(
                      height: 240,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.15),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            PageView.builder(
                              controller: controller,
                              itemCount: images.length,
                              onPageChanged: (i) =>
                                  setState(() => currentImage = i),
                              itemBuilder: (_, index) => Image.network(
                                images[index]["image_url"],
                                fit: BoxFit.cover,
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
                                      Colors.black.withOpacity(.4),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 10,
                              top: 90,
                              child: _arrowBtn(
                                context,
                                Icons.arrow_back_ios_new,
                                prevImage,
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 90,
                              child: _arrowBtn(
                                context,
                                Icons.arrow_forward_ios,
                                nextImage,
                              ),
                            ),
                            Positioned(
                              bottom: 14,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  images.length,
                                  (i) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    width: currentImage == i ? 16 : 8,
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
                    ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
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
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Montserrat",
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 18,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              venue["location"]?.toString() ?? "",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "\$${venue["price_per_hour"]} / hour",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Montserrat",
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
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
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            fontFamily: "Montserrat",
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          venue["description"]?.toString() ?? "",
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: "Montserrat",
                            color: colors.onSurface,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "Reviews",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: "Montserrat",
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer
                                        .withOpacity(.6),
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
                              ],
                            ),
                            if (hasMore)
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _AllReviewsPage(
                                      reviews: reviews,
                                      venueName:
                                          venue["name"]?.toString() ?? "",
                                      onDelete: (id) async {
                                        await deleteReview(id);
                                      },
                                    ),
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer
                                        .withOpacity(.45),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "See all",
                                    style: TextStyle(
                                      fontFamily: "Montserrat",
                                      fontSize: 12,
                                      color: colors.onPrimaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
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
                        if (hasMore) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _AllReviewsPage(
                                    reviews: reviews,
                                    venueName:
                                        venue["name"]?.toString() ?? "",
                                    onDelete: (id) async {
                                      await deleteReview(id);
                                    },
                                  ),
                                ),
                              ),
                              child: Text(
                                "See all ${reviews.length} reviews →",
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      icon: const Icon(
                        Icons.calendar_month_rounded,
                        size: 20,
                      ),
                      label: const Text(
                        "Manage Availability",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditAvailabilityPage(venue: venue),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primary,
                        side: BorderSide(color: colors.primary, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text(
                        "Edit Venue",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditVenuePage(venue: venue),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(width: 10),
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
                const SizedBox(height: 4),
                Text(
                  r["comment"]?.toString() ?? "",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.error.withOpacity(.08),
                  borderRadius: BorderRadius.circular(8),
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

  Widget _arrowBtn(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _AllReviewsPage extends StatefulWidget {
  final List reviews;
  final String venueName;
  final Function(int) onDelete;

  const _AllReviewsPage({
    required this.reviews,
    required this.venueName,
    required this.onDelete,
  });

  @override
  State<_AllReviewsPage> createState() => _AllReviewsPageState();
}

class _AllReviewsPageState extends State<_AllReviewsPage> {
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.secondary],
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
                      const SizedBox(height: 14),
                      Text(
                        "All Reviews",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.venueName,
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          color: colors.onPrimary.withOpacity(.8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.onPrimary.withOpacity(.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              avgRating.toStringAsFixed(1),
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: colors.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "from ${reviews.length} review${reviews.length != 1 ? 's' : ''}",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 13,
                                color: colors.onPrimary.withOpacity(.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          reviews.isEmpty
              ? SliverFillRemaining(
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
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _reviewCard(context, reviews[i]),
                      childCount: reviews.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _reviewCard(BuildContext context, Map r) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
                Text(
                  r["comment"]?.toString() ?? "",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13,
                    color: colors.onSurface,
                    height: 1.4,
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