const db = require("../config/db");
const notificationModel = require("../model/notificationModel");

function toBool(value) {
  return value === true || value === 1 || value === "1" || value === "true";
}

function toNumber(value) {
  if (value === null || value === undefined) return 0;
  const n = Number(value);
  return Number.isNaN(n) ? 0 : n;
}

function cleanText(value) {
  if (value === null || value === undefined) return "";
  const text = value.toString().trim();
  if (!text || text === "null") return "";
  return text;
}

function venueNameForNotification(venue) {
  const name = cleanText(venue?.name);

  if (!name) return "your venue";

  return name.length > 60 ? `${name.substring(0, 60)}...` : name;
}

function mapVenue(row) {
  const visible = cleanText(row.admin_visibility) === "visible";
  const reviewed = toBool(row.venue_reviewed);
  const flagged = toBool(row.venue_flagged);

  const imagesCount = toNumber(row.images_count);
  const availabilityCount = toNumber(row.availability_count);

  const missing = [];

  if (!cleanText(row.name)) missing.push("Name");
  if (!cleanText(row.location)) missing.push("Location");
  if (!row.price_per_hour) missing.push("Price");
  if (imagesCount <= 0 && !cleanText(row.image_url)) missing.push("Images");
  if (availabilityCount <= 0) missing.push("Availability");

  const needsAttention =
    !visible || !reviewed || flagged || missing.length > 0;

  return {
    id: row.id,
    owner_id: row.owner_id,
    owner_name: row.owner_name,
    owner_email: row.owner_email,
    owner_image: row.owner_image,

    name: row.name,
    description: row.description,
    location: row.location,
    latitude: row.latitude,
    longitude: row.longitude,
    price_per_hour: row.price_per_hour,
    image_url: row.image_url,
    created_at: row.created_at,

    admin_visibility: row.admin_visibility || "hidden",
    venue_reviewed: reviewed,
    venue_reviewed_at: row.venue_reviewed_at || null,
    venue_flagged: flagged,
    venue_flag_reason: cleanText(row.venue_flag_reason),

    images_count: imagesCount,
    availability_count: availabilityCount,

    booking_summary: {
      total: toNumber(row.total_bookings),
      pending: toNumber(row.pending_bookings),
      confirmed: toNumber(row.confirmed_bookings),
      completed: toNumber(row.completed_bookings),
      cancelled: toNumber(row.cancelled_bookings),
    },

    rating_summary: {
      average: Number(toNumber(row.rating_avg).toFixed(1)),
      reviews_count: toNumber(row.reviews_count),
      low_ratings: toNumber(row.low_ratings),
    },

    missing,
    needs_attention: needsAttention,
  };
}

const venueBaseSelect = `
  SELECT
    v.id,
    v.owner_id,
    v.name,
    v.description,
    v.location,
    v.latitude,
    v.longitude,
    v.price_per_hour,
    v.image_url,
    v.rating_avg,
    v.created_at,

    COALESCE(v.admin_visibility, 'hidden') AS admin_visibility,
    COALESCE(v.venue_reviewed, 0) AS venue_reviewed,
    v.venue_reviewed_at,
    COALESCE(v.venue_flagged, 0) AS venue_flagged,
    v.venue_flag_reason,

    u.full_name AS owner_name,
    u.email AS owner_email,
    u.profile_image AS owner_image,

    COALESCE(img.images_count, 0) AS images_count,
    COALESCE(av.availability_count, 0) AS availability_count,

    COALESCE(vb.total_bookings, 0) AS total_bookings,
    COALESCE(vb.pending_bookings, 0) AS pending_bookings,
    COALESCE(vb.confirmed_bookings, 0) AS confirmed_bookings,
    COALESCE(vb.completed_bookings, 0) AS completed_bookings,
    COALESCE(vb.cancelled_bookings, 0) AS cancelled_bookings,

    COALESCE(rv.reviews_count, 0) AS reviews_count,
    COALESCE(rv.rating_avg, 0) AS rating_avg,
    COALESCE(rv.low_ratings, 0) AS low_ratings

  FROM venues v

  LEFT JOIN users u
    ON u.id = v.owner_id

  LEFT JOIN (
    SELECT
      venue_id,
      COUNT(*) AS images_count
    FROM venue_images
    GROUP BY venue_id
  ) img ON img.venue_id = v.id

  LEFT JOIN (
    SELECT
      venue_id,
      COUNT(*) AS availability_count
    FROM venue_availability
    GROUP BY venue_id
  ) av ON av.venue_id = v.id

  LEFT JOIN (
    SELECT
      venue_id,
      COUNT(*) AS total_bookings,
      SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS pending_bookings,
      SUM(CASE WHEN status = 'confirmed' THEN 1 ELSE 0 END) AS confirmed_bookings,
      SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_bookings,
      SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_bookings
    FROM venue_bookings
    GROUP BY venue_id
  ) vb ON vb.venue_id = v.id

  LEFT JOIN (
    SELECT
      venue_id,
      COUNT(*) AS reviews_count,
      IFNULL(AVG(rating), 0) AS rating_avg,
      SUM(CASE WHEN rating <= 2 THEN 1 ELSE 0 END) AS low_ratings
    FROM reviews
    WHERE venue_id IS NOT NULL
    GROUP BY venue_id
  ) rv ON rv.venue_id = v.id
`;

