const db = require("../config/db");
const userActivityLogModel = require("../model/userActivityLogModel");

function toNumber(value) {
  return Number(value || 0);
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
        userId,
        adminId || null,
        action,
        description || null,
        metadata ? JSON.stringify(metadata) : null,
      ]
    );
  } catch (error) {
    console.error("Failed to write admin activity log:", error.message);
  }
}

exports.getDashboardStats = async (req, res) => {
  try {
    const [[userStats]] = await db.query(`
      SELECT
        COUNT(*) AS total_users,
        SUM(CASE WHEN role = 'client' THEN 1 ELSE 0 END) AS total_clients,
        SUM(CASE WHEN role = 'photographer' THEN 1 ELSE 0 END) AS total_photographers,
        SUM(CASE WHEN role = 'venue_owner' THEN 1 ELSE 0 END) AS total_venue_owners,
        SUM(CASE WHEN role = 'warehouse_owner' THEN 1 ELSE 0 END) AS total_warehouse_owners,
        SUM(CASE WHEN role = 'admin' THEN 1 ELSE 0 END) AS total_admins
      FROM users
    `);

    const [[photographerStats]] = await db.query(`
      SELECT
        COUNT(*) AS total_photographer_profiles,
        AVG(rating_avg) AS avg_photographer_rating
      FROM photographers
    `);

    const [[venueStats]] = await db.query(`
      SELECT
        COUNT(*) AS total_venues,
        AVG(rating_avg) AS avg_venue_rating
      FROM venues
    `);

    const [[photographerBookingStats]] = await db.query(`
      SELECT
        COUNT(*) AS total_photographer_bookings,
        SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS photographer_pending_bookings,
        SUM(CASE WHEN status = 'confirmed' THEN 1 ELSE 0 END) AS photographer_confirmed_bookings,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS photographer_completed_bookings,
        SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS photographer_cancelled_bookings,
        SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) AS photographer_rejected_bookings,
        SUM(CASE WHEN deposit_paid = 1 THEN deposit_amount ELSE 0 END) AS photographer_deposits_total,
        SUM(CASE WHEN remaining_paid = 1 THEN remaining_amount ELSE 0 END) AS photographer_remaining_paid_total
      FROM photographer_bookings
    `);

    const [[venueBookingStats]] = await db.query(`
      SELECT
        COUNT(*) AS total_venue_bookings,
        SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS venue_pending_bookings,
        SUM(CASE WHEN status = 'confirmed' THEN 1 ELSE 0 END) AS venue_confirmed_bookings,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS venue_completed_bookings,
        SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS venue_cancelled_bookings,
        SUM(CASE WHEN deposit_paid = 1 THEN deposit_amount ELSE 0 END) AS venue_deposits_total
      FROM venue_bookings
    `);

    const [[warehouseStats]] = await db.query(`
      SELECT
        COUNT(*) AS total_warehouse_products,
        SUM(CASE WHEN status = 'available' AND is_active = 1 THEN 1 ELSE 0 END) AS available_products,
        SUM(CASE WHEN status = 'out_of_stock' THEN 1 ELSE 0 END) AS out_of_stock_products,
        SUM(CASE WHEN status = 'hidden' THEN 1 ELSE 0 END) AS hidden_products
      FROM warehouse_products
    `);

    const [[warehouseOrderStats]] = await db.query(`
      SELECT
        COUNT(*) AS total_warehouse_orders,
        SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS warehouse_pending_orders,
        SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) AS warehouse_approved_orders,
        SUM(CASE WHEN status = 'completed' OR status = 'delivered' THEN 1 ELSE 0 END) AS warehouse_completed_orders,
        SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) AS warehouse_rejected_orders,
        SUM(CASE WHEN status = 'cancelled' OR status = 'canceled' THEN 1 ELSE 0 END) AS warehouse_cancelled_orders,
        SUM(CASE WHEN payment_status = 'paid' THEN total_price ELSE 0 END) AS warehouse_paid_total
      FROM warehouse_orders
    `);

    const [[printStats]] = await db.query(`
      SELECT
        COUNT(*) AS total_print_requests,
        SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS print_pending_requests,
        SUM(CASE WHEN status = 'accepted' THEN 1 ELSE 0 END) AS print_accepted_requests,
        SUM(CASE WHEN status = 'printed' THEN 1 ELSE 0 END) AS print_printed_requests,
        SUM(CASE WHEN status = 'ready_for_pickup' THEN 1 ELSE 0 END) AS print_ready_requests,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS print_completed_requests,
        SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) AS print_rejected_requests
      FROM print_requests
    `);

    const [[communityStats]] = await db.query(`
      SELECT
        COUNT(*) AS total_community_posts,
        SUM(CASE WHEN is_hidden = 1 THEN 1 ELSE 0 END) AS hidden_community_posts
      FROM community_posts
    `);

    const [[reportStats]] = await db.query(`
      SELECT
        COUNT(*) AS total_community_reports
      FROM community_reports
    `);

    const [latestUsers] = await db.query(`
      SELECT id, full_name, email, role, profile_image, created_at
      FROM users
      ORDER BY created_at DESC
      LIMIT 5
    `);

    const [latestPhotographerBookings] = await db.query(`
      SELECT
        pb.id,
        pb.session_type,
        pb.date,
        pb.time,
        pb.status,
        pb.total_price,
        pb.deposit_amount,
        client.full_name AS client_name,
        photographerUser.full_name AS photographer_name
      FROM photographer_bookings pb
      LEFT JOIN users client ON pb.client_id = client.id
      LEFT JOIN photographers p ON pb.photographer_id = p.photographer_id
      LEFT JOIN users photographerUser ON p.user_id = photographerUser.id
      ORDER BY pb.created_at DESC
      LIMIT 5
    `);

    const [latestVenueBookings] = await db.query(`
      SELECT
        vb.id,
        vb.booking_date,
        vb.start_time,
        vb.end_time,
        vb.status,
        vb.total_price,
        vb.deposit_amount,
        client.full_name AS client_name,
        v.name AS venue_name
      FROM venue_bookings vb
      LEFT JOIN users client ON vb.client_id = client.id
      LEFT JOIN venues v ON vb.venue_id = v.id
      ORDER BY vb.created_at DESC
      LIMIT 5
    `);

    res.json({
      success: true,
      stats: {
        users: {
          total_users: toNumber(userStats.total_users),
          total_clients: toNumber(userStats.total_clients),
          total_photographers: toNumber(userStats.total_photographers),
          total_venue_owners: toNumber(userStats.total_venue_owners),
          total_warehouse_owners: toNumber(userStats.total_warehouse_owners),
          total_admins: toNumber(userStats.total_admins),
        },

        photographers: {
          total_photographer_profiles: toNumber(
            photographerStats.total_photographer_profiles
          ),
          avg_photographer_rating: Number(
            photographerStats.avg_photographer_rating || 0
          ),
        },

        venues: {
          total_venues: toNumber(venueStats.total_venues),
          avg_venue_rating: Number(venueStats.avg_venue_rating || 0),
        },

        photographer_bookings: {
          total: toNumber(
            photographerBookingStats.total_photographer_bookings
          ),
          pending: toNumber(
            photographerBookingStats.photographer_pending_bookings
          ),
          confirmed: toNumber(
            photographerBookingStats.photographer_confirmed_bookings
          ),
          completed: toNumber(
            photographerBookingStats.photographer_completed_bookings
          ),
          cancelled: toNumber(
            photographerBookingStats.photographer_cancelled_bookings
          ),
          rejected: toNumber(
            photographerBookingStats.photographer_rejected_bookings
          ),
          deposits_total: Number(
            photographerBookingStats.photographer_deposits_total || 0
          ),
          remaining_paid_total: Number(
            photographerBookingStats.photographer_remaining_paid_total || 0
          ),
        },

        venue_bookings: {
          total: toNumber(venueBookingStats.total_venue_bookings),
          pending: toNumber(venueBookingStats.venue_pending_bookings),
          confirmed: toNumber(venueBookingStats.venue_confirmed_bookings),
          completed: toNumber(venueBookingStats.venue_completed_bookings),
          cancelled: toNumber(venueBookingStats.venue_cancelled_bookings),
          deposits_total: Number(venueBookingStats.venue_deposits_total || 0),
        },

        warehouse: {
          total_products: toNumber(warehouseStats.total_warehouse_products),
          available_products: toNumber(warehouseStats.available_products),
          out_of_stock_products: toNumber(warehouseStats.out_of_stock_products),
          hidden_products: toNumber(warehouseStats.hidden_products),
          total_orders: toNumber(warehouseOrderStats.total_warehouse_orders),
          pending_orders: toNumber(
            warehouseOrderStats.warehouse_pending_orders
          ),
          approved_orders: toNumber(
            warehouseOrderStats.warehouse_approved_orders
          ),
          completed_orders: toNumber(
            warehouseOrderStats.warehouse_completed_orders
          ),
          rejected_orders: toNumber(
            warehouseOrderStats.warehouse_rejected_orders
          ),
          cancelled_orders: toNumber(
            warehouseOrderStats.warehouse_cancelled_orders
          ),
          paid_total: Number(warehouseOrderStats.warehouse_paid_total || 0),
        },

        print_requests: {
          total: toNumber(printStats.total_print_requests),
          pending: toNumber(printStats.print_pending_requests),
          accepted: toNumber(printStats.print_accepted_requests),
          printed: toNumber(printStats.print_printed_requests),
          ready_for_pickup: toNumber(printStats.print_ready_requests),
          completed: toNumber(printStats.print_completed_requests),
          rejected: toNumber(printStats.print_rejected_requests),
        },

        community: {
          total_posts: toNumber(communityStats.total_community_posts),
          hidden_posts: toNumber(communityStats.hidden_community_posts),
          total_reports: toNumber(reportStats.total_community_reports),
        },
      },

      latest: {
        users: latestUsers,
        photographer_bookings: latestPhotographerBookings,
        venue_bookings: latestVenueBookings,
      },
    });
  } catch (error) {
    console.error("Admin dashboard error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to load admin dashboard",
      error: error.message,
    });
  }
};

