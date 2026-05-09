const bookingGalleryModel = require("../model/bookingGalleryModel");
const crypto = require("crypto");

const WATERMARK_LOGO_PUBLIC_ID = "water_mark";

function isTruthy(value) {
  return (
    value === true ||
    value === 1 ||
    value === "1" ||
    value === "true" ||
    value === "TRUE"
  );
}

function isCloudinaryUrl(url) {
  return typeof url === "string" && url.includes("res.cloudinary.com");
}

function overlayPublicId(publicId) {
  return publicId.replace(/\//g, ":");
}

function addLogoWatermarkToCloudinaryUrl(mediaUrl, mediaType = "image") {
  if (!mediaUrl || !isCloudinaryUrl(mediaUrl)) {
    return mediaUrl;
  }

  const overlayId = overlayPublicId(WATERMARK_LOGO_PUBLIC_ID);

  if (mediaUrl.includes(`l_${overlayId}`)) {
    return mediaUrl;
  }

  const transformation =
    `l_${overlayId},fl_relative,w_0.28,o_95/` +
    `fl_layer_apply,g_north_west,x_0.03,y_0.03/`;

  const uploadPart =
    mediaType === "video" ? "/video/upload/" : "/image/upload/";

  if (mediaUrl.includes(uploadPart)) {
    return mediaUrl.replace(uploadPart, `${uploadPart}${transformation}`);
  }

  if (mediaUrl.includes("/upload/")) {
    return mediaUrl.replace("/upload/", `/upload/${transformation}`);
  }

  return mediaUrl;
}

const getMediaType = (file) => {
  const originalName = file.originalname || "";
  const mimetype = file.mimetype || "";
  const path = file.path || "";

  const ext = originalName.split(".").pop().toLowerCase();

  const videoExtensions = ["mp4", "mov", "avi", "mkv", "webm"];

  const isVideo =
    mimetype.startsWith("video") ||
    videoExtensions.includes(ext) ||
    path.includes("/video/upload/") ||
    path.toLowerCase().endsWith(".mp4") ||
    path.toLowerCase().endsWith(".mov") ||
    path.toLowerCase().endsWith(".webm");

  return isVideo ? "video" : "image";
};

const getThumbnailUrl = (mediaUrl, mediaType) => {
  if (!mediaUrl) return mediaUrl;

  if (mediaType === "video") {
    if (!mediaUrl.includes("/video/upload/")) return mediaUrl;

    return mediaUrl
      .replace("/video/upload/", "/video/upload/so_1,w_600,h_600,c_fill,f_jpg/")
      .replace(/\.(mp4|mov|webm|avi|mkv)$/i, ".jpg");
  }

  if (mediaType === "image") {
    if (!mediaUrl.includes("/image/upload/")) return mediaUrl;

    return mediaUrl.replace(
      "/image/upload/",
      "/image/upload/w_600,h_600,c_fill,q_auto/"
    );
  }

  return mediaUrl;
};

const normalizeDate = (value) => {
  if (!value || value === "null" || value === "undefined") return null;
  return value;
};

const normalizeBool = (value, fallback = 0) => {
  if (value === undefined || value === null || value === "") return fallback;
  return isTruthy(value) ? 1 : 0;
};

exports.createOrGetGallery = async (req, res) => {
  try {
    const { bookingId } = req.params;

    const {
      title,
      description,
      estimated_delivery_date,
      allow_download,
      preview_watermarked,
    } = req.body;

    const booking =
      await bookingGalleryModel.getCompletedBookingForPhotographer(
        bookingId,
        req.user.id
      );

    if (!booking) {
      return res.status(404).json({
        message:
          "Completed booking not found, or you are not authorized to create a gallery for it.",
      });
    }

    let gallery = await bookingGalleryModel.getGalleryByBookingId(bookingId);

    if (!gallery) {
      await bookingGalleryModel.createGallery({
        booking_id: booking.booking_id,
        photographer_id: booking.photographer_id,
        client_id: booking.client_id,
        title: title || `${booking.session_type || "Session"} Gallery`,
        description: description || null,
        estimated_delivery_date: normalizeDate(estimated_delivery_date),
        allow_download: normalizeBool(allow_download, 0),
        preview_watermarked: normalizeBool(preview_watermarked, 0),
      });

      gallery = await bookingGalleryModel.getGalleryByBookingId(bookingId);
    }

    const items = await bookingGalleryModel.getGalleryItems(gallery.id);

    return res.status(200).json({
      message: "Gallery ready",
      gallery,
      items,
    });
  } catch (err) {
    console.error("createOrGetGallery error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.updateGallerySettings = async (req, res) => {
  try {
    const { galleryId } = req.params;

    const gallery = await bookingGalleryModel.photographerOwnsGallery(
      galleryId,
      req.user.id
    );

    if (!gallery) {
      return res.status(403).json({
        message: "Not authorized to update this gallery.",
      });
    }

    if (gallery.status === "finalized" || gallery.status === "archived") {
      return res.status(400).json({
        message: "Finalized or archived galleries cannot be edited.",
      });
    }

    const updates = {};

    if (req.body.title !== undefined) {
      updates.title = req.body.title || null;
    }

    if (req.body.description !== undefined) {
      updates.description = req.body.description || null;
    }

    if (req.body.estimated_delivery_date !== undefined) {
      updates.estimated_delivery_date = normalizeDate(
        req.body.estimated_delivery_date
      );
    }

    if (req.body.allow_download !== undefined) {
      updates.allow_download = normalizeBool(req.body.allow_download, 0);
    }

    if (req.body.preview_watermarked !== undefined) {
      updates.preview_watermarked = normalizeBool(
        req.body.preview_watermarked,
        0
      );
    }

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({
        message: "No valid fields to update.",
      });
    }

    await bookingGalleryModel.updateGallerySettings(galleryId, updates);

    const updatedGallery = await bookingGalleryModel.getGalleryById(galleryId);
    const items = await bookingGalleryModel.getGalleryItems(galleryId);

    return res.status(200).json({
      message: "Gallery settings updated successfully.",
      gallery: updatedGallery,
      items,
    });
  } catch (err) {
    console.error("updateGallerySettings error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.getMyGalleries = async (req, res) => {
  try {
    const galleries = await bookingGalleryModel.getMyGalleries(req.user.id);

    return res.status(200).json({
      galleries,
    });
  } catch (err) {
    console.error("getMyGalleries error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.getGalleryByBooking = async (req, res) => {
  try {
    const { bookingId } = req.params;

    const booking = await bookingGalleryModel.getAuthorizedBooking(
      bookingId,
      req.user
    );

    if (!booking) {
      return res.status(403).json({
        message: "Not authorized to view this gallery.",
      });
    }

    const gallery = await bookingGalleryModel.getGalleryByBookingId(bookingId);

    if (!gallery) {
      return res.status(404).json({
        message: "No gallery has been created for this booking yet.",
      });
    }

    if (req.user.role === "client" && gallery.status === "draft") {
      return res.status(200).json({
        message: "Gallery is not delivered yet.",
        gallery: {
          id: gallery.id,
          booking_id: gallery.booking_id,
          title: gallery.title,
          description: gallery.description,
          cover_image: gallery.cover_image,
          status: gallery.status,
          estimated_delivery_date: gallery.estimated_delivery_date,
          delivered_at: gallery.delivered_at,
          archive_at: gallery.archive_at,
          allow_download: gallery.allow_download,
          preview_watermarked: gallery.preview_watermarked,
        },
        items: [],
      });
    }

    const items = await bookingGalleryModel.getGalleryItems(gallery.id);

    return res.status(200).json({
      gallery,
      items,
    });
  } catch (err) {
    console.error("getGalleryByBooking error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.uploadGalleryPhotos = async (req, res) => {
  try {
    const { galleryId } = req.params;

    const gallery = await bookingGalleryModel.photographerOwnsGallery(
      galleryId,
      req.user.id
    );

    if (!gallery) {
      return res.status(403).json({
        message: "Not authorized to upload photos to this gallery.",
      });
    }

    if (gallery.status !== "draft" && gallery.status !== "revision_requested") {
      return res.status(400).json({
        message:
          "You can upload photos only while the gallery is in draft or revision mode.",
      });
    }

    if (!req.files || req.files.length === 0) {
      return res.status(400).json({
        message: "Please upload at least one photo or video.",
      });
    }

    let sortOrder = await bookingGalleryModel.getMaxSortOrder(galleryId);
    const insertedItems = [];

    for (const file of req.files) {
      sortOrder += 1;

      const mediaUrl = file.path;
      const publicId = file.filename;
      const mediaType = getMediaType(file);
      const thumbnailUrl = getThumbnailUrl(mediaUrl, mediaType);

      const result = await bookingGalleryModel.addGalleryItem({
        gallery_id: galleryId,
        original_url: mediaUrl,
        media_url: mediaUrl,
        thumbnail_url: thumbnailUrl,
        cloudinary_public_id: publicId,
        media_type: mediaType,
        sort_order: sortOrder,
      });

      insertedItems.push({
        id: result.insertId,
        media_url: mediaUrl,
        original_url: mediaUrl,
        thumbnail_url: thumbnailUrl,
        cloudinary_public_id: publicId,
        media_type: mediaType,
        sort_order: sortOrder,
      });
    }

    if (insertedItems.length > 0) {
      await bookingGalleryModel.updateGalleryCoverIfEmpty(
        galleryId,
        insertedItems[0].thumbnail_url || insertedItems[0].media_url
      );
    }

    const updatedGallery = await bookingGalleryModel.getGalleryById(galleryId);
    const items = await bookingGalleryModel.getGalleryItems(galleryId);

    return res.status(201).json({
      message: "Files uploaded successfully.",
      gallery: updatedGallery,
      items,
    });
  } catch (err) {
    console.error("uploadGalleryPhotos error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.deliverGallery = async (req, res) => {
  try {
    const { galleryId } = req.params;

    const gallery = await bookingGalleryModel.photographerOwnsGallery(
      galleryId,
      req.user.id
    );

    if (!gallery) {
      return res.status(403).json({
        message: "Not authorized to deliver this gallery.",
      });
    }

    if (gallery.status !== "draft" && gallery.status !== "revision_requested") {
      return res.status(400).json({
        message: "Only draft or revision galleries can be delivered.",
      });
    }

    if (!gallery.estimated_delivery_date) {
      return res.status(400).json({
        message:
          "Please set the estimated delivery date before delivering the gallery.",
      });
    }

    const totalItems = await bookingGalleryModel.countGalleryItems(galleryId);

    if (totalItems === 0) {
      return res.status(400).json({
        message:
          "You cannot deliver an empty gallery. Please upload photos first.",
      });
    }

    await bookingGalleryModel.deliverGallery(galleryId);

    const updatedGallery = await bookingGalleryModel.getGalleryById(galleryId);
    const items = await bookingGalleryModel.getGalleryItems(galleryId);

    return res.status(200).json({
      message: "Gallery delivered successfully.",
      gallery: updatedGallery,
      items,
    });
  } catch (err) {
    console.error("deliverGallery error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.deleteGalleryItem = async (req, res) => {
  try {
    const { itemId } = req.params;

    const item = await bookingGalleryModel.photographerOwnsGalleryItem(
      itemId,
      req.user.id
    );

    if (!item) {
      return res.status(403).json({
        message: "Not authorized to delete this photo.",
      });
    }

    if (
      item.gallery_status === "finalized" ||
      item.gallery_status === "archived"
    ) {
      return res.status(400).json({
        message: "Finalized or archived gallery items cannot be deleted.",
      });
    }

    await bookingGalleryModel.deleteGalleryItem(itemId);

    return res.status(200).json({
      message: "Photo removed from gallery successfully.",
    });
  } catch (err) {
    console.error("deleteGalleryItem error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.toggleFavoriteItem = async (req, res) => {
  try {
    const { itemId } = req.params;
    const { is_favorite } = req.body;

    const item = await bookingGalleryModel.clientOwnsGalleryItem(
      itemId,
      req.user.id
    );

    if (!item) {
      return res.status(403).json({
        message: "Not authorized to update this item.",
      });
    }

    if (
      item.gallery_status !== "delivered" &&
      item.gallery_status !== "finalized"
    ) {
      return res.status(400).json({
        message: "You can select favorites only after the gallery is delivered.",
      });
    }

    const favoriteValue =
      is_favorite === true || is_favorite === 1 || is_favorite === "1";

    await bookingGalleryModel.updateGalleryItemFavorite(itemId, favoriteValue);

    const updatedItem = await bookingGalleryModel.getGalleryItemById(itemId);

    return res.status(200).json({
      message: favoriteValue ? "Added to favorites." : "Removed from favorites.",
      item: updatedItem,
    });
  } catch (err) {
    console.error("toggleFavoriteItem error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.requestItemRevision = async (req, res) => {
  try {
    const { itemId } = req.params;
    const { note } = req.body;

    const cleanNote = (note || "").trim();

    if (!cleanNote) {
      return res.status(400).json({
        message: "Revision note is required.",
      });
    }

    if (cleanNote.length < 3) {
      return res.status(400).json({
        message: "Revision note is too short.",
      });
    }

    const item = await bookingGalleryModel.clientOwnsDeliveredGalleryItem(
      itemId,
      req.user.id
    );

    if (!item) {
      return res.status(403).json({
        message: "Not authorized to request edits for this item.",
      });
    }

    const allowedStatuses = ["delivered", "revision_requested"];

    if (!allowedStatuses.includes(item.gallery_status)) {
      return res.status(400).json({
        message: "You can request edits only before the gallery is finalized.",
      });
    }

    const originalItemId = item.parent_item_id || item.id;

    const activeRequest =
      await bookingGalleryModel.getActiveRevisionRequestForItem(originalItemId);

    if (activeRequest) {
      return res.status(400).json({
        message:
          "There is already a pending edit request for this file. Please wait for the photographer to upload the edited version.",
      });
    }

    const totalRequests =
      await bookingGalleryModel.countRevisionRequestsForItem(originalItemId);

    if (totalRequests >= 2) {
      return res.status(400).json({
        message:
          "You have reached the maximum number of edit requests for this file.",
      });
    }

    const latestRequest =
      await bookingGalleryModel.getLatestRevisionRequestByItem(originalItemId);

    const roundNumber = totalRequests + 1;

    const result = await bookingGalleryModel.createItemRevisionRequest({
      item_id: originalItemId,
      gallery_id: item.gallery_id,
      client_id: req.user.id,
      note: cleanNote,
      round_number: roundNumber,
      parent_request_id: latestRequest?.id || null,
    });

    await bookingGalleryModel.updateGalleryStatusToRevisionRequested(
      item.gallery_id
    );

    const revisionRequest =
      await bookingGalleryModel.getLatestRevisionRequestByItem(originalItemId);

    const updatedItem = await bookingGalleryModel.getGalleryItemById(
      originalItemId
    );

    return res.status(201).json({
      message: "Revision request sent successfully.",
      request: revisionRequest,
      item: {
        ...updatedItem,
        revision_request_id: result.insertId,
        revision_note: cleanNote,
        revision_status: "pending",
        revision_requested_at: revisionRequest?.requested_at || null,
        revision_round_number: roundNumber,
      },
    });
  } catch (err) {
    console.error("requestItemRevision error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.uploadEditedVersion = async (req, res) => {
  try {
    const { requestId } = req.params;
    const { photographer_response } = req.body;

    const revisionRequest =
      await bookingGalleryModel.getRevisionRequestForPhotographer(
        requestId,
        req.user.id
      );

    if (!revisionRequest) {
      return res.status(403).json({
        message: "Not authorized to upload an edited version for this request.",
      });
    }

    if (
      revisionRequest.status !== "pending" &&
      revisionRequest.status !== "in_progress"
    ) {
      return res.status(400).json({
        message: "This revision request is already completed.",
      });
    }

    if (!req.file) {
      return res.status(400).json({
        message: "Please upload the edited photo or video.",
      });
    }

    const mediaUrl = req.file.path;
    const publicId = req.file.filename;
    const mediaType = getMediaType(req.file);
    const thumbnailUrl = getThumbnailUrl(mediaUrl, mediaType);

    const originalItemId = revisionRequest.item_id;

    const maxVersionNumber =
      await bookingGalleryModel.getMaxVersionNumberForItem(originalItemId);

    const nextVersionNumber = maxVersionNumber + 1;

    let sortOrder = await bookingGalleryModel.getMaxSortOrder(
      revisionRequest.gallery_id
    );

    sortOrder += 1;

    const result = await bookingGalleryModel.addEditedGalleryItem({
      gallery_id: revisionRequest.gallery_id,
      original_url: mediaUrl,
      media_url: mediaUrl,
      thumbnail_url: thumbnailUrl,
      cloudinary_public_id: publicId,
      media_type: mediaType,
      sort_order: sortOrder,
      parent_item_id: originalItemId,
      revision_request_id: revisionRequest.id,
      version_number: nextVersionNumber,
    });

    await bookingGalleryModel.markRevisionRequestDone({
      requestId: revisionRequest.id,
      editedItemId: result.insertId,
      photographerResponse: photographer_response || null,
    });

    const editedItem = await bookingGalleryModel.getGalleryItemById(
      result.insertId
    );

    return res.status(201).json({
      message: "Edited version uploaded successfully.",
      item: editedItem,
      request: {
        ...revisionRequest,
        status: "done",
        edited_item_id: result.insertId,
        photographer_response: photographer_response || null,
      },
    });
  } catch (err) {
    console.error("uploadEditedVersion error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.finalizeGallery = async (req, res) => {
  try {
    const { galleryId } = req.params;

    const gallery = await bookingGalleryModel.clientOwnsGallery(
      galleryId,
      req.user.id
    );

    if (!gallery) {
      return res.status(403).json({
        message: "Not authorized to finalize this gallery.",
      });
    }

    if (gallery.status === "finalized") {
      const items = await bookingGalleryModel.getGalleryItems(galleryId);

      return res.status(200).json({
        message: "Gallery is already finalized.",
        gallery,
        items,
      });
    }

    if (gallery.status === "archived") {
      return res.status(400).json({
        message: "Archived gallery cannot be finalized.",
      });
    }

    const allowedStatuses = ["delivered", "revision_requested"];

    if (!allowedStatuses.includes(gallery.status)) {
      return res.status(400).json({
        message: "You can finalize the gallery only after it is delivered.",
      });
    }

    const hasActiveRevision =
      await bookingGalleryModel.hasActiveRevisionRequestsForGallery(galleryId);

    if (hasActiveRevision) {
      return res.status(400).json({
        message:
          "You still have pending edit requests. Please wait until they are completed before finalizing the gallery.",
      });
    }

    await bookingGalleryModel.finalizeGallery(galleryId);

    const updatedGallery = await bookingGalleryModel.getGalleryById(galleryId);
    const items = await bookingGalleryModel.getGalleryItems(galleryId);

    return res.status(200).json({
      message: "Gallery finalized successfully.",
      gallery: updatedGallery,
      items,
    });
  } catch (err) {
    console.error("finalizeGallery error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.createShareLink = async (req, res) => {
  try {
    const { galleryId } = req.params;
    const { allow_download, expires_in_days } = req.body;

    const baseUrl = process.env.PUBLIC_APP_URL;

    if (!baseUrl) {
      return res.status(500).json({
        message: "PUBLIC_APP_URL is not configured on the server.",
      });
    }

    const gallery = await bookingGalleryModel.clientOwnsGallery(
      galleryId,
      req.user.id
    );

    if (!gallery) {
      return res.status(403).json({
        message: "Not authorized to share this gallery.",
      });
    }

    if (gallery.status !== "finalized") {
      return res.status(400).json({
        message: "Only finalized galleries can be shared.",
      });
    }

    const days = Number(expires_in_days || 7);
    const safeDays = [7, 14, 30, 60].includes(days) ? days : 7;

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + safeDays);

    const token = crypto.randomBytes(32).toString("hex");

    const requestedAllowDownload =
      allow_download === true ||
      allow_download === 1 ||
      allow_download === "1" ||
      allow_download === "true";

    const finalAllowDownload =
      requestedAllowDownload && Number(gallery.allow_download) === 1;

    const result = await bookingGalleryModel.createGalleryShareLink({
      gallery_id: gallery.id,
      client_id: req.user.id,
      token,
      allow_download: finalAllowDownload,
      expires_at: expiresAt,
    });

    return res.status(201).json({
      message: "Share link created successfully.",
      share: {
        id: result.insertId,
        token,
        expires_at: expiresAt,
        allow_download: finalAllowDownload,
      },
      share_url: `${baseUrl}/#/shared-gallery/${token}`,
    });
  } catch (err) {
    console.error("createShareLink error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.getSharedGallery = async (req, res) => {
  try {
    const { token } = req.params;

    const share = await bookingGalleryModel.getShareLinkByToken(token);

    if (!share) {
      return res.status(404).json({
        message: "Share link not found.",
      });
    }

    if (share.revoked_at) {
      return res.status(403).json({
        message: "This share link has been revoked.",
      });
    }

    if (share.expires_at && new Date(share.expires_at) < new Date()) {
      return res.status(403).json({
        message: "This share link has expired.",
      });
    }

    const gallery = await bookingGalleryModel.getGalleryById(share.gallery_id);

    if (!gallery || gallery.status !== "finalized") {
      return res.status(403).json({
        message: "This gallery is not available for sharing.",
      });
    }

    const items = await bookingGalleryModel.getGalleryItems(gallery.id);

    return res.status(200).json({
      gallery: {
        id: gallery.id,
        title: gallery.title,
        description: gallery.description,
        cover_image: gallery.cover_image,
        status: gallery.status,
        finalized_at: gallery.finalized_at,
        archive_at: gallery.archive_at,
        allow_download: gallery.allow_download,
        preview_watermarked: gallery.preview_watermarked,
      },
      share: {
        id: share.id,
        allow_download: share.allow_download,
        expires_at: share.expires_at,
      },
      items,
    });
  } catch (err) {
    console.error("getSharedGallery error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.revokeShareLink = async (req, res) => {
  try {
    const { shareId } = req.params;

    const share = await bookingGalleryModel.getShareLinkForClient(
      shareId,
      req.user.id
    );

    if (!share) {
      return res.status(403).json({
        message: "Not authorized to revoke this share link.",
      });
    }

    await bookingGalleryModel.revokeShareLink(shareId);

    return res.status(200).json({
      message: "Share link revoked successfully.",
    });
  } catch (err) {
    console.error("revokeShareLink error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.requestPortfolioPermission = async (req, res) => {
  try {
    const { itemId } = req.params;

    const item =
      await bookingGalleryModel.photographerOwnsPortfolioPermissionItem(
        itemId,
        req.user.id
      );

    if (!item) {
      return res.status(403).json({
        message: "Not authorized to request portfolio permission for this item.",
      });
    }

    if (item.gallery_status !== "finalized") {
      return res.status(400).json({
        message:
          "Portfolio permission can be requested only after gallery is finalized.",
      });
    }

    if (item.portfolio_item_id) {
      return res.status(400).json({
        message: "This item is already added to portfolio.",
      });
    }

    if (item.portfolio_permission_status === "pending") {
      return res.status(400).json({
        message: "Portfolio permission is already pending.",
      });
    }

    if (item.portfolio_permission_status === "approved") {
      return res.status(400).json({
        message: "This item is already approved for portfolio.",
      });
    }

    if (item.portfolio_permission_status === "rejected") {
      return res.status(400).json({
        message: "The client rejected portfolio permission for this item.",
      });
    }

    await bookingGalleryModel.updatePortfolioPermissionStatus(itemId, "pending");

    const updatedItem = await bookingGalleryModel.getGalleryItemById(itemId);

    return res.status(200).json({
      message: "Portfolio permission request sent successfully.",
      item: updatedItem,
    });
  } catch (err) {
    console.error("requestPortfolioPermission error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.respondPortfolioPermission = async (req, res) => {
  try {
    const { itemId } = req.params;
    const { status } = req.body;

    const allowedStatuses = ["approved", "rejected"];

    if (!allowedStatuses.includes(status)) {
      return res.status(400).json({
        message: "Invalid portfolio permission response.",
      });
    }

    const item = await bookingGalleryModel.clientOwnsPortfolioPermissionItem(
      itemId,
      req.user.id
    );

    if (!item) {
      return res.status(403).json({
        message: "Not authorized to respond to this portfolio request.",
      });
    }

    if (item.portfolio_permission_status !== "pending") {
      return res.status(400).json({
        message:
          "There is no pending portfolio permission request for this item.",
      });
    }

    await bookingGalleryModel.updatePortfolioPermissionStatus(itemId, status);

    const updatedItem = await bookingGalleryModel.getGalleryItemById(itemId);

    return res.status(200).json({
      message:
        status === "rejected"
          ? "Portfolio permission rejected."
          : "Portfolio permission approved.",
      item: updatedItem,
    });
  } catch (err) {
    console.error("respondPortfolioPermission error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.addGalleryItemToPortfolio = async (req, res) => {
  try {
    const { itemId } = req.params;
    const { album_id, category_id, title, description, use_watermark } =
      req.body;

    const item =
      await bookingGalleryModel.photographerOwnsPortfolioPermissionItem(
        itemId,
        req.user.id
      );

    if (!item) {
      return res.status(403).json({
        message: "Not authorized to add this item to portfolio.",
      });
    }

    if (item.gallery_status !== "finalized") {
      return res.status(400).json({
        message: "Only finalized gallery items can be added to portfolio.",
      });
    }

    if (item.portfolio_permission_status !== "approved") {
      return res.status(400).json({
        message:
          "Client approval is required before adding this item to portfolio.",
      });
    }

    const alreadyAdded =
      await bookingGalleryModel.itemAlreadyAddedToPortfolio(itemId);

    if (alreadyAdded) {
      return res.status(400).json({
        message: "This item is already added to portfolio.",
      });
    }

    const portfolio =
      await bookingGalleryModel.getPhotographerPortfolioByUserId(req.user.id);

    if (!portfolio) {
      return res.status(404).json({
        message: "Photographer portfolio was not found.",
      });
    }

    const mediaType = item.media_type || "image";
    const wantsWatermark = isTruthy(use_watermark);
    const originalMediaUrl = item.original_url || item.media_url || "";

    if (!originalMediaUrl) {
      return res.status(400).json({
        message: "Gallery item media URL is missing.",
      });
    }

    const portfolioMediaUrl = wantsWatermark
      ? addLogoWatermarkToCloudinaryUrl(originalMediaUrl, mediaType)
      : originalMediaUrl;

    const portfolioThumbnailUrl =
      mediaType === "video"
        ? item.thumbnail_url || getThumbnailUrl(originalMediaUrl, "video")
        : portfolioMediaUrl;

    const result = await bookingGalleryModel.createPortfolioItemFromGallery({
      portfolio_id: portfolio.id,
      album_id: album_id || null,
      category_id: category_id || null,
      title: title || item.title || "Gallery Item",
      description: description || item.description || null,
      media_url: portfolioMediaUrl,
      original_media_url: originalMediaUrl,
      media_type: mediaType,
      thumbnail_url: portfolioThumbnailUrl,
      use_watermark: wantsWatermark ? 1 : 0,
    });

    await bookingGalleryModel.linkGalleryItemToPortfolioItem(
      itemId,
      result.insertId
    );

    const updatedItem = await bookingGalleryModel.getGalleryItemById(itemId);

    return res.status(201).json({
      message: "Item added to portfolio successfully.",
      portfolio_item_id: result.insertId,
      media_url: portfolioMediaUrl,
      original_media_url: originalMediaUrl,
      use_watermark: wantsWatermark ? 1 : 0,
      item: updatedItem,
    });
  } catch (err) {
    console.error("addGalleryItemToPortfolio error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.getPortfolioOptions = async (req, res) => {
  try {
    const options =
      await bookingGalleryModel.getPortfolioOptionsForPhotographer(req.user.id);

    if (!options) {
      return res.status(404).json({
        message: "Photographer portfolio was not found.",
      });
    }

    return res.status(200).json(options);
  } catch (err) {
    console.error("getPortfolioOptions error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};
exports.getClientGalleries = async (req, res) => {
  try {
    const galleries = await bookingGalleryModel.getClientGalleries(req.user.id);

    return res.status(200).json({
      galleries,
    });
  } catch (err) {
    console.error("getClientGalleries error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.requestCleanCopy = async (req, res) => {
  try {
    const galleryId = req.params.galleryId;
    const clientId = req.user.id;

    const gallery = await bookingGalleryModel.requestCleanCopy(
      galleryId,
      clientId
    );

    if (!gallery) {
      return res.status(404).json({
        message: "Gallery not found.",
      });
    }

    return res.status(200).json({
      message: "Clean copy request sent to the photographer.",
      gallery,
    });
  } catch (err) {
    console.error("requestCleanCopy error:", err);

    return res.status(err.statusCode || 500).json({
      message: err.message || "Server error",
    });
  }
};

exports.respondCleanCopy = async (req, res) => {
  try {
    const galleryId = req.params.galleryId;
    const photographerId = req.user.id;
    const { status } = req.body;

    const gallery = await bookingGalleryModel.respondCleanCopy(
      galleryId,
      photographerId,
      status
    );

    if (!gallery) {
      return res.status(404).json({
        message: "Gallery not found.",
      });
    }

    return res.status(200).json({
      message:
        status === "approved"
          ? "Clean copy approved. Watermark is now disabled for this gallery."
          : "Clean copy request rejected.",
      gallery,
    });
  } catch (err) {
    console.error("respondCleanCopy error:", err);

    return res.status(err.statusCode || 500).json({
      message: err.message || "Server error",
    });
  }
};