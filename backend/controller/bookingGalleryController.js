const bookingGalleryModel = require("../model/bookingGalleryModel");
const notificationModel = require("../model/notificationModel");
const userActivityLogModel = require("../model/userActivityLogModel");
const db = require("../config/db");
const crypto = require("crypto");
const Stripe = require("stripe");
const sharp = require("sharp");
const cloudinary = require("../config/cloudinary");
const Groq = require("groq-sdk");

const stripe = Stripe(process.env.STRIPE_SECRET_KEY);

const groq = new Groq({
  apiKey: process.env.GROQ_API_KEY,
});

const AI_ALLOWED_EDIT_TYPES = [
  "lighting",
  "color",
  "retouch",
  "crop",
  "background",
  "export",
  "other",
];

const AI_ALLOWED_PRESETS = [
  "natural_enhance",
  "bright_clean",
  "warm_tone",
  "soft_portrait",
  "cool_tone",
  "vivid_colors",
  "cinematic",
  "matte_soft",
  "black_white",
  "sharpen_details",
];

const AI_ALLOWED_INTENSITIES = ["light", "standard", "strong"];

const WATERMARK_LOGO_PUBLIC_ID = "water_mark";

const PRESET_NAMES = {
  natural_enhance: "Natural Enhance",
  bright_clean: "Bright & Clean",
  warm_tone: "Warm Tone",
  soft_portrait: "Soft Portrait",
  cool_tone: "Cool Tone",
  vivid_colors: "Vivid Colors",
  cinematic: "Cinematic",
  matte_soft: "Matte Soft",
  black_white: "Black & White",
  sharpen_details: "Sharpen Details",
};

const ALLOWED_PRESETS = Object.keys(PRESET_NAMES);

function safeAiString(value) {
  if (value === undefined || value === null) return "";
  return String(value).trim();
}

function safeAiArray(value, fallback) {
  if (!Array.isArray(value)) return fallback;

  const cleaned = value
    .map((item) => safeAiString(item))
    .filter((item) => item.length > 0)
    .slice(0, 6);

  return cleaned.length > 0 ? cleaned : fallback;
}

function normalizeAiRevisionSuggestion(raw) {
  const editType = AI_ALLOWED_EDIT_TYPES.includes(raw.edit_type)
    ? raw.edit_type
    : "lighting";

  const preset = AI_ALLOWED_PRESETS.includes(raw.suggested_preset)
    ? raw.suggested_preset
    : "natural_enhance";

  const intensity = AI_ALLOWED_INTENSITIES.includes(raw.suggested_intensity)
    ? raw.suggested_intensity
    : "standard";

  const fallbackIssueLabels = {
    lighting: "Lighting Issue",
    color: "Color Tone",
    retouch: "Portrait Retouch",
    crop: "Crop / Composition",
    background: "Background Edit",
    export: "Final Export",
    other: "Custom Edit",
  };

  return {
    edit_type: editType,
    custom_edit_type:
      editType === "other" ? safeAiString(raw.custom_edit_type) : "",
    suggested_preset: preset,
    suggested_intensity: intensity,
    checklist: safeAiArray(raw.checklist, [
      "Review client request",
      "Apply the suggested adjustment",
      "Check colors and lighting",
      "Export edited version",
    ]),
    photographer_response:
      safeAiString(raw.photographer_response) ||
      "I reviewed the requested changes and prepared an edit plan for this photo.",
    reason:
      safeAiString(raw.reason) ||
      "The suggestion was generated based on the client's revision note.",
    detected_issue_label:
      safeAiString(raw.detected_issue_label) ||
      fallbackIssueLabels[editType] ||
      "Revision Request",
  };
}

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

const normalizeDate = (value) => {
  if (!value || value === "null" || value === "undefined") return null;
  return value;
};

const normalizeBool = (value, fallback = 0) => {
  if (value === undefined || value === null || value === "") return fallback;
  return isTruthy(value) ? 1 : 0;
};

const notifyUser = async (
  userId,
  title,
  body,
  type,
  referenceType = null,
  referenceId = null
) => {
  if (!userId) return;

  try {
    await notificationModel.createNotification(
      userId,
      title,
      body,
      type,
      referenceType,
      referenceId
    );
  } catch (err) {
    console.error("Notification error:", err.message);
  }
};

const logUserActivity = async ({
  actorId,
  targetUserId,
  action,
  category,
  description,
  metadata = null,
}) => {
  try {
    await userActivityLogModel.logActivity({
      actorId,
      targetUserId,
      action,
      category,
      description,
      metadata,
    });
  } catch (err) {
    console.error("User activity log error:", err.message);
  }
};

const getPhotographerUserIdFromPhotographerId = async (photographerId) => {
  if (!photographerId) return null;

  try {
    const [rows] = await db.query(
      `SELECT user_id
       FROM photographers
       WHERE photographer_id = ?
       LIMIT 1`,
      [photographerId]
    );

    return rows[0]?.user_id || null;
  } catch (err) {
    console.error("getPhotographerUserIdFromPhotographerId error:", err.message);
    return null;
  }
};

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

