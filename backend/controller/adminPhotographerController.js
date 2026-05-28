const db = require("../config/db");

function toNumber(value) {
  const n = Number(value || 0);
  return Number.isFinite(n) ? n : 0;
}

function toBool(value) {
  return value === true || value === 1 || value === "1";
}

function percentage(part, total) {
  const p = toNumber(part);
  const t = toNumber(total);

  if (t <= 0) return 0;

  return Number(((p / t) * 100).toFixed(1));
}

function cleanText(value) {
  if (value === null || value === undefined) return "";
  const text = value.toString().trim();
  if (!text || text === "null" || text === "undefined") return "";
  return text;
}

async function logAdminActivity({
  userId,
  adminId,
  action,
  description,
  metadata = null,
}) {
  try {
    await db.query(
      `
      INSERT INTO admin_activity_logs (
        user_id,
        admin_id,
        action,
        description,
        metadata
      )
      VALUES (?, ?, ?, ?, ?)
      `,
      [
        userId || null,
        adminId || null,
        action,
        description || null,
        metadata ? JSON.stringify(metadata) : null,
      ]
    );
  } catch (error) {
    console.error("Admin photographer activity log error:", error.message);
  }
}

function buildPhotographerQuality(row) {
  const missing = [];

  const hasBio = cleanText(row.photographer_bio).length > 0;
  const hasLocation = cleanText(row.location).length > 0;
  const hasPrice = toNumber(row.price_per_hour) > 0;
  const hasSpecialties = cleanText(row.specialties).length > 0;
  const hasPortfolio = toNumber(row.portfolio_items_count) > 0;
  const hasAvailability = toNumber(row.availability_days_count) > 0;
  const portfolioReviewed = toNumber(row.portfolio_reviewed) === 1;
  const adminFlagged = toNumber(row.admin_flagged) === 1;
const visibility = cleanText(row.admin_visibility) || "hidden";

  if (!hasBio) missing.push("Bio");
  if (!hasLocation) missing.push("Location");
  if (!hasPrice) missing.push("Price per hour");
  if (!hasSpecialties) missing.push("Specialties");
  if (!hasPortfolio) missing.push("Portfolio");
  if (!hasAvailability) missing.push("Availability");
  if (!portfolioReviewed) missing.push("Portfolio review");

  const totalBookings = toNumber(row.total_bookings);
  const completedBookings = toNumber(row.completed_bookings);
  const cancelledBookings = toNumber(row.cancelled_bookings);
  const rejectedBookings = toNumber(row.rejected_bookings);

  const completionRate = percentage(completedBookings, totalBookings);
  const cancellationRate = percentage(cancelledBookings, totalBookings);
  const rejectionRate = percentage(rejectedBookings, totalBookings);

  const ratingAvg = Number(row.rating_avg || 0);
  const ratingCount = toNumber(row.rating_count);

  let trustScore = 0;

  if (hasBio && hasLocation && hasPrice && hasSpecialties) trustScore += 20;
  if (hasPortfolio) trustScore += 20;
  if (portfolioReviewed) trustScore += 20;
  if (hasAvailability) trustScore += 20;

  if (ratingCount > 0) {
    if (ratingAvg >= 4) trustScore += 10;
    else if (ratingAvg >= 3.5) trustScore += 5;
  }

  if (totalBookings === 0) {
    trustScore += 5;
  } else if (cancellationRate <= 20 && rejectionRate <= 30) {
    trustScore += 10;
  } else if (cancellationRate <= 35 && rejectionRate <= 45) {
    trustScore += 5;
  }

  trustScore = Math.min(100, trustScore);

  const warnings = [];

  if (visibility === "hidden") warnings.push("Hidden from clients");
  if (adminFlagged) warnings.push("Flagged by admin");
  if (!hasPortfolio) warnings.push("No portfolio");
  if (!hasAvailability) warnings.push("No availability");
  if (ratingCount >= 3 && ratingAvg < 3.5) warnings.push("Low rating");
  if (totalBookings >= 3 && cancellationRate >= 30) {
    warnings.push("High cancellation rate");
  }
  if (totalBookings >= 3 && rejectionRate >= 40) {
    warnings.push("High rejection rate");
  }

  let verificationStatus = "not_verified";

  if (
    missing.length === 0 &&
    visibility === "visible" &&
    !adminFlagged
  ) {
    verificationStatus = "verified";
  } else if (adminFlagged || warnings.length > 0) {
    verificationStatus = "needs_review";
  }

  return {
    trust_score: trustScore,
    verification_status: verificationStatus,
    missing_requirements: missing,
    warnings,
    completion_rate: completionRate,
    cancellation_rate: cancellationRate,
    rejection_rate: rejectionRate,
    has_profile_info: hasBio && hasLocation && hasPrice && hasSpecialties,
    has_portfolio: hasPortfolio,
    has_availability: hasAvailability,
    portfolio_reviewed: portfolioReviewed,
    admin_flagged: adminFlagged,
    admin_visibility: visibility,
  };
}

