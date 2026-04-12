const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const userModel = require('../model/userModel');
const crypto = require("crypto");
const transporter = require("../config/mailer");

const JWT_SECRET = "supersecretkey";


// REGISTER
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

    res.status(500).json({ error: error.message });

  }
};



// LOGIN
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

    res.status(500).json({ error: error.message });

  }
};



// GET USER
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

    res.status(500).json({ error: error.message });

  }
};



// FORGOT PASSWORD
exports.forgotPassword = async (req, res) => {

  try {

    const { email } = req.body;

    if (!email) {
      return res.status(400).json({
        message: "Email is required"
      });
    }

    const user = await userModel.findUserByEmail(email);

    /// اذا الايميل غير موجود
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



// RESET PASSWORD
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