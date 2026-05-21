const db = require("../config/db");

const MAX_REVISION_ATTEMPTS = 2;

const getGalleryForClient = async (galleryId, clientId) => {
  const [rows] = await db.query(
    `SELECT
       id,
       booking_id,
       photographer_id,
       client_id,
       status
     FROM booking_galleries
     WHERE id = ?
       AND client_id = ?
     LIMIT 1`,
    [galleryId, clientId]
  );

  return rows[0] || null;
};

const getItemsForBulkRevision = async ({ galleryId, itemIds }) => {
  if (!Array.isArray(itemIds) || itemIds.length === 0) return [];

  const placeholders = itemIds.map(() => "?").join(",");

  const [rows] = await db.query(
    `SELECT
       i.id AS selected_item_id,
       i.gallery_id,
       i.media_type,
       i.version_type,
       i.parent_item_id,
       COALESCE(i.parent_item_id, i.id) AS root_item_id,

       (
         SELECT COUNT(*)
         FROM booking_gallery_item_revision_requests rr_count
         WHERE rr_count.item_id = COALESCE(i.parent_item_id, i.id)
       ) AS revision_count,

       (
         SELECT rr_latest.id
         FROM booking_gallery_item_revision_requests rr_latest
         WHERE rr_latest.item_id = COALESCE(i.parent_item_id, i.id)
         ORDER BY rr_latest.id DESC
         LIMIT 1
       ) AS latest_request_id,

       (
         SELECT rr_latest.status
         FROM booking_gallery_item_revision_requests rr_latest
         WHERE rr_latest.item_id = COALESCE(i.parent_item_id, i.id)
         ORDER BY rr_latest.id DESC
         LIMIT 1
       ) AS latest_revision_status

     FROM booking_gallery_items i
     WHERE i.gallery_id = ?
       AND i.id IN (${placeholders})`,
    [galleryId, ...itemIds]
  );

  return rows;
};

const createRevisionRequestsForItems = async ({
  galleryId,
  clientId,
  note,
  items,
}) => {
  if (!Array.isArray(items) || items.length === 0) {
    return {
      createdRequestIds: [],
      createdCount: 0,
    };
  }

  const connection = await db.getConnection();

  try {
    await connection.beginTransaction();

    const createdRequestIds = [];

    for (const item of items) {
      const rootItemId = item.root_item_id;
      const revisionCount = Number(item.revision_count || 0);
      const roundNumber = revisionCount + 1;
      const parentRequestId = item.latest_request_id || null;

      const [result] = await connection.query(
        `INSERT INTO booking_gallery_item_revision_requests
           (
             item_id,
             gallery_id,
             client_id,
             note,
             status,
             requested_at,
             updated_at,
             round_number,
             parent_request_id
           )
         VALUES (?, ?, ?, ?, 'pending', NOW(), NOW(), ?, ?)`,
        [
          rootItemId,
          galleryId,
          clientId,
          note,
          roundNumber,
          parentRequestId,
        ]
      );

      createdRequestIds.push(result.insertId);
    }

    await connection.query(
      `UPDATE booking_galleries
       SET status = CASE
          WHEN status IN ('finalized', 'archived') THEN status
          ELSE 'revision_requested'
       END,
       updated_at = NOW()
       WHERE id = ?`,
      [galleryId]
    );

    await connection.commit();

    return {
      createdRequestIds,
      createdCount: createdRequestIds.length,
    };
  } catch (err) {
    await connection.rollback();
    throw err;
  } finally {
    connection.release();
  }
};

const getRevisionRequestsForPhotographerBulk = async ({
  requestIds,
  photographerUserId,
}) => {
  if (!Array.isArray(requestIds) || requestIds.length === 0) return [];

  const placeholders = requestIds.map(() => "?").join(",");

  const [rows] = await db.query(
    `SELECT
       rr.id AS request_id,
       rr.item_id,
       rr.gallery_id,
       rr.client_id,
       rr.note,
       rr.status,
       rr.round_number,
       rr.photographer_response,

       g.booking_id,
       g.photographer_id,
       g.status AS gallery_status,

       i.id AS original_item_id,
       i.original_url,
       i.media_url,
       i.thumbnail_url,
       i.cloudinary_public_id,
       i.media_type,
       i.version_type,
       i.parent_item_id

     FROM booking_gallery_item_revision_requests rr
     JOIN booking_galleries g
       ON g.id = rr.gallery_id
     JOIN photographers p
       ON p.photographer_id = g.photographer_id
     JOIN booking_gallery_items i
       ON i.id = rr.item_id
     WHERE rr.id IN (${placeholders})
       AND p.user_id = ?`,
    [...requestIds, photographerUserId]
  );

  return rows;
};

module.exports = {
  MAX_REVISION_ATTEMPTS,
  getGalleryForClient,
  getItemsForBulkRevision,
  createRevisionRequestsForItems,
  getRevisionRequestsForPhotographerBulk,
};