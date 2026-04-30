const db = require("../config/db");

const createReview = async ({
  booking_id,
  photographer_id,
  client_id,
  rating,
  comment,
}) => {
  const [result] = await db.query(
    `INSERT INTO photographer_reviews
     (booking_id, photographer_id, client_id, rating, comment)
     VALUES (?, ?, ?, ?, ?)`,
    [booking_id, photographer_id, client_id, rating, comment]
  );

  return result;
};

const getReviewByBookingId = async (bookingId) => {
  const [rows] = await db.query(
    `SELECT * FROM photographer_reviews WHERE booking_id = ?`,
    [bookingId]
  );
  return rows[0];
};

const getCompletedBookingForReview = async (bookingId, clientId) => {
  const [rows] = await db.query(
    `SELECT pb.*, p.photographer_id
     FROM photographer_bookings pb
     JOIN photographers p ON p.photographer_id = pb.photographer_id
     WHERE pb.id = ?
       AND pb.client_id = ?
       AND pb.status = 'completed'`,
    [bookingId, clientId]
  );

  return rows[0];
};

const updatePhotographerRatingStats = async (photographerId) => {
  const [rows] = await db.query(
    `SELECT 
        COUNT(*) AS rating_count,
        IFNULL(AVG(rating), 0) AS rating_avg
     FROM photographer_reviews
     WHERE photographer_id = ?`,
    [photographerId]
  );

  const ratingCount = rows[0]?.rating_count || 0;
  const ratingAvg = rows[0]?.rating_avg || 0;

  await db.query(
    `UPDATE photographers
     SET rating_count = ?, rating_avg = ?
     WHERE photographer_id = ?`,
    [ratingCount, ratingAvg, photographerId]
  );

  return {
    rating_count: ratingCount,
    rating_avg: Number(ratingAvg),
  };
};

const getPhotographerReviews = async (photographerId) => {
  const [rows] = await db.query(
    `SELECT pr.*, u.full_name, u.profile_image
     FROM photographer_reviews pr
     JOIN users u ON u.id = pr.client_id
     WHERE pr.photographer_id = ?
     ORDER BY pr.created_at DESC`,
    [photographerId]
  );

  return rows;
};

module.exports = {
  createReview,
  getReviewByBookingId,
  getCompletedBookingForReview,
  updatePhotographerRatingStats,
  getPhotographerReviews,
};