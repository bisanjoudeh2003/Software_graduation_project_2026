const express = require('express');
const pool = require('./config/db');
const userModel = require("./model/userModel");

const authRoutes = require('./route/authRoutes');
const photographerRoutes = require("./route/photographerRoutes");

const portfolioRoutes = require("./route/portfolioRoutes");
const uploadRoutes = require("./route/uploadRoutes");
const bookingRoutes = require("./route/BookingRoutes");
const notificationRoutes = require("./route/notificationRoutes");
const cors = require("cors");
const bcrypt = require("bcrypt");

const app = express();


// CORS
app.use(cors({
  origin: "*",
  methods: ["GET","POST","PUT","DELETE"],
  allowedHeaders: ["Content-Type","Authorization"]
}));


app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use((err, req, res, next) => {
  console.log("GLOBAL ERROR:", JSON.stringify(err, null, 2));
  res.status(500).json({ error: err.message });
});



const { startReminderJob } = require('./utils/reminderJob');
startReminderJob();

app.use("/api/notifications", notificationRoutes);
// ROUTES
app.use('/api/auth', authRoutes);
app.use("/api/photographer", photographerRoutes);
app.use("/api/bookings" , bookingRoutes);

app.use("/api/upload", uploadRoutes);
app.use('/api/availability', require('./route/availabilityRoutes'));

app.use("/api/portfolio", portfolioRoutes);

// TEST DATABASE CONNECTION
(async () => {
  try {

    const [rows] = await pool.query('SELECT NOW() AS currentTime');

    console.log('Database connected at:', rows[0].currentTime);

  } catch (err) {

    console.error('Database connection error:', err);

  }
})();



// TEST ROUTE
app.get("/", (req, res) => {
  res.send("API running");
});



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



// RESET PASSWORD LOGIC
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



// START SERVER
app.listen(3000, "0.0.0.0", () => {

  console.log("Server running on port 3000");

});