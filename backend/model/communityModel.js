const db = require("../config/db");

exports.getPosts = async ({
  userId,
  category,
  search,
  sort,
}) => {
  const conditions = ["cp.is_hidden = 0"];
  const params = [];

  if (category && category !== "all") {
    if (category === "questions") {
      conditions.push("cp.is_question = 1");
    } else {
      conditions.push("cp.category = ?");
      params.push(category);
    }
  }

  if (search && search.trim()) {
    conditions.push("(cp.title LIKE ? OR cp.body LIKE ? OR u.full_name LIKE ?)");
    const q = `%${search.trim()}%`;
    params.push(q, q, q);
  }

  let orderBy = "cp.created_at DESC";

  if (sort === "popular") {
    orderBy = "likes_count DESC, comments_count DESC, cp.created_at DESC";
  }

  const [rows] = await db.query(
    `
    SELECT
      cp.*,

      u.id AS photographer_user_id,
      u.full_name AS photographer_name,
      u.email AS photographer_email,
      u.profile_image AS photographer_profile_image,
      u.role AS photographer_role,

      COUNT(DISTINCT cpl.id) AS likes_count,
      COUNT(DISTINCT cps.id) AS saves_count,
      COUNT(DISTINCT cc.id) AS comments_count,

      MAX(CASE WHEN my_like.id IS NOT NULL THEN 1 ELSE 0 END) AS is_liked,
      MAX(CASE WHEN my_save.id IS NOT NULL THEN 1 ELSE 0 END) AS is_saved

    FROM community_posts cp
    JOIN users u ON cp.photographer_id = u.id

    LEFT JOIN community_post_likes cpl ON cp.id = cpl.post_id
    LEFT JOIN community_post_saves cps ON cp.id = cps.post_id
    LEFT JOIN community_comments cc ON cp.id = cc.post_id AND cc.is_hidden = 0

    LEFT JOIN community_post_likes my_like
      ON cp.id = my_like.post_id AND my_like.user_id = ?

    LEFT JOIN community_post_saves my_save
      ON cp.id = my_save.post_id AND my_save.user_id = ?

    WHERE ${conditions.join(" AND ")}

    GROUP BY cp.id
    ORDER BY ${orderBy}
    LIMIT 100
    `,
    [userId, userId, ...params]
  );

  return rows;
};

exports.getPostById = async (postId, userId) => {
  const [[post]] = await db.query(
    `
    SELECT
      cp.*,

      u.id AS photographer_user_id,
      u.full_name AS photographer_name,
      u.email AS photographer_email,
      u.profile_image AS photographer_profile_image,
      u.role AS photographer_role,

      COUNT(DISTINCT cpl.id) AS likes_count,
      COUNT(DISTINCT cps.id) AS saves_count,
      COUNT(DISTINCT cc.id) AS comments_count,

      MAX(CASE WHEN my_like.id IS NOT NULL THEN 1 ELSE 0 END) AS is_liked,
      MAX(CASE WHEN my_save.id IS NOT NULL THEN 1 ELSE 0 END) AS is_saved

    FROM community_posts cp
    JOIN users u ON cp.photographer_id = u.id

    LEFT JOIN community_post_likes cpl ON cp.id = cpl.post_id
    LEFT JOIN community_post_saves cps ON cp.id = cps.post_id
    LEFT JOIN community_comments cc ON cp.id = cc.post_id AND cc.is_hidden = 0

    LEFT JOIN community_post_likes my_like
      ON cp.id = my_like.post_id AND my_like.user_id = ?

    LEFT JOIN community_post_saves my_save
      ON cp.id = my_save.post_id AND my_save.user_id = ?

    WHERE cp.id = ?
      AND cp.is_hidden = 0

    GROUP BY cp.id
    LIMIT 1
    `,
    [userId, userId, postId]
  );

  return post;
};

exports.createPost = async ({
  photographerId,
  title,
  body,
  category,
  mediaUrl,
  mediaType,
  isQuestion,
}) => {
  const [result] = await db.query(
    `
    INSERT INTO community_posts
    (
      photographer_id,
      title,
      body,
      category,
      media_url,
      media_type,
      is_question
    )
    VALUES (?, ?, ?, ?, ?, ?, ?)
    `,
    [
      photographerId,
      title || null,
      body,
      category || "general",
      mediaUrl || null,
      mediaType || "image",
      isQuestion ? 1 : 0,
    ]
  );

  return result.insertId;
};

exports.deleteOwnPost = async (postId, userId) => {
  const [result] = await db.query(
    `
    UPDATE community_posts
    SET is_hidden = 1
    WHERE id = ?
      AND photographer_id = ?
    `,
    [postId, userId]
  );

  return result;
};

exports.toggleLike = async (postId, userId) => {
  const [[existing]] = await db.query(
    `
    SELECT id
    FROM community_post_likes
    WHERE post_id = ?
      AND user_id = ?
    LIMIT 1
    `,
    [postId, userId]
  );

  if (existing) {
    await db.query(
      `
      DELETE FROM community_post_likes
      WHERE id = ?
      `,
      [existing.id]
    );

    return { liked: false };
  }

  await db.query(
    `
    INSERT INTO community_post_likes (post_id, user_id)
    VALUES (?, ?)
    `,
    [postId, userId]
  );

  return { liked: true };
};

exports.toggleSave = async (postId, userId) => {
  const [[existing]] = await db.query(
    `
    SELECT id
    FROM community_post_saves
    WHERE post_id = ?
      AND user_id = ?
    LIMIT 1
    `,
    [postId, userId]
  );

  if (existing) {
    await db.query(
      `
      DELETE FROM community_post_saves
      WHERE id = ?
      `,
      [existing.id]
    );

    return { saved: false };
  }

  await db.query(
    `
    INSERT INTO community_post_saves (post_id, user_id)
    VALUES (?, ?)
    `,
    [postId, userId]
  );

  return { saved: true };
};

