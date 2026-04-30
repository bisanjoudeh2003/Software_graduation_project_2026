const db = require("../config/db");

const getCompletedBookingForPhotographer = async (bookingId, userId) => {
  const [rows] = await db.query(
    `SELECT 
       b.id AS booking_id,
       b.client_id,
       b.photographer_id,
       b.session_type,
       b.date,
       b.status,
       p.user_id AS photographer_user_id
     FROM photographer_bookings b
     JOIN photographers p ON b.photographer_id = p.photographer_id
     WHERE b.id = ?
       AND p.user_id = ?
       AND b.status = 'completed'`,
    [bookingId, userId]
  );

  return rows[0];
};

const getAuthorizedBooking = async (bookingId, user) => {
  if (user.role === "photographer") {
    const [rows] = await db.query(
      `SELECT 
         b.id AS booking_id,
         b.client_id,
         b.photographer_id,
         b.session_type,
         b.date,
         b.status,
         p.user_id AS photographer_user_id
       FROM photographer_bookings b
       JOIN photographers p ON b.photographer_id = p.photographer_id
       WHERE b.id = ?
         AND p.user_id = ?`,
      [bookingId, user.id]
    );

    return rows[0];
  }

  if (user.role === "client") {
    const [rows] = await db.query(
      `SELECT 
         b.id AS booking_id,
         b.client_id,
         b.photographer_id,
         b.session_type,
         b.date,
         b.status
       FROM photographer_bookings b
       WHERE b.id = ?
         AND b.client_id = ?`,
      [bookingId, user.id]
    );

    return rows[0];
  }

  return null;
};

const getGalleryByBookingId = async (bookingId) => {
  const [rows] = await db.query(
    `SELECT *
     FROM booking_galleries
     WHERE booking_id = ?
     LIMIT 1`,
    [bookingId]
  );

  return rows[0];
};

const getGalleryById = async (galleryId) => {
  const [rows] = await db.query(
    `SELECT *
     FROM booking_galleries
     WHERE id = ?
     LIMIT 1`,
    [galleryId]
  );

  return rows[0];
};

const createGallery = async ({
  booking_id,
  photographer_id,
  client_id,
  title,
  description,
  estimated_delivery_date,
}) => {
  const [result] = await db.query(
    `INSERT INTO booking_galleries
       (booking_id, photographer_id, client_id, title, description, estimated_delivery_date, status)
     VALUES (?, ?, ?, ?, ?, ?, 'draft')`,
    [
      booking_id,
      photographer_id,
      client_id,
      title || null,
      description || null,
      estimated_delivery_date || null,
    ]
  );

  return result;
};

const getGalleryItems = async (galleryId) => {
  const [rows] = await db.query(
    `SELECT
       i.*,

       COALESCE(rr_direct.id, rr_latest.id) AS revision_request_id,
       COALESCE(rr_direct.note, rr_latest.note) AS revision_note,
       COALESCE(rr_direct.status, rr_latest.status) AS revision_status,
       COALESCE(rr_direct.requested_at, rr_latest.requested_at) AS revision_requested_at,
       COALESCE(rr_direct.round_number, rr_latest.round_number) AS revision_round_number,
       COALESCE(rr_direct.edited_item_id, rr_latest.edited_item_id) AS revision_edited_item_id,

       (
         SELECT COUNT(*)
         FROM booking_gallery_items edited
         WHERE edited.parent_item_id = COALESCE(i.parent_item_id, i.id)
       ) AS edited_versions_count

     FROM booking_gallery_items i

     LEFT JOIN booking_gallery_item_revision_requests rr_direct
       ON rr_direct.id = i.revision_request_id

     LEFT JOIN (
       SELECT r1.*
       FROM booking_gallery_item_revision_requests r1
       INNER JOIN (
         SELECT item_id, MAX(id) AS latest_id
         FROM booking_gallery_item_revision_requests
         GROUP BY item_id
       ) latest ON r1.id = latest.latest_id
     ) rr_latest ON rr_latest.item_id = COALESCE(i.parent_item_id, i.id)

     WHERE i.gallery_id = ?
     ORDER BY 
       COALESCE(i.parent_item_id, i.id) ASC,
       i.version_number ASC,
       i.sort_order ASC,
       i.uploaded_at ASC`,
    [galleryId]
  );

  return rows;
};
const addGalleryItem = async ({
  gallery_id,
  original_url,
  media_url,
  thumbnail_url,
  cloudinary_public_id,
  media_type,
  sort_order,
}) => {
  const [result] = await db.query(
    `INSERT INTO booking_gallery_items
       (
        gallery_id,
        original_url,
        media_url,
        thumbnail_url,
        cloudinary_public_id,
        media_type,
        sort_order,
        parent_item_id,
        revision_request_id,
        version_number,
        version_type,
        is_final
       )
     VALUES (?, ?, ?, ?, ?, ?, ?, NULL, NULL, 1, 'original', 0)`,
    [
      gallery_id,
      original_url || null,
      media_url,
      thumbnail_url || null,
      cloudinary_public_id || null,
      media_type || "image",
      sort_order || 0,
    ]
  );

  return result;
};

