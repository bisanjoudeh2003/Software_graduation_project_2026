const multiItemRevisionModel = require("../model/multiItemRevisionModel");
const bookingGalleryModel = require("../model/bookingGalleryModel");
const sharp = require("sharp");
const cloudinary = require("../config/cloudinary");
const Groq = require("groq-sdk");

const groq = new Groq({
  apiKey: process.env.GROQ_API_KEY,
});

function toInt(value) {
  if (value === undefined || value === null) return 0;
  return Number.parseInt(value, 10) || 0;
}

function cleanText(value) {
  if (value === undefined || value === null) return "";
  return String(value).trim();
}

function normalizeIds(value) {
  if (!Array.isArray(value)) return [];

  const ids = value.map((item) => toInt(item)).filter((id) => id > 0);
  return [...new Set(ids)];
}

function isActiveRevisionStatus(status) {
  return status === "pending" || status === "in_progress";
}

function safeAiString(value) {
  if (value === undefined || value === null) return "";
  return String(value).trim();
}

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
const ALLOWED_INTENSITIES = ["light", "standard", "strong"];

const AI_ALLOWED_EDIT_TYPES = [
  "lighting",
  "color",
  "retouch",
  "crop",
  "background",
  "export",
  "other",
];

function normalizeGroupAiSuggestion(raw) {
  const editType = AI_ALLOWED_EDIT_TYPES.includes(raw.edit_type)
    ? raw.edit_type
    : "lighting";

  const preset = ALLOWED_PRESETS.includes(raw.suggested_preset)
    ? raw.suggested_preset
    : "natural_enhance";

  const intensity = ALLOWED_INTENSITIES.includes(raw.suggested_intensity)
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
    suggested_preset: preset,
    suggested_intensity: intensity,
    detected_issue_label:
      safeAiString(raw.detected_issue_label) ||
      fallbackIssueLabels[editType] ||
      "Revision Request",
    reason:
      safeAiString(raw.reason) ||
      "The suggestion was generated based on the shared client request.",
    photographer_response:
      safeAiString(raw.photographer_response) ||
      `Applied ${PRESET_NAMES[preset]} preset with ${intensity} intensity to the selected photos.`,
  };
}

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