function shapePhotographerRow(row) {
  const quality = buildPhotographerQuality(row);

  return {
    photographer_id: row.photographer_id,
    user_id: row.user_id,

    full_name: row.full_name,
    email: row.email,
    profile_image: row.profile_image,
    account_status: row.account_status,

    location: row.location,
    specialties: row.specialties,
    price_per_hour: row.price_per_hour,
    experience_years: row.experience_years,

    rating_avg: Number(row.rating_avg || 0),
    rating_count: toNumber(row.rating_count),
    low_rating_count: toNumber(row.low_rating_count),

    admin_visibility: quality.admin_visibility,
    portfolio_reviewed: quality.portfolio_reviewed,
    reviewed_at: row.reviewed_at,
    admin_flagged: quality.admin_flagged,
    admin_flag_reason: row.admin_flag_reason,

    trust_score: quality.trust_score,
    verification_status: quality.verification_status,
    missing_requirements: quality.missing_requirements,
    warnings: quality.warnings,

    portfolio_summary: {
      total_items: toNumber(row.portfolio_items_count),
      featured_items: toNumber(row.featured_items_count),
      albums_count: toNumber(row.albums_count),
      last_upload_at: row.last_portfolio_upload,
    },

    booking_summary: {
      total: toNumber(row.total_bookings),
      completed: toNumber(row.completed_bookings),
      cancelled: toNumber(row.cancelled_bookings),
      rejected: toNumber(row.rejected_bookings),
      pending: toNumber(row.pending_bookings),
      confirmed: toNumber(row.confirmed_bookings),
      completion_rate: quality.completion_rate,
      cancellation_rate: quality.cancellation_rate,
      rejection_rate: quality.rejection_rate,
    },

    availability_summary: {
      has_availability: quality.has_availability,
      weekly_days_count: toNumber(row.availability_days_count),
      blocked_slots_count: toNumber(row.blocked_slots_count),
    },
  };
}

