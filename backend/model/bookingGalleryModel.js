const db = require("../config/db");

const REMAINING_AMOUNT_SQL = `
  CASE
    WHEN b.remaining_amount IS NULL OR b.remaining_amount <= 0
    THEN GREATEST(COALESCE(b.total_price, 0) - COALESCE(b.deposit_amount, 0), 0)
    ELSE b.remaining_amount
  END
`;



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
    `SELECT
       g.*,

       b.total_price,
       b.deposit_amount,
       ${REMAINING_AMOUNT_SQL} AS remaining_amount,
       b.remaining_paid,
       b.remaining_paid_at,
       b.remaining_payment_status,
       b.remaining_stripe_payment_intent_id

     FROM booking_galleries g
     JOIN photographer_bookings b ON g.booking_id = b.id
     WHERE g.booking_id = ?
     LIMIT 1`,
    [bookingId]
  );

  return rows[0];
};
const getGalleryById = async (galleryId) => {
  const [rows] = await db.query(
    `SELECT
       g.*,

       b.total_price,
       b.deposit_amount,
       ${REMAINING_AMOUNT_SQL} AS remaining_amount,
       b.remaining_paid,
       b.remaining_paid_at,
       b.remaining_payment_status,
       b.remaining_stripe_payment_intent_id

     FROM booking_galleries g
     JOIN photographer_bookings b ON g.booking_id = b.id
     WHERE g.id = ?
     LIMIT 1`,
    [galleryId]
  );

  return rows[0];
};;

const createGallery = async ({
  booking_id,
  photographer_id,
  client_id,
  title,
  description,
  estimated_delivery_date,
  allow_download,
  preview_watermarked,
}) => {
  const [result] = await db.query(
    `INSERT INTO booking_galleries
       (
        booking_id,
        photographer_id,
        client_id,
        title,
        description,
        estimated_delivery_date,
        allow_download,
        preview_watermarked,
        status
       )
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'draft')`,
    [
      booking_id,
      photographer_id,
      client_id,
      title || null,
      description || null,
      estimated_delivery_date || null,
      allow_download ? 1 : 0,
      preview_watermarked ? 1 : 0,
    ]
  );

  return result;
};

const updateGallerySettings = async (galleryId, updates) => {
  const allowedFields = [
    "title",
    "description",
    "estimated_delivery_date",
    "allow_download",
    "preview_watermarked",
  ];

  const fields = [];
  const values = [];

  Object.keys(updates).forEach((key) => {
    if (allowedFields.includes(key)) {
      fields.push(`${key} = ?`);
      values.push(updates[key]);
    }
  });

  if (fields.length === 0) {
    return { affectedRows: 0 };
  }

  values.push(galleryId);

  const [result] = await db.query(
    `UPDATE booking_galleries
     SET ${fields.join(", ")},
         updated_at = NOW()
     WHERE id = ?`,
    values
  );

  return result;
};
const getMyGalleries = async (userId) => {
  const [rows] = await db.query(
    `SELECT
       g.id,
       g.booking_id,
       g.photographer_id,
       g.client_id,
       g.title,
       g.description,
       g.cover_image,
       g.status,
       g.estimated_delivery_date,
       g.delivered_at,
       g.finalized_at,
       g.archive_at,
       g.allow_download,
       g.preview_watermarked,
       g.clean_copy_requested,
       g.clean_copy_status,
       g.clean_copy_requested_at,
       g.clean_copy_responded_at,
       g.created_at,
       g.updated_at,

       b.id AS booking_id,
       b.session_type,
       b.date AS session_date,
       b.time AS session_time,
       b.status AS booking_status,
       b.location AS session_location,

       b.total_price,
       b.deposit_amount,
      ${REMAINING_AMOUNT_SQL} AS remaining_amount,
       b.remaining_paid,
       b.remaining_paid_at,
       b.remaining_payment_status,

       COALESCE(client_user.full_name, 'Client') AS client_name,
       client_user.profile_image AS client_profile_image,

       (
         SELECT COUNT(*)
         FROM booking_gallery_items i
         WHERE i.gallery_id = g.id
       ) AS files_count,

       (
         SELECT COUNT(*)
         FROM booking_gallery_items i
         WHERE i.gallery_id = g.id
           AND i.is_favorite = 1
       ) AS favorites_count,

       (
         SELECT COUNT(*)
         FROM booking_gallery_item_revision_requests rr
         WHERE rr.gallery_id = g.id
       ) AS revisions_count

     FROM booking_galleries g
     JOIN photographer_bookings b ON g.booking_id = b.id
     JOIN photographers p ON g.photographer_id = p.photographer_id
     LEFT JOIN users client_user ON g.client_id = client_user.id
     WHERE p.user_id = ?
     ORDER BY g.updated_at DESC, g.created_at DESC`,
    [userId]
  );

  return rows;
};

