const db = require("../config/db");
const notificationModel = require("../model/notificationModel");

function toBool(value) {
  return value === true || value === 1 || value === "1" || value === "true";
}

function cleanText(value) {
  if (value === null || value === undefined) return "";
  const text = value.toString().trim();
  if (!text || text === "null") return "";
  return text;
}

function toNumber(value) {
  const n = Number(value);
  return Number.isNaN(n) ? 0 : n;
}

function postTitleForNotification(post) {
  const title = cleanText(post?.title);

  if (title) {
    return title.length > 60 ? `${title.substring(0, 60)}...` : title;
  }

  return "your community post";
}

function mapPost(row) {
  return {
    id: row.id,
    photographer_id: row.photographer_id,

    title: row.title,
    body: row.body,
    category: row.category,
    media_url: row.media_url,
    media_type: row.media_type,
    is_question: toBool(row.is_question),
    is_hidden: toBool(row.is_hidden),

    approval_status: row.approval_status || "pending",
    rejection_reason: cleanText(row.rejection_reason),
    reviewed_by: row.reviewed_by,
    reviewed_at: row.reviewed_at,

    created_at: row.created_at,
    updated_at: row.updated_at,

    photographer: {
      id: row.photographer_user_id,
      name: row.photographer_name,
      email: row.photographer_email,
      image: row.photographer_profile_image,
    },

    stats: {
      likes: toNumber(row.likes_count),
      saves: toNumber(row.saves_count),
      comments: toNumber(row.comments_count),
      reports: toNumber(row.reports_count),
      media: toNumber(row.media_count),
    },
  };
}

const adminPostSelect = `
  SELECT
    cp.*,

    u.id AS photographer_user_id,
    u.full_name AS photographer_name,
    u.email AS photographer_email,
    u.profile_image AS photographer_profile_image,

    COUNT(DISTINCT cpl.id) AS likes_count,
    COUNT(DISTINCT cps.id) AS saves_count,
    COUNT(DISTINCT cc.id) AS comments_count,
    COUNT(DISTINCT cr.id) AS reports_count,
    COUNT(DISTINCT cpm.id) AS media_count

  FROM community_posts cp
  JOIN users u ON u.id = cp.photographer_id

  LEFT JOIN community_post_likes cpl ON cpl.post_id = cp.id
  LEFT JOIN community_post_saves cps ON cps.post_id = cp.id
  LEFT JOIN community_comments cc ON cc.post_id = cp.id AND cc.is_hidden = 0
  LEFT JOIN community_reports cr ON cr.post_id = cp.id
  LEFT JOIN community_post_media cpm ON cpm.post_id = cp.id
`;

exports.getAdminCommunityPosts = async (req, res) => {
  try {
    const { q = "", filter = "pending" } = req.query;

    const search = cleanText(q);
    const params = [];

    let where = "WHERE 1 = 1";

    if (filter === "pending") {
      where += " AND COALESCE(cp.approval_status, 'pending') = 'pending'";
    } else if (filter === "approved") {
      where += " AND cp.approval_status = 'approved' AND cp.is_hidden = 0";
    } else if (filter === "rejected") {
      where += " AND cp.approval_status = 'rejected'";
    } else if (filter === "hidden") {
      where += " AND cp.is_hidden = 1";
    } else if (filter === "reported") {
      where += " AND cr.id IS NOT NULL";
    }

    if (search) {
      where += `
        AND (
          cp.title LIKE ?
          OR cp.body LIKE ?
          OR cp.category LIKE ?
          OR u.full_name LIKE ?
          OR u.email LIKE ?
        )
      `;

      params.push(
        `%${search}%`,
        `%${search}%`,
        `%${search}%`,
        `%${search}%`,
        `%${search}%`
      );
    }

    const [rows] = await db.query(
      `
      ${adminPostSelect}
      ${where}
      GROUP BY cp.id
      ORDER BY cp.created_at DESC
      LIMIT 150
      `,
      params
    );

    const posts = rows.map(mapPost);

    const [[summary]] = await db.query(
      `
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN COALESCE(approval_status, 'pending') = 'pending' THEN 1 ELSE 0 END) AS pending,
        SUM(CASE WHEN approval_status = 'approved' AND is_hidden = 0 THEN 1 ELSE 0 END) AS approved,
        SUM(CASE WHEN approval_status = 'rejected' THEN 1 ELSE 0 END) AS rejected,
        SUM(CASE WHEN is_hidden = 1 THEN 1 ELSE 0 END) AS hidden
      FROM community_posts
      `
    );

    const [[reportedSummary]] = await db.query(
      `
      SELECT COUNT(DISTINCT post_id) AS reported
      FROM community_reports
      `
    );

    return res.json({
      success: true,
      summary: {
        total: toNumber(summary.total),
        pending: toNumber(summary.pending),
        approved: toNumber(summary.approved),
        rejected: toNumber(summary.rejected),
        hidden: toNumber(summary.hidden),
        reported: toNumber(reportedSummary.reported),
      },
      posts,
    });
  } catch (error) {
    console.error("getAdminCommunityPosts error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to load community posts",
      error: error.message,
    });
  }
};

