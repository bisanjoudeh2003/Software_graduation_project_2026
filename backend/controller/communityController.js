const communityModel = require("../model/communityModel");
const notificationModel = require("../model/notificationModel");

function isPhotographer(req) {
  return req.user && req.user.role === "photographer";
}

function mediaTypeFromUrlOrMime(file) {
  if (file.mimetype && file.mimetype.startsWith("video")) {
    return "video";
  }

  const url = file.path || "";
  const lower = url.toLowerCase();

  if (
    lower.includes(".mp4") ||
    lower.includes(".mov") ||
    lower.includes(".webm") ||
    lower.includes(".avi") ||
    lower.includes(".mkv")
  ) {
    return "video";
  }

  return "image";
}

function normalizeMediaList(media) {
  if (!media) return [];

  if (Array.isArray(media)) return media;

  if (typeof media === "string") {
    try {
      const parsed = JSON.parse(media);
      return Array.isArray(parsed) ? parsed : [];
    } catch (_) {
      return [];
    }
  }

  return [];
}

exports.uploadCommunityMedia = async (req, res) => {
  try {
    const files = req.files || [];

    if (!files.length) {
      return res.status(400).json({
        success: false,
        message: "No media uploaded",
      });
    }

    const media = files.map((file) => ({
      media_url: file.path,
      media_type: mediaTypeFromUrlOrMime(file),
    }));

    res.json({
      success: true,
      media,
    });
  } catch (error) {
    console.error("Upload community media error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to upload community media",
      error: error.message,
    });
  }
};

exports.getPosts = async (req, res) => {
  try {
    const userId = req.user.id;
    const { category, search, sort } = req.query;

    const posts = await communityModel.getPosts({
      userId,
      category: category || "all",
      search: search || "",
      sort: sort || "latest",
    });

    const postIds = posts.map((post) => post.id);
    const mediaMap = await communityModel.getMediaByPostIds(postIds);

    const finalPosts = posts.map((post) => ({
      ...post,
      media: mediaMap[post.id] || [],
    }));

    res.json({
      success: true,
      posts: finalPosts,
    });
  } catch (error) {
    console.error("Get community posts error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to load community posts",
      error: error.message,
    });
  }
};

exports.getPostById = async (req, res) => {
  try {
    const userId = req.user.id;
    const postId = req.params.id;

    const post = await communityModel.getPostById(postId, userId);

    if (!post) {
      return res.status(404).json({
        success: false,
        message: "Post not found",
      });
    }

    const comments = await communityModel.getComments(postId);
    const media = await communityModel.getMediaByPostId(postId);

    res.json({
      success: true,
      post: {
        ...post,
        media,
      },
      comments,
    });
  } catch (error) {
    console.error("Get community post details error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to load post details",
      error: error.message,
    });
  }
};

exports.createPost = async (req, res) => {
  try {
    if (!isPhotographer(req)) {
      return res.status(403).json({
        success: false,
        message: "Only photographers can create community posts",
      });
    }

    const photographerId = req.user.id;

    const {
      title,
      body,
      category,
      media_url,
      media_type,
      is_question,
      media,
    } = req.body;

    if (!body || !body.toString().trim()) {
      return res.status(400).json({
        success: false,
        message: "Post body is required",
      });
    }

    const mediaList = normalizeMediaList(media);

    let firstMediaUrl = media_url || null;
    let firstMediaType = media_type || "image";

    if (mediaList.length > 0) {
      firstMediaUrl = mediaList[0].media_url;
      firstMediaType = mediaList[0].media_type || "image";
    }

    const postId = await communityModel.createPost({
      photographerId,
      title: title?.toString().trim() || null,
      body: body.toString().trim(),
      category: category || "general",
      mediaUrl: firstMediaUrl,
      mediaType: firstMediaType,
      isQuestion:
        is_question === true ||
        is_question === 1 ||
        is_question === "1" ||
        is_question === "true",
    });

    if (mediaList.length > 0) {
      await communityModel.addPostMedia(postId, mediaList);
    } else if (firstMediaUrl) {
      await communityModel.addPostMedia(postId, [
        {
          media_url: firstMediaUrl,
          media_type: firstMediaType,
        },
      ]);
    }

    res.status(201).json({
      success: true,
      message: "Post created successfully",
      post_id: postId,
    });
  } catch (error) {
    console.error("Create community post error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to create post",
      error: error.message,
    });
  }
};

exports.deleteOwnPost = async (req, res) => {
  try {
    const userId = req.user.id;
    const postId = req.params.id;

    const result = await communityModel.deleteOwnPost(postId, userId);

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "Post not found or you do not own this post",
      });
    }

    res.json({
      success: true,
      message: "Post deleted successfully",
    });
  } catch (error) {
    console.error("Delete community post error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to delete post",
      error: error.message,
    });
  }
};

