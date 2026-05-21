const db = require("../config/db");

// ─────────────────────────────────────────────
// Create request
// ─────────────────────────────────────────────

const createPrintRequest = async ({
  galleryId,
  bookingId,
  clientId,
  photographerId,
  printSize,
  quantity,
  notes,
}) => {
  const [result] = await db.query(
    `INSERT INTO print_requests
      (gallery_id, booking_id, client_id, photographer_id, print_size, quantity, notes, status)
     VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')`,
    [
      galleryId,
      bookingId,
      clientId,
      photographerId, // photographers.photographer_id
      printSize,
      quantity,
      notes || null,
    ]
  );

  return result.insertId;
};

const addPrintRequestItems = async (printRequestId, itemIds) => {
  if (!itemIds || itemIds.length === 0) return;

  const values = itemIds.map((itemId) => [printRequestId, itemId]);

  await db.query(
    `INSERT INTO print_request_items
      (print_request_id, gallery_item_id)
     VALUES ?`,
    [values]
  );
};

// ─────────────────────────────────────────────
// Validation queries
// ─────────────────────────────────────────────

const getGalleryForPrintRequest = async (galleryId, clientId) => {
  const [rows] = await db.query(
    `SELECT
       g.id AS gallery_id,
       g.booking_id,
       g.client_id,

       g.photographer_id AS photographer_profile_id,
       p.user_id AS photographer_user_id,

       g.status AS gallery_status,

       b.total_price,
       b.deposit_amount,
       b.remaining_amount,
       b.remaining_paid,
       b.remaining_payment_status

     FROM booking_galleries g
     JOIN photographer_bookings b ON g.booking_id = b.id
     JOIN photographers p ON g.photographer_id = p.photographer_id
     WHERE g.id = ?
       AND g.client_id = ?
     LIMIT 1`,
    [galleryId, clientId]
  );

  return rows[0];
};

const getValidGalleryItemsForClient = async ({
  galleryId,
  clientId,
  itemIds,
}) => {
  if (!itemIds || itemIds.length === 0) return [];

  const [rows] = await db.query(
    `SELECT
       i.id,
       i.gallery_id,
       i.media_type,
       i.media_url,
       i.thumbnail_url,
       i.version_type,
       i.is_final
     FROM booking_gallery_items i
     JOIN booking_galleries g ON i.gallery_id = g.id
     WHERE i.gallery_id = ?
       AND g.client_id = ?
       AND i.id IN (?)`,
    [galleryId, clientId, itemIds]
  );

  return rows;
};

// ─────────────────────────────────────────────
// Fetch one request
// ─────────────────────────────────────────────

const getPrintRequestById = async (requestId) => {
  const [rows] = await db.query(
    `SELECT
       pr.*,

       c.full_name AS client_name,
       c.profile_image AS client_image,

       ph.user_id AS photographer_user_id,
       pu.full_name AS photographer_name,
       pu.profile_image AS photographer_image

     FROM print_requests pr
     LEFT JOIN users c ON pr.client_id = c.id
     LEFT JOIN photographers ph ON pr.photographer_id = ph.photographer_id
     LEFT JOIN users pu ON ph.user_id = pu.id
     WHERE pr.id = ?
     LIMIT 1`,
    [requestId]
  );

  return rows[0];
};

// ─────────────────────────────────────────────
// Fetch requests lists
// ─────────────────────────────────────────────

const getPrintRequestsForClient = async (clientId) => {
  const [rows] = await db.query(
    `SELECT
       pr.*,
       g.title AS gallery_title,

       ph.user_id AS photographer_user_id,
       pu.full_name AS photographer_name,
       pu.profile_image AS photographer_image,

       COUNT(pri.id) AS items_count
     FROM print_requests pr
     JOIN booking_galleries g ON pr.gallery_id = g.id
     JOIN photographers ph ON pr.photographer_id = ph.photographer_id
     JOIN users pu ON ph.user_id = pu.id
     LEFT JOIN print_request_items pri ON pr.id = pri.print_request_id
     WHERE pr.client_id = ?
     GROUP BY pr.id
     ORDER BY pr.created_at DESC, pr.id DESC`,
    [clientId]
  );

  return rows;
};

