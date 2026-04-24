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

    const user = await userModel.findPublicProfileById(id); 

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

exports.updateDarkMode = async (req, res) => {
  try {
    const userId = req.user.id;
    const { dark_mode } = req.body;

    if (dark_mode === undefined || dark_mode === null) {
      return res.status(400).json({
        message: "dark_mode is required"
      });
    }

    if (dark_mode !== 0 && dark_mode !== 1) {
      return res.status(400).json({
        message: "dark_mode must be 0 or 1"
      });
    }

    await userModel.updateDarkMode(userId, dark_mode);

    return res.status(200).json({
      message: "Dark mode updated successfully",
      dark_mode
    });
  } catch (error) {
    console.error("updateDarkMode error:", error);
    return res.status(500).json({
      message: "Server error"
    });
  }
};