exports.getAdminVenues = async (req, res) => {
  try {
    const { q = "", filter = "all" } = req.query;

    const search = cleanText(q);
    const params = [];

    let where = "WHERE 1 = 1";

    if (search) {
      where += `
        AND (
          v.name LIKE ?
          OR v.location LIKE ?
          OR u.full_name LIKE ?
          OR u.email LIKE ?
        )
      `;

      params.push(
        `%${search}%`,
        `%${search}%`,
        `%${search}%`,
        `%${search}%`
      );
    }

    const [rows] = await db.query(
      `
      ${venueBaseSelect}
      ${where}
      ORDER BY v.created_at DESC
      `,
      params
    );

    const venues = rows.map(mapVenue);

    const filteredVenues = venues.filter((venue) => {
      if (filter === "needs_attention") return venue.needs_attention;
      if (filter === "hidden") return venue.admin_visibility === "hidden";
      if (filter === "flagged") return venue.venue_flagged;
      if (filter === "not_reviewed") return !venue.venue_reviewed;
      return true;
    });

    const summary = {
      total: venues.length,
      visible: venues.filter((v) => v.admin_visibility === "visible").length,
      hidden: venues.filter((v) => v.admin_visibility === "hidden").length,
      reviewed: venues.filter((v) => v.venue_reviewed).length,
      not_reviewed: venues.filter((v) => !v.venue_reviewed).length,
      flagged: venues.filter((v) => v.venue_flagged).length,
      needs_attention: venues.filter((v) => v.needs_attention).length,
    };

    return res.json({
      success: true,
      summary,
      venues: filteredVenues,
    });
  } catch (error) {
    console.error("getAdminVenues error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to load venues",
      error: error.message,
    });
  }
};

exports.getAdminVenueDetails = async (req, res) => {
  try {
    const venueId = req.params.venueId;

    const [rows] = await db.query(
      `
      ${venueBaseSelect}
      WHERE v.id = ?
      LIMIT 1
      `,
      [venueId]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Venue not found",
      });
    }

    const venue = mapVenue(rows[0]);

    const [images] = await db.query(
      `
      SELECT id, image_url, created_at
      FROM venue_images
      WHERE venue_id = ?
      ORDER BY created_at DESC
      `,
      [venueId]
    );

    const [availability] = await db.query(
      `
      SELECT id, date, start_time, end_time, is_booked
      FROM venue_availability
      WHERE venue_id = ?
      ORDER BY date DESC, start_time ASC
      LIMIT 20
      `,
      [venueId]
    );

    return res.json({
      success: true,
      venue: {
        ...venue,
        images,
        availability,
      },
    });
  } catch (error) {
    console.error("getAdminVenueDetails error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to load venue details",
      error: error.message,
    });
  }
};

