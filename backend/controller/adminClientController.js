const db = require("../config/db");

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

function buildClientWarnings(client) {
  const warnings = [];

  const total = toNumber(client.total_bookings);
  const clientCancelled = toNumber(client.client_cancelled_bookings);
  const pending = toNumber(client.pending_bookings);
  const flagged = toBool(client.client_flagged);
  const restricted = toBool(client.booking_restricted);

  if (flagged) warnings.push("Flagged by admin");
  if (restricted) warnings.push("Booking restricted");

  if (total > 0) {
    const cancellationRate = (clientCancelled / total) * 100;
    if (cancellationRate >= 50) {
      warnings.push("High client cancellation rate");
    }
  }

  if (pending >= 3) warnings.push("Many pending bookings");

  return warnings;
}

function mapClient(row) {
  const total = toNumber(row.total_bookings);
  const clientCancelled = toNumber(row.client_cancelled_bookings);

  const cancellationRate =
    total > 0 ? Number(((clientCancelled / total) * 100).toFixed(1)) : 0;

  const flagged = toBool(row.client_flagged);
  const restricted = toBool(row.booking_restricted);

  const warnings = buildClientWarnings({
    ...row,
    total_bookings: total,
    client_cancelled_bookings: clientCancelled,
    pending_bookings: row.pending_bookings,
  });

  const client = {
    id: row.id,
    full_name: row.full_name,
    email: row.email,
    phone: row.phone,
    profile_image: row.profile_image,
    status: row.status || "active",
    created_at: row.created_at,

    client_flagged: flagged,
    client_flag_reason: cleanText(row.client_flag_reason),

    booking_restricted: restricted,
    booking_restriction_reason: cleanText(row.booking_restriction_reason),

    booking_summary: {
      total,
      completed: toNumber(row.completed_bookings),
      client_cancelled: clientCancelled,
      cancelled: clientCancelled,
      pending: toNumber(row.pending_bookings),
      confirmed: toNumber(row.confirmed_bookings),
      rejected: toNumber(row.rejected_bookings),
      cancellation_rate: cancellationRate,
    },

    payment_summary: {
      paid_deposits: toNumber(row.paid_deposits),
      unpaid_deposits: toNumber(row.unpaid_deposits),
    },

    print_summary: {
      total: toNumber(row.total_print_requests),
      pending: toNumber(row.pending_print_requests),
      completed: toNumber(row.completed_print_requests),
      rejected: toNumber(row.rejected_print_requests),
    },

    warnings,
  };

  if (restricted) {
    client.client_status = "restricted";
  } else if (flagged || warnings.length > 0) {
    client.client_status = "needs_review";
  } else {
    client.client_status = "normal";
  }

  // نخلي هذول موجودين عشان الفرونت الحالي ما يعطي error لو كان بقرأهم
  client.risk_status = client.client_status;
  client.trust_score =
    client.client_status === "normal"
      ? 80
      : client.client_status === "needs_review"
      ? 55
      : 30;

  return client;
}

const clientBaseSelect = `
  SELECT
    u.id,
    u.full_name,
    u.email,
    u.phone,
    u.profile_image,
    COALESCE(u.status, 'active') AS status,
    u.created_at,

    COALESCE(u.client_flagged, 0) AS client_flagged,
    u.client_flag_reason,
    COALESCE(u.booking_restricted, 0) AS booking_restricted,
    u.booking_restriction_reason,

    COALESCE(pb.total_bookings, 0) AS total_bookings,
    COALESCE(pb.completed_bookings, 0) AS completed_bookings,
    COALESCE(pb.client_cancelled_bookings, 0) AS client_cancelled_bookings,
    COALESCE(pb.pending_bookings, 0) AS pending_bookings,
    COALESCE(pb.confirmed_bookings, 0) AS confirmed_bookings,
    COALESCE(pb.rejected_bookings, 0) AS rejected_bookings,
    COALESCE(pb.paid_deposits, 0) AS paid_deposits,
    COALESCE(pb.unpaid_deposits, 0) AS unpaid_deposits,

    COALESCE(pr.total_print_requests, 0) AS total_print_requests,
    COALESCE(pr.pending_print_requests, 0) AS pending_print_requests,
    COALESCE(pr.completed_print_requests, 0) AS completed_print_requests,
    COALESCE(pr.rejected_print_requests, 0) AS rejected_print_requests

  FROM users u

  LEFT JOIN (
    SELECT
      client_id,
      COUNT(*) AS total_bookings,
      SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_bookings,
      SUM(CASE WHEN status = 'cancelled' AND cancelled_by = 'client' THEN 1 ELSE 0 END) AS client_cancelled_bookings,
      SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS pending_bookings,
      SUM(CASE WHEN status = 'confirmed' THEN 1 ELSE 0 END) AS confirmed_bookings,
      SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) AS rejected_bookings,
      SUM(CASE WHEN deposit_paid = 1 THEN 1 ELSE 0 END) AS paid_deposits,
      SUM(CASE WHEN COALESCE(deposit_paid, 0) = 0 THEN 1 ELSE 0 END) AS unpaid_deposits
    FROM photographer_bookings
    GROUP BY client_id
  ) pb ON pb.client_id = u.id

  LEFT JOIN (
    SELECT
      client_id,
      COUNT(*) AS total_print_requests,
      SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS pending_print_requests,
      SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_print_requests,
      SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) AS rejected_print_requests
    FROM print_requests
    GROUP BY client_id
  ) pr ON pr.client_id = u.id
`;