const downloadImageAsBuffer = async (imageUrl) => {
  const response = await fetch(imageUrl);

  if (!response.ok) {
    throw new Error("Failed to download the source image.");
  }

  const arrayBuffer = await response.arrayBuffer();
  return Buffer.from(arrayBuffer);
};

const uploadPresetBufferToCloudinary = (buffer) => {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      {
        folder: "lensia/revision_presets",
        resource_type: "image",
        format: "jpg",
      },
      (error, result) => {
        if (error) return reject(error);
        return resolve(result);
      }
    );

    stream.end(buffer);
  });
};

const applyImagePresetWithSharp = async (
  inputBuffer,
  preset,
  intensity = "standard"
) => {
  const factor =
    intensity === "light" ? 0.75 : intensity === "strong" ? 1.25 : 1;

  const scale = (value) => 1 + (value - 1) * factor;
  const offset = (value) => value * factor;

  let image = sharp(inputBuffer).rotate().toColorspace("srgb");

  switch (preset) {
    case "natural_enhance":
      image = image
        .modulate({
          brightness: scale(1.05),
          saturation: scale(1.06),
        })
        .linear(scale(1.04), offset(-3))
        .sharpen({ sigma: 0.45 * factor });
      break;

    case "bright_clean":
      image = image
        .modulate({
          brightness: scale(1.12),
          saturation: scale(1.04),
        })
        .linear(scale(1.08), offset(-2))
        .sharpen({ sigma: 0.6 * factor });
      break;

    case "warm_tone":
      image = image
        .modulate({
          brightness: scale(1.03),
          saturation: scale(1.12),
        })
        .tint({ r: 255, g: 238, b: 210 })
        .linear(scale(1.03), offset(-2));
      break;

    case "soft_portrait":
      image = image
        .modulate({
          brightness: scale(1.04),
          saturation: scale(1.03),
        })
        .blur(0.35 * factor)
        .sharpen({ sigma: 0.25 * factor });
      break;

    case "cool_tone":
      image = image
        .modulate({
          brightness: scale(1.03),
          saturation: scale(1.05),
        })
        .tint({ r: 220, g: 238, b: 255 })
        .linear(scale(1.04), offset(-2))
        .sharpen({ sigma: 0.45 * factor });
      break;

    case "vivid_colors":
      image = image
        .modulate({
          brightness: scale(1.04),
          saturation: scale(1.22),
        })
        .linear(scale(1.08), offset(-4))
        .sharpen({ sigma: 0.55 * factor });
      break;

    case "cinematic":
      image = image
        .modulate({
          brightness: scale(0.98),
          saturation: scale(1.10),
        })
        .linear(scale(1.16), offset(-10))
        .tint({ r: 238, g: 232, b: 220 })
        .sharpen({ sigma: 0.5 * factor });
      break;

    case "matte_soft":
      image = image
        .modulate({
          brightness: scale(1.04),
          saturation: scale(0.94),
        })
        .linear(scale(0.94), offset(10))
        .blur(0.18 * factor)
        .sharpen({ sigma: 0.2 * factor });
      break;

    case "black_white":
      image = image
        .grayscale()
        .linear(scale(1.08), offset(-5))
        .sharpen({ sigma: 0.5 * factor });
      break;

    case "sharpen_details":
      image = image
        .modulate({
          brightness: scale(1.02),
          saturation: scale(1.04),
        })
        .linear(scale(1.08), offset(-5))
        .sharpen({ sigma: 1.1 * factor });
      break;

    default:
      throw new Error("Unsupported preset.");
  }

  return image
    .jpeg({
      quality: 92,
      mozjpeg: true,
    })
    .toBuffer();
};

