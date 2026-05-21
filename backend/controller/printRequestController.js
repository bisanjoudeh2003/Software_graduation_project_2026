const printRequestModel = require("../model/printRequestModel");
const notificationModel = require("../model/notificationModel");

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

const allowedPrintSizes = ["10x15 cm", "13x18 cm", "A4"];

const allowedStatuses = [
  "pending",
  "accepted",
  "printed",
  "ready_for_pickup",
  "completed",
  "rejected",
];

const cleanNumberArray = (items) => {
  if (!Array.isArray(items)) return [];

  return items
    .map((id) => Number(id))
    .filter((id) => Number.isInteger(id) && id > 0);
};

const isRemainingPaid = (gallery) => {
  if (!gallery) return false;

  const remainingPaid =
    gallery.remaining_paid === true ||
    gallery.remaining_paid === 1 ||
    gallery.remaining_paid?.toString() === "1";

  const remainingAmount =
    Number(gallery.remaining_amount || 0) > 0
      ? Number(gallery.remaining_amount || 0)
      : Math.max(
          Number(gallery.total_price || 0) -
            Number(gallery.deposit_amount || 0),
          0
        );

  return remainingAmount <= 0 || remainingPaid;
};

const statusLabel = (status) => {
  return status.replaceAll("_", " ");
};

const statusMessageForClient = (status) => {
  switch (status) {
    case "accepted":
      return "Your print request has been accepted by the photographer.";
    case "printed":
      return "Your printed photos are now marked as printed.";
    case "ready_for_pickup":
      return "Your printed photos are ready. Pickup or delivery will be arranged with the photographer.";
    case "completed":
      return "Your print request has been completed.";
    case "rejected":
      return "Your print request has been rejected by the photographer.";
    default:
      return `Your print request is now ${statusLabel(status)}.`;
  }
};

const safeCreateNotification = async ({
  userId,
  title,
  body,
  type,
  referenceType,
  referenceId,
}) => {
  try {
    if (!userId) return;

    await notificationModel.createNotification(
      userId,
      title,
      body,
      type,
      referenceType,
      referenceId
    );
  } catch (notifyErr) {
    console.error("Print request notification error:", notifyErr.message);
  }
};

// ─────────────────────────────────────────────
// CLIENT: Create print request
// POST /api/print-requests
// ─────────────────────────────────────────────