async function getPhotographerAdminRows({ q = "" } = {}) {
  let sql = `
    SELECT
      p.photographer_id,
      p.user_id,
      p.bio AS photographer_bio,
      p.experience_years,
      p.price_per_hour,
      p.rating_avg,
      p.rating_count,
      p.location,
      p.specialties,
      p.latitude,
      p.longitude,
COALESCE(p.admin_visibility, 'hidden') AS admin_visibility,
      COALESCE(p.portfolio_reviewed, 0) AS portfolio_reviewed,
      p.reviewed_at,
      COALESCE(p.admin_flagged, 0) AS admin_flagged,
      p.admin_flag_reason,

      u.full_name,
      u.email,
      u.profile_image,
      COALESCE(u.status, 'active') AS account_status,

      COALESCE(portfolioStats.portfolio_items_count, 0) AS portfolio_items_count,
      COALESCE(portfolioStats.featured_items_count, 0) AS featured_items_count,
      COALESCE(portfolioStats.albums_count, 0) AS albums_count,
      portfolioStats.last_portfolio_upload,

      COALESCE(bookingStats.total_bookings, 0) AS total_bookings,
      COALESCE(bookingStats.completed_bookings, 0) AS completed_bookings,
      COALESCE(bookingStats.cancelled_bookings, 0) AS cancelled_bookings,
      COALESCE(bookingStats.rejected_bookings, 0) AS rejected_bookings,
      COALESCE(bookingStats.pending_bookings, 0) AS pending_bookings,
      COALESCE(bookingStats.confirmed_bookings, 0) AS confirmed_bookings,

      COALESCE(availabilityStats.availability_days_count, 0) AS availability_days_count,
      COALESCE(availabilityStats.blocked_slots_count, 0) AS blocked_slots_count,

      COALESCE(reviewStats.low_rating_count, 0) AS low_rating_count

    FROM photographers p
    JOIN users u ON u.id = p.user_id

    LEFT JOIN (
      SELECT
        pf.photographer_id,
        COUNT(DISTINCT pi.id) AS portfolio_items_count,
        SUM(CASE WHEN pi.is_featured = 1 THEN 1 ELSE 0 END) AS featured_items_count,
        COUNT(DISTINCT pa.id) AS albums_count,
        MAX(pi.created_at) AS last_portfolio_upload
      FROM photographer_portfolios pf
      LEFT JOIN portfolio_items pi ON pi.portfolio_id = pf.id
      LEFT JOIN portfolio_albums pa ON pa.portfolio_id = pf.id
      GROUP BY pf.photographer_id
    ) portfolioStats ON portfolioStats.photographer_id = p.photographer_id

    LEFT JOIN (
      SELECT
        photographer_id,
        COUNT(*) AS total_bookings,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_bookings,
        SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_bookings,
        SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) AS rejected_bookings,
        SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS pending_bookings,
        SUM(CASE WHEN status = 'confirmed' THEN 1 ELSE 0 END) AS confirmed_bookings
      FROM photographer_bookings
      GROUP BY photographer_id
    ) bookingStats ON bookingStats.photographer_id = p.photographer_id

    LEFT JOIN (
      SELECT
        pws.photographer_id,
        COUNT(DISTINCT pws.day_of_week) AS availability_days_count,
        COALESCE(blocked.blocked_slots_count, 0) AS blocked_slots_count
      FROM photographer_weekly_schedule pws
      LEFT JOIN (
        SELECT
          photographer_id,
          COUNT(*) AS blocked_slots_count
        FROM photographer_blocked_slots
        GROUP BY photographer_id
      ) blocked ON blocked.photographer_id = pws.photographer_id
      GROUP BY pws.photographer_id
    ) availabilityStats ON availabilityStats.photographer_id = p.photographer_id

    LEFT JOIN (
      SELECT
        photographer_id,
        SUM(CASE WHEN rating <= 2 THEN 1 ELSE 0 END) AS low_rating_count
      FROM photographer_reviews
      GROUP BY photographer_id
    ) reviewStats ON reviewStats.photographer_id = p.photographer_id

    WHERE u.role = 'photographer'
  `;

  const params = [];

  if (q && q.trim()) {
    sql += `
      AND (
        u.full_name LIKE ?
        OR u.email LIKE ?
        OR p.location LIKE ?
        OR p.specialties LIKE ?
      )
    `;

    const searchValue = `%${q.trim()}%`;
    params.push(searchValue, searchValue, searchValue, searchValue);
  }

  sql += ` ORDER BY p.photographer_id DESC`;

  const [rows] = await db.query(sql, params);
  return rows;
}

function filterPhotographers(list, filter) {
  if (!filter || filter === "all") return list;

  return list.filter((p) => {
    if (filter === "verified") {
      return p.verification_status === "verified";
    }

    if (filter === "not_verified") {
      return p.verification_status === "not_verified";
    }

    if (filter === "needs_review") {
      return p.verification_status === "needs_review" || p.admin_flagged;
    }

    if (filter === "hidden") {
      return p.admin_visibility === "hidden";
    }

    if (filter === "visible") {
      return p.admin_visibility === "visible";
    }

    if (filter === "portfolio_not_reviewed") {
      return !p.portfolio_reviewed;
    }

    if (filter === "low_rating") {
      return p.rating_count >= 3 && p.rating_avg < 3.5;
    }

    if (filter === "low_completion") {
      return p.booking_summary.total >= 3 && p.booking_summary.completion_rate < 50;
    }

    if (filter === "no_availability") {
      return !p.availability_summary.has_availability;
    }

    return true;
  });
}

exports.getAdminPhotographers = async (req, res) => {
  try {
    const { q = "", filter = "all" } = req.query;

    const rows = await getPhotographerAdminRows({ q });
    const shaped = rows.map(shapePhotographerRow);
    const filtered = filterPhotographers(shaped, filter);

    const summary = {
      total: shaped.length,
      verified: shaped.filter((p) => p.verification_status === "verified").length,
      not_verified: shaped.filter((p) => p.verification_status === "not_verified").length,
      needs_review: shaped.filter((p) => p.verification_status === "needs_review").length,
      hidden: shaped.filter((p) => p.admin_visibility === "hidden").length,
      portfolio_not_reviewed: shaped.filter((p) => !p.portfolio_reviewed).length,
      no_availability: shaped.filter((p) => !p.availability_summary.has_availability).length,
    };

    return res.json({
      success: true,
      summary,
      photographers: filtered,
    });
  } catch (error) {
    console.error("getAdminPhotographers error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to load admin photographers",
      error: error.message,
    });
  }
};