exports.getAllUsers = async (req, res) => {
  try {
    const { role, status, q } = req.query;

    let sql = `
      SELECT
        id,
        full_name,
        email,
        phone,
        role,
        profile_image,
        cover_image,
        bio,
        COALESCE(status, 'active') AS status,
        created_at
      FROM users
      WHERE 1 = 1
    `;

    const params = [];

    if (role && role !== "all") {
      sql += ` AND role = ?`;
      params.push(role);
    }

    if (status && status !== "all") {
      sql += ` AND COALESCE(status, 'active') = ?`;
      params.push(status);
    }

    if (q && q.trim() !== "") {
      sql += `
        AND (
          full_name LIKE ?
          OR email LIKE ?
          OR phone LIKE ?
          OR role LIKE ?
        )
      `;

      const searchValue = `%${q.trim()}%`;
      params.push(searchValue, searchValue, searchValue, searchValue);
    }

    sql += ` ORDER BY created_at DESC`;

    const [users] = await db.query(sql, params);

    res.json({
      success: true,
      users,
    });
  } catch (error) {
    console.error("Admin get users error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to load users",
      error: error.message,
    });
  }
};

exports.getUserDetailsByAdmin = async (req, res) => {
  try {
    const userId = req.params.id;

    const [[user]] = await db.query(
      `
      SELECT
        u.id,
        u.full_name,
        u.email,
        u.phone,
        u.role,
        u.profile_image,
        u.cover_image,
        u.bio,
        u.social_links,
        u.notifications_enabled,
        u.dark_mode,
        COALESCE(u.status, 'active') AS status,
        u.created_at,

        p.photographer_id,
        p.bio AS photographer_bio,
        p.experience_years,
        p.price_per_hour,
        p.rating_avg,
        p.rating_count,
        p.portfolio_template,
        p.location AS photographer_location,
        p.specialties,
        p.latitude,
        p.longitude

      FROM users u
      LEFT JOIN photographers p ON p.user_id = u.id
      WHERE u.id = ?
      LIMIT 1
      `,
      [userId]
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    if (user.social_links && typeof user.social_links === "string") {
      try {
        user.social_links = JSON.parse(user.social_links);
      } catch (_) {
        user.social_links = {};
      }
    }

    res.json({
      success: true,
      user,
    });
  } catch (error) {
    console.error("Admin get user details error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to load user details",
      error: error.message,
    });
  }
};

