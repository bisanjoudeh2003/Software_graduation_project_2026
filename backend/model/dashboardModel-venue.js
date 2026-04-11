const pool = require("../config/db");

exports.getDashboard = async (ownerId) => {

  // ── User info ──
  const [user] = await pool.query(
    `SELECT full_name, profile_image FROM users WHERE id = ?`,
    [ownerId]
  );

  // ── Upcoming Bookings — اقرب 3 ──
  const [rows] = await pool.query(
    `SELECT
      vb.id,
      vb.total_price,
      vb.status,
      vb.deposit_paid,
      vb.deposit_amount,
      vb.remaining_paid,
      vb.booking_date as date,
      vb.start_time,
      vb.end_time,
      v.name as venue_name,
      (SELECT image_url FROM venue_images 
       WHERE venue_id = v.id LIMIT 1) as image_url
     FROM venue_bookings vb
     JOIN venues v ON v.id = vb.venue_id
     WHERE v.owner_id = ?
     AND vb.status IN ('pending', 'confirmed')
     AND vb.booking_date >= CURDATE()
     ORDER BY vb.booking_date ASC, vb.start_time ASC
     LIMIT 3`,
    [ownerId]
  );

  // ── Total Bookings: confirmed + completed ──
  const [totalRows] = await pool.query(
    `SELECT COUNT(*) as totalBookings
     FROM venue_bookings vb
     JOIN venues v ON v.id = vb.venue_id
     WHERE v.owner_id = ?
     AND vb.status IN ('confirmed', 'completed')`,
    [ownerId]
  );

  // ── Revenue = deposits + remaining payments ──
  const [revenueRows] = await pool.query(
    `SELECT 
      IFNULL(SUM(vb.deposit_amount), 0) as totalDeposits,
      IFNULL(SUM(CASE WHEN vb.remaining_paid = 1 
                      THEN vb.total_price * 0.7 
                      ELSE 0 END), 0) as totalRemaining
     FROM venue_bookings vb
     JOIN venues v ON v.id = vb.venue_id
     WHERE v.owner_id = ?
     AND vb.status IN ('confirmed', 'completed')
     AND vb.deposit_paid = 1`,
    [ownerId]
  );

  const totalDeposits  = parseFloat(revenueRows[0]?.totalDeposits ?? 0);
  const totalRemaining = parseFloat(revenueRows[0]?.totalRemaining ?? 0);
  const revenue        = totalDeposits + totalRemaining;

  return {
    name:          user[0]?.full_name ?? "",
    profile_image: user[0]?.profile_image ?? "",
    totalBookings: totalRows[0]?.totalBookings ?? 0,
    revenue:       revenue.toFixed(0),
    bookings: rows.map(b => ({
      ...b,
      date:       b.date?.toString().substring(0, 10),
      start_time: b.start_time?.toString().substring(0, 5),
      end_time:   b.end_time?.toString().substring(0, 5),
    })),
  };
};