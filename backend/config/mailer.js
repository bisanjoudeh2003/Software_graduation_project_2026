const nodemailer = require("nodemailer");

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "rayaabudaia66@gmail.com",
    pass: "oarg uijs ppqt znzp", 
  },
});

module.exports = transporter;