exports.aiSuggestRevisionPlan = async (req, res) => {
  try {
    const { requestId } = req.params;

    const regenerate =
      req.body.regenerate === true ||
      req.body.regenerate === 1 ||
      req.body.regenerate === "1" ||
      req.body.regenerate === "true";

    if (!process.env.GROQ_API_KEY) {
      return res.status(500).json({
        message: "GROQ_API_KEY is missing in .env.",
      });
    }

    const revisionRequest =
      await bookingGalleryModel.getRevisionRequestForPhotographer(
        requestId,
        req.user.id
      );

    if (!revisionRequest) {
      return res.status(403).json({
        message: "Not authorized to generate an AI suggestion for this request.",
      });
    }

    if (
      revisionRequest.status !== "pending" &&
      revisionRequest.status !== "in_progress"
    ) {
      return res.status(400).json({
        message:
          "AI suggestions are available only for active revision requests.",
      });
    }

    const clientNote = safeAiString(revisionRequest.note);
    const mediaType =
      safeAiString(revisionRequest.original_media_type) || "image";
    const currentEditType = safeAiString(revisionRequest.edit_type);

    const alternativeInstruction = regenerate
      ? `
This is a regenerate request.

Generate an alternative valid plan.
Do not repeat the exact same suggested_preset, checklist, and photographer_response if another suitable option exists.
You may choose a different suitable preset or intensity while still respecting the client's request.
Keep the plan realistic and useful.
`
      : `
Generate the most direct and reliable plan for this request.
`;

    if (!clientNote) {
      return res.status(400).json({
        message: "Client revision note is required for AI suggestion.",
      });
    }

    const prompt = `
You are an AI assistant inside a photography revision workflow.

The client requested this revision:
"${clientNote}"

Media type: ${mediaType}
Current selected edit type: ${currentEditType || "not selected"}

Your job:
Suggest the best editing plan for the photographer.
${alternativeInstruction} 
Allowed edit_type values:
lighting, color, retouch, crop, background, export, other

Allowed suggested_preset values:
natural_enhance, bright_clean, warm_tone, soft_portrait, cool_tone, vivid_colors, cinematic, matte_soft, black_white, sharpen_details

Allowed suggested_intensity values:
light, standard, strong

Rules:
- If the client asks for a brighter photo, choose lighting and bright_clean.
- If the client asks for warmer colors, choose color and warm_tone.
- If the client asks for stronger or richer colors, choose color and vivid_colors.
- If the client asks for face, skin, portrait softness, or retouching, choose retouch and soft_portrait.
- If the client asks about background issues, choose background and cool_tone.
- If the client asks for clearer details, choose export and sharpen_details.
- If the request says slightly, a little, small change, or minor, choose light intensity.
- If the request is normal, choose standard intensity.
- If the photo is very dark, very dull, or the client asks for a strong change, choose strong intensity.
- detected_issue_label must be short, like Lighting Issue, Color Tone, Portrait Retouch, Background Edit, Crop / Composition, Final Export, or Custom Edit.
- Keep checklist items short and practical.
- Write photographer_response in English, polite, and professional.
- Return JSON only. Do not write anything outside the JSON.
Return exactly this JSON shape:
{
  "edit_type": "lighting",
  "custom_edit_type": "",
  "suggested_preset": "bright_clean",
  "suggested_intensity": "standard",
  "detected_issue_label": "Lighting Issue",
  "checklist": [
    "Review client request",
    "Increase brightness",
    "Check colors",
    "Export edited version"
  ],
  "photographer_response": "I improved the lighting and kept the photo natural.",
  "reason": "The client asked for a brighter photo."
}
`;

    const completion = await groq.chat.completions.create({
      model: process.env.GROQ_MODEL || "llama-3.1-8b-instant",
      temperature: regenerate ? 0.75 : 0.2,
      max_tokens: 600,
      response_format: {
        type: "json_object",
      },
      messages: [
        {
          role: "system",
          content:
            "You generate structured JSON edit plans for a photography app. Return valid JSON only.",
        },
        {
          role: "user",
          content: prompt,
        },
      ],
    });

    const content = completion.choices?.[0]?.message?.content || "{}";

    let parsed;

    try {
      parsed = JSON.parse(content);
    } catch (error) {
      return res.status(500).json({
        message: "AI returned invalid JSON.",
      });
    }

    const suggestion = normalizeAiRevisionSuggestion(parsed);

    return res.status(200).json({
      message: "AI edit plan generated successfully.",
      suggestion,
    });
  } catch (err) {
    console.error("aiSuggestRevisionPlan error:", err);

    let statusCode = 500;
    let message = "Failed to generate AI edit plan.";

    if (err?.status === 401) {
      statusCode = 401;
      message = "Invalid Groq API key.";
    } else if (err?.status === 429) {
      statusCode = 429;
      message = "Groq rate limit reached. Please try again shortly.";
    } else if (err?.status === 400) {
      statusCode = 400;
      message = "Invalid Groq request or model name.";
    }

    return res.status(statusCode).json({
      message,
      error: err.message,
    });
  }
};

