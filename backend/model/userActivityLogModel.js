const db = require("../config/db");

exports.logActivity = async ({
  actorId = null,
  targetUserId = null,
  action,
  category,
  description = null,
  metadata = null,
}) => {
  try {
    if (!action || !category) {
      return;
    }

    await db.query(
      `
      INSERT INTO user_activity_logs (
        actor_id,
        target_user_id,
        action,
        category,
        description,
        metadata
      )
      VALUES (?, ?, ?, ?, ?, ?)
      `,
      [
        actorId,
        targetUserId,
        action,
        category,
        description,
        metadata ? JSON.stringify(metadata) : null,
      ]
    );
  } catch (error) {
    console.error("User activity log error:", error.message);
  }
};

exports.getLogsByTargetUser = async (userId) => {
  const [rows] = await db.query(
    `
    SELECT
      l.id,
      l.actor_id,
      l.target_user_id,
      l.action,
      l.category,
      l.description,
      l.metadata,
      l.created_at,

      actor.full_name AS actor_name,
      actor.email AS actor_email,
      actor.role AS actor_role,
      actor.profile_image AS actor_image,

      target.full_name AS target_name,
      target.email AS target_email,
      target.role AS target_role,
      target.profile_image AS target_image

    FROM user_activity_logs l
    LEFT JOIN users actor ON actor.id = l.actor_id
    LEFT JOIN users target ON target.id = l.target_user_id
    WHERE l.target_user_id = ?
    ORDER BY l.created_at DESC
    `,
    [userId]
  );

  return rows.map((row) => {
    if (row.metadata && typeof row.metadata === "string") {
      try {
        row.metadata = JSON.parse(row.metadata);
      } catch (_) {
        row.metadata = null;
      }
    }

    return row;
  });
};

exports.getAllLogs = async ({
  category = "all",
  action = "all",
  role = "all",
  q = "",
} = {}) => {
  let sql = `
    SELECT
      l.id,
      l.actor_id,
      l.target_user_id,
      l.action,
      l.category,
      l.description,
      l.metadata,
      l.created_at,

      actor.full_name AS actor_name,
      actor.email AS actor_email,
      actor.role AS actor_role,
      actor.profile_image AS actor_image,

      target.full_name AS target_name,
      target.email AS target_email,
      target.role AS target_role,
      target.profile_image AS target_image

    FROM user_activity_logs l
    LEFT JOIN users actor ON actor.id = l.actor_id
    LEFT JOIN users target ON target.id = l.target_user_id
    WHERE 1 = 1
  `;

  const params = [];

  if (category && category !== "all") {
    sql += ` AND l.category = ?`;
    params.push(category);
  }

  if (action && action !== "all") {
    sql += ` AND l.action = ?`;
    params.push(action);
  }

  if (role && role !== "all") {
    sql += ` AND target.role = ?`;
    params.push(role);
  }

  if (q && q.trim() !== "") {
    sql += `
      AND (
        actor.full_name LIKE ?
        OR actor.email LIKE ?
        OR target.full_name LIKE ?
        OR target.email LIKE ?
        OR l.action LIKE ?
        OR l.category LIKE ?
      )
    `;

    const searchValue = `%${q.trim()}%`;
    params.push(
      searchValue,
      searchValue,
      searchValue,
      searchValue,
      searchValue,
      searchValue
    );
  }

  sql += ` ORDER BY l.created_at DESC`;

  const [rows] = await db.query(sql, params);

  return rows.map((row) => {
    if (row.metadata && typeof row.metadata === "string") {
      try {
        row.metadata = JSON.parse(row.metadata);
      } catch (_) {
        row.metadata = null;
      }
    }

    return row;
  });
};