exports.updateUserStatus = async (req, res) => {
  try {
    const adminId = req.user.id;
    const userId = req.params.id;
    const { status } = req.body;

    const allowedStatuses = ["active", "blocked"];

    if (!allowedStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: "Invalid status",
      });
    }

    if (Number(userId) === Number(adminId)) {
      return res.status(400).json({
        success: false,
        message: "Admin cannot block their own account",
      });
    }

    const [[user]] = await db.query(
      `
      SELECT id, role, COALESCE(status, 'active') AS current_status
      FROM users
      WHERE id = ?
      LIMIT 1
      `,
      [userId]
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    if (user.role === "admin") {
      return res.status(400).json({
        success: false,
        message: "Admin accounts are protected",
      });
    }

    await db.query(
      `
      UPDATE users
      SET status = ?
      WHERE id = ?
      `,
      [status, userId]
    );

    await logAdminActivity({
      userId,
      adminId,
      action: status === "blocked" ? "account_deactivated" : "account_activated",
      description:
        status === "blocked"
          ? "Account was deactivated by admin."
          : "Account was activated by admin.",
      metadata: {
        old_status: user.current_status,
        new_status: status,
      },
    });

    res.json({
      success: true,
      message:
        status === "blocked"
          ? "User blocked successfully"
          : "User activated successfully",
    });
  } catch (error) {
    console.error("Admin update user status error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to update user status",
      error: error.message,
    });
  }
};