const getThumbnailUrl = (mediaUrl, mediaType) => {
  if (!mediaUrl) return mediaUrl;

  if (mediaType === "image" && mediaUrl.includes("/image/upload/")) {
    return mediaUrl.replace(
      "/image/upload/",
      "/image/upload/w_600,h_600,c_fill,q_auto/"
    );
  }

  return mediaUrl;
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

exports.suggestGroupRevisionPlan = async (req, res) => {
  try {
    const note = cleanText(req.body.note);
    const fileCount = toInt(req.body.file_count) || 1;

    if (!process.env.GROQ_API_KEY) {
      return res.status(500).json({
        success: false,
        message: "GROQ_API_KEY is missing in .env.",
      });
    }

    if (!note) {
      return res.status(400).json({
        success: false,
        message: "Client revision note is required.",
      });
    }

    if (note.length < 3) {
      return res.status(400).json({
        success: false,
        message: "Revision note is too short.",
      });
    }

    const prompt = `
You are an AI assistant inside a photography app.

The photographer is reviewing a group of photos that all have the same client revision request.

Client request:
"${note}"

Number of selected files: ${fileCount}

Your job:
Suggest one practical group edit plan for the selected photos.

Allowed edit_type values:
lighting, color, retouch, crop, background, export, other

Allowed suggested_preset values:
natural_enhance, bright_clean, warm_tone, soft_portrait, cool_tone, vivid_colors, cinematic, matte_soft, black_white, sharpen_details

Allowed suggested_intensity values:
light, standard, strong

Rules:
- If the client asks for brighter photos, choose lighting and bright_clean.
- If the client asks for warmer colors, choose color and warm_tone.
- If the client asks for stronger or richer colors, choose color and vivid_colors.
- If the client asks for face, skin, portrait softness, or retouching, choose retouch and soft_portrait.
- If the client asks about background issues, choose background and cool_tone.
- If the client asks for clearer details, choose export and sharpen_details.
- If the request says slightly, a little, small change, or minor, choose light intensity.
- If the request is normal, choose standard intensity.
- If the photos are very dark, very dull, or the client asks for a strong change, choose strong intensity.
- Keep the plan safe for a group of photos.
- Write photographer_response in English, polite, and professional.
- Return JSON only. Do not write anything outside JSON.

Return exactly this JSON shape:
{
  "edit_type": "lighting",
  "suggested_preset": "bright_clean",
  "suggested_intensity": "standard",
  "detected_issue_label": "Lighting Issue",
  "reason": "The client asked for brighter photos, so a clean brightness adjustment is the safest group edit.",
  "photographer_response": "I applied a bright and clean edit to the selected photos while keeping them natural."
}
`;

    const completion = await groq.chat.completions.create({
      model: process.env.GROQ_MODEL || "llama-3.1-8b-instant",
      temperature: 0.25,
      max_tokens: 450,
      response_format: {
        type: "json_object",
      },
      messages: [
        {
          role: "system",
          content:
            "You generate structured JSON group edit plans for a photography app. Return valid JSON only.",
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
    } catch (_) {
      return res.status(500).json({
        success: false,
        message: "AI returned invalid JSON.",
      });
    }

    const suggestion = normalizeGroupAiSuggestion(parsed);

    return res.status(200).json({
      success: true,
      message: "AI group edit plan generated successfully.",
      suggestion,
    });
  } catch (err) {
    console.error("suggestGroupRevisionPlan error:", err);

    let statusCode = 500;
    let message = "Failed to generate group edit plan.";

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
      success: false,
      message,
      error: err.message,
    });
  }
};

exports.requestRevisionForSelectedItems = async (req, res) => {
  try {
    const galleryId = toInt(req.params.galleryId);
    const clientId = req.user?.id;

    const itemIds = normalizeIds(req.body.item_ids);
    const note = cleanText(req.body.note);

    if (!galleryId) {
      return res.status(400).json({
        success: false,
        message: "Invalid gallery id.",
      });
    }

    if (!clientId) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized.",
      });
    }

    if (itemIds.length === 0) {
      return res.status(400).json({
        success: false,
        message: "Select at least one file.",
      });
    }

    if (itemIds.length > 20) {
      return res.status(400).json({
        success: false,
        message: "You can request edits for up to 20 files at a time.",
      });
    }

    if (!note) {
      return res.status(400).json({
        success: false,
        message: "Please write one revision note for the selected files.",
      });
    }

    if (note.length < 3) {
      return res.status(400).json({
        success: false,
        message: "Revision note is too short.",
      });
    }

    const gallery = await multiItemRevisionModel.getGalleryForClient(
      galleryId,
      clientId
    );

    if (!gallery) {
      return res.status(403).json({
        success: false,
        message: "You are not allowed to request revisions for this gallery.",
      });
    }

    if (gallery.status === "finalized" || gallery.status === "archived") {
      return res.status(400).json({
        success: false,
        message: "This gallery is closed for edit requests.",
      });
    }

    const foundItems = await multiItemRevisionModel.getItemsForBulkRevision({
      galleryId,
      itemIds,
    });

    const foundSelectedIds = new Set(
      foundItems.map((item) => toInt(item.selected_item_id))
    );

    const skippedItems = [];

    for (const requestedId of itemIds) {
      if (!foundSelectedIds.has(requestedId)) {
        skippedItems.push({
          item_id: requestedId,
          reason: "File was not found in this gallery.",
        });
      }
    }

    const seenRootIds = new Set();
    const validItems = [];

    for (const item of foundItems) {
      const selectedItemId = toInt(item.selected_item_id);
      const rootItemId = toInt(item.root_item_id);
      const revisionCount = toInt(item.revision_count);
      const latestStatus = (item.latest_revision_status || "").toString();

      if (!rootItemId) {
        skippedItems.push({
          item_id: selectedItemId,
          reason: "Invalid file.",
        });
        continue;
      }

      if (seenRootIds.has(rootItemId)) {
        skippedItems.push({
          item_id: selectedItemId,
          reason: "Another version of this file was already selected.",
        });
        continue;
      }

      if (isActiveRevisionStatus(latestStatus)) {
        skippedItems.push({
          item_id: selectedItemId,
          reason: "This file already has an active edit request.",
        });
        continue;
      }

      if (revisionCount >= multiItemRevisionModel.MAX_REVISION_ATTEMPTS) {
        skippedItems.push({
          item_id: selectedItemId,
          reason: "This file has reached the maximum number of edit requests.",
        });
        continue;
      }

      seenRootIds.add(rootItemId);
      validItems.push(item);
    }

    if (validItems.length === 0) {
      return res.status(400).json({
        success: false,
        message: "No selected files are available for revision requests.",
        created_count: 0,
        skipped_count: skippedItems.length,
        skipped_items: skippedItems,
      });
    }

    const result = await multiItemRevisionModel.createRevisionRequestsForItems({
      galleryId,
      clientId,
      note,
      items: validItems,
    });

    return res.status(201).json({
      success: true,
      message: "Revision requests created successfully.",
      created_count: result.createdCount,
      skipped_count: skippedItems.length,
      created_request_ids: result.createdRequestIds,
      skipped_items: skippedItems,
    });
  } catch (err) {
    console.error("requestRevisionForSelectedItems error:", err);

    return res.status(500).json({
      success: false,
      message: "Failed to create revision requests.",
      error: err.message,
    });
  }
};