exports.getAdminPhotographerDetails = async (req, res) => {
  try {
    const photographerId = req.params.photographerId;

    const rows = await getPhotographerAdminRows();

    const row = rows.find(
      (item) => Number(item.photographer_id) === Number(photographerId)
    );

    if (!row) {
      return res.status(404).json({
        success: false,
        message: "Photographer not found",
      });
    }

    const photographer = shapePhotographerRow(row);

    return res.json({
      success: true,
      photographer,
    });
  } catch (error) {
    console.error("getAdminPhotographerDetails error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to load photographer details",
      error: error.message,
    });
  }
};

exports.updatePhotographerVisibility = async (req, res) => {
  try {
    const adminId = req.user.id;
    const photographerId = req.params.photographerId;
    const { visibility } = req.body;

    const allowed = ["visible", "hidden"];

    if (!allowed.includes(visibility)) {
      return res.status(400).json({
        success: false,
        message: "visibility must be visible or hidden",
      });
    }

    const [[photographer]] = await db.query(
      `
SELECT photographer_id, user_id, COALESCE(admin_visibility, 'hidden') AS old_visibility      FROM photographers
      WHERE photographer_id = ?
      LIMIT 1
      `,
      [photographerId]
    );

    if (!photographer) {
      return res.status(404).json({
        success: false,
        message: "Photographer not found",
      });
    }

    await db.query(
      `
      UPDATE photographers
      SET admin_visibility = ?
      WHERE photographer_id = ?
      `,
      [visibility, photographerId]
    );

    await logAdminActivity({
      userId: photographer.user_id,
      adminId,
      action:
        visibility === "hidden"
          ? "photographer_hidden_from_clients"
          : "photographer_visible_to_clients",
      description:
        visibility === "hidden"
          ? "Admin hid this photographer from client search."
          : "Admin made this photographer visible to clients.",
      metadata: {
        photographer_id: photographer.photographer_id,
        old_visibility: photographer.old_visibility,
        new_visibility: visibility,
      },
    });

    return res.json({
      success: true,
      message:
        visibility === "hidden"
          ? "Photographer hidden from clients"
          : "Photographer is now visible to clients",
    });
  } catch (error) {
    console.error("updatePhotographerVisibility error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to update photographer visibility",
      error: error.message,
    });
  }
};

exports.updatePortfolioReviewed = async (req, res) => {
  try {
    const adminId = req.user.id;
    const photographerId = req.params.photographerId;
    const reviewed = toBool(req.body.reviewed);

    const [[photographer]] = await db.query(
      `
      SELECT photographer_id, user_id, COALESCE(portfolio_reviewed, 0) AS old_reviewed
      FROM photographers
      WHERE photographer_id = ?
      LIMIT 1
      `,
      [photographerId]
    );

    if (!photographer) {
      return res.status(404).json({
        success: false,
        message: "Photographer not found",
      });
    }

    await db.query(
      `
      UPDATE photographers
      SET
        portfolio_reviewed = ?,
        reviewed_at = CASE WHEN ? = 1 THEN NOW() ELSE NULL END
      WHERE photographer_id = ?
      `,
      [reviewed ? 1 : 0, reviewed ? 1 : 0, photographerId]
    );

    await logAdminActivity({
      userId: photographer.user_id,
      adminId,
      action: reviewed
        ? "photographer_portfolio_marked_reviewed"
        : "photographer_portfolio_review_removed",
      description: reviewed
        ? "Admin marked this photographer portfolio as reviewed."
        : "Admin removed the portfolio reviewed status from this photographer.",
      metadata: {
        photographer_id: photographer.photographer_id,
        old_reviewed: photographer.old_reviewed,
        new_reviewed: reviewed ? 1 : 0,
      },
    });

    return res.json({
      success: true,
      message: reviewed
        ? "Portfolio marked as reviewed"
        : "Portfolio review status removed",
    });
  } catch (error) {
    console.error("updatePortfolioReviewed error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to update portfolio review status",
      error: error.message,
    });
  }
};