exports.getUserAdminNotes = async (req, res) => {
  try {
    const userId = req.params.id;

    const [[targetUser]] = await db.query(
      `
      SELECT id, role
      FROM users
      WHERE id = ?
      LIMIT 1
      `,
      [userId]
    );

    if (!targetUser) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    const [notes] = await db.query(
      `
      SELECT
        n.id,
        n.user_id,
        n.admin_id,
        n.note,
        n.created_at,
        admin.full_name AS admin_name,
        admin.email AS admin_email,
        admin.profile_image AS admin_image
      FROM admin_notes n
      LEFT JOIN users admin ON admin.id = n.admin_id
      WHERE n.user_id = ?
      ORDER BY n.created_at DESC
      `,
      [userId]
    );

    res.json({
      success: true,
      notes,
    });
  } catch (error) {
    console.error("Admin get notes error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to load admin notes",
      error: error.message,
    });
  }
};

exports.addUserAdminNote = async (req, res) => {
  try {
    const adminId = req.user.id;
    const userId = req.params.id;
    const { note } = req.body;

    if (!note || !note.trim()) {
      return res.status(400).json({
        success: false,
        message: "Note is required",
      });
    }

    if (note.trim().length < 3) {
      return res.status(400).json({
        success: false,
        message: "Note is too short",
      });
    }

    const [[adminUser]] = await db.query(
      `
      SELECT id, role
      FROM users
      WHERE id = ?
      LIMIT 1
      `,
      [adminId]
    );

    if (!adminUser || adminUser.role !== "admin") {
      return res.status(403).json({
        success: false,
        message: "Only admins can add notes",
      });
    }

    const [[targetUser]] = await db.query(
      `
      SELECT id, role
      FROM users
      WHERE id = ?
      LIMIT 1
      `,
      [userId]
    );

    if (!targetUser) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    if (targetUser.role === "admin") {
      return res.status(400).json({
        success: false,
        message: "Admin accounts are protected",
      });
    }

    const cleanedNote = note.trim();

    const [result] = await db.query(
      `
      INSERT INTO admin_notes (
        user_id,
        admin_id,
        note
      )
      VALUES (?, ?, ?)
      `,
      [userId, adminId, cleanedNote]
    );

    const [[createdNote]] = await db.query(
      `
      SELECT
        n.id,
        n.user_id,
        n.admin_id,
        n.note,
        n.created_at,
        admin.full_name AS admin_name,
        admin.email AS admin_email,
        admin.profile_image AS admin_image
      FROM admin_notes n
      LEFT JOIN users admin ON admin.id = n.admin_id
      WHERE n.id = ?
      LIMIT 1
      `,
      [result.insertId]
    );

    await logAdminActivity({
      userId,
      adminId,
      action: "admin_note_added",
      description: "Admin added an internal note to this account.",
      metadata: {
        note_id: createdNote.id,
        note_preview: cleanedNote.slice(0, 120),
      },
    });

    res.status(201).json({
      success: true,
      message: "Admin note added successfully",
      note: createdNote,
    });
  } catch (error) {
    console.error("Admin add note error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to add admin note",
      error: error.message,
    });
  }
};

