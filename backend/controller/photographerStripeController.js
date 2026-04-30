const Stripe = require("stripe");
const stripe = Stripe(process.env.STRIPE_SECRET_KEY);
const pool = require("../config/db");
const notificationModel = require("../model/notificationModel");

exports.createPhotographerPaymentIntent = async (req, res) => {
  try {
    const { booking_id } = req.body;

    const [rows] = await pool.query(
      `SELECT *
       FROM photographer_bookings
       WHERE id = ? AND client_id = ?`,
      [booking_id, req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: "Photographer booking not found" });
    }

    const booking = rows[0];

    if (booking.status !== "pending" && booking.status !== "confirmed") {
      return res.status(400).json({ error: "Booking is not active" });
    }

    if (booking.deposit_paid === 1) {
      return res.status(400).json({ error: "Deposit already paid" });
    }

    const depositAmount = Math.round(Number(booking.deposit_amount || 0) * 100);

    if (!depositAmount || depositAmount <= 0) {
      return res.status(400).json({ error: "Invalid deposit amount" });
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount: depositAmount,
      currency: "usd",
      metadata: {
        booking_id: booking_id.toString(),
        client_id: req.user.id.toString(),
        booking_type: "photographer",
      },
    });

    res.json({
      clientSecret: paymentIntent.client_secret,
      amount: depositAmount,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.confirmPhotographerPayment = async (req, res) => {
  const connection = await pool.getConnection();

  try {
    const { booking_id, payment_intent_id } = req.body;

    const paymentIntent = await stripe.paymentIntents.retrieve(payment_intent_id);

    if (paymentIntent.status !== "succeeded") {
      return res.status(400).json({ error: "Payment not completed" });
    }

    if (paymentIntent.metadata.booking_id !== booking_id.toString()) {
      return res.status(400).json({ error: "Invalid booking relation" });
    }

    if (paymentIntent.metadata.client_id !== req.user.id.toString()) {
      return res.status(403).json({ error: "Unauthorized payment" });
    }

    await connection.beginTransaction();

    const [rows] = await connection.query(
      `SELECT pb.*, p.user_id, u.full_name AS photographer_name
       FROM photographer_bookings pb
       JOIN photographers p ON p.photographer_id = pb.photographer_id
       JOIN users u ON u.id = p.user_id
       WHERE pb.id = ? AND pb.client_id = ?
       FOR UPDATE`,
      [booking_id, req.user.id]
    );

    if (rows.length === 0) {
      await connection.rollback();
      return res.status(404).json({ error: "Booking not found" });
    }

    const booking = rows[0];

    if (booking.deposit_paid === 1) {
      await connection.rollback();
      return res.status(400).json({ error: "Deposit already paid" });
    }

    const depositAmount = paymentIntent.amount / 100;

    await connection.query(
      `UPDATE photographer_bookings
       SET deposit_paid = 1,
           deposit_amount = ?,
           stripe_payment_intent_id = ?
       WHERE id = ? AND client_id = ?`,
      [depositAmount, payment_intent_id, booking_id, req.user.id]
    );

    await connection.commit();

    await notificationModel.createNotification(
      booking.user_id,
      "New Booking Request",
      `A client paid the deposit for a ${booking.photographer_name} session`,
      "booking"
    );

    res.json({ message: "Photographer deposit paid successfully" });
  } catch (err) {
    await connection.rollback();
    res.status(500).json({ error: err.message });
  } finally {
    connection.release();
  }
};