exports.getAdminCommunityPostDetails = async (req, res) => {
  try {
    const postId = req.params.postId;

    const [rows] = await db.query(
      `
      ${adminPostSelect}
      WHERE cp.id = ?
      GROUP BY cp.id
      LIMIT 1
      `,
      [postId]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Post not found",
      });
    }

    const post = mapPost(rows[0]);

    const [media] = await db.query(
      `
      SELECT id, media_url, media_type, sort_order, created_at
      FROM community_post_media
      WHERE post_id = ?
      ORDER BY sort_order ASC, id ASC
      `,
      [postId]
    );

    const [comments] = await db.query(
      `
      SELECT
        cc.*,
        u.full_name AS user_name,
        u.email AS user_email,
        u.profile_image AS user_profile_image,
        u.role AS user_role
      FROM community_comments cc
      JOIN users u ON u.id = cc.user_id
      WHERE cc.post_id = ?
      ORDER BY cc.created_at ASC
      `,
      [postId]
    );

    const [reports] = await db.query(
      `
      SELECT
        cr.*,
        u.full_name AS reporter_name,
        u.email AS reporter_email,
        u.profile_image AS reporter_image
      FROM community_reports cr
      JOIN users u ON u.id = cr.reporter_id
      WHERE cr.post_id = ?
      ORDER BY cr.created_at DESC
      `,
      [postId]
    );

    return res.json({
      success: true,
      post: {
        ...post,
        media,
        comments,
        reports,
      },
    });
  } catch (error) {
    console.error("getAdminCommunityPostDetails error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to load post details",
      error: error.message,
    });
  }
};

exports.approveCommunityPost = async (req, res) => {
  try {
    const postId = req.params.postId;
    const adminId = req.user.id;

    const [[post]] = await db.query(
      `
      SELECT
        id,
        photographer_id,
        title,
        approval_status,
        is_hidden
      FROM community_posts
      WHERE id = ?
      LIMIT 1
      `,
      [postId]
    );

    if (!post) {
      return res.status(404).json({
        success: false,
        message: "Post not found",
      });
    }

    await db.query(
      `
      UPDATE community_posts
      SET
        approval_status = 'approved',
        rejection_reason = NULL,
        reviewed_by = ?,
        reviewed_at = NOW(),
        is_hidden = 0
      WHERE id = ?
      `,
      [adminId, postId]
    );

    try {
      await notificationModel.createNotification(
        post.photographer_id,
        "Community Post Approved",
        `Your post "${postTitleForNotification(post)}" has been approved and is now visible in the community.`,
        "community_post_approved",
        "community_post",
        postId
      );
    } catch (notificationError) {
      console.log(
        "Photographer community approve notification error:",
        notificationError.message
      );
    }

    return res.json({
      success: true,
      message: "Post approved successfully",
    });
  } catch (error) {
    console.error("approveCommunityPost error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to approve post",
      error: error.message,
    });
  }
};

