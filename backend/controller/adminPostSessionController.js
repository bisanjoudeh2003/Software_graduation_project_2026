const db = require("../config/db");
const notificationModel = require("../model/notificationModel");

const TRUE_VALUES = [1, "1", true, "true", "TRUE"];

function isTruthy(value) {
  return TRUE_VALUES.includes(value);
}

function numberValue(value) {
  const n = Number(value || 0);
  return Number.isNaN(n) ? 0 : n;
}

function isDeliveredStatus(status) {
  return ["delivered", "revision_requested", "finalized", "archived"].includes(
    String(status || "").toLowerCase()
  );
}

function toDateOnly(value) {
  if (!value) return null;

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) return null;

  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function daysBetweenDates(fromDate, toDate) {
  if (!fromDate || !toDate) return 0;

  const oneDay = 1000 * 60 * 60 * 24;
  return Math.floor((toDate.getTime() - fromDate.getTime()) / oneDay);
}

function getDeliveryCommitment({
  estimatedDeliveryDate,
  deliveredAt,
  delivered,
}) {
  const expectedDate = toDateOnly(estimatedDeliveryDate);
  const actualDeliveredDate = toDateOnly(deliveredAt);
  const today = toDateOnly(new Date());

  if (!expectedDate) {
    return {
      delivery_commitment_status: "no_expected_date",
      delivery_commitment_label: "No expected date",
      delivery_days_late: 0,
      delivery_is_overdue: false,
      delivery_was_late: false,
      delivery_was_on_time: false,
      can_send_delivery_reminder: false,
    };
  }

  if (delivered && actualDeliveredDate) {
    const daysLate = daysBetweenDates(expectedDate, actualDeliveredDate);

    if (daysLate <= 0) {
      return {
        delivery_commitment_status: "on_time",
        delivery_commitment_label: "On time",
        delivery_days_late: 0,
        delivery_is_overdue: false,
        delivery_was_late: false,
        delivery_was_on_time: true,
        can_send_delivery_reminder: false,
      };
    }

    return {
      delivery_commitment_status: "late",
      delivery_commitment_label: `Delivered late by ${daysLate} day${
        daysLate === 1 ? "" : "s"
      }`,
      delivery_days_late: daysLate,
      delivery_is_overdue: false,
      delivery_was_late: true,
      delivery_was_on_time: false,
      can_send_delivery_reminder: false,
    };
  }

  const daysAfterExpected = daysBetweenDates(expectedDate, today);

  if (daysAfterExpected > 0) {
    return {
      delivery_commitment_status: "overdue",
      delivery_commitment_label: `Overdue by ${daysAfterExpected} day${
        daysAfterExpected === 1 ? "" : "s"
      }`,
      delivery_days_late: daysAfterExpected,
      delivery_is_overdue: true,
      delivery_was_late: false,
      delivery_was_on_time: false,
      can_send_delivery_reminder: true,
    };
  }

  return {
    delivery_commitment_status: "within_time",
    delivery_commitment_label: "Within expected time",
    delivery_days_late: 0,
    delivery_is_overdue: false,
    delivery_was_late: false,
    delivery_was_on_time: false,
    can_send_delivery_reminder: false,
  };
}

function clampScore(value) {
  if (value < 0) return 0;
  if (value > 100) return 100;
  return value;
}

