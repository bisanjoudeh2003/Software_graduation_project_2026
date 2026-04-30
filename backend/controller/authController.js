const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require("crypto");

const pool = require("../config/db");
const userModel = require('../model/userModel');
const transporter = require("../config/mailer");

const JWT_SECRET = "supersecretkey";



/// REGISTER
exports.register = async (req, res) => {

  try {

    const { full_name, email, password, role } = req.body;

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await userModel.createUser(
      full_name,
      email,
      hashedPassword,
      role
    );

    res.status(201).json(user);

  } catch (error) {

    res.status(500).json({
      error: error.message
    });

  }

};



/// LOGIN
exports.login = async (req, res) => {

  try {

    const { email, password } = req.body;

    const user = await userModel.findUserByEmail(email);

    if (!user) {

      return res.status(400).json({
        message: "User not found"
      });

    }

    const validPassword =
      await bcrypt.compare(password, user.password);

    if (!validPassword) {

      return res.status(400).json({
        message: "Invalid password"
      });

    }

    const token = jwt.sign(
      { id: user.id, role: user.role },
      JWT_SECRET,
      { expiresIn: "1d" }
    );

    res.json({
      token: token,
      role: user.role
    });

  } catch (error) {

    res.status(500).json({
      error: error.message
    });

  }

};



/// GET USER
exports.getMe = async (req, res) => {

  try {

    const user =
      await userModel.findUserById(req.user.id);

    if (!user) {

      return res.status(404).json({
        message: "User not found"
      });

    }

    res.json(user);

  } catch (error) {

    res.status(500).json({
      error: error.message
    });

  }

};



/// UPDATE PROFILE
exports.updateProfile = async (req, res) => {
  try {
    const userId = req.user.id;

    const { full_name, phone, bio, social_links } = req.body;
console.log("UPDATE PROFILE BODY:", req.body);
    await pool.query(
      `UPDATE users
       SET full_name = ?, phone = ?, bio = ?, social_links = ?
       WHERE id = ?`,
      [
        full_name,
        phone || null,
        bio || null,
        social_links ? JSON.stringify(social_links) : JSON.stringify({}),
        userId
      ]
    );

    const [rows] = await pool.query(
      `SELECT id, full_name, email, role, phone, profile_image, cover_image, bio, social_links
       FROM users
       WHERE id = ?`,
      [userId]
    );

    const user = rows[0];

    if (user?.social_links && typeof user.social_links === "string") {
      try {
        user.social_links = JSON.parse(user.social_links);
      } catch (_) {
        user.social_links = {};
      }
    }

    res.json(user);

  } catch (err) {
    res.status(500).json({
      error: err.message
    });
  }
};



/// CHANGE PASSWORD
exports.changePassword = async (req, res) => {

  try {

    const userId = req.user.id;

    const { oldPassword, newPassword } = req.body;

    const [rows] = await pool.query(

      `SELECT password
       FROM users
       WHERE id=?`,

      [userId]

    );

    if (rows.length === 0) {
      return res.status(404).json({
        error: "User not found"
      });
    }

    const match = await bcrypt.compare(
      oldPassword,
      rows[0].password
    );

    if (!match) {
      return res.status(400).json({
        error: "Old password incorrect"
      });
    }

    const hash =
      await bcrypt.hash(newPassword, 10);

    await pool.query(

      `UPDATE users
       SET password = ?
       WHERE id=?`,

      [hash, userId]

    );

    res.json({
      message: "Password updated"
    });

  } catch (err) {

    res.status(500).json({
      error: err.message
    });

  }

};



/// FORGOT PASSWORD
exports.forgotPassword = async (req, res) => {

  try {

    const { email } = req.body;

    if (!email) {
      return res.status(400).json({
        message: "Email is required"
      });
    }

    const user =
      await userModel.findUserByEmail(email);

    // اذا الايميل غير موجود
    if (!user) {
      return res.status(404).json({
        message: "Email not found"
      });
    }

    const resetToken =
      crypto.randomBytes(32).toString("hex");

    const expiry =
      new Date(Date.now() + 15 * 60 * 1000);

    await userModel.saveResetToken(
      user.id,
      resetToken,
      expiry
    );

    const resetLink =
      `http://localhost:3000/reset-password?token=${resetToken}`;

    await transporter.sendMail({

      to: email,

      subject: "Reset Your Password",

      html: `
        <h3>Password Reset</h3>
        <p>Click the link below:</p>
        <a href="${resetLink}">${resetLink}</a>
        <p>This link expires in 15 minutes</p>
      `,

    });

    return res.json({
      message: "Reset link sent"
    });

  } catch (err) {

    console.error(err);
    return res.status(500).json({
      message: "Server error"
    });

  }

};



/// RESET PASSWORD
exports.resetPassword = async (req, res) => {

  try {

    const { token, newPassword } = req.body;

    const user =
      await userModel.findUserByResetToken(token);

    if (!user) {

      return res.status(400).json({
        message: "Invalid or expired link"
      });

    }

    const hashedPassword =
      await bcrypt.hash(newPassword, 10);

    await userModel.updatePassword(
      user.id,
      hashedPassword
    );

    res.json({
      message: "Password reset successful"
    });

  } catch (err) {

    res.status(500).json({
      error: err.message
    });

  }

};



//UPDATE PROFILE IMAGE
exports.updateProfileImage = async (req, res) => {

  try {

    const userId = req.user.id;

    const { image_url } = req.body;

    await userModel.updateProfileImage(userId, image_url);

    res.json({
      message: "Profile image updated"
    });

  } catch (err) {

    res.status(500).json({
      error: err.message
    });

  }

};