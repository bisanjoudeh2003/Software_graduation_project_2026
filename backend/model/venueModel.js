const pool = require("../config/db");

exports.createVenue = async (venue) => {
  const { owner_id, name, description, location, latitude, longitude, price_per_hour, image_url } = venue;
  const [result] = await pool.query(
    `INSERT INTO venues (owner_id,name,description,location,latitude,longitude,price_per_hour,image_url) VALUES (?,?,?,?,?,?,?,?)`,
    [owner_id, name, description, location, latitude, longitude, price_per_hour, image_url]
  );
  const [newVenue] = await pool.query("SELECT * FROM venues WHERE id=?", [result.insertId]);
  return newVenue[0];
};

exports.getOwnerVenues = async (ownerId) => {
  const [rows] = await pool.query(`
    SELECT v.*,
      (SELECT image_url FROM venue_images WHERE venue_id=v.id LIMIT 1) as image_url,
      COUNT(r.id) as reviews_count,
      IFNULL(AVG(r.rating),0) as rating_avg
    FROM venues v
    LEFT JOIN reviews r ON r.venue_id=v.id
    WHERE v.owner_id=?
    GROUP BY v.id
  `, [ownerId]);
  return rows;
};

exports.deleteVenue = async (venueId) => {
  await pool.query("DELETE FROM venues WHERE id=?", [venueId]);
};

// ✅ نسخة وحدة فقط — مع owner_name و owner_image
exports.getVenueDetails = async (venueId) => {
  const [venue] = await pool.query(`
    SELECT v.*,
      COUNT(r.id) as reviews_count,
      IFNULL(AVG(r.rating),0) as rating_avg,
      u.full_name as owner_name,
      u.profile_image as owner_image
    FROM venues v
    LEFT JOIN reviews r ON r.venue_id=v.id
    LEFT JOIN users u ON u.id=v.owner_id
    WHERE v.id=?
    GROUP BY v.id
  `, [venueId]);

  const [images] = await pool.query(
    `SELECT image_url FROM venue_images WHERE venue_id=?`, [venueId]
  );

  const [reviews] = await pool.query(`
    SELECT r.*, u.full_name
    FROM reviews r
    JOIN users u ON u.id=r.client_id
    WHERE r.venue_id=?
    ORDER BY r.created_at DESC
  `, [venueId]);

  return { venue: venue[0], images, reviews };
};

exports.searchVenues = async (query, ownerId) => {
  const search = `%${query}%`;
  const [rows] = await pool.query(`
    SELECT v.*,
      (SELECT image_url FROM venue_images WHERE venue_id=v.id LIMIT 1) as image_url,
      COUNT(r.id) as reviews_count,
      IFNULL(AVG(r.rating),0) as rating_avg
    FROM venues v
    LEFT JOIN reviews r ON r.venue_id=v.id
    WHERE v.owner_id=? AND (v.name LIKE ? OR v.location LIKE ? OR v.description LIKE ?)
    GROUP BY v.id
  `, [ownerId, search, search, search]);
  return rows;
};

exports.updateVenue = async (id, name, description, location, latitude, longitude, price) => {
  await pool.query(`
    UPDATE venues SET name=?, description=?, location=?, latitude=?, longitude=?, price_per_hour=?
    WHERE id=?
  `, [name, description, location, latitude, longitude, price, id]);
};

// ✅ مع owner_name و owner_image
exports.getAllVenues = async () => {
  const [rows] = await pool.query(`
    SELECT v.*,
      (SELECT image_url FROM venue_images WHERE venue_id=v.id LIMIT 1) as image_url,
      COUNT(r.id) as reviews_count,
      IFNULL(AVG(r.rating),0) as rating_avg,
      u.full_name as owner_name,
      u.profile_image as owner_image
    FROM venues v
    LEFT JOIN reviews r ON r.venue_id=v.id
    LEFT JOIN users u ON u.id=v.owner_id
    GROUP BY v.id
  `);
  return rows;
};

exports.searchAllVenues = async (query) => {
  const search = `%${query}%`;
  const [rows] = await pool.query(`
    SELECT v.*,
      (SELECT image_url FROM venue_images WHERE venue_id=v.id LIMIT 1) as image_url,
      COUNT(r.id) as reviews_count,
      IFNULL(AVG(r.rating),0) as rating_avg,
      u.full_name as owner_name,
      u.profile_image as owner_image
    FROM venues v
    LEFT JOIN reviews r ON r.venue_id=v.id
    LEFT JOIN users u ON u.id=v.owner_id
    WHERE v.name LIKE ? OR v.location LIKE ? OR v.description LIKE ?
    GROUP BY v.id
  `, [search, search, search]);
  return rows;
};