exports.updatePhotographerFlag = async (req, res) => {
  try {
    const adminId = req.user.id;
    const photographerId = req.params.photographerId;
    const flagged = toBool(req.body.flagged);
    const reason = cleanText(req.body.reason);

    if (flagged && reason.length < 3) {
      return res.status(400).json({
        success: false,
        message: "Flag reason is required",
      });
    }

    const [[photographer]] = await db.query(
      `
      SELECT photographer_id, user_id, COALESCE(admin_flagged, 0) AS old_flagged
      FROM photographers
      WHERE photographer_id = ?
      LIMIT 1
      `,
      [photographerId]
    );

    if (!photographer) {
      return res.status(404).json({
        success: false,
        message: "Photographer not found",
      });
    }

    await db.query(
      `
      UPDATE photographers
      SET
        admin_flagged = ?,
        admin_flag_reason = ?
      WHERE photographer_id = ?
      `,
      [flagged ? 1 : 0, flagged ? reason : null, photographerId]
    );

    await logAdminActivity({
      userId: photographer.user_id,
      adminId,
      action: flagged
        ? "photographer_flagged_for_review"
        : "photographer_flag_removed",
      description: flagged
        ? "Admin flagged this photographer for review."
        : "Admin removed the review flag from this photographer.",
      metadata: {
        photographer_id: photographer.photographer_id,
        old_flagged: photographer.old_flagged,
        new_flagged: flagged ? 1 : 0,
        reason: flagged ? reason : null,
      },
    });

    return res.json({
      success: true,
      message: flagged
        ? "Photographer flagged for review"
        : "Photographer flag removed",
    });
  } catch (error) {
    console.error("updatePhotographerFlag error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to update photographer flag",
      error: error.message,
    });
  }
};


exports.getAdminPhotographerPortfolio = async (req, res) => {
  try {
    const photographerId = req.params.photographerId;

    const [[photographer]] = await db.query(
      `
      SELECT
        p.photographer_id,
        p.user_id,
        p.admin_visibility,
        p.portfolio_reviewed,
        p.reviewed_at,
        p.admin_flagged,
        p.admin_flag_reason,
        u.full_name,
        u.email,
        u.profile_image
      FROM photographers p
      JOIN users u ON u.id = p.user_id
      WHERE p.photographer_id = ?
      LIMIT 1
      `,
      [photographerId]
    );

    if (!photographer) {
      return res.status(404).json({
        success: false,
        message: "Photographer not found",
      });
    }

    const [[portfolio]] = await db.query(
      `
      SELECT *
      FROM photographer_portfolios
      WHERE photographer_id = ?
      LIMIT 1
      `,
      [photographerId]
    );

    if (!portfolio) {
      return res.json({
        success: true,
        photographer,
        portfolio: null,
        categories: [],
        albums: [],
        items: [],
        featured: [],
        summary: {
          total_items: 0,
          featured_items: 0,
          albums_count: 0,
          categories_count: 0,
        },
      });
    }

    const portfolioId = portfolio.id;

    const [categories] = await db.query(
      `
      SELECT *
      FROM portfolio_categories
      WHERE portfolio_id = ?
      ORDER BY id ASC
      `,
      [portfolioId]
    );

    const [albums] = await db.query(
      `
      SELECT *
      FROM portfolio_albums
      WHERE portfolio_id = ?
      ORDER BY id ASC
      `,
      [portfolioId]
    );

  const [items] = await db.query(
  `
  SELECT
    pi.*,
    pa.title AS album_name,
    pc.name AS category_name
  FROM portfolio_items pi
  LEFT JOIN portfolio_albums pa ON pa.id = pi.album_id
  LEFT JOIN portfolio_categories pc ON pc.id = pi.category_id
  WHERE pi.portfolio_id = ?
  ORDER BY
    pi.is_featured DESC,
    pi.sort_order ASC,
    pi.created_at DESC
  `,
  [portfolioId]
);

    const featured = items.filter((item) => Number(item.is_featured) === 1);

    return res.json({
      success: true,
      photographer,
      portfolio,
      categories,
      albums,
      items,
      featured,
      summary: {
        total_items: items.length,
        featured_items: featured.length,
        albums_count: albums.length,
        categories_count: categories.length,
      },
    });
  } catch (error) {
    console.error("getAdminPhotographerPortfolio error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to load photographer portfolio",
      error: error.message,
    });
  }
};