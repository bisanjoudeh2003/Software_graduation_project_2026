const bookingGalleryModel = require("../model/bookingGalleryModel");

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
    return mediaUrl
      .replace("/video/upload/", "/video/upload/so_1,w_600,h_600,c_fill/")
      .replace(/\.(mp4|mov|webm|avi|mkv)$/i, ".jpg");
  }

  if (mediaType === "image") {
    return mediaUrl.replace(
      "/image/upload/",
      "/image/upload/w_600,h_600,c_fill,q_auto/"
    );
  }

  return mediaUrl;
};
exports.createOrGetGallery = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { title, description, estimated_delivery_date } = req.body;

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
        title:
          title ||
          `${booking.session_type || "Session"} Gallery`,
        description: description || null,
        estimated_delivery_date: estimated_delivery_date || null,
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
          status: gallery.status,
          estimated_delivery_date: gallery.estimated_delivery_date,
          delivered_at: gallery.delivered_at,
          archive_at: gallery.archive_at,
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

    return res.status(201).json({
      message: "Files uploaded successfully.",
      items: insertedItems,
    });
  } catch (err) {
    console.error("uploadGalleryPhotos error:", err);
    return res.status(500).json({
      message: "Server error",
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

    const totalItems = await bookingGalleryModel.countGalleryItems(galleryId);

    if (totalItems === 0) {
      return res.status(400).json({
        message: "You cannot deliver an empty gallery. Please upload photos first.",
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

    await bookingGalleryModel.deleteGalleryItem(itemId);

    return res.status(200).json({
      message: "Photo removed from gallery successfully.",
    });
  } catch (err) {
    console.error("deleteGalleryItem error:", err);
    return res.status(500).json({
      message: "Server error",
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

    if (item.gallery_status !== "delivered" && item.gallery_status !== "finalized") {
      return res.status(400).json({
        message: "You can select favorites only after the gallery is delivered.",
      });
    }

    const favoriteValue =
      is_favorite === true ||
      is_favorite === 1 ||
      is_favorite === "1";

    await bookingGalleryModel.updateGalleryItemFavorite(itemId, favoriteValue);

    const updatedItem = await bookingGalleryModel.getGalleryItemById(itemId);

    return res.status(200).json({
      message: favoriteValue
        ? "Added to favorites."
        : "Removed from favorites.",
      item: updatedItem,
    });
  } catch (err) {
    console.error("toggleFavoriteItem error:", err);
    return res.status(500).json({
      message: "Server error",
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

    const allowedStatuses = ["delivered", "finalized", "revision_requested"];

    if (!allowedStatuses.includes(item.gallery_status)) {
      return res.status(400).json({
        message: "You can request edits only after the gallery is delivered.",
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
    });
  }
};