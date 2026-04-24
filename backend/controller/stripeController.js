const Stripe = require("stripe");
const stripe = Stripe(process.env.STRIPE_SECRET_KEY);
const pool = require("../config/db");
const notificationModel = require("../model/notificationModel");

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
      `SELECT vb.*, v.owner_id, v.name AS venue_name
       FROM venue_bookings vb
       JOIN venues v ON v.id = vb.venue_id
       WHERE vb.id = ? AND vb.client_id = ?
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

    // هل يوجد شخص آخر دفع لنفس الموعد؟
    const [takenRows] = await connection.query(
      `SELECT id
       FROM venue_bookings
       WHERE availability_id = ?
         AND id != ?
         AND deposit_paid = 1
         AND status IN ('pending', 'confirmed', 'completed')
       LIMIT 1
       FOR UPDATE`,
      [booking.availability_id, booking_id]
    );

    if (takenRows.length > 0) {
      await connection.query(
        `UPDATE venue_bookings
         SET status = 'cancelled'
         WHERE id = ?`,
        [booking_id]
      );

      await connection.commit();
      return res.status(409).json({
        error: "This slot has already been reserved by another paid booking"
      });
    }

    const depositAmount = paymentIntent.amount / 100;

    await connection.query(
      `UPDATE venue_bookings
       SET deposit_paid = 1,
           deposit_amount = ?,
           stripe_payment_intent_id = ?
       WHERE id = ? AND client_id = ?`,
      [depositAmount, payment_intent_id, booking_id, req.user.id]
    );

    // هنا فقط نحجز الـ availability فعليًا
    await connection.query(
      `UPDATE venue_availability
       SET is_booked = 1
       WHERE id = ?`,
      [booking.availability_id]
    );

    // نلغي كل الطلبات الأخرى غير المدفوعة لنفس الموعد
    await connection.query(
      `UPDATE venue_bookings
       SET status = 'cancelled'
       WHERE availability_id = ?
         AND id != ?
         AND deposit_paid = 0
         AND status = 'pending'`,
      [booking.availability_id, booking_id]
    );

    await connection.commit();

    // بعد نجاح الحجز الفعلي فقط: إشعار لصاحب الفنيو
    await notificationModel.createNotification(
      booking.owner_id,
      "New Booking Request",
      `A client paid the deposit for ${booking.venue_name}`,
      "booking"
    );

    res.json({ message: "Deposit paid successfully" });
  } catch (err) {
    await connection.rollback();
    res.status(500).json({ error: err.message });
  } finally {
    connection.release();
  }
};

exports.refundDeposit = async (bookingId) => {
  const [rows] = await pool.query(
    "SELECT * FROM venue_bookings WHERE id = ?",
    [bookingId]
  );

  if (rows.length === 0) return;
  const booking = rows[0];

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