exports.toggleLike = async (req, res) => {
  try {
    const userId = req.user.id;
    const postId = req.params.id;

    const post = await communityModel.checkPostExists(postId);

    if (!post || post.is_hidden) {
      return res.status(404).json({
        success: false,
        message: "Post not found",
      });
    }

    const result = await communityModel.toggleLike(postId, userId);

    if (result.liked && Number(post.photographer_id) !== Number(userId)) {
      try {
        await notificationModel.createNotification(
          post.photographer_id,
          "New Like on Your Post",
          "Someone liked your community post.",
          "community"
        );
      } catch (notificationError) {
        console.log(
          "Community like notification error:",
          notificationError.message
        );
      }
    }

    res.json({
      success: true,
      liked: result.liked,
      message: result.liked ? "Post liked" : "Post unliked",
    });
  } catch (error) {
    console.error("Toggle community like error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to update like",
      error: error.message,
    });
  }
};

exports.toggleSave = async (req, res) => {
  try {
    const userId = req.user.id;
    const postId = req.params.id;

    const post = await communityModel.checkPostExists(postId);

    if (!post || post.is_hidden) {
      return res.status(404).json({
        success: false,
        message: "Post not found",
      });
    }

    const result = await communityModel.toggleSave(postId, userId);

    res.json({
      success: true,
      saved: result.saved,
      message: result.saved ? "Post saved" : "Post removed from saved",
    });
  } catch (error) {
    console.error("Toggle community save error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to update save",
      error: error.message,
    });
  }
};

exports.getSavedPosts = async (req, res) => {
  try {
    const userId = req.user.id;

    const posts = await communityModel.getSavedPosts(userId);
    const postIds = posts.map((post) => post.id);
    const mediaMap = await communityModel.getMediaByPostIds(postIds);

    const finalPosts = posts.map((post) => ({
      ...post,
      media: mediaMap[post.id] || [],
    }));

    res.json({
      success: true,
      posts: finalPosts,
    });
  } catch (error) {
    console.error("Get saved community posts error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to load saved posts",
      error: error.message,
    });
  }
};

exports.getComments = async (req, res) => {
  try {
    const postId = req.params.id;

    const comments = await communityModel.getComments(postId);

    res.json({
      success: true,
      comments,
    });
  } catch (error) {
    console.error("Get community comments error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to load comments",
      error: error.message,
    });
  }
};

exports.addComment = async (req, res) => {
  try {
    const userId = req.user.id;
    const postId = req.params.id;
    const { comment } = req.body;

    if (!comment || !comment.toString().trim()) {
      return res.status(400).json({
        success: false,
        message: "Comment is required",
      });
    }

    const post = await communityModel.checkPostExists(postId);

    if (!post || post.is_hidden) {
      return res.status(404).json({
        success: false,
        message: "Post not found",
      });
    }

    const commentId = await communityModel.addComment(
      postId,
      userId,
      comment.toString().trim()
    );

    if (Number(post.photographer_id) !== Number(userId)) {
      try {
        await notificationModel.createNotification(
          post.photographer_id,
          "New Comment on Your Post",
          "Someone commented on your community post.",
          "community"
        );
      } catch (notificationError) {
        console.log(
          "Community comment notification error:",
          notificationError.message
        );
      }
    }

    res.status(201).json({
      success: true,
      message: "Comment added successfully",
      comment_id: commentId,
    });
  } catch (error) {
    console.error("Add community comment error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to add comment",
      error: error.message,
    });
  }
};

exports.deleteOwnComment = async (req, res) => {
  try {
    const userId = req.user.id;
    const commentId = req.params.commentId;

    const result = await communityModel.deleteOwnComment(commentId, userId);

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "Comment not found or you do not own this comment",
      });
    }

    res.json({
      success: true,
      message: "Comment deleted successfully",
    });
  } catch (error) {
    console.error("Delete community comment error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to delete comment",
      error: error.message,
    });
  }
};

exports.reportPost = async (req, res) => {
  try {
    const reporterId = req.user.id;
    const postId = req.params.id;
    const { reason } = req.body;

    if (!reason || !reason.toString().trim()) {
      return res.status(400).json({
        success: false,
        message: "Report reason is required",
      });
    }

    const post = await communityModel.checkPostExists(postId);

    if (!post || post.is_hidden) {
      return res.status(404).json({
        success: false,
        message: "Post not found",
      });
    }

    const reportId = await communityModel.reportPost(
      postId,
      reporterId,
      reason.toString().trim()
    );

    res.status(201).json({
      success: true,
      message: "Post reported successfully",
      report_id: reportId,
    });
  } catch (error) {
    console.error("Report community post error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to report post",
      error: error.message,
    });
  }
};

exports.getReels = async (req, res) => {
  try {
    const userId = req.user.id;

    const reels = await communityModel.getVideoPosts(userId);

    res.json({
      success: true,
      reels,
    });
  } catch (error) {
    console.error("Get community reels error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to load reels",
      error: error.message,
    });
  }
};