exports.applyPresetToSelectedRevisionRequests = async (req, res) => {
  try {
    const requestIds = normalizeIds(req.body.request_ids);
    const preset = cleanText(req.body.preset);
    const intensity = cleanText(req.body.intensity || "standard");
    const photographerResponse =
      cleanText(req.body.photographer_response) ||
      `Applied ${
        PRESET_NAMES[preset] || "selected"
      } preset with ${intensity} intensity.`;

    if (requestIds.length === 0) {
      return res.status(400).json({
        success: false,
        message: "Select at least one edit request.",
      });
    }

    if (requestIds.length > 10) {
      return res.status(400).json({
        success: false,
        message: "You can apply a preset to up to 10 files at a time.",
      });
    }

    if (!ALLOWED_PRESETS.includes(preset)) {
      return res.status(400).json({
        success: false,
        message: "Invalid preset.",
      });
    }

    if (!ALLOWED_INTENSITIES.includes(intensity)) {
      return res.status(400).json({
        success: false,
        message: "Invalid intensity.",
      });
    }

    const requests =
      await multiItemRevisionModel.getRevisionRequestsForPhotographerBulk({
        requestIds,
        photographerUserId: req.user.id,
      });

    const foundIds = new Set(requests.map((item) => toInt(item.request_id)));
    const skippedItems = [];
    const createdItems = [];

    for (const id of requestIds) {
      if (!foundIds.has(id)) {
        skippedItems.push({
          request_id: id,
          reason: "Request not found or not authorized.",
        });
      }
    }

    for (const revisionRequest of requests) {
      const requestId = toInt(revisionRequest.request_id);

      if (
        revisionRequest.status !== "pending" &&
        revisionRequest.status !== "in_progress"
      ) {
        skippedItems.push({
          request_id: requestId,
          reason: "Request is not active.",
        });
        continue;
      }

      if ((revisionRequest.media_type || "image") !== "image") {
        skippedItems.push({
          request_id: requestId,
          reason: "Presets are available for photos only.",
        });
        continue;
      }

      const sourceUrl =
        revisionRequest.original_url || revisionRequest.media_url || "";

      if (!sourceUrl) {
        skippedItems.push({
          request_id: requestId,
          reason: "Original image URL is missing.",
        });
        continue;
      }

      try {
        const inputBuffer = await downloadImageAsBuffer(sourceUrl);
        const outputBuffer = await applyImagePresetWithSharp(
          inputBuffer,
          preset,
          intensity
        );

        const uploadResult = await uploadPresetBufferToCloudinary(outputBuffer);

        const mediaUrl = uploadResult.secure_url;
        const publicId = uploadResult.public_id;
        const mediaType = "image";
        const thumbnailUrl = getThumbnailUrl(mediaUrl, mediaType);

        const originalItemId = toInt(revisionRequest.item_id);

        const maxVersionNumber =
          await bookingGalleryModel.getMaxVersionNumberForItem(originalItemId);

        const nextVersionNumber = maxVersionNumber + 1;

        let sortOrder = await bookingGalleryModel.getMaxSortOrder(
          revisionRequest.gallery_id
        );

        sortOrder += 1;

        const result = await bookingGalleryModel.addEditedGalleryItem({
          gallery_id: revisionRequest.gallery_id,
          original_url: sourceUrl,
          media_url: mediaUrl,
          thumbnail_url: thumbnailUrl,
          cloudinary_public_id: publicId,
          media_type: mediaType,
          sort_order: sortOrder,
          parent_item_id: originalItemId,
          revision_request_id: requestId,
          version_number: nextVersionNumber,
          filter_name: `${preset}_${intensity}`,
        });

        await bookingGalleryModel.markRevisionRequestDone({
          requestId,
          editedItemId: result.insertId,
          photographerResponse,
        });

        const editedItem = await bookingGalleryModel.getGalleryItemById(
          result.insertId
        );

        createdItems.push({
          request_id: requestId,
          item: editedItem,
        });
      } catch (error) {
        skippedItems.push({
          request_id: requestId,
          reason: error.message || "Failed to apply preset.",
        });
      }
    }

    if (createdItems.length === 0) {
      return res.status(400).json({
        success: false,
        message: "No files were edited.",
        created_count: 0,
        skipped_count: skippedItems.length,
        skipped_items: skippedItems,
      });
    }

    return res.status(201).json({
      success: true,
      message: "Preset applied to selected files.",
      created_count: createdItems.length,
      skipped_count: skippedItems.length,
      preset,
      intensity,
      items: createdItems,
      skipped_items: skippedItems,
    });
  } catch (err) {
    console.error("applyPresetToSelectedRevisionRequests error:", err);

    return res.status(500).json({
      success: false,
      message: "Failed to apply preset to selected requests.",
      error: err.message,
    });
  }
};