exports.getAdminClients = async (req, res) => {
  try {
    const { q = "", filter = "all" } = req.query;

    const search = cleanText(q);
    const params = [];

    let where = `
      WHERE u.role = 'client'
    `;

    if (search) {
      where += `
        AND (
          u.full_name LIKE ?
          OR u.email LIKE ?
          OR u.phone LIKE ?
        )
      `;

      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }

    if (filter === "flagged") {
      where += " AND COALESCE(u.client_flagged, 0) = 1";
    }

    if (filter === "restricted") {
      where += " AND COALESCE(u.booking_restricted, 0) = 1";
    }

    const [rows] = await db.query(
      `
      ${clientBaseSelect}
      ${where}
      ORDER BY u.created_at DESC
      `,
      params
    );

    const clients = rows.map(mapClient);

    const filteredClients = clients.filter((client) => {
      if (filter === "needs_review") {
        return client.client_status === "needs_review";
      }

      if (filter === "high_cancellation") {
        return client.booking_summary.cancellation_rate >= 50;
      }

      if (filter === "has_print_requests") {
        return client.print_summary.total > 0;
      }

      if (filter === "normal") {
        return client.client_status === "normal";
      }

      return true;
    });

    const summary = {
      total: clients.length,
      normal: clients.filter((c) => c.client_status === "normal").length,
      needs_review: clients.filter((c) => c.client_status === "needs_review").length,
      flagged: clients.filter((c) => c.client_flagged).length,
      restricted: clients.filter((c) => c.booking_restricted).length,
      high_cancellation: clients.filter(
        (c) => c.booking_summary.cancellation_rate >= 50
      ).length,
      with_print_requests: clients.filter((c) => c.print_summary.total > 0).length,
    };

    return res.json({
      success: true,
      summary,
      clients: filteredClients,
    });
  } catch (error) {
    console.error("getAdminClients error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to load clients",
      error: error.message,
    });
  }
};

exports.getAdminClientDetails = async (req, res) => {
  try {
    const clientId = req.params.clientId;

    const [rows] = await db.query(
      `
      ${clientBaseSelect}
      WHERE u.id = ?
        AND u.role = 'client'
      LIMIT 1
      `,
      [clientId]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Client not found",
      });
    }

    const client = mapClient(rows[0]);

    return res.json({
      success: true,
      client,
    });
  } catch (error) {
    console.error("getAdminClientDetails error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to load client details",
      error: error.message,
    });
  }
};

exports.updateClientFlag = async (req, res) => {
  try {
    const clientId = req.params.clientId;
    const flagged = toBool(req.body.flagged);
    const reason = cleanText(req.body.reason);

    if (flagged && reason.length < 3) {
      return res.status(400).json({
        success: false,
        message: "Flag reason is required",
      });
    }

    const [[client]] = await db.query(
      `
      SELECT id, role
      FROM users
      WHERE id = ?
      LIMIT 1
      `,
      [clientId]
    );

    if (!client || client.role !== "client") {
      return res.status(404).json({
        success: false,
        message: "Client not found",
      });
    }

    await db.query(
      `
      UPDATE users
      SET
        client_flagged = ?,
        client_flag_reason = ?
      WHERE id = ?
        AND role = 'client'
      `,
      [flagged ? 1 : 0, flagged ? reason : null, clientId]
    );

    return res.json({
      success: true,
      message: flagged ? "Client flagged successfully" : "Client flag removed",
    });
  } catch (error) {
    console.error("updateClientFlag error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to update client flag",
      error: error.message,
    });
  }
};

exports.updateBookingRestriction = async (req, res) => {
  try {
    const clientId = req.params.clientId;
    const restricted = toBool(req.body.restricted);
    const reason = cleanText(req.body.reason);

    if (restricted && reason.length < 3) {
      return res.status(400).json({
        success: false,
        message: "Restriction reason is required",
      });
    }

    const [[client]] = await db.query(
      `
      SELECT id, role
      FROM users
      WHERE id = ?
      LIMIT 1
      `,
      [clientId]
    );

    if (!client || client.role !== "client") {
      return res.status(404).json({
        success: false,
        message: "Client not found",
      });
    }

    await db.query(
      `
      UPDATE users
      SET
        booking_restricted = ?,
        booking_restriction_reason = ?
      WHERE id = ?
        AND role = 'client'
      `,
      [restricted ? 1 : 0, restricted ? reason : null, clientId]
    );

    return res.json({
      success: true,
      message: restricted
        ? "Client booking restriction enabled"
        : "Client booking restriction removed",
    });
  } catch (error) {
    console.error("updateBookingRestriction error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to update booking restriction",
      error: error.message,
    });
  }
};