exports.createRemainingPaymentIntent = async (req, res) => {
  try {
    const { galleryId } = req.params;

    const paymentInfo =
      await bookingGalleryModel.getGalleryPaymentInfoForClient(
        galleryId,
        req.user.id
      );

    if (!paymentInfo) {
      return res.status(404).json({
        message: "Gallery not found.",
      });
    }

    if (paymentInfo.gallery_status !== "finalized") {
      return res.status(400).json({
        message:
          "Remaining balance can be paid only after finalizing the gallery.",
      });
    }

    const remainingAmount = Number(paymentInfo.remaining_amount || 0);

    if (remainingAmount <= 0) {
      return res.status(400).json({
        message: "No remaining balance is required for this booking.",
      });
    }

    if (Number(paymentInfo.remaining_paid) === 1) {
      return res.status(400).json({
        message: "Remaining balance is already paid.",
      });
    }

    const amountInCents = Math.round(remainingAmount * 100);

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountInCents,
      currency: "usd",
      metadata: {
        type: "photographer_remaining_payment",
        gallery_id: galleryId.toString(),
        booking_id: paymentInfo.booking_id.toString(),
        client_id: req.user.id.toString(),
      },
    });

    await bookingGalleryModel.markRemainingPaymentProcessing({
      bookingId: paymentInfo.booking_id,
      clientId: req.user.id,
      paymentIntentId: paymentIntent.id,
    });

    return res.status(200).json({
      clientSecret: paymentIntent.client_secret,
      payment_intent_id: paymentIntent.id,
      amount: amountInCents,
      remaining_amount: remainingAmount,
    });
  } catch (err) {
    console.error("createRemainingPaymentIntent error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.confirmRemainingPayment = async (req, res) => {
  try {
    const { galleryId } = req.params;
    const { payment_intent_id } = req.body;

    if (!payment_intent_id) {
      return res.status(400).json({
        message: "Payment intent id is required.",
      });
    }

    const paymentInfo =
      await bookingGalleryModel.getGalleryPaymentInfoForClient(
        galleryId,
        req.user.id
      );

    if (!paymentInfo) {
      return res.status(404).json({
        message: "Gallery not found.",
      });
    }

    const paymentIntent = await stripe.paymentIntents.retrieve(
      payment_intent_id
    );

    if (paymentIntent.status !== "succeeded") {
      return res.status(400).json({
        message: "Payment is not completed.",
      });
    }

    if (paymentIntent.metadata.gallery_id !== galleryId.toString()) {
      return res.status(400).json({
        message: "Invalid gallery relation.",
      });
    }

    if (
      paymentIntent.metadata.booking_id !== paymentInfo.booking_id.toString()
    ) {
      return res.status(400).json({
        message: "Invalid booking relation.",
      });
    }

    if (paymentIntent.metadata.client_id !== req.user.id.toString()) {
      return res.status(403).json({
        message: "Unauthorized payment.",
      });
    }

    await bookingGalleryModel.markRemainingPaymentPaid({
      bookingId: paymentInfo.booking_id,
      clientId: req.user.id,
      paymentIntentId: payment_intent_id,
    });

    await logUserActivity({
      actorId: req.user.id,
      targetUserId: req.user.id,
      action: "remaining_payment_paid",
      category: "payment",
      description: "Client paid the remaining balance for a gallery.",
      metadata: {
        gallery_id: galleryId,
        booking_id: paymentInfo.booking_id,
        amount: paymentInfo.remaining_amount,
      },
    });

    const photographerUserId = await getPhotographerUserIdFromPhotographerId(
      paymentInfo.photographer_id
    );

    await notifyUser(
      photographerUserId,
      "Remaining balance paid",
      "The client paid the remaining balance. You can now enable downloads or approve a clean copy.",
      "remaining_payment_paid",
      "booking_gallery",
      paymentInfo.booking_id
    );

    const updatedGallery = await bookingGalleryModel.getGalleryById(galleryId);
    const items = await bookingGalleryModel.getGalleryItems(galleryId);

    return res.status(200).json({
      message: "Remaining balance paid successfully.",
      gallery: updatedGallery,
      items,
    });
  } catch (err) {
    console.error("confirmRemainingPayment error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
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

      await logUserActivity({
        actorId: req.user.id,
        targetUserId: req.user.id,
        action: "gallery_created",
        category: "gallery",
        description: "Photographer created a gallery for a completed booking.",
        metadata: {
          booking_id: booking.booking_id,
          gallery_id: gallery?.id || null,
          client_id: booking.client_id,
        },
      });
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

    if (gallery.status === "archived") {
      return res.status(400).json({
        message: "Archived galleries cannot be edited.",
      });
    }

    const updates = {};
    const isFinalized = gallery.status === "finalized";

    if (isFinalized) {
      if (req.body.allow_download !== undefined) {
        updates.allow_download = normalizeBool(req.body.allow_download, 0);
      }

      if (req.body.preview_watermarked !== undefined) {
        updates.preview_watermarked = normalizeBool(
          req.body.preview_watermarked,
          0
        );
      }
    } else {
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
    }

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({
        message: isFinalized
          ? "No final delivery settings were changed."
          : "No valid fields to update.",
      });
    }

    await bookingGalleryModel.updateGallerySettings(galleryId, updates);

    const updatedGallery = await bookingGalleryModel.getGalleryById(galleryId);
    const items = await bookingGalleryModel.getGalleryItems(galleryId);

    return res.status(200).json({
      message: isFinalized
        ? "Final delivery settings updated successfully."
        : "Gallery settings updated successfully.",
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
          total_price: gallery.total_price,
          deposit_amount: gallery.deposit_amount,
          remaining_amount: gallery.remaining_amount,
          remaining_paid: gallery.remaining_paid,
          remaining_paid_at: gallery.remaining_paid_at,
          remaining_payment_status: gallery.remaining_payment_status,
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

      await logUserActivity({
        actorId: req.user.id,
        targetUserId: req.user.id,
        action: "gallery_files_uploaded",
        category: "gallery",
        description: "Photographer uploaded files to a gallery.",
        metadata: {
          gallery_id: galleryId,
          uploaded_count: insertedItems.length,
        },
      });
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

    await logUserActivity({
      actorId: req.user.id,
      targetUserId: req.user.id,
      action: "gallery_delivered",
      category: "gallery",
      description: "Photographer delivered a gallery to the client.",
      metadata: {
        gallery_id: galleryId,
        booking_id: gallery.booking_id,
        client_id: gallery.client_id,
      },
    });

    await notifyUser(
      gallery.client_id,
      "Gallery delivered",
      `${gallery.title || "Your gallery"} has been delivered. You can now review the final files.`,
      "gallery_delivered",
      "booking_gallery",
      gallery.booking_id
    );

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

    await logUserActivity({
      actorId: req.user.id,
      targetUserId: req.user.id,
      action: "revision_requested",
      category: "gallery",
      description: "Client requested a revision for a gallery item.",
      metadata: {
        request_id: result.insertId,
        gallery_id: item.gallery_id,
        item_id: originalItemId,
        round_number: roundNumber,
      },
    });

    const galleryForNotification = await bookingGalleryModel.getGalleryById(
      item.gallery_id
    );

    const photographerUserId = galleryForNotification
      ? await getPhotographerUserIdFromPhotographerId(
          galleryForNotification.photographer_id
        )
      : null;

    await notifyUser(
      photographerUserId,
      "Revision requested",
      `The client requested an edit in ${galleryForNotification?.title || "a gallery"}.`,
      "revision_requested",
      "booking_gallery",
      galleryForNotification?.booking_id || item.booking_id
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

exports.updateRevisionRequestStatus = async (req, res) => {
  try {
    const { requestId } = req.params;
    const { status } = req.body;

    const allowedStatuses = ["pending", "in_progress", "done"];

    if (!allowedStatuses.includes(status)) {
      return res.status(400).json({
        message: "Invalid revision status.",
      });
    }

    const revisionRequest =
      await bookingGalleryModel.getRevisionRequestForPhotographer(
        requestId,
        req.user.id
      );

    if (!revisionRequest) {
      return res.status(403).json({
        message: "Not authorized to update this revision request.",
      });
    }

    if (revisionRequest.status === "approved") {
      return res.status(400).json({
        message: "Approved revision requests cannot be changed.",
      });
    }

    if (revisionRequest.status === "rejected") {
      return res.status(400).json({
        message: "Rejected revision requests cannot be changed.",
      });
    }

    const completedAt = status === "done" ? new Date() : null;

    await bookingGalleryModel.updateRevisionRequestStatus({
      requestId: revisionRequest.id,
      status,
      completedAt,
    });

    const updatedRequest =
      await bookingGalleryModel.getRevisionRequestForPhotographer(
        requestId,
        req.user.id
      );

    const updatedItem = await bookingGalleryModel.getGalleryItemById(
      revisionRequest.item_id
    );

    return res.status(200).json({
      message: "Revision status updated successfully.",
      request: updatedRequest,
      item: {
        ...updatedItem,
        revision_request_id: updatedRequest.id,
        revision_note: updatedRequest.note,
        revision_status: updatedRequest.status,
        revision_requested_at: updatedRequest.requested_at,
        revision_round_number: updatedRequest.round_number,
        latest_revision_request_id: updatedRequest.id,
        latest_revision_note: updatedRequest.note,
        latest_revision_status: updatedRequest.status,
        latest_revision_round_number: updatedRequest.round_number,
        latest_revision_edited_item_id: updatedRequest.edited_item_id,
      },
    });
  } catch (err) {
    console.error("updateRevisionRequestStatus error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};

exports.updateRevisionWorkspacePlan = async (req, res) => {
  try {
    const { requestId } = req.params;

    const {
      edit_type,
      custom_edit_type,
      checklist,
      photographer_response,
      ai_suggestion_reason,
      ai_suggested_preset,
      ai_suggested_intensity,
      ai_detected_issue,
    } = req.body;

    const allowedEditTypes = [
      "lighting",
      "color",
      "retouch",
      "crop",
      "background",
      "export",
      "other",
    ];

    const cleanEditType = (edit_type || "").toString().trim();

    if (!cleanEditType) {
      return res.status(400).json({
        message: "Edit type is required.",
      });
    }

    if (!allowedEditTypes.includes(cleanEditType)) {
      return res.status(400).json({
        message: "Invalid edit type.",
      });
    }

    const cleanCustomEditType =
      cleanEditType === "other"
        ? (custom_edit_type || "").toString().trim()
        : null;

    if (cleanEditType === "other" && !cleanCustomEditType) {
      return res.status(400).json({
        message: "Custom edit type is required when edit type is Other.",
      });
    }

    const revisionRequest =
      await bookingGalleryModel.getRevisionRequestForPhotographer(
        requestId,
        req.user.id
      );

    if (!revisionRequest) {
      return res.status(403).json({
        message: "Not authorized to update this revision workspace.",
      });
    }

    if (revisionRequest.status === "approved") {
      return res.status(400).json({
        message: "Approved revision requests cannot be changed.",
      });
    }

    if (revisionRequest.status === "rejected") {
      return res.status(400).json({
        message: "Rejected revision requests cannot be changed.",
      });
    }

    let cleanChecklist = [];

    if (Array.isArray(checklist)) {
      cleanChecklist = checklist
        .map((task) => {
          const title = (task?.title || "").toString().trim();
          if (!title) return null;

          return {
            title,
            done: task?.done === true || task?.done === 1 || task?.done === "1",
          };
        })
        .filter(Boolean);
    }

    const cleanPhotographerResponse =
      (photographer_response || "").toString().trim() || null;

    const cleanAiSuggestionReason =
      (ai_suggestion_reason || "").toString().trim() || null;

    const cleanAiSuggestedPreset =
      (ai_suggested_preset || "").toString().trim() || null;

    const cleanAiSuggestedIntensity =
      (ai_suggested_intensity || "").toString().trim() || null;

    const cleanAiDetectedIssue =
      (ai_detected_issue || "").toString().trim() || null;

    await bookingGalleryModel.updateRevisionWorkspacePlan({
      requestId: revisionRequest.id,
      editType: cleanEditType,
      customEditType: cleanCustomEditType,
      checklistJson: cleanChecklist,
      photographerResponse: cleanPhotographerResponse,
      aiSuggestionReason: cleanAiSuggestionReason,
      aiSuggestedPreset: cleanAiSuggestedPreset,
      aiSuggestedIntensity: cleanAiSuggestedIntensity,
      aiDetectedIssue: cleanAiDetectedIssue,
    });

    const updatedRequest =
      await bookingGalleryModel.getRevisionRequestForPhotographer(
        requestId,
        req.user.id
      );

    const updatedItem = await bookingGalleryModel.getGalleryItemById(
      revisionRequest.item_id
    );

    return res.status(200).json({
      message: "Revision workspace plan saved successfully.",
      request: updatedRequest,
      item: {
        ...updatedItem,
        revision_request_id: updatedRequest.id,
        revision_note: updatedRequest.note,
        revision_status: updatedRequest.status,
        revision_requested_at: updatedRequest.requested_at,
        revision_round_number: updatedRequest.round_number,
        revision_edit_type: updatedRequest.edit_type,
        revision_custom_edit_type: updatedRequest.custom_edit_type,
        revision_checklist_json: updatedRequest.checklist_json,
        revision_photographer_response: updatedRequest.photographer_response,
        revision_ai_suggestion_reason: updatedRequest.ai_suggestion_reason,
        revision_ai_suggested_preset: updatedRequest.ai_suggested_preset,
        revision_ai_suggested_intensity: updatedRequest.ai_suggested_intensity,
        revision_ai_detected_issue: updatedRequest.ai_detected_issue,
        revision_workspace_updated_at: updatedRequest.workspace_updated_at,
        latest_revision_request_id: updatedRequest.id,
        latest_revision_note: updatedRequest.note,
        latest_revision_status: updatedRequest.status,
        latest_revision_round_number: updatedRequest.round_number,
        latest_revision_edited_item_id: updatedRequest.edited_item_id,
        latest_revision_edit_type: updatedRequest.edit_type,
        latest_revision_custom_edit_type: updatedRequest.custom_edit_type,
        latest_revision_checklist_json: updatedRequest.checklist_json,
        latest_revision_photographer_response:
          updatedRequest.photographer_response,
        latest_revision_workspace_updated_at: updatedRequest.workspace_updated_at,
        latest_revision_ai_suggestion_reason: updatedRequest.ai_suggestion_reason,
        latest_revision_ai_suggested_preset: updatedRequest.ai_suggested_preset,
        latest_revision_ai_suggested_intensity: updatedRequest.ai_suggested_intensity,
        latest_revision_ai_detected_issue: updatedRequest.ai_detected_issue,
      },
    });
  } catch (err) {
    console.error("updateRevisionWorkspacePlan error:", err);
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
      filter_name: "manual_upload",
    });

    await bookingGalleryModel.markRevisionRequestDone({
      requestId: revisionRequest.id,
      editedItemId: result.insertId,
      photographerResponse: photographer_response || null,
    });

    await logUserActivity({
      actorId: req.user.id,
      targetUserId: req.user.id,
      action: "revision_completed",
      category: "gallery",
      description: "Photographer uploaded an edited version for a revision request.",
      metadata: {
        request_id: revisionRequest.id,
        gallery_id: revisionRequest.gallery_id,
        edited_item_id: result.insertId,
      },
    });

    const editedItem = await bookingGalleryModel.getGalleryItemById(
      result.insertId
    );

    await notifyUser(
      revisionRequest.client_id,
      "Edited version uploaded",
      "Your photographer uploaded an edited version for your requested changes.",
      "edited_version_uploaded",
      "booking_gallery",
      revisionRequest.booking_id
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

exports.applyPresetToRevision = async (req, res) => {
  try {
    const { requestId } = req.params;
    const { preset, intensity, photographer_response } = req.body;

    const cleanPreset = (preset || "").toString().trim();
    const cleanIntensity = (intensity || "standard").toString().trim();

    const allowedIntensities = ["light", "standard", "strong"];

    if (!ALLOWED_PRESETS.includes(cleanPreset)) {
      return res.status(400).json({
        message: "Invalid preset.",
      });
    }

    if (!allowedIntensities.includes(cleanIntensity)) {
      return res.status(400).json({
        message: "Invalid preset intensity.",
      });
    }

    const revisionRequest =
      await bookingGalleryModel.getRevisionRequestForPhotographer(
        requestId,
        req.user.id
      );

    if (!revisionRequest) {
      return res.status(403).json({
        message: "Not authorized to apply a preset for this request.",
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

    const originalItem = await bookingGalleryModel.getGalleryItemById(
      revisionRequest.item_id
    );

    if (!originalItem) {
      return res.status(404).json({
        message: "Original gallery item was not found.",
      });
    }

    if ((originalItem.media_type || "image") !== "image") {
      return res.status(400).json({
        message: "Presets are available for photos only for now.",
      });
    }

    const sourceUrl = originalItem.original_url || originalItem.media_url || "";

    if (!sourceUrl) {
      return res.status(400).json({
        message: "Original image URL is missing.",
      });
    }

    const inputBuffer = await downloadImageAsBuffer(sourceUrl);

    const outputBuffer = await applyImagePresetWithSharp(
      inputBuffer,
      cleanPreset,
      cleanIntensity
    );

    const uploadResult = await uploadPresetBufferToCloudinary(outputBuffer);

    const mediaUrl = uploadResult.secure_url;
    const publicId = uploadResult.public_id;
    const mediaType = "image";
    const thumbnailUrl = getThumbnailUrl(mediaUrl, mediaType);

    const originalItemId = revisionRequest.item_id;

    const maxVersionNumber =
      await bookingGalleryModel.getMaxVersionNumberForItem(originalItemId);

    const nextVersionNumber = maxVersionNumber + 1;

    let sortOrder = await bookingGalleryModel.getMaxSortOrder(
      revisionRequest.gallery_id
    );

    sortOrder += 1;

    const filterName = `${cleanPreset}_${cleanIntensity}`;

    const result = await bookingGalleryModel.addEditedGalleryItem({
      gallery_id: revisionRequest.gallery_id,
      original_url: sourceUrl,
      media_url: mediaUrl,
      thumbnail_url: thumbnailUrl,
      cloudinary_public_id: publicId,
      media_type: mediaType,
      sort_order: sortOrder,
      parent_item_id: originalItemId,
      revision_request_id: revisionRequest.id,
      version_number: nextVersionNumber,
      filter_name: filterName,
    });

    const responseText =
      photographer_response ||
      `Applied ${PRESET_NAMES[cleanPreset]} preset with ${cleanIntensity} intensity.`;

    await bookingGalleryModel.markRevisionRequestDone({
      requestId: revisionRequest.id,
      editedItemId: result.insertId,
      photographerResponse: responseText,
    });

    await logUserActivity({
      actorId: req.user.id,
      targetUserId: req.user.id,
      action: "revision_completed_with_preset",
      category: "gallery",
      description: "Photographer applied a preset and completed a revision request.",
      metadata: {
        request_id: revisionRequest.id,
        gallery_id: revisionRequest.gallery_id,
        edited_item_id: result.insertId,
        preset: cleanPreset,
        intensity: cleanIntensity,
      },
    });

    const editedItem = await bookingGalleryModel.getGalleryItemById(
      result.insertId
    );

    await notifyUser(
      revisionRequest.client_id,
      "Edited version uploaded",
      `Your photographer applied ${PRESET_NAMES[cleanPreset]} and uploaded an edited version.`,
      "edited_version_uploaded",
      "booking_gallery",
      revisionRequest.booking_id
    );

    return res.status(201).json({
      message: "Preset applied and edited version saved successfully.",
      item: editedItem,
      request: {
        ...revisionRequest,
        status: "done",
        edited_item_id: result.insertId,
        photographer_response: responseText,
      },
    });
  } catch (err) {
    console.error("applyPresetToRevision error:", err);
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
      const updatedGallery = await bookingGalleryModel.getGalleryById(galleryId);
      const items = await bookingGalleryModel.getGalleryItems(galleryId);

      return res.status(200).json({
        message: "Gallery is already finalized.",
        gallery: updatedGallery,
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

    await logUserActivity({
      actorId: req.user.id,
      targetUserId: req.user.id,
      action: "gallery_finalized",
      category: "gallery",
      description: "Client finalized a delivered gallery.",
      metadata: {
        gallery_id: galleryId,
        booking_id: gallery.booking_id,
        photographer_id: gallery.photographer_id,
      },
    });

    const photographerUserId = await getPhotographerUserIdFromPhotographerId(
      gallery.photographer_id
    );

    await notifyUser(
      photographerUserId,
      "Gallery finalized",
      `${gallery.title || "A gallery"} has been finalized by the client.`,
      "gallery_finalized",
      "booking_gallery",
      gallery.booking_id
    );

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

    const remainingAmount = Number(gallery.remaining_amount || 0);
    const remainingPaid = Number(gallery.remaining_paid || 0) === 1;

    if (remainingAmount > 0 && !remainingPaid) {
      return res.status(400).json({
        message: "Please pay the remaining balance before sharing this gallery.",
      });
    }

    const days = Number(expires_in_days || 7);
    const safeDays = [7, 14, 30, 60].includes(days) ? days : 7;

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + safeDays);

    const token = crypto.randomBytes(32).toString("hex");

    const requestedAllowDownload = isTruthy(allow_download);
    const finalAllowDownload = requestedAllowDownload ? 1 : 0;

    const result = await bookingGalleryModel.createGalleryShareLink({
      gallery_id: gallery.id,
      client_id: req.user.id,
      token,
      allow_download: finalAllowDownload,
      expires_at: expiresAt,
    });

    await logUserActivity({
      actorId: req.user.id,
      targetUserId: req.user.id,
      action: "gallery_share_link_created",
      category: "gallery",
      description: "Client created a share link for a finalized gallery.",
      metadata: {
        gallery_id: gallery.id,
        share_id: result.insertId,
        allow_download: finalAllowDownload,
        expires_in_days: safeDays,
      },
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

exports.createShareLinkDemo = async (req, res) => {
  try {
    const { galleryId } = req.params;
    const { allow_download, expires_in_days } = req.body;

    const baseUrl = process.env.PUBLIC_APP_URL;

    if (!baseUrl) {
      return res.status(500).json({
        message: "PUBLIC_APP_URL is not configured on the server.",
      });
    }

    const gallery = await bookingGalleryModel.getGalleryById(galleryId);

    if (!gallery) {
      return res.status(404).json({
        message: "Gallery not found.",
      });
    }

    if (gallery.status !== "finalized") {
      return res.status(400).json({
        message: "Only finalized galleries can be shared.",
      });
    }

    const remainingAmount = Number(gallery.remaining_amount || 0);
    const remainingPaid = Number(gallery.remaining_paid || 0) === 1;

    if (remainingAmount > 0 && !remainingPaid) {
      return res.status(400).json({
        message: "Please pay the remaining balance before sharing this gallery.",
      });
    }

    const days = Number(expires_in_days || 7);
    const safeDays = [7, 14, 30, 60].includes(days) ? days : 7;

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + safeDays);

    const token = crypto.randomBytes(32).toString("hex");

    const requestedAllowDownload = isTruthy(allow_download);
    const finalAllowDownload = requestedAllowDownload ? 1 : 0;

    const result = await bookingGalleryModel.createGalleryShareLink({
      gallery_id: gallery.id,
      client_id: gallery.client_id || null,
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
    console.error("createShareLinkDemo error:", err);
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

    const remainingAmount = Number(gallery.remaining_amount || 0);
    const remainingPaid = Number(gallery.remaining_paid || 0) === 1;

    if (remainingAmount > 0 && !remainingPaid) {
      return res.status(403).json({
        message: "This gallery is not available until payment is completed.",
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
        remaining_amount: gallery.remaining_amount,
        remaining_paid: gallery.remaining_paid,
        remaining_payment_status: gallery.remaining_payment_status,
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

    await notifyUser(
      item.client_id,
      "Portfolio permission requested",
      "The photographer requested permission to add one of your finalized gallery files to their portfolio.",
      "portfolio_permission_requested",
      "booking_gallery",
      item.booking_id
    );

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

    const photographerUserId = await getPhotographerUserIdFromPhotographerId(
      item.photographer_id
    );

    await notifyUser(
      photographerUserId,
      status === "approved"
        ? "Portfolio permission approved"
        : "Portfolio permission rejected",
      status === "approved"
        ? "The client approved your request to use the gallery file in your portfolio."
        : "The client rejected your request to use the gallery file in your portfolio.",
      status === "approved"
        ? "portfolio_permission_approved"
        : "portfolio_permission_rejected",
      "booking_gallery",
      item.booking_id
    );

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

    await logUserActivity({
      actorId: req.user.id,
      targetUserId: req.user.id,
      action: "clean_copy_requested",
      category: "gallery",
      description: "Client requested a clean copy without watermark.",
      metadata: {
        gallery_id: galleryId,
        booking_id: gallery.booking_id,
        photographer_id: gallery.photographer_id,
      },
    });

    const photographerUserId = await getPhotographerUserIdFromPhotographerId(
      gallery.photographer_id
    );

    await notifyUser(
      photographerUserId,
      "Clean copy requested",
      `${gallery.title || "A finalized gallery"} needs a clean copy without watermark.`,
      "clean_copy_requested",
      "booking_gallery",
      gallery.booking_id
    );

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
    const { status } = req.body;

    const gallery = await bookingGalleryModel.respondCleanCopy(
      galleryId,
      req.user.id,
      status
    );

    if (!gallery) {
      return res.status(404).json({
        message: "Gallery not found.",
      });
    }

    await logUserActivity({
      actorId: req.user.id,
      targetUserId: req.user.id,
      action:
        status === "approved"
          ? "clean_copy_approved"
          : "clean_copy_rejected",
      category: "gallery",
      description:
        status === "approved"
          ? "Photographer approved a clean copy request."
          : "Photographer rejected a clean copy request.",
      metadata: {
        gallery_id: galleryId,
        booking_id: gallery.booking_id,
        client_id: gallery.client_id,
      },
    });

    await notifyUser(
      gallery.client_id,
      status === "approved" ? "Clean copy approved" : "Clean copy rejected",
      status === "approved"
        ? `${gallery.title || "Your gallery"} is now available without watermark.`
        : `The photographer rejected the clean copy request for ${gallery.title || "your gallery"}.`,
      status === "approved" ? "clean_copy_approved" : "clean_copy_rejected",
      "booking_gallery",
      gallery.booking_id
    );

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