const pool = require("../config/db");

exports.getReports = async (req, res) => {
  try {
    const ownerId = req.user.id;

    // ── Total Stats ──
    const [stats] = await pool.query(
      `SELECT
        COUNT(CASE WHEN vb.status IN ('confirmed','completed') THEN 1 END) as totalBookings,
        COUNT(CASE WHEN vb.status = 'completed' THEN 1 END) as completedBookings,
        COUNT(CASE WHEN vb.status = 'cancelled' THEN 1 END) as cancelledBookings,
        IFNULL(SUM(CASE WHEN vb.deposit_paid = 1 THEN vb.deposit_amount ELSE 0 END), 0) as depositRevenue,
        IFNULL(SUM(CASE WHEN vb.remaining_paid = 1 THEN vb.total_price * 0.7 ELSE 0 END), 0) as remainingRevenue
       FROM venue_bookings vb
       JOIN venues v ON v.id = vb.venue_id
       WHERE v.owner_id = ?`,
      [ownerId]
    );

    // ── Best Venue ──
    const [bestVenue] = await pool.query(
      `SELECT
        v.name,
        COUNT(vb.id) as bookings_count,
        (SELECT image_url FROM venue_images WHERE venue_id = v.id LIMIT 1) as image_url
       FROM venues v
       LEFT JOIN venue_bookings vb ON vb.venue_id = v.id
         AND vb.status IN ('confirmed', 'completed')
       WHERE v.owner_id = ?
       GROUP BY v.id
       ORDER BY bookings_count DESC
       LIMIT 1`,
      [ownerId]
    );

    // ── Monthly Bookings (آخر 6 شهور) ──
    const [monthly] = await pool.query(
      `SELECT
        DATE_FORMAT(vb.booking_date, '%b %Y') as month,
        DATE_FORMAT(vb.booking_date, '%Y-%m') as month_key,
        COUNT(*) as count,
        IFNULL(SUM(vb.deposit_amount), 0) as revenue
       FROM venue_bookings vb
       JOIN venues v ON v.id = vb.venue_id
       WHERE v.owner_id = ?
       AND vb.status IN ('confirmed', 'completed')
       AND vb.booking_date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
       GROUP BY month_key, month
       ORDER BY month_key ASC`,
      [ownerId]
    );

    // ── Venues Performance ──
    const [venues] = await pool.query(
      `SELECT
        v.name,
        COUNT(CASE WHEN vb.status IN ('confirmed','completed') THEN 1 END) as bookings,
        IFNULL(SUM(CASE WHEN vb.deposit_paid = 1 THEN vb.deposit_amount ELSE 0 END), 0) as revenue
       FROM venues v
       LEFT JOIN venue_bookings vb ON vb.venue_id = v.id
       WHERE v.owner_id = ?
       GROUP BY v.id
       ORDER BY bookings DESC`,
      [ownerId]
    );

    const totalRevenue = parseFloat(stats[0].depositRevenue) +
                         parseFloat(stats[0].remainingRevenue);

    res.json({
      totalBookings:    stats[0].totalBookings,
      completedBookings: stats[0].completedBookings,
      cancelledBookings: stats[0].cancelledBookings,
      totalRevenue:     totalRevenue.toFixed(0),
      bestVenue:        bestVenue[0] ?? null,
      monthly,
      venues,
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};