function getQualityOverview(session) {
  let score = 0;
  const reasons = [];

  if (session.gallery_created) {
    score += 15;
  } else {
    reasons.push("Album is missing");
  }

  if (session.delivered) {
    score += 15;
  } else {
    reasons.push("Album is not delivered");
  }

  if (session.delivery_commitment_status === "on_time") {
    score += 20;
  } else if (session.delivery_commitment_status === "within_time") {
    score += 12;
  } else if (session.delivery_commitment_status === "late") {
    score += 6;
    reasons.push("Gallery was delivered late");
  } else if (session.delivery_commitment_status === "overdue") {
    score -= 20;
    reasons.push("Delivery is overdue");
  } else if (session.delivery_commitment_status === "no_expected_date") {
    reasons.push("Expected delivery date is not set");
  }

  if (session.revisions_done) {
    score += 12;
  } else {
    score -= 8;
    reasons.push("There are active revision requests");
  }

  if (session.final_access) {
    score += 10;
  } else {
    reasons.push("Final access is still locked");
  }

  if (session.photographer_review_submitted) {
    score += 8;
  } else {
    reasons.push("Photographer review is missing");
  }

  if (
    session.photographer_rating !== null &&
    Number(session.photographer_rating) < 3
  ) {
    score -= 15;
    reasons.push("Photographer rating is low");
  }

  if (session.has_system_venue) {
    if (session.venue_booking_exists) {
      score += 5;
    } else {
      score -= 8;
      reasons.push("Venue booking was not matched");
    }

    if (session.venue_deposit_paid) {
      score += 5;
    } else {
      reasons.push("Venue deposit is unpaid");
    }

    if (session.venue_completed) {
      score += 5;
    } else {
      reasons.push("Venue booking is not completed");
    }

    if (session.venue_review_submitted) {
      score += 5;
    } else {
      reasons.push("Venue review is missing");
    }

    if (session.venue_rating !== null && Number(session.venue_rating) < 3) {
      score -= 15;
      reasons.push("Venue rating is low");
    }
  } else {
    score += 5;
  }

  score = clampScore(Math.round(score));

  let priorityLevel = "low";
  let priorityLabel = "Low Priority";

  if (
    session.delivery_commitment_status === "overdue" ||
    session.active_revision_count > 0 ||
    (session.photographer_rating !== null &&
      Number(session.photographer_rating) < 3) ||
    (session.venue_rating !== null && Number(session.venue_rating) < 3)
  ) {
    priorityLevel = "high";
    priorityLabel = "High Priority";
  } else if (
    !session.gallery_created ||
    !session.delivered ||
    !session.final_access ||
    !session.photographer_review_submitted ||
    session.clean_copy_status === "pending" ||
    (session.has_system_venue && !session.venue_review_submitted)
  ) {
    priorityLevel = "medium";
    priorityLabel = "Medium Priority";
  } else if (score >= 90) {
    priorityLevel = "completed";
    priorityLabel = "Completed";
  }

  let qualityReason = "Post-session flow looks good.";

  if (reasons.length > 0) {
    qualityReason = reasons.slice(0, 3).join(", ");
  }

  return {
    quality_score: score,
    priority_level: priorityLevel,
    priority_label: priorityLabel,
    quality_reason: qualityReason,
    quality_reasons: reasons,
  };
}

function getPhotographyStatusText(session) {
  if (!session.gallery_created) return "Gallery Missing";
  if (!session.delivered) return "Not Delivered";
  if (!session.revisions_done) return "Revision Pending";
  if (session.clean_copy_status === "pending") return "Clean Copy Pending";
  if (!session.final_access) return "Access Locked";
  if (!session.photographer_review_submitted) return "No Photographer Review";

  if (
    session.photographer_rating !== null &&
    Number(session.photographer_rating) < 3
  ) {
    return "Low Photographer Rating";
  }

  return "Completed";
}

function getVenueStatusText(session) {
  if (!session.has_system_venue) return "External Location";
  if (!session.venue_booking_id) return "Venue Booking Missing";
  if (!session.venue_deposit_paid) return "Venue Deposit Unpaid";
  if (!session.venue_completed) return "Venue Not Completed";
  if (!session.venue_review_submitted) return "No Venue Review";

  if (session.venue_rating !== null && Number(session.venue_rating) < 3) {
    return "Low Venue Rating";
  }

  return "Completed";
}

function getOverallStatusText(session) {
  if (session.photography_status_text !== "Completed") {
    return session.photography_status_text;
  }

  if (session.has_system_venue && session.venue_status_text !== "Completed") {
    return session.venue_status_text;
  }

  return "Completed";
}