exports.updateVenueVisibility = async (req, res) => {
  try {
    const venueId = req.params.venueId;
    const visibility = cleanText(req.body.visibility);

    if (!["visible", "hidden"].includes(visibility)) {
      return res.status(400).json({
        success: false,
        message: "visibility must be visible or hidden",
      });
    }

    const [[venue]] = await db.query(
      `
      SELECT id, owner_id, name, admin_visibility, venue_reviewed
      FROM venues
      WHERE id = ?
      LIMIT 1
      `,
      [venueId]
    );

    if (!venue) {
      return res.status(404).json({
        success: false,
        message: "Venue not found",
      });
    }

    await db.query(
      `
      UPDATE venues
      SET
        admin_visibility = ?
      WHERE id = ?
      `,
      [visibility, venueId]
    );

    try {
      await notificationModel.createNotification(
        venue.owner_id,
        visibility === "visible" ? "Venue Is Now Visible" : "Venue Hidden",
        visibility === "visible"
          ? `Your venue "${venueNameForNotification(venue)}" is now visible to clients.`
          : `Your venue "${venueNameForNotification(venue)}" has been hidden by admin.`,
        visibility === "visible" ? "venue_visible" : "venue_hidden",
        "venue",
        venueId
      );
    } catch (notificationError) {
      console.log(
        "Venue owner visibility notification error:",
        notificationError.message
      );
    }

    return res.json({
      success: true,
      message:
        visibility === "visible"
          ? "Venue is now visible to clients"
          : "Venue is now hidden from clients",
    });
  } catch (error) {
    console.error("updateVenueVisibility error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to update venue visibility",
      error: error.message,
    });
  }
};

exports.updateVenueReviewed = async (req, res) => {
  try {
    const venueId = req.params.venueId;
    const reviewed = toBool(req.body.reviewed);

    const [[venue]] = await db.query(
      `
      SELECT id, owner_id, name, admin_visibility, venue_reviewed
      FROM venues
      WHERE id = ?
      LIMIT 1
      `,
      [venueId]
    );

    if (!venue) {
      return res.status(404).json({
        success: false,
        message: "Venue not found",
      });
    }

    await db.query(
      `
      UPDATE venues
      SET
        venue_reviewed = ?,
        venue_reviewed_at = ?
      WHERE id = ?
      `,
      [reviewed ? 1 : 0, reviewed ? new Date() : null, venueId]
    );

    try {
      await notificationModel.createNotification(
        venue.owner_id,
        reviewed ? "Venue Review Completed" : "Venue Needs Review Again",
        reviewed
          ? `Your venue "${venueNameForNotification(venue)}" has been reviewed by admin.`
          : `The review status was removed from your venue "${venueNameForNotification(venue)}".`,
        reviewed ? "venue_reviewed" : "venue_review_removed",
        "venue",
        venueId
      );
    } catch (notificationError) {
      console.log(
        "Venue owner reviewed notification error:",
        notificationError.message
      );
    }

    return res.json({
      success: true,
      message: reviewed
        ? "Venue marked as reviewed"
        : "Venue review status removed",
    });
  } catch (error) {
    console.error("updateVenueReviewed error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to update venue review status",
      error: error.message,
    });
  }
};

exports.updateVenueFlag = async (req, res) => {
  try {
    const venueId = req.params.venueId;
    const flagged = toBool(req.body.flagged);
    const reason = cleanText(req.body.reason);

    if (flagged && reason.length < 3) {
      return res.status(400).json({
        success: false,
        message: "Flag reason is required",
      });
    }

    const [[venue]] = await db.query(
      `
      SELECT id, owner_id, name, venue_flagged, venue_flag_reason
      FROM venues
      WHERE id = ?
      LIMIT 1
      `,
      [venueId]
    );

    if (!venue) {
      return res.status(404).json({
        success: false,
        message: "Venue not found",
      });
    }

    await db.query(
      `
      UPDATE venues
      SET
        venue_flagged = ?,
        venue_flag_reason = ?
      WHERE id = ?
      `,
      [flagged ? 1 : 0, flagged ? reason : null, venueId]
    );

    try {
      await notificationModel.createNotification(
        venue.owner_id,
        flagged ? "Venue Flagged by Admin" : "Venue Flag Removed",
        flagged
          ? `Your venue "${venueNameForNotification(venue)}" was flagged by admin. Reason: ${reason}`
          : `The admin flag was removed from your venue "${venueNameForNotification(venue)}".`,
        flagged ? "venue_flagged" : "venue_flag_removed",
        "venue",
        venueId
      );
    } catch (notificationError) {
      console.log(
        "Venue owner flag notification error:",
        notificationError.message
      );
    }

    return res.json({
      success: true,
      message: flagged ? "Venue flagged successfully" : "Venue flag removed",
    });
  } catch (error) {
    console.error("updateVenueFlag error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to update venue flag",
      error: error.message,
    });
  }
};