exports.deleteAdminNote = async (req, res) => {
  try {
    const adminId = req.user.id;
    const noteId = req.params.noteId;

    const [[note]] = await db.query(
      `
      SELECT id, user_id, note
      FROM admin_notes
      WHERE id = ?
      LIMIT 1
      `,
      [noteId]
    );

    if (!note) {
      return res.status(404).json({
        success: false,
        message: "Note not found",
      });
    }

    await db.query(
      `
      DELETE FROM admin_notes
      WHERE id = ?
      `,
      [noteId]
    );

    await logAdminActivity({
      userId: note.user_id,
      adminId,
      action: "admin_note_deleted",
      description: "Admin deleted an internal note from this account.",
      metadata: {
        note_id: note.id,
        deleted_note_preview: note.note ? note.note.slice(0, 120) : "",
      },
    });

    res.json({
      success: true,
      message: "Admin note deleted successfully",
    });
  } catch (error) {
    console.error("Admin delete note error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to delete admin note",
      error: error.message,
    });
  }
};

exports.getUserActivityLogs = async (req, res) => {
  try {
    const userId = req.params.id;

    const [[targetUser]] = await db.query(
      `
      SELECT id, full_name, email, role
      FROM users
      WHERE id = ?
      LIMIT 1
      `,
      [userId]
    );

    if (!targetUser) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    const [adminLogs] = await db.query(
      `
      SELECT
        l.id,
        l.user_id,
        l.admin_id,
        l.action,
        l.description,
        l.metadata,
        l.created_at,

        admin.full_name AS admin_name,
        admin.email AS admin_email,
        admin.profile_image AS admin_image,

        target.full_name AS target_user_name,
        target.email AS target_user_email,
        target.role AS target_user_role
      FROM admin_activity_logs l
      LEFT JOIN users admin ON admin.id = l.admin_id
      LEFT JOIN users target ON target.id = l.user_id
      WHERE l.user_id = ?
      ORDER BY l.created_at DESC
      `,
      [userId]
    );

    const parsedAdminLogs = adminLogs.map((log) => {
      if (log.metadata && typeof log.metadata === "string") {
        try {
          log.metadata = JSON.parse(log.metadata);
        } catch (_) {
          log.metadata = null;
        }
      }

      return log;
    });

    const userLogs = await userActivityLogModel.getLogsByTargetUser(userId);

    res.json({
      success: true,
      user: targetUser,
      admin_logs: parsedAdminLogs,
      user_logs: userLogs,
    });
  } catch (error) {
    console.error("Admin get activity logs error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to load activity logs",
      error: error.message,
    });
  }
};