const getPrintRequestsForPhotographer = async (photographerUserId) => {
  const [rows] = await db.query(
    `SELECT
       pr.*,
       g.title AS gallery_title,

       u.full_name AS client_name,
       u.profile_image AS client_image,

       COUNT(pri.id) AS items_count
     FROM print_requests pr
     JOIN booking_galleries g ON pr.gallery_id = g.id
     JOIN users u ON pr.client_id = u.id
     JOIN photographers p ON pr.photographer_id = p.photographer_id
     LEFT JOIN print_request_items pri ON pr.id = pri.print_request_id
     WHERE p.user_id = ?
     GROUP BY pr.id
     ORDER BY
       CASE pr.status
         WHEN 'pending' THEN 0
         WHEN 'accepted' THEN 1
         WHEN 'printed' THEN 2
         WHEN 'ready_for_pickup' THEN 3
         WHEN 'completed' THEN 4
         WHEN 'rejected' THEN 5
         ELSE 6
       END,
       pr.created_at DESC,
       pr.id DESC`,
    [photographerUserId]
  );

  return rows;
};

const getPrintRequestsForGallery = async (galleryId, userId, role) => {
  let whereClause = "pr.gallery_id = ?";
  const params = [galleryId];

  if (role === "client") {
    whereClause += " AND pr.client_id = ?";
    params.push(userId);
  }

  if (role === "photographer") {
    whereClause += " AND ph.user_id = ?";
    params.push(userId);
  }

  const [rows] = await db.query(
    `SELECT
       pr.*,

       c.full_name AS client_name,
       c.profile_image AS client_image,

       ph.user_id AS photographer_user_id,
       pu.full_name AS photographer_name,
       pu.profile_image AS photographer_image,

       COUNT(pri.id) AS items_count
     FROM print_requests pr
     LEFT JOIN users c ON pr.client_id = c.id
     LEFT JOIN photographers ph ON pr.photographer_id = ph.photographer_id
     LEFT JOIN users pu ON ph.user_id = pu.id
     LEFT JOIN print_request_items pri ON pr.id = pri.print_request_id
     WHERE ${whereClause}
     GROUP BY pr.id
     ORDER BY pr.created_at DESC, pr.id DESC`,
    params
  );

  return rows;
};

// ─────────────────────────────────────────────
// Request items
// ─────────────────────────────────────────────

const getPrintRequestItems = async (printRequestId) => {
  const [rows] = await db.query(
    `SELECT
       pri.id AS print_request_item_id,
       pri.print_request_id,

       i.id,
       i.gallery_id,
       i.title,
       i.description,
       i.original_url,
       i.media_url,
       i.thumbnail_url,
       i.watermarked_url,
       i.media_type,
       i.filter_name,
       i.edit_status,
       i.version_type,
       i.version_number,
       i.parent_item_id,
       i.is_final,
       i.uploaded_at

     FROM print_request_items pri
     JOIN booking_gallery_items i ON pri.gallery_item_id = i.id
     WHERE pri.print_request_id = ?
     ORDER BY pri.id ASC`,
    [printRequestId]
  );

  return rows;
};

// ─────────────────────────────────────────────
// Status update
// ─────────────────────────────────────────────

const updatePrintRequestStatus = async ({
  requestId,
  photographerId,
  status,
}) => {
  // photographerId here is req.user.id, not photographers.photographer_id
  const [result] = await db.query(
    `UPDATE print_requests pr
     JOIN photographers p ON pr.photographer_id = p.photographer_id
     SET pr.status = ?
     WHERE pr.id = ?
       AND p.user_id = ?`,
    [status, requestId, photographerId]
  );

  return result.affectedRows > 0;
};

module.exports = {
  createPrintRequest,
  addPrintRequestItems,

  getGalleryForPrintRequest,
  getValidGalleryItemsForClient,

  getPrintRequestById,
  getPrintRequestsForClient,
  getPrintRequestsForPhotographer,
  getPrintRequestsForGallery,
  getPrintRequestItems,

  updatePrintRequestStatus,
};