function getStatusNote(session) {
  switch (session.overall_status_text) {
    case "Gallery Missing":
      return "The photography session is completed, but no gallery has been created yet.";
    case "Not Delivered":
      return "A gallery exists, but it has not been delivered to the client yet.";
    case "Revision Pending":
      return "There are active revision requests that still need follow-up.";
    case "Clean Copy Pending":
      return "The client requested a clean copy without watermark and it is still pending.";
    case "Access Locked":
      return "Final access or download is not fully enabled yet.";
    case "No Photographer Review":
      return "The client has not reviewed the photographer after the session.";
    case "Low Photographer Rating":
      return "The photographer received a low rating and may need admin review.";
    case "External Location":
      return "The client used an external location, so venue follow-up is not required.";
    case "Venue Booking Missing":
      return "The session has a system venue, but no matching venue booking was found.";
    case "Venue Deposit Unpaid":
      return "The venue booking exists, but the venue deposit is not paid.";
    case "Venue Not Completed":
      return "The venue booking has not been marked as completed yet.";
    case "No Venue Review":
      return "The client has not reviewed the venue after the session.";
    case "Low Venue Rating":
      return "The venue received a low rating and may need admin review.";
    default:
      return "Post-session flow completed successfully.";
  }
}

exports.getPostSessionMonitor = async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT
        b.id AS booking_id,
        b.client_id,
        b.photographer_id,
        b.venue_id,
        b.session_type,
        b.date AS completed_at,
        b.time,
        b.location,
        b.status AS booking_status,
        b.created_at AS booking_created_at,
        b.updated_at AS booking_updated_at,

        b.remaining_amount,
        b.remaining_paid,
        b.remaining_paid_at,
        b.remaining_payment_status,

        c.full_name AS client_name,
        c.email AS client_email,

        pu.id AS photographer_user_id,
        pu.full_name AS photographer_name,
        pu.email AS photographer_email,

        g.id AS gallery_id,
        g.title AS gallery_title,
        g.status AS gallery_status,
        g.cover_image,
        g.estimated_delivery_date,
        g.delivered_at,
        g.finalized_at,
        g.allow_download,
        g.preview_watermarked,
        g.clean_copy_status,
        g.clean_copy_requested_at,
        g.clean_copy_responded_at,
        g.updated_at AS gallery_updated_at,

        COALESCE(rev.revision_count, 0) AS revision_count,
        COALESCE(rev.active_revision_count, 0) AS active_revision_count,
        rev.last_revision_update,

        pr.id AS photographer_review_id,
        pr.rating AS photographer_rating,
        pr.comment AS photographer_review_comment,
        pr.created_at AS photographer_review_created_at,

        v.id AS venue_system_id,
        v.name AS venue_name,
        v.location AS venue_location,
        v.owner_id AS venue_owner_id,
        v.rating_avg AS venue_rating_avg,

        vb.id AS venue_booking_id,
        vb.status AS venue_booking_status,
        vb.deposit_paid AS venue_deposit_paid,
        vb.remaining_paid AS venue_remaining_paid,
        vb.total_price AS venue_total_price,
        vb.deposit_amount AS venue_deposit_amount,
        vb.created_at AS venue_booking_created_at,

        vr.id AS venue_review_id,
        vr.rating AS venue_rating,
        vr.comment AS venue_review_comment,
        vr.created_at AS venue_review_created_at

      FROM photographer_bookings b

      JOIN users c
        ON c.id = b.client_id

      JOIN photographers p
        ON p.photographer_id = b.photographer_id

      JOIN users pu
        ON pu.id = p.user_id

      LEFT JOIN booking_galleries g
        ON g.booking_id = b.id

      LEFT JOIN (
        SELECT
          gallery_id,
          COUNT(*) AS revision_count,
          SUM(
            CASE
              WHEN status IN ('pending', 'in_progress')
              THEN 1 ELSE 0
            END
          ) AS active_revision_count,
          MAX(updated_at) AS last_revision_update
        FROM booking_gallery_item_revision_requests
        GROUP BY gallery_id
      ) rev
        ON rev.gallery_id = g.id

      LEFT JOIN photographer_reviews pr
        ON pr.booking_id = b.id

      LEFT JOIN venues v
        ON v.id = b.venue_id

      LEFT JOIN venue_bookings vb
        ON vb.client_id = b.client_id
        AND vb.venue_id = b.venue_id
        AND vb.booking_date = b.date

      LEFT JOIN (
        SELECT
          r1.id,
          r1.client_id,
          r1.venue_id,
          r1.rating,
          r1.comment,
          r1.created_at
        FROM reviews r1
        INNER JOIN (
          SELECT
            client_id,
            venue_id,
            MAX(id) AS max_id
          FROM reviews
          GROUP BY client_id, venue_id
        ) latest
          ON latest.max_id = r1.id
      ) vr
        ON vr.client_id = b.client_id
        AND vr.venue_id = b.venue_id

      WHERE b.status = 'completed'

      ORDER BY
        b.date DESC,
        b.id DESC
    `);

    const sessions = rows.map((row) => {
      const galleryCreated =
        row.gallery_id !== null && row.gallery_id !== undefined;

      const delivered = galleryCreated && isDeliveredStatus(row.gallery_status);

      const activeRevisionCount = numberValue(row.active_revision_count);
      const revisionCount = numberValue(row.revision_count);
      const revisionsDone = activeRevisionCount === 0;

      const remainingAmount = numberValue(row.remaining_amount);
      const remainingPaid = isTruthy(row.remaining_paid);

      const finalAccess =
        galleryCreated &&
        (remainingAmount <= 0 ||
          (remainingPaid && isTruthy(row.allow_download)));

      const photographerRating =
        row.photographer_rating === null ||
        row.photographer_rating === undefined
          ? null
          : Number(row.photographer_rating);

      const photographerReviewSubmitted =
        row.photographer_review_id !== null &&
        row.photographer_review_id !== undefined;

      const hasSystemVenue =
        row.venue_id !== null &&
        row.venue_id !== undefined &&
        row.venue_system_id !== null &&
        row.venue_system_id !== undefined;

      const venueBookingExists =
        row.venue_booking_id !== null &&
        row.venue_booking_id !== undefined;

      const venueDepositPaid = isTruthy(row.venue_deposit_paid);

      const venueCompleted =
        String(row.venue_booking_status || "").toLowerCase() === "completed";

      const venueRating =
        row.venue_rating === null || row.venue_rating === undefined
          ? null
          : Number(row.venue_rating);

      const venueReviewSubmitted =
        row.venue_review_id !== null && row.venue_review_id !== undefined;

      const deliveryCommitment = getDeliveryCommitment({
        estimatedDeliveryDate: row.estimated_delivery_date,
        deliveredAt: row.delivered_at,
        delivered,
      });

      const session = {
        booking_id: row.booking_id,
        session_type: row.session_type,
        title:
          row.gallery_title || `${row.session_type || "Photography"} Session`,

        client_id: row.client_id,
        client_name: row.client_name,
        client_email: row.client_email,

        photographer_id: row.photographer_id,
        photographer_user_id: row.photographer_user_id,
        photographer_name: row.photographer_name,
        photographer_email: row.photographer_email,

        completed_at: row.completed_at,
        last_update:
          row.gallery_updated_at ||
          row.last_revision_update ||
          row.booking_updated_at ||
          row.booking_created_at ||
          row.completed_at,

        gallery_id: row.gallery_id,
        gallery_created: galleryCreated,
        gallery_status: row.gallery_status || "not_created",
        cover_image: row.cover_image,
        estimated_delivery_date: row.estimated_delivery_date,
        delivered_at: row.delivered_at,
        finalized_at: row.finalized_at,

        delivered,
        revisions_done: revisionsDone,
        final_access: finalAccess,

        revision_count: revisionCount,
        active_revision_count: activeRevisionCount,

        clean_copy_status: row.clean_copy_status || "none",
        clean_copy_requested_at: row.clean_copy_requested_at,
        clean_copy_responded_at: row.clean_copy_responded_at,

        remaining_amount: remainingAmount,
        remaining_paid: remainingPaid,
        remaining_paid_at: row.remaining_paid_at,
        remaining_payment_status: row.remaining_payment_status,

        allow_download: isTruthy(row.allow_download),
        preview_watermarked: isTruthy(row.preview_watermarked),

        photographer_review_id: row.photographer_review_id,
        photographer_review_submitted: photographerReviewSubmitted,
        photographer_rating: photographerRating,
        photographer_review_comment: row.photographer_review_comment,
        photographer_review_created_at: row.photographer_review_created_at,

        has_system_venue: hasSystemVenue,
        venue_id: row.venue_id,
        venue_name: hasSystemVenue ? row.venue_name : "External Location",
        venue_location: hasSystemVenue ? row.venue_location : row.location,
        venue_owner_id: row.venue_owner_id,
        venue_rating_avg: row.venue_rating_avg,

        venue_booking_id: row.venue_booking_id,
        venue_booking_status: row.venue_booking_status,
        venue_booking_exists: venueBookingExists,
        venue_deposit_paid: venueDepositPaid,
        venue_remaining_paid: isTruthy(row.venue_remaining_paid),
        venue_completed: venueCompleted,
        venue_total_price: numberValue(row.venue_total_price),
        venue_deposit_amount: numberValue(row.venue_deposit_amount),

        venue_review_id: row.venue_review_id,
        venue_review_submitted: venueReviewSubmitted,
        venue_rating: venueRating,
        venue_review_comment: row.venue_review_comment,
        venue_review_created_at: row.venue_review_created_at,

        ...deliveryCommitment,
      };

      session.photography_status_text = getPhotographyStatusText(session);
      session.venue_status_text = getVenueStatusText(session);
      session.overall_status_text = getOverallStatusText(session);
      session.status_text = session.overall_status_text;
      session.status_note = getStatusNote(session);
      session.needs_admin_review =
        session.overall_status_text !== "Completed" &&
        session.overall_status_text !== "External Location";

      const qualityOverview = getQualityOverview(session);

      session.quality_score = qualityOverview.quality_score;
      session.priority_level = qualityOverview.priority_level;
      session.priority_label = qualityOverview.priority_label;
      session.quality_reason = qualityOverview.quality_reason;
      session.quality_reasons = qualityOverview.quality_reasons;

      return session;
    });

    const summary = {
      total_sessions: sessions.length,

      completed_flow: sessions.filter(
        (s) => s.overall_status_text === "Completed"
      ).length,

      needs_review: sessions.filter((s) => s.needs_admin_review).length,

      missing_gallery: sessions.filter((s) => !s.gallery_created).length,

      not_delivered: sessions.filter(
        (s) => s.gallery_created && !s.delivered
      ).length,

      pending_revisions: sessions.filter(
        (s) => s.active_revision_count > 0
      ).length,

      access_locked: sessions.filter((s) => !s.final_access).length,

      missing_photographer_reviews: sessions.filter(
        (s) => !s.photographer_review_submitted
      ).length,

      low_photographer_ratings: sessions.filter(
        (s) =>
          s.photographer_rating !== null && Number(s.photographer_rating) < 3
      ).length,

      clean_copy_pending: sessions.filter(
        (s) => s.clean_copy_status === "pending"
      ).length,

      system_venue_sessions: sessions.filter((s) => s.has_system_venue).length,

      external_location_sessions: sessions.filter(
        (s) => !s.has_system_venue
      ).length,

      venue_booking_missing: sessions.filter(
        (s) => s.has_system_venue && !s.venue_booking_exists
      ).length,

      venue_deposit_unpaid: sessions.filter(
        (s) =>
          s.has_system_venue &&
          s.venue_booking_exists &&
          !s.venue_deposit_paid
      ).length,

      venue_not_completed: sessions.filter(
        (s) =>
          s.has_system_venue && s.venue_booking_exists && !s.venue_completed
      ).length,

      missing_venue_reviews: sessions.filter(
        (s) => s.has_system_venue && !s.venue_review_submitted
      ).length,

      low_venue_ratings: sessions.filter(
        (s) => s.venue_rating !== null && Number(s.venue_rating) < 3
      ).length,

      delivery_on_time: sessions.filter(
        (s) => s.delivery_commitment_status === "on_time"
      ).length,

      delivery_late: sessions.filter(
        (s) => s.delivery_commitment_status === "late"
      ).length,

      delivery_overdue: sessions.filter(
        (s) => s.delivery_commitment_status === "overdue"
      ).length,

      delivery_within_time: sessions.filter(
        (s) => s.delivery_commitment_status === "within_time"
      ).length,

      delivery_no_expected_date: sessions.filter(
        (s) => s.delivery_commitment_status === "no_expected_date"
      ).length,

      quality_high_priority: sessions.filter(
        (s) => s.priority_level === "high"
      ).length,

      quality_medium_priority: sessions.filter(
        (s) => s.priority_level === "medium"
      ).length,

      quality_low_priority: sessions.filter(
        (s) => s.priority_level === "low"
      ).length,

      quality_completed: sessions.filter(
        (s) => s.priority_level === "completed"
      ).length,

      average_quality_score:
        sessions.length === 0
          ? 0
          : Math.round(
              sessions.reduce(
                (sum, s) => sum + Number(s.quality_score || 0),
                0
              ) / sessions.length
            ),
    };

    return res.status(200).json({
      summary,
      sessions,
    });
  } catch (err) {
    console.error("getPostSessionMonitor error:", err);

    return res.status(500).json({
      message: "Failed to load post-session monitor.",
      error: err.message,
    });
  }
};

exports.sendDeliveryReminder = async (req, res) => {
  try {
    const bookingId = req.params.bookingId;

    const [rows] = await db.query(
      `
      SELECT
        b.id AS booking_id,
        b.session_type,
        b.status AS booking_status,

        p.photographer_id,
        pu.id AS photographer_user_id,
        pu.full_name AS photographer_name,

        c.full_name AS client_name,

        g.id AS gallery_id,
        g.status AS gallery_status,
        g.estimated_delivery_date,
        g.delivered_at

      FROM photographer_bookings b

      JOIN photographers p
        ON p.photographer_id = b.photographer_id

      JOIN users pu
        ON pu.id = p.user_id

      JOIN users c
        ON c.id = b.client_id

      LEFT JOIN booking_galleries g
        ON g.booking_id = b.id

      WHERE b.id = ?
        AND b.status = 'completed'

      LIMIT 1
      `,
      [bookingId]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        message: "Completed booking was not found.",
      });
    }

    const row = rows[0];

    const galleryCreated =
      row.gallery_id !== null && row.gallery_id !== undefined;

    const delivered = galleryCreated && isDeliveredStatus(row.gallery_status);

    const deliveryCommitment = getDeliveryCommitment({
      estimatedDeliveryDate: row.estimated_delivery_date,
      deliveredAt: row.delivered_at,
      delivered,
    });

    if (!deliveryCommitment.can_send_delivery_reminder) {
      return res.status(400).json({
        message:
          "Delivery reminder is not allowed because the gallery is not overdue or it was already delivered.",
        delivery_commitment_status:
          deliveryCommitment.delivery_commitment_status,
      });
    }

    await notificationModel.createNotification(
      row.photographer_user_id,
      "Gallery delivery reminder",
      `Your ${
        row.session_type || "photography"
      } session gallery for ${
        row.client_name
      } is overdue. Please deliver the album as soon as possible.`,
      "delivery_reminder",
      "photographer_booking",
      row.booking_id
    );

    return res.status(200).json({
      message: "Delivery reminder sent to photographer successfully.",
    });
  } catch (err) {
    console.error("sendDeliveryReminder error:", err);

    return res.status(500).json({
      message: "Failed to send delivery reminder.",
      error: err.message,
    });
  }
};

exports.sendPhotographerReviewReminder = async (req, res) => {
  try {
    const bookingId = req.params.bookingId;

    const [rows] = await db.query(
      `
      SELECT
        b.id AS booking_id,
        b.session_type,
        b.status AS booking_status,

        c.id AS client_user_id,
        c.full_name AS client_name,

        pu.full_name AS photographer_name,

        pr.id AS photographer_review_id

      FROM photographer_bookings b

      JOIN users c
        ON c.id = b.client_id

      JOIN photographers p
        ON p.photographer_id = b.photographer_id

      JOIN users pu
        ON pu.id = p.user_id

      LEFT JOIN photographer_reviews pr
        ON pr.booking_id = b.id

      WHERE b.id = ?
        AND b.status = 'completed'

      LIMIT 1
      `,
      [bookingId]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        message: "Completed booking was not found.",
      });
    }

    const row = rows[0];

    if (row.photographer_review_id) {
      return res.status(400).json({
        message: "Client already reviewed this photographer.",
      });
    }

    await notificationModel.createNotification(
      row.client_user_id,
      "Rate your photographer",
      `Please rate ${row.photographer_name} for your ${
        row.session_type || "photography"
      } session. Your feedback helps improve service quality.`,
      "photographer_review_reminder",
      "photographer_booking",
      row.booking_id
    );

    return res.status(200).json({
      message: "Photographer review reminder sent to client successfully.",
    });
  } catch (err) {
    console.error("sendPhotographerReviewReminder error:", err);

    return res.status(500).json({
      message: "Failed to send photographer review reminder.",
      error: err.message,
    });
  }
};

exports.sendVenueReviewReminder = async (req, res) => {
  try {
    const bookingId = req.params.bookingId;

    const [rows] = await db.query(
      `
      SELECT
        b.id AS booking_id,
        b.session_type,
        b.status AS booking_status,
        b.venue_id,

        c.id AS client_user_id,
        c.full_name AS client_name,

        v.id AS venue_system_id,
        v.name AS venue_name,

        r.id AS venue_review_id

      FROM photographer_bookings b

      JOIN users c
        ON c.id = b.client_id

      LEFT JOIN venues v
        ON v.id = b.venue_id

      LEFT JOIN reviews r
        ON r.client_id = b.client_id
        AND r.venue_id = b.venue_id

      WHERE b.id = ?
        AND b.status = 'completed'

      LIMIT 1
      `,
      [bookingId]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        message: "Completed booking was not found.",
      });
    }

    const row = rows[0];

    const hasSystemVenue =
      row.venue_id !== null &&
      row.venue_id !== undefined &&
      row.venue_system_id !== null &&
      row.venue_system_id !== undefined;

    if (!hasSystemVenue) {
      return res.status(400).json({
        message:
          "This session used an external location. Venue review reminder is not required.",
      });
    }

    if (row.venue_review_id) {
      return res.status(400).json({
        message: "Client already reviewed this venue.",
      });
    }

    await notificationModel.createNotification(
      row.client_user_id,
      "Rate your venue",
      `Please rate ${row.venue_name} for your ${
        row.session_type || "photography"
      } session. Your feedback helps improve venue quality.`,
      "venue_review_reminder",
      "photographer_booking",
      row.booking_id
    );

    return res.status(200).json({
      message: "Venue review reminder sent to client successfully.",
    });
  } catch (err) {
    console.error("sendVenueReviewReminder error:", err);

    return res.status(500).json({
      message: "Failed to send venue review reminder.",
      error: err.message,
    });
  }
};