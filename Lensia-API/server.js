const express = require('express');
const pool = require('./config/db');
require('dotenv').config();
const userModel = require("./model/userModel");
const authRoutes = require('./route/authRoutes');
const photographerRoutes = require("./route/photographerRoutes");
const photographerPortfolioRoutes = require("./route/photographerPortfolioRoutes");
const portfolioItemsRoutes = require("./route/portfolioItemsRoutes");
const venueRoutes = require("./route/venueRoutes");
const availabilityRoutes = require("./route/availabilityRoutes");
const bookingRoutes = require("./route/bookingRoutes");
const dashboardRoutes_venue = require("./route/dashboardRoutes-venue")
const uploadRoutes = require("./route/uploadRoutes");
const settingsRoutes = require("./route/venuesettingsRoutes");
const reviewRoutes = require("./route/VenueratingRoutes");
const venueImageRoutes = require("./route/venueImageRoutes");
const notificationRoutes =require("./route/venueNotificationRoutes");
const venuefavoriteRoutes =require("./route/venuefavoriteRoute");
const messagesRoutes=require("./route/messagesRoute");
const stripeRoutes = require("./route/stripeRoute");
const userRoutes = require("./route/userRoutes");
const ReportRoutes =require("./route/ReportRoutes");
const cors = require("cors");
const bcrypt = require("bcrypt");
const app = express();

const http = require("http");
const {Server} = require("socket.io");

const server = http.createServer(app);





// CORS
app.use(cors({
  origin: "*",
  methods: ["GET","POST","PUT","DELETE"],
  allowedHeaders: ["Content-Type","Authorization"]
}));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ROUTES
app.use('/api/auth', authRoutes);
app.use("/api/photographer", photographerRoutes);
app.use("/api/photographer-portfolio", photographerPortfolioRoutes);
app.use("/api/portfolio-items", portfolioItemsRoutes);
app.use("/api", venueRoutes);
app.use("/api", availabilityRoutes);
app.use("/api", bookingRoutes);
app.use("/api",dashboardRoutes_venue);
app.use("/api",uploadRoutes);
app.use("/api",settingsRoutes);
app.use("/api", reviewRoutes);
app.use("/api",venueImageRoutes);
app.use("/api",venuefavoriteRoutes)
app.use("/api",notificationRoutes);
app.use("/api",messagesRoutes);
app.use("/api", stripeRoutes);
app.use("/api",ReportRoutes)
app.use("/api", userRoutes);
(async () => {
  try {
    const [rows] = await pool.query('SELECT NOW() AS currentTime');
    console.log('Database connected at:', rows[0].currentTime);
  } catch (err) {
    console.error('Database connection error:', err);
  }
})();

// RESET PASSWORD PAGE
app.get("/reset-password", (req, res) => {

  const token = req.query.token;

  res.send(`
<!DOCTYPE html>
<html>

<head>

<title>Reset Password</title>

<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;600&display=swap" rel="stylesheet">

<style>

*{
box-sizing:border-box;
margin:0;
padding:0;
font-family:'Montserrat', sans-serif;
}

body{
background:#f4f4f4;
display:flex;
justify-content:center;
align-items:center;
height:100vh;
}

.card{
background:white;
padding:40px;
width:380px;
border-radius:14px;
box-shadow:0 8px 20px rgba(0,0,0,0.08);
}

h2{
margin-bottom:25px;
font-weight:600;
color:#1e1e1e;
}

input{
width:100%;
padding:14px;
margin-bottom:15px;
border-radius:8px;
border:1px solid #ddd;
font-size:14px;
}

input:focus{
outline:none;
border-color:#2F4F3E;
}

button{
width:100%;
padding:14px;
background:#2F4F3E;
color:white;
border:none;
border-radius:8px;
font-size:15px;
font-weight:600;
cursor:pointer;
transition:0.2s;
}

button:hover{
background:#274535;
}

.message{
margin-top:15px;
font-size:14px;
text-align:center;
}

.success{
color:green;
}

.error{
color:red;
}

</style>

</head>

<body>

<div class="card">

<h2>Reset Password</h2>

<form method="POST" action="/reset-password">

<input type="hidden" name="token" value="${token}" />

<input
type="password"
name="password"
placeholder="New Password"
required
/>

<input
type="password"
name="confirm"
placeholder="Confirm Password"
required
/>

<button type="submit">
Reset Password
</button>

</form>

</div>

</body>
</html>
  `);

});

app.post("/reset-password", async (req, res) => {

  try {

    const { token, password, confirm } = req.body;

    if (!token || !password || !confirm) {
      return res.send("Missing data");
    }

    if (password !== confirm) {
      return res.send("Passwords do not match");
    }

    const user = await userModel.findUserByResetToken(token);

    if (!user) {
      return res.send("Invalid or expired link");
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    await userModel.updatePassword(
      user.id,
      hashedPassword
    );

    res.send("Password reset successful");

  } catch (err) {

    console.error(err);

    res.send("Server error");

  }

});

app.post("/api/upload", (req, res) => {
  res.json({
    message: "UPLOAD DIRECT ROUTE WORKING"
  });
});
const io = new Server(server,{
cors:{origin:"*"}
});

global.io = io;

io.on("connection",(socket)=>{
console.log("User connected:",socket.id);
});
// START SERVER
app.listen(3000, "0.0.0.0", () => {
  console.log("Server running on port 3000");
});