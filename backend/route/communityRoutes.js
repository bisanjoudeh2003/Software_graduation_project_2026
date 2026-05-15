const express = require("express");
const router = express.Router();

const authMiddleware = require("../middleware/authMiddleware");
const communityController = require("../controller/communityController");
const upload = require("../middleware/uploadMiddleware");

router.use(authMiddleware);

/*
|--------------------------------------------------------------------------
| Upload community media
|--------------------------------------------------------------------------
| POST /api/community/upload-media
| field name: media
|--------------------------------------------------------------------------
*/

router.post(
  "/upload-media",
  upload.array("media", 10),
  communityController.uploadCommunityMedia
);

/*
|--------------------------------------------------------------------------
| Reels
|--------------------------------------------------------------------------
| GET /api/community/reels
|--------------------------------------------------------------------------
*/

router.get("/reels", communityController.getReels);

/*
|--------------------------------------------------------------------------
| Posts
|--------------------------------------------------------------------------
*/

router.get("/posts", communityController.getPosts);
router.get("/posts/saved", communityController.getSavedPosts);
router.get("/posts/:id", communityController.getPostById);
router.post("/posts", communityController.createPost);
router.delete("/posts/:id", communityController.deleteOwnPost);

/*
|--------------------------------------------------------------------------
| Likes / Saves
|--------------------------------------------------------------------------
*/

router.post("/posts/:id/like", communityController.toggleLike);
router.post("/posts/:id/save", communityController.toggleSave);

/*
|--------------------------------------------------------------------------
| Comments
|--------------------------------------------------------------------------
*/

router.get("/posts/:id/comments", communityController.getComments);
router.post("/posts/:id/comments", communityController.addComment);

router.delete(
  "/comments/:commentId",
  communityController.deleteOwnComment
);

/*
|--------------------------------------------------------------------------
| Reports
|--------------------------------------------------------------------------
*/

router.post("/posts/:id/report", communityController.reportPost);

module.exports = router;