exports.createPrintRequest = async (req, res) => {
  try {
    const clientId = req.user.id;

    const { gallery_id, booking_id, items, print_size, quantity, notes } =
      req.body;

    const galleryId = Number(gallery_id);
    const bookingId = Number(booking_id);
    const itemIds = cleanNumberArray(items);

    const cleanPrintSize = (print_size || "").toString().trim();
    const cleanQuantity = Number(quantity || 1);
    const cleanNotes = notes ? notes.toString().trim() : null;

    if (!galleryId || !bookingId) {
      return res.status(400).json({
        message: "Gallery id and booking id are required.",
      });
    }

    if (itemIds.length === 0) {
      return res.status(400).json({
        message: "Please select at least one photo to print.",
      });
    }

    if (!allowedPrintSizes.includes(cleanPrintSize)) {
      return res.status(400).json({
        message: "Invalid print size.",
      });
    }

    if (!Number.isInteger(cleanQuantity) || cleanQuantity < 1) {
      return res.status(400).json({
        message: "Quantity must be at least 1.",
      });
    }

    if (cleanQuantity > 20) {
      return res.status(400).json({
        message: "Quantity is too high for one request.",
      });
    }

    const gallery = await printRequestModel.getGalleryForPrintRequest(
      galleryId,
      clientId
    );

    if (!gallery) {
      return res.status(404).json({
        message: "Gallery not found.",
      });
    }

    if (Number(gallery.booking_id) !== bookingId) {
      return res.status(400).json({
        message: "Booking does not match this gallery.",
      });
    }

    if (gallery.gallery_status !== "finalized") {
      return res.status(400).json({
        message:
          "Print requests are available only after finalizing the gallery.",
      });
    }

    if (!isRemainingPaid(gallery)) {
      return res.status(400).json({
        message: "Please pay the remaining balance before requesting prints.",
      });
    }

    const validItems = await printRequestModel.getValidGalleryItemsForClient({
      galleryId,
      clientId,
      itemIds,
    });

    if (validItems.length !== itemIds.length) {
      return res.status(400).json({
        message: "Some selected files are not valid for this gallery.",
      });
    }

    const nonImageItem = validItems.find((item) => {
      return (item.media_type || "image").toString() !== "image";
    });

    if (nonImageItem) {
      return res.status(400).json({
        message: "Only photos can be requested for printing.",
      });
    }

    const printRequestId = await printRequestModel.createPrintRequest({
      galleryId,
      bookingId,
      clientId,
      photographerId: gallery.photographer_profile_id,
      printSize: cleanPrintSize,
      quantity: cleanQuantity,
      notes: cleanNotes,
    });

    await printRequestModel.addPrintRequestItems(printRequestId, itemIds);

    const request = await printRequestModel.getPrintRequestById(printRequestId);
    const requestItems = await printRequestModel.getPrintRequestItems(
      printRequestId
    );

    await safeCreateNotification({
      userId: gallery.photographer_user_id,
      title: "New print request",
      body: `A client requested printed copies for ${itemIds.length} photo(s).`,
      type: "print_request_created",
      referenceType: "print_request",
      referenceId: printRequestId,
    });

    return res.status(201).json({
      message: "Print request sent successfully.",
      request,
      items: requestItems,
    });
  } catch (err) {
    console.error("createPrintRequest error:", err);

    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

// ─────────────────────────────────────────────
// CLIENT: My print requests
// GET /api/print-requests/client
// ─────────────────────────────────────────────

exports.getMyPrintRequestsAsClient = async (req, res) => {
  try {
    const clientId = req.user.id;

    const requests = await printRequestModel.getPrintRequestsForClient(
      clientId
    );

    return res.status(200).json({
      requests,
    });
  } catch (err) {
    console.error("getMyPrintRequestsAsClient error:", err);

    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

// ─────────────────────────────────────────────
// PHOTOGRAPHER: My print requests
// GET /api/print-requests/photographer
// ─────────────────────────────────────────────

exports.getMyPrintRequestsAsPhotographer = async (req, res) => {
  try {
    const photographerUserId = req.user.id;

    const requests =
      await printRequestModel.getPrintRequestsForPhotographer(
        photographerUserId
      );

    return res.status(200).json({
      requests,
    });
  } catch (err) {
    console.error("getMyPrintRequestsAsPhotographer error:", err);

    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

// ─────────────────────────────────────────────
// SHARED: Requests for a specific gallery
// GET /api/print-requests/gallery/:galleryId
// ─────────────────────────────────────────────

exports.getPrintRequestsByGallery = async (req, res) => {
  try {
    const galleryId = Number(req.params.galleryId);
    const userId = req.user.id;
    const role = req.user.role;

    if (!galleryId) {
      return res.status(400).json({
        message: "Invalid gallery id.",
      });
    }

    const requests = await printRequestModel.getPrintRequestsForGallery(
      galleryId,
      userId,
      role
    );

    return res.status(200).json({
      requests,
    });
  } catch (err) {
    console.error("getPrintRequestsByGallery error:", err);

    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

// ─────────────────────────────────────────────
// SHARED: One print request details
// GET /api/print-requests/:id
// ─────────────────────────────────────────────

exports.getPrintRequestDetails = async (req, res) => {
  try {
    const requestId = Number(req.params.id);

    if (!requestId) {
      return res.status(400).json({
        message: "Invalid print request id.",
      });
    }

    const request = await printRequestModel.getPrintRequestById(requestId);

    if (!request) {
      return res.status(404).json({
        message: "Print request not found.",
      });
    }

    const userId = req.user.id;
    const role = req.user.role;

    const canView =
      (role === "client" && Number(request.client_id) === Number(userId)) ||
      (role === "photographer" &&
        Number(request.photographer_user_id) === Number(userId));

    if (!canView) {
      return res.status(403).json({
        message: "Not authorized to view this print request.",
      });
    }

    const items = await printRequestModel.getPrintRequestItems(requestId);

    return res.status(200).json({
      request,
      items,
    });
  } catch (err) {
    console.error("getPrintRequestDetails error:", err);

    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

// ─────────────────────────────────────────────
// PHOTOGRAPHER: Update request status
// PATCH /api/print-requests/:id/status
// ─────────────────────────────────────────────

exports.updatePrintRequestStatus = async (req, res) => {
  try {
    const requestId = Number(req.params.id);
    const photographerUserId = req.user.id;
    const status = (req.body.status || "").toString().trim();

    if (!requestId) {
      return res.status(400).json({
        message: "Invalid print request id.",
      });
    }

    if (!allowedStatuses.includes(status)) {
      return res.status(400).json({
        message: "Invalid print request status.",
      });
    }

    if (status === "pending") {
      return res.status(400).json({
        message: "Cannot move request back to pending.",
      });
    }

    const existing = await printRequestModel.getPrintRequestById(requestId);

    if (!existing) {
      return res.status(404).json({
        message: "Print request not found.",
      });
    }

    if (Number(existing.photographer_user_id) !== Number(photographerUserId)) {
      return res.status(403).json({
        message: "Not authorized to update this print request.",
      });
    }

    const updated = await printRequestModel.updatePrintRequestStatus({
      requestId,
      photographerId: photographerUserId,
      status,
    });

    if (!updated) {
      return res.status(400).json({
        message: "Failed to update print request status.",
      });
    }

    const request = await printRequestModel.getPrintRequestById(requestId);
    const items = await printRequestModel.getPrintRequestItems(requestId);

    await safeCreateNotification({
      userId: request.client_id,
      title: "Print request updated",
      body: statusMessageForClient(status),
      type: "print_request_updated",
      referenceType: "print_request",
      referenceId: requestId,
    });

    return res.status(200).json({
      message: "Print request status updated.",
      request,
      items,
    });
  } catch (err) {
    console.error("updatePrintRequestStatus error:", err);

    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};