exports.rejectCommunityPost = async (req, res) => {
  try {
    const postId = req.params.postId;
    const adminId = req.user.id;
    const reason = cleanText(req.body.reason);

    if (reason.length < 3) {
      return res.status(400).json({
        success: false,
        message: "Rejection reason is required",
      });
    }

    const [[post]] = await db.query(
      `
      SELECT
        id,
        photographer_id,
        title,
        approval_status,
        is_hidden
      FROM community_posts
      WHERE id = ?
      LIMIT 1
      `,
      [postId]
    );

    if (!post) {
      return res.status(404).json({
        success: false,
        message: "Post not found",
      });
    }

    await db.query(
      `
      UPDATE community_posts
      SET
        approval_status = 'rejected',
        rejection_reason = ?,
        reviewed_by = ?,
        reviewed_at = NOW(),
        is_hidden = 1
      WHERE id = ?
      `,
      [reason, adminId, postId]
    );

    try {
      await notificationModel.createNotification(
        post.photographer_id,
        "Community Post Rejected",
        `Your post "${postTitleForNotification(post)}" was rejected. Reason: ${reason}`,
        "community_post_rejected",
        "community_post",
        postId
      );
    } catch (notificationError) {
      console.log(
        "Photographer community reject notification error:",
        notificationError.message
      );
    }

    return res.json({
      success: true,
      message: "Post rejected successfully",
    });
  } catch (error) {
    console.error("rejectCommunityPost error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to reject post",
      error: error.message,
    });
  }
};

exports.updateCommunityPostVisibility = async (req, res) => {
  try {
    const postId = req.params.postId;
    const hidden = toBool(req.body.hidden);

    const [[post]] = await db.query(
      `
      SELECT
        id,
        photographer_id,
        title,
        approval_status,
        is_hidden
      FROM community_posts
      WHERE id = ?
      LIMIT 1
      `,
      [postId]
    );

    if (!post) {
      return res.status(404).json({
        success: false,
        message: "Post not found",
      });
    }

    await db.query(
      `
      UPDATE community_posts
      SET is_hidden = ?
      WHERE id = ?
      `,
      [hidden ? 1 : 0, postId]
    );

    try {
      const isApproved = post.approval_status === "approved";

      await notificationModel.createNotification(
        post.photographer_id,
        hidden ? "Community Post Hidden" : "Community Post Visible Again",
        hidden
          ? `Your post "${postTitleForNotification(post)}" has been hidden by admin.`
          : isApproved
            ? `Your post "${postTitleForNotification(post)}" is visible again in the community.`
            : `Your post "${postTitleForNotification(post)}" visibility was updated by admin.`,
        hidden ? "community_post_hidden" : "community_post_visible",
        "community_post",
        postId
      );
    } catch (notificationError) {
      console.log(
        "Photographer community visibility notification error:",
        notificationError.message
      );
    }

    return res.json({
      success: true,
      message: hidden ? "Post hidden successfully" : "Post unhidden successfully",
    });
  } catch (error) {
    console.error("updateCommunityPostVisibility error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to update post visibility",
      error: error.message,
    });
  }
};

exports.hideCommunityComment = async (req, res) => {
  try {
    const commentId = req.params.commentId;
    const hidden = toBool(req.body.hidden);

    const [[comment]] = await db.query(
      `
      SELECT
        cc.id,
        cc.user_id,
        cc.post_id,
        cc.comment,
        cp.photographer_id,
        cp.title AS post_title
      FROM community_comments cc
      JOIN community_posts cp ON cp.id = cc.post_id
      WHERE cc.id = ?
      LIMIT 1
      `,
      [commentId]
    );

    if (!comment) {
      return res.status(404).json({
        success: false,
        message: "Comment not found",
      });
    }

    await db.query(
      `
      UPDATE community_comments
      SET is_hidden = ?
      WHERE id = ?
      `,
      [hidden ? 1 : 0, commentId]
    );

    try {
      await notificationModel.createNotification(
        comment.user_id,
        hidden ? "Community Comment Hidden" : "Community Comment Visible Again",
        hidden
          ? "One of your community comments was hidden by admin."
          : "One of your community comments is visible again.",
        hidden ? "community_comment_hidden" : "community_comment_visible",
        "community_post",
        comment.post_id
      );
    } catch (notificationError) {
      console.log(
        "Community comment visibility notification error:",
        notificationError.message
      );
    }

    return res.json({
      success: true,
      message: hidden ? "Comment hidden successfully" : "Comment unhidden successfully",
    });
  } catch (error) {
    console.error("hideCommunityComment error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to update comment visibility",
      error: error.message,
    });
  }
};