const getGalleryItems = async (galleryId) => {
  const [rows] = await db.query(
    `SELECT
       i.*,
       g.status AS gallery_status,
       g.booking_id,
       g.client_id,
       g.photographer_id,
       g.estimated_delivery_date,
       g.delivered_at,
       g.finalized_at,
       g.archive_at,
       g.allow_download,
       g.preview_watermarked,

       COALESCE(i.parent_item_id, i.id) AS root_item_id,

       COALESCE(rr_direct.id, rr_latest.id) AS revision_request_id,
       COALESCE(rr_direct.note, rr_latest.note) AS revision_note,
       COALESCE(rr_direct.status, rr_latest.status) AS revision_status,
       COALESCE(rr_direct.requested_at, rr_latest.requested_at) AS revision_requested_at,
       COALESCE(rr_direct.round_number, rr_latest.round_number) AS revision_round_number,
       COALESCE(rr_direct.edited_item_id, rr_latest.edited_item_id) AS revision_edited_item_id,

       COALESCE(rr_direct.edit_type, rr_latest.edit_type) AS revision_edit_type,
       COALESCE(rr_direct.custom_edit_type, rr_latest.custom_edit_type) AS revision_custom_edit_type,
       COALESCE(rr_direct.checklist_json, rr_latest.checklist_json) AS revision_checklist_json,
       COALESCE(rr_direct.photographer_response, rr_latest.photographer_response) AS revision_photographer_response,
       COALESCE(rr_direct.workspace_updated_at, rr_latest.workspace_updated_at) AS revision_workspace_updated_at,
COALESCE(rr_direct.ai_suggestion_reason, rr_latest.ai_suggestion_reason) AS revision_ai_suggestion_reason,
COALESCE(rr_direct.ai_suggested_preset, rr_latest.ai_suggested_preset) AS revision_ai_suggested_preset,
COALESCE(rr_direct.ai_suggested_intensity, rr_latest.ai_suggested_intensity) AS revision_ai_suggested_intensity,
COALESCE(rr_direct.ai_detected_issue, rr_latest.ai_detected_issue) AS revision_ai_detected_issue,
       rr_latest.id AS latest_revision_request_id,
       rr_latest.note AS latest_revision_note,
       rr_latest.status AS latest_revision_status,
       rr_latest.round_number AS latest_revision_round_number,
       rr_latest.edited_item_id AS latest_revision_edited_item_id,

       rr_latest.edit_type AS latest_revision_edit_type,
       rr_latest.custom_edit_type AS latest_revision_custom_edit_type,
       rr_latest.checklist_json AS latest_revision_checklist_json,
       rr_latest.photographer_response AS latest_revision_photographer_response,
       rr_latest.workspace_updated_at AS latest_revision_workspace_updated_at,
       rr_latest.ai_suggestion_reason AS latest_revision_ai_suggestion_reason,
rr_latest.ai_suggested_preset AS latest_revision_ai_suggested_preset,
rr_latest.ai_suggested_intensity AS latest_revision_ai_suggested_intensity,
rr_latest.ai_detected_issue AS latest_revision_ai_detected_issue,

       (
         SELECT COUNT(*)
         FROM booking_gallery_items edited
         WHERE edited.parent_item_id = COALESCE(i.parent_item_id, i.id)
       ) AS edited_versions_count,

       (
         SELECT COUNT(*)
         FROM booking_gallery_item_revision_requests req_count
         WHERE req_count.item_id = COALESCE(i.parent_item_id, i.id)
       ) AS revision_requests_count

     FROM booking_gallery_items i
     JOIN booking_galleries g ON i.gallery_id = g.id

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
     ) rr_latest 
       ON rr_latest.item_id = COALESCE(i.parent_item_id, i.id)

     WHERE i.gallery_id = ?
     ORDER BY 
       COALESCE(i.parent_item_id, i.id) ASC,
       i.version_number ASC,
       i.id ASC`,
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
    `SELECT 
       i.*,
       g.status AS gallery_status,
       g.booking_id,
       g.client_id,
       g.photographer_id
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
    `SELECT 
       i.*,
       g.status AS gallery_status,
       g.booking_id,
       g.client_id,
       g.photographer_id,
       g.estimated_delivery_date,
       g.delivered_at,
       g.finalized_at,
       g.archive_at,
       g.allow_download,
       g.preview_watermarked
     FROM booking_gallery_items i
     JOIN booking_galleries g ON i.gallery_id = g.id
     WHERE i.id = ?
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
       AND status IN ('delivered', 'revision_requested')`,
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
  filter_name = null,
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
        filter_name,
        edit_status,
        sort_order,
        parent_item_id,
        revision_request_id,
        version_number,
        version_type,
        is_final
       )
     VALUES (?, ?, ?, ?, ?, ?, ?, 'edited', ?, ?, ?, ?, 'edited', 0)`,
    [
      gallery_id,
      original_url || null,
      media_url,
      thumbnail_url || null,
      cloudinary_public_id || null,
      media_type || "image",
      filter_name || null,
      sort_order || 0,
      parent_item_id,
      revision_request_id,
      version_number,
    ]
  );

  return result;
};
const updateRevisionWorkspacePlan = async ({
  requestId,
  editType,
  customEditType,
  checklistJson,
  photographerResponse,
  aiSuggestionReason = null,
  aiSuggestedPreset = null,
  aiSuggestedIntensity = null,
  aiDetectedIssue = null,
}) => {
  const [result] = await db.query(
    `UPDATE booking_gallery_item_revision_requests
     SET edit_type = ?,
         custom_edit_type = ?,
         checklist_json = ?,
         photographer_response = ?,
         ai_suggestion_reason = ?,
         ai_suggested_preset = ?,
         ai_suggested_intensity = ?,
         ai_detected_issue = ?,
         workspace_updated_at = NOW(),
         updated_at = NOW()
     WHERE id = ?`,
    [
      editType || null,
      customEditType || null,
      checklistJson ? JSON.stringify(checklistJson) : null,
      photographerResponse || null,
      aiSuggestionReason || null,
      aiSuggestedPreset || null,
      aiSuggestedIntensity || null,
      aiDetectedIssue || null,
      requestId,
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
const updateRevisionRequestStatus = async ({
  requestId,
  status,
  completedAt = null,
}) => {
  const [result] = await db.query(
    `UPDATE booking_gallery_item_revision_requests
     SET status = ?,
         completed_at = ?,
         updated_at = NOW()
     WHERE id = ?`,
    [status, completedAt, requestId]
  );

  return result;
};
const clientOwnsGallery = async (galleryId, userId) => {
  const [rows] = await db.query(
    `SELECT
       g.*,

       b.total_price,
       b.deposit_amount,
       ${REMAINING_AMOUNT_SQL} AS remaining_amount,
       b.remaining_paid,
       b.remaining_paid_at,
       b.remaining_payment_status,
       b.remaining_stripe_payment_intent_id

     FROM booking_galleries g
     JOIN photographer_bookings b ON g.booking_id = b.id
     WHERE g.id = ?
       AND g.client_id = ?
     LIMIT 1`,
    [galleryId, userId]
  );

  return rows[0];
};
const hasActiveRevisionRequestsForGallery = async (galleryId) => {
  const [rows] = await db.query(
    `SELECT COUNT(*) AS total
     FROM booking_gallery_item_revision_requests
     WHERE gallery_id = ?
       AND status IN ('pending', 'in_progress')`,
    [galleryId]
  );

  return Number(rows[0]?.total || 0) > 0;
};
const finalizeGallery = async (galleryId) => {
  const [result] = await db.query(
    `UPDATE booking_galleries
     SET status = 'finalized',
         finalized_at = NOW(),
         updated_at = NOW()
     WHERE id = ?`,
    [galleryId]
  );

  return result;
};

const createGalleryShareLink = async ({
  gallery_id,
  client_id,
  token,
  allow_download,
  expires_at,
}) => {
  const [result] = await db.query(
    `INSERT INTO gallery_share_links
       (gallery_id, client_id, token, allow_download, expires_at)
     VALUES (?, ?, ?, ?, ?)`,
    [
      gallery_id,
      client_id,
      token,
      allow_download ? 1 : 0,
      expires_at || null,
    ]
  );

  return result;
};

const getShareLinkByToken = async (token) => {
  const [rows] = await db.query(
    `SELECT *
     FROM gallery_share_links
     WHERE token = ?
     LIMIT 1`,
    [token]
  );

  return rows[0];
};

const getShareLinkForClient = async (shareId, userId) => {
  const [rows] = await db.query(
    `SELECT *
     FROM gallery_share_links
     WHERE id = ?
       AND client_id = ?
     LIMIT 1`,
    [shareId, userId]
  );

  return rows[0];
};

const revokeShareLink = async (shareId) => {
  const [result] = await db.query(
    `UPDATE gallery_share_links
     SET revoked_at = NOW()
     WHERE id = ?`,
    [shareId]
  );

  return result;
};

const updatePortfolioPermissionStatus = async (itemId, status) => {
  const [result] = await db.query(
    `UPDATE booking_gallery_items
     SET portfolio_permission_status = ?
     WHERE id = ?`,
    [status, itemId]
  );

  return result;
};

const clientOwnsPortfolioPermissionItem = async (itemId, userId) => {
  const [rows] = await db.query(
    `SELECT
       i.*,
       g.id AS gallery_id,
       g.client_id,
       g.photographer_id,
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

const photographerOwnsPortfolioPermissionItem = async (itemId, userId) => {
  const [rows] = await db.query(
    `SELECT
       i.*,
       g.id AS gallery_id,
       g.client_id,
       g.photographer_id,
       g.status AS gallery_status,
       p.user_id AS photographer_user_id
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

const linkGalleryItemToPortfolioItem = async (itemId, portfolioItemId) => {
  const [result] = await db.query(
    `UPDATE booking_gallery_items
     SET portfolio_item_id = ?
     WHERE id = ?`,
    [portfolioItemId, itemId]
  );

  return result;
};

const getPhotographerPortfolioByUserId = async (userId) => {
  const [rows] = await db.query(
    `SELECT 
       pf.*
     FROM photographer_portfolios pf
     JOIN photographers p ON pf.photographer_id = p.photographer_id
     WHERE p.user_id = ?
     LIMIT 1`,
    [userId]
  );

  return rows[0];
};

const createPortfolioItemFromGallery = async ({
  portfolio_id,
  album_id,
  category_id,
  title,
  description,
  media_url,
  original_media_url,
  media_type,
  thumbnail_url,
  use_watermark,
}) => {
  const [result] = await db.query(
    `INSERT INTO portfolio_items
       (
        portfolio_id,
        album_id,
        category_id,
        title,
        description,
        media_url,
        original_media_url,
        media_type,
        thumbnail_url,
        use_watermark
       )
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      portfolio_id,
      album_id || null,
      category_id || null,
      title || null,
      description || null,
      media_url,
      original_media_url || media_url,
      media_type || "image",
      thumbnail_url || null,
      use_watermark ? 1 : 0,
    ]
  );

  return result;
};

const itemAlreadyAddedToPortfolio = async (itemId) => {
  const [rows] = await db.query(
    `SELECT portfolio_item_id
     FROM booking_gallery_items
     WHERE id = ?
       AND portfolio_item_id IS NOT NULL
     LIMIT 1`,
    [itemId]
  );

  return rows[0];
};

const getPortfolioOptionsForPhotographer = async (userId) => {
  const portfolio = await getPhotographerPortfolioByUserId(userId);

  if (!portfolio) {
    return null;
  }

  const [albums] = await db.query(
    `SELECT 
       id,
       title
     FROM portfolio_albums
     WHERE portfolio_id = ?
     ORDER BY title ASC`,
    [portfolio.id]
  );

  const [categories] = await db.query(
    `SELECT 
       id,
       name AS title
     FROM portfolio_categories
     WHERE portfolio_id = ?
     ORDER BY name ASC`,
    [portfolio.id]
  );

  return {
    portfolio: {
      id: portfolio.id,
      photographer_id: portfolio.photographer_id,
    },
    albums,
    categories,
  };
};
const getClientGalleries = async (userId) => {
  const [rows] = await db.query(
    `SELECT
       g.id,
       g.booking_id,
       g.photographer_id,
       g.client_id,
       g.title,
       g.description,
       g.cover_image,
       g.status,
       g.estimated_delivery_date,
       g.delivered_at,
       g.finalized_at,
       g.archive_at,
       g.allow_download,
       g.preview_watermarked,
       g.clean_copy_requested,
       g.clean_copy_status,
       g.clean_copy_requested_at,
       g.clean_copy_responded_at,
       g.created_at,
       g.updated_at,

       b.id AS booking_id,
       b.session_type,
       b.date AS session_date,
       b.time AS session_time,
       b.status AS booking_status,
       b.location AS session_location,

       b.total_price,
       b.deposit_amount,
     ${REMAINING_AMOUNT_SQL} AS remaining_amount,
       b.remaining_paid,
       b.remaining_paid_at,
       b.remaining_payment_status,

       photographer_user.full_name AS photographer_name,
       photographer_user.profile_image AS photographer_profile_image,

       (
         SELECT COUNT(*)
         FROM booking_gallery_items i
         WHERE i.gallery_id = g.id
       ) AS files_count,

       (
         SELECT COUNT(*)
         FROM booking_gallery_items i
         WHERE i.gallery_id = g.id
           AND i.is_favorite = 1
       ) AS favorites_count,

       (
         SELECT COUNT(*)
         FROM booking_gallery_item_revision_requests rr
         WHERE rr.gallery_id = g.id
       ) AS revisions_count

     FROM booking_galleries g
     JOIN photographer_bookings b ON g.booking_id = b.id
     JOIN photographers p ON g.photographer_id = p.photographer_id
     JOIN users photographer_user ON p.user_id = photographer_user.id
     WHERE g.client_id = ?
     ORDER BY g.updated_at DESC, g.created_at DESC`,
    [userId]
  );

  return rows;
};

const requestCleanCopy = async (galleryId, clientId) => {
  const [rows] = await db.query(
    `SELECT
       g.*,
       b.remaining_amount,
       b.remaining_paid,
       b.remaining_payment_status
     FROM booking_galleries g
     JOIN photographer_bookings b ON g.booking_id = b.id
     WHERE g.id = ?
       AND g.client_id = ?
     LIMIT 1`,
    [galleryId, clientId]
  );

  if (rows.length === 0) {
    return null;
  }

  const gallery = rows[0];

  if (gallery.status !== "finalized") {
    const error = new Error(
      "Clean copy can only be requested after finalizing the gallery."
    );
    error.statusCode = 400;
    throw error;
  }

  const remainingAmount = Number(gallery.remaining_amount || 0);
  const remainingPaid = Number(gallery.remaining_paid || 0) === 1;

  if (remainingAmount > 0 && !remainingPaid) {
    const error = new Error(
      "You must pay the remaining balance before requesting a clean copy."
    );
    error.statusCode = 400;
    throw error;
  }

  if (gallery.clean_copy_status === "pending") {
    const error = new Error("Clean copy request is already pending.");
    error.statusCode = 400;
    throw error;
  }

  if (gallery.clean_copy_status === "approved") {
    const error = new Error("Clean copy is already approved.");
    error.statusCode = 400;
    throw error;
  }

  await db.query(
    `UPDATE booking_galleries
     SET clean_copy_requested = 1,
         clean_copy_status = 'pending',
         clean_copy_requested_at = NOW(),
         updated_at = NOW()
     WHERE id = ?`,
    [galleryId]
  );

  return await getGalleryById(galleryId);
};

const respondCleanCopy = async (galleryId, userId, status) => {
  if (status !== "approved" && status !== "rejected") {
    const error = new Error("Invalid clean copy response.");
    error.statusCode = 400;
    throw error;
  }

  const [photographerRows] = await db.query(
    `SELECT photographer_id
     FROM photographers
     WHERE user_id = ?
     LIMIT 1`,
    [userId]
  );

  if (photographerRows.length === 0) {
    const error = new Error("Photographer profile not found.");
    error.statusCode = 404;
    throw error;
  }

  const photographerId = photographerRows[0].photographer_id;

  const [rows] = await db.query(
    `SELECT
       g.*,
       b.remaining_amount,
       b.remaining_paid,
       b.remaining_payment_status
     FROM booking_galleries g
     JOIN photographer_bookings b ON g.booking_id = b.id
     WHERE g.id = ?
       AND g.photographer_id = ?
     LIMIT 1`,
    [galleryId, photographerId]
  );

  if (rows.length === 0) {
    return null;
  }

  const gallery = rows[0];

  if (gallery.status !== "finalized") {
    const error = new Error(
      "Clean copy can only be handled after the gallery is finalized."
    );
    error.statusCode = 400;
    throw error;
  }

  const remainingAmount = Number(gallery.remaining_amount || 0);
  const remainingPaid = Number(gallery.remaining_paid || 0) === 1;

  if (remainingAmount > 0 && !remainingPaid) {
    const error = new Error(
      "The client must pay the remaining balance before clean copy can be approved."
    );
    error.statusCode = 400;
    throw error;
  }

  if (gallery.clean_copy_status !== "pending") {
    const error = new Error("There is no pending clean copy request.");
    error.statusCode = 400;
    throw error;
  }

  if (status === "approved") {
    await db.query(
      `UPDATE booking_galleries
       SET clean_copy_status = 'approved',
           clean_copy_responded_at = NOW(),
           preview_watermarked = 0,
           updated_at = NOW()
       WHERE id = ?`,
      [galleryId]
    );
  } else {
    await db.query(
      `UPDATE booking_galleries
       SET clean_copy_status = 'rejected',
           clean_copy_responded_at = NOW(),
           updated_at = NOW()
       WHERE id = ?`,
      [galleryId]
    );
  }

  return await getGalleryById(galleryId);
};


const getGalleryWithBookingPaymentById = async (galleryId, clientId) => {
  const [rows] = await db.query(
    `SELECT
       g.*,
       b.total_price,
       b.deposit_amount,
       ${REMAINING_AMOUNT_SQL} AS remaining_amount,
       b.remaining_paid,
       b.remaining_paid_at,
       b.remaining_payment_status,
       b.remaining_stripe_payment_intent_id
     FROM booking_galleries g
     JOIN photographer_bookings b ON g.booking_id = b.id
     WHERE g.id = ?
       AND g.client_id = ?
     LIMIT 1`,
    [galleryId, clientId]
  );

  return rows[0];
};
const getGalleryPaymentInfoForClient = async (galleryId, clientId) => {
  const [rows] = await db.query(
    `SELECT
       g.id AS gallery_id,
       g.booking_id,
       g.client_id,
       g.photographer_id,
       g.status AS gallery_status,
       g.allow_download,
       g.preview_watermarked,

       b.total_price,
       b.deposit_amount,
       ${REMAINING_AMOUNT_SQL} AS remaining_amount,
       b.remaining_paid,
       b.remaining_paid_at,
       b.remaining_payment_status,
       b.remaining_stripe_payment_intent_id
     FROM booking_galleries g
     JOIN photographer_bookings b ON g.booking_id = b.id
     WHERE g.id = ?
       AND g.client_id = ?
     LIMIT 1`,
    [galleryId, clientId]
  );

  return rows[0];
};

const markRemainingPaymentProcessing = async ({
  bookingId,
  clientId,
  paymentIntentId,
}) => {
  const [result] = await db.query(
    `UPDATE photographer_bookings
     SET remaining_payment_status = 'processing',
         remaining_stripe_payment_intent_id = ?,
         updated_at = NOW()
     WHERE id = ?
       AND client_id = ?
       AND remaining_paid = 0`,
    [paymentIntentId, bookingId, clientId]
  );

  return result;
};

const markRemainingPaymentPaid = async ({
  bookingId,
  clientId,
  paymentIntentId,
}) => {
  const [result] = await db.query(
    `UPDATE photographer_bookings
     SET remaining_paid = 1,
         remaining_paid_at = NOW(),
         remaining_payment_status = 'paid',
         remaining_stripe_payment_intent_id = ?,
         updated_at = NOW()
     WHERE id = ?
       AND client_id = ?`,
    [paymentIntentId, bookingId, clientId]
  );

  return result;
};

module.exports = {
  getCompletedBookingForPhotographer,
  getAuthorizedBooking,
  getGalleryByBookingId,
  getGalleryById,
  createGallery,
  updateGallerySettings,
  getMyGalleries,
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
  clientOwnsGallery,
  hasActiveRevisionRequestsForGallery,
  finalizeGallery,
  createGalleryShareLink,
  getShareLinkByToken,
  getShareLinkForClient,
  revokeShareLink,
  updatePortfolioPermissionStatus,
  clientOwnsPortfolioPermissionItem,
  photographerOwnsPortfolioPermissionItem,
  linkGalleryItemToPortfolioItem,
  getPhotographerPortfolioByUserId,
  createPortfolioItemFromGallery,
  itemAlreadyAddedToPortfolio,
  getPortfolioOptionsForPhotographer,
  getClientGalleries,
  requestCleanCopy,
  respondCleanCopy,
  getGalleryWithBookingPaymentById,
getGalleryPaymentInfoForClient,
markRemainingPaymentProcessing,
markRemainingPaymentPaid,
updateRevisionRequestStatus,
updateRevisionWorkspacePlan,
};

