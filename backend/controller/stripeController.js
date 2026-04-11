const Stripe = require("stripe");
const stripe = Stripe(process.env.STRIPE_SECRET_KEY);
const pool = require("../config/db");

exports.createPaymentIntent = async (req, res) => {
  try {
    const { booking_id } = req.body;

    const [rows] = await pool.query(
      `SELECT * FROM venue_bookings WHERE id = ? AND client_id = ?`,
      [booking_id, req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: "Booking not found" });
    }

    const booking = rows[0];

    // ← بدل confirmed فقط، قبل pending أيضاً
    if (booking.status !== "pending" && booking.status !== "confirmed") {
      return res.status(400).json({ error: "Booking is not active" });
    }

    if (booking.deposit_paid === 1) {
      return res.status(400).json({ error: "Deposit already paid" });
    }

    const depositAmount = Math.round(booking.total_price * 0.3 * 100);

    const paymentIntent = await stripe.paymentIntents.create({
      amount: depositAmount,
      currency: "usd",
      metadata: {
        booking_id: booking_id.toString(),
        client_id: req.user.id.toString(),
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
exports.confirmPayment = async (req, res) => {
  try {
    const { booking_id, payment_intent_id } = req.body;

    const paymentIntent = await stripe.paymentIntents.retrieve(payment_intent_id);

    if (paymentIntent.status !== "succeeded") {
      return res.status(400).json({ error: "Payment not completed" });
    }

    // ✅ تحقق من metadata
    if (paymentIntent.metadata.booking_id !== booking_id.toString()) {
      return res.status(400).json({ error: "Invalid booking ارتباط" });
    }

    if (paymentIntent.metadata.client_id !== req.user.id.toString()) {
      return res.status(403).json({ error: "Unauthorized payment" });
    }

    const depositAmount = paymentIntent.amount / 100;

   await pool.query(
  `UPDATE venue_bookings 
   SET deposit_paid = 1, deposit_amount = ?, stripe_payment_intent_id = ?
   WHERE id = ? AND client_id = ?`,
  [depositAmount, payment_intent_id, booking_id, req.user.id]
);

    res.json({ message: "Deposit paid successfully" });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
exports.refundDeposit = async (bookingId) => {
  const [rows] = await pool.query(
    "SELECT * FROM venue_bookings WHERE id = ?",
    [bookingId]
  );
  
  if (rows.length === 0) return;
  const booking = rows[0];
  
  // لو ما في deposit مدفوع → ما في شي يرجع
  if (!booking.deposit_paid || !booking.stripe_payment_intent_id) return;

  try {
    await stripe.refunds.create({
      payment_intent: booking.stripe_payment_intent_id,
    });
  } catch (err) {
    console.log("Stripe refund error:", err.message);
  }

  await pool.query(
    "UPDATE venue_bookings SET deposit_paid = 0, deposit_amount = 0 WHERE id = ?",
    [bookingId]
  );
};