exports.getSavedPosts = async (userId) => {
  const [rows] = await db.query(
    `
    SELECT
      cp.*,

      u.id AS photographer_user_id,
      u.full_name AS photographer_name,
      u.email AS photographer_email,
      u.profile_image AS photographer_profile_image,
      u.role AS photographer_role,

      COUNT(DISTINCT cpl.id) AS likes_count,
      COUNT(DISTINCT cc.id) AS comments_count,

      1 AS is_saved,
      MAX(CASE WHEN my_like.id IS NOT NULL THEN 1 ELSE 0 END) AS is_liked

    FROM community_post_saves cps
    JOIN community_posts cp ON cps.post_id = cp.id
    JOIN users u ON cp.photographer_id = u.id

    LEFT JOIN community_post_likes cpl ON cp.id = cpl.post_id
    LEFT JOIN community_comments cc ON cp.id = cc.post_id AND cc.is_hidden = 0

    LEFT JOIN community_post_likes my_like
      ON cp.id = my_like.post_id AND my_like.user_id = ?

    WHERE cps.user_id = ?
      AND cp.is_hidden = 0

    GROUP BY cp.id
    ORDER BY cps.created_at DESC
    `,
    [userId, userId]
  );

  return rows;
};

exports.getComments = async (postId) => {
  const [rows] = await db.query(
    `
    SELECT
      cc.*,
      u.full_name AS user_name,
      u.profile_image AS user_profile_image,
      u.role AS user_role
    FROM community_comments cc
    JOIN users u ON cc.user_id = u.id
    WHERE cc.post_id = ?
      AND cc.is_hidden = 0
    ORDER BY cc.created_at ASC
    `,
    [postId]
  );

  return rows;
};

exports.addComment = async (postId, userId, comment) => {
  const [result] = await db.query(
    `
    INSERT INTO community_comments
    (
      post_id,
      user_id,
      comment
    )
    VALUES (?, ?, ?)
    `,
    [postId, userId, comment]
  );

  return result.insertId;
};

exports.deleteOwnComment = async (commentId, userId) => {
  const [result] = await db.query(
    `
    UPDATE community_comments
    SET is_hidden = 1
    WHERE id = ?
      AND user_id = ?
    `,
    [commentId, userId]
  );

  return result;
};

exports.reportPost = async (postId, reporterId, reason) => {
  const [result] = await db.query(
    `
    INSERT INTO community_reports
    (
      post_id,
      reporter_id,
      reason
    )
    VALUES (?, ?, ?)
    `,
    [postId, reporterId, reason]
  );

  return result.insertId;
};

exports.checkPostExists = async (postId) => {
  const [[post]] = await db.query(
    `
    SELECT id, photographer_id, is_hidden
    FROM community_posts
    WHERE id = ?
    LIMIT 1
    `,
    [postId]
  );

  return post;
};

exports.addPostMedia = async (postId, mediaList = []) => {
  if (!mediaList || mediaList.length === 0) return;

  const values = mediaList.map((media, index) => [
    postId,
    media.media_url,
    media.media_type || "image",
    index,
  ]);

  await db.query(
    `
    INSERT INTO community_post_media
    (
      post_id,
      media_url,
      media_type,
      sort_order
    )
    VALUES ?
    `,
    [values]
  );
};

exports.getMediaByPostIds = async (postIds = []) => {
  if (!postIds || postIds.length === 0) return {};

  const [rows] = await db.query(
    `
    SELECT *
    FROM community_post_media
    WHERE post_id IN (?)
    ORDER BY sort_order ASC, id ASC
    `,
    [postIds]
  );

  const map = {};

  for (const row of rows) {
    if (!map[row.post_id]) {
      map[row.post_id] = [];
    }

    map[row.post_id].push(row);
  }

  return map;
};

exports.getMediaByPostId = async (postId) => {
  const [rows] = await db.query(
    `
    SELECT *
    FROM community_post_media
    WHERE post_id = ?
    ORDER BY sort_order ASC, id ASC
    `,
    [postId]
  );

  return rows;
};

exports.getVideoPosts = async (userId) => {
  const [rows] = await db.query(
    `
    SELECT
      cp.*,

      u.id AS photographer_user_id,
      u.full_name AS photographer_name,
      u.profile_image AS photographer_profile_image,

      cpm.id AS media_id,
      cpm.media_url AS reel_url,
      cpm.media_type AS reel_type,

      COUNT(DISTINCT cpl.id) AS likes_count,
      COUNT(DISTINCT cc.id) AS comments_count,

      MAX(CASE WHEN my_like.id IS NOT NULL THEN 1 ELSE 0 END) AS is_liked,
      MAX(CASE WHEN my_save.id IS NOT NULL THEN 1 ELSE 0 END) AS is_saved

    FROM community_posts cp
    JOIN users u ON cp.photographer_id = u.id
    JOIN community_post_media cpm ON cp.id = cpm.post_id

    LEFT JOIN community_post_likes cpl ON cp.id = cpl.post_id
    LEFT JOIN community_comments cc ON cp.id = cc.post_id AND cc.is_hidden = 0

    LEFT JOIN community_post_likes my_like
      ON cp.id = my_like.post_id AND my_like.user_id = ?

    LEFT JOIN community_post_saves my_save
      ON cp.id = my_save.post_id AND my_save.user_id = ?

    WHERE cp.is_hidden = 0
      AND cpm.media_type = 'video'

    GROUP BY cp.id, cpm.id
    ORDER BY cp.created_at DESC
    LIMIT 100
    `,
    [userId, userId]
  );

  return rows;
};