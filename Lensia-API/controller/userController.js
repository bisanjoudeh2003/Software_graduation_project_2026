const userModel = require("../model/userModel");
const pool = require("../config/db");

exports.getUserProfile = async (req, res) => {
  try {
    const userId = req.params.id;
    const user = await userModel.findUserById(userId);
    res.json(user);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.searchUsers = async (req, res) => {
  try {
    const { q } = req.query;
    if (!q || q.trim().length < 2) return res.json([]);

    const [rows] = await pool.query(
      `SELECT id, full_name, profile_image, role 
       FROM users 
       WHERE full_name LIKE ? 
       AND id != ?
       AND role != 'admin'
       LIMIT 20`,
      [`%${q.trim()}%`, req.user.id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getPublicProfile = async (req, res) => {
  try {
    const { id } = req.params;

    const user = await userModel.findPublicProfileById(id); // ← عدلت هون

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    if (user.social_links && typeof user.social_links === "string") {
      try {
        user.social_links = JSON.parse(user.social_links);
      } catch (_) {
        user.social_links = {};
      }
    }

    res.status(200).json(user);
  } catch (error) {
    console.error("getPublicProfile error:", error);
    res.status(500).json({ message: "Server error" });
  }
};

exports.updateUserBio = async (req, res) => {
  try {
    const userId = req.user.id;
    const { bio, social_links } = req.body;

    if (bio && bio.length > 500) {
      return res.status(400).json({ message: "البيو ما يتجاوز 500 حرف" });
    }

    const allowedKeys = ["instagram", "facebook", "twitter", "linkedin", "website"];
    if (social_links) {
      const invalid = Object.keys(social_links).filter(
        (k) => !allowedKeys.includes(k)
      );
      if (invalid.length > 0) {
        return res.status(400).json({
          message: `سوشيال لينكس غير مسموحة: ${invalid.join(", ")}`,
        });
      }
    }

    await userModel.updateBio(userId, bio || null, social_links || {}); // ← عدلت هون

    res.status(200).json({ message: "تم تحديث البيو بنجاح" });
  } catch (error) {
    console.error("updateUserBio error:", error);
    res.status(500).json({ message: "خطأ في السيرفر" });
  }
};