const getMaxSortOrder = async (galleryId) => {
  const [rows] = await db.query(
    `SELECT COALESCE(MAX(sort_order), 0) AS max_order
     FROM booking_gallery_items
     WHERE gallery_id = ?`,
    [galleryId]
  );

  return rows[0]?.max_order || 0;
};

const updateGalleryCoverIfEmpty = async (galleryId, coverImage) => {
  const [result] = await db.query(
    `UPDATE booking_galleries
     SET cover_image = COALESCE(cover_image, ?),
         updated_at = NOW()
     WHERE id = ?`,
    [coverImage, galleryId]
  );

  return result;
};

const countGalleryItems = async (galleryId) => {
  const [rows] = await db.query(
    `SELECT COUNT(*) AS total
     FROM booking_gallery_items
     WHERE gallery_id = ?`,
    [galleryId]
  );

  return rows[0]?.total || 0;
};

const deliverGallery = async (galleryId) => {
  const [result] = await db.query(
    `UPDATE booking_galleries
     SET status = 'delivered',
         delivered_at = NOW(),
         archive_at = DATE_ADD(NOW(), INTERVAL 60 DAY),
         updated_at = NOW()
     WHERE id = ?`,
    [galleryId]
  );

  return result;
};

const deleteGalleryItem = async (itemId) => {
  const [result] = await db.query(
    `DELETE FROM booking_gallery_items
     WHERE id = ?`,
    [itemId]
  );

  return result;
};

const getGalleryItemWithGallery = async (itemId) => {
  const [rows] = await db.query(
    `SELECT 
       i.*,
       g.booking_id,
       g.photographer_id,
       g.client_id,
       g.status AS gallery_status
     FROM booking_gallery_items i
     JOIN booking_galleries g ON i.gallery_id = g.id
     WHERE i.id = ?
     LIMIT 1`,
    [itemId]
  );

  return rows[0];
};

const photographerOwnsGallery = async (galleryId, userId) => {
  const [rows] = await db.query(
    `SELECT g.*
     FROM booking_galleries g
     JOIN photographers p ON g.photographer_id = p.photographer_id
     WHERE g.id = ?
       AND p.user_id = ?
     LIMIT 1`,
    [galleryId, userId]
  );

  return rows[0];
};

const photographerOwnsGalleryItem = async (itemId, userId) => {
  const [rows] = await db.query(
    `SELECT i.*
     FROM booking_gallery_items i
     JOIN booking_galleries g ON i.gallery_id = g.id
     JOIN photographers p ON g.photographer_id = p.photographer_id
     WHERE i.id = ?
       AND p.user_id = ?
     LIMIT 1`,
    [itemId, userId]
  );

  return rows[0];
};
const clientOwnsGalleryItem = async (itemId, userId) => {
  const [rows] = await db.query(
    `SELECT 
       i.*,
       g.booking_id,
       g.client_id,
       g.status AS gallery_status
     FROM booking_gallery_items i
     JOIN booking_galleries g ON i.gallery_id = g.id
     WHERE i.id = ?
       AND g.client_id = ?
     LIMIT 1`,
    [itemId, userId]
  );

  return rows[0];
};

const updateGalleryItemFavorite = async (itemId, isFavorite) => {
  const [result] = await db.query(
    `UPDATE booking_gallery_items
     SET is_favorite = ?,
         is_selected = ?
     WHERE id = ?`,
    [isFavorite ? 1 : 0, isFavorite ? 1 : 0, itemId]
  );

  return result;
};

const getGalleryItemById = async (itemId) => {
  const [rows] = await db.query(
    `SELECT *
     FROM booking_gallery_items
     WHERE id = ?
     LIMIT 1`,
    [itemId]
  );

  return rows[0];
};


const clientOwnsDeliveredGalleryItem = async (itemId, userId) => {
  const [rows] = await db.query(
    `SELECT 
       i.*,
       g.id AS gallery_id,
       g.booking_id,
       g.client_id,
       g.status AS gallery_status
     FROM booking_gallery_items i
     JOIN booking_galleries g ON i.gallery_id = g.id
     WHERE i.id = ?
       AND g.client_id = ?
     LIMIT 1`,
    [itemId, userId]
  );

  return rows[0];
};

const createItemRevisionRequest = async ({
  item_id,
  gallery_id,
  client_id,
  note,
  round_number,
  parent_request_id,
}) => {
  const [result] = await db.query(
    `INSERT INTO booking_gallery_item_revision_requests
       (
        item_id,
        gallery_id,
        client_id,
        note,
        status,
        round_number,
        parent_request_id
       )
     VALUES (?, ?, ?, ?, 'pending', ?, ?)`,
    [
      item_id,
      gallery_id,
      client_id,
      note,
      round_number || 1,
      parent_request_id || null,
    ]
  );

  return result;
};

const updateGalleryStatusToRevisionRequested = async (galleryId) => {
  const [result] = await db.query(
    `UPDATE booking_galleries
     SET status = 'revision_requested',
         updated_at = NOW()
     WHERE id = ?
       AND status IN ('delivered', 'finalized', 'revision_requested')`,
    [galleryId]
  );

  return result;
};



const getOriginalItemId = (item) => {
  return item.parent_item_id || item.id;
};

const countRevisionRequestsForItem = async (originalItemId) => {
  const [rows] = await db.query(
    `SELECT COUNT(*) AS total
     FROM booking_gallery_item_revision_requests
     WHERE item_id = ?`,
    [originalItemId]
  );

  return rows[0]?.total || 0;
};

const getActiveRevisionRequestForItem = async (originalItemId) => {
  const [rows] = await db.query(
    `SELECT *
     FROM booking_gallery_item_revision_requests
     WHERE item_id = ?
       AND status IN ('pending', 'in_progress')
     ORDER BY id DESC
     LIMIT 1`,
    [originalItemId]
  );

  return rows[0];
};

const getLatestRevisionRequestByItem = async (itemId) => {
  const [rows] = await db.query(
    `SELECT *
     FROM booking_gallery_item_revision_requests
     WHERE item_id = ?
     ORDER BY id DESC
     LIMIT 1`,
    [itemId]
  );

  return rows[0];
};

const getRevisionRequestForPhotographer = async (requestId, userId) => {
  const [rows] = await db.query(
    `SELECT
       rr.*,
       g.id AS gallery_id,
       g.booking_id,
       g.photographer_id,
       g.client_id,
       g.status AS gallery_status,
       i.media_url AS original_media_url,
       i.thumbnail_url AS original_thumbnail_url,
       i.media_type AS original_media_type,
       i.version_type AS original_version_type,
       i.parent_item_id AS original_parent_item_id
     FROM booking_gallery_item_revision_requests rr
     JOIN booking_galleries g ON rr.gallery_id = g.id
     JOIN photographers p ON g.photographer_id = p.photographer_id
     JOIN booking_gallery_items i ON rr.item_id = i.id
     WHERE rr.id = ?
       AND p.user_id = ?
     LIMIT 1`,
    [requestId, userId]
  );

  return rows[0];
};

const getMaxVersionNumberForItem = async (originalItemId) => {
  const [rows] = await db.query(
    `SELECT COALESCE(MAX(version_number), 1) AS max_version
     FROM booking_gallery_items
     WHERE id = ?
        OR parent_item_id = ?`,
    [originalItemId, originalItemId]
  );

  return rows[0]?.max_version || 1;
};

const addEditedGalleryItem = async ({
  gallery_id,
  original_url,
  media_url,
  thumbnail_url,
  cloudinary_public_id,
  media_type,
  sort_order,
  parent_item_id,
  revision_request_id,
  version_number,
}) => {
  const [result] = await db.query(
    `INSERT INTO booking_gallery_items
       (
        gallery_id,
        original_url,
        media_url,
        thumbnail_url,
        cloudinary_public_id,
        media_type,
        sort_order,
        parent_item_id,
        revision_request_id,
        version_number,
        version_type,
        is_final
       )
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'edited', 0)`,
    [
      gallery_id,
      original_url || null,
      media_url,
      thumbnail_url || null,
      cloudinary_public_id || null,
      media_type || "image",
      sort_order || 0,
      parent_item_id,
      revision_request_id,
      version_number,
    ]
  );

  return result;
};

const markRevisionRequestDone = async ({
  requestId,
  editedItemId,
  photographerResponse,
}) => {
  const [result] = await db.query(
    `UPDATE booking_gallery_item_revision_requests
     SET status = 'done',
         edited_item_id = ?,
         photographer_response = ?,
         completed_at = NOW(),
         updated_at = NOW()
     WHERE id = ?`,
    [editedItemId, photographerResponse || null, requestId]
  );

  return result;
};



module.exports = {
  getCompletedBookingForPhotographer,
  getAuthorizedBooking,
  getGalleryByBookingId,
  getGalleryById,
  createGallery,
  getGalleryItems,
  addGalleryItem,
  getMaxSortOrder,
  updateGalleryCoverIfEmpty,
  countGalleryItems,
  deliverGallery,
  deleteGalleryItem,
  getGalleryItemWithGallery,
  photographerOwnsGallery,
  photographerOwnsGalleryItem,
  clientOwnsGalleryItem,
  updateGalleryItemFavorite,
  getGalleryItemById,
  clientOwnsDeliveredGalleryItem,
  createItemRevisionRequest,
  updateGalleryStatusToRevisionRequested,
  getLatestRevisionRequestByItem,
  getOriginalItemId,
  countRevisionRequestsForItem,
  getActiveRevisionRequestForItem,
  getRevisionRequestForPhotographer,
  getMaxVersionNumberForItem,
  addEditedGalleryItem,
  markRevisionRequestDone,
};



