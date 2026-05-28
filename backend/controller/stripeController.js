const Stripe = require("stripe");
const stripe = Stripe(process.env.STRIPE_SECRET_KEY);

const pool = require("../config/db");
const notificationModel = require("../model/notificationModel");

/*
|--------------------------------------------------------------------------
| Helpers
|--------------------------------------------------------------------------
*/

const notifyUserSafely = async (
  userId,
  title,
  body,
  type,
  referenceType = null,
  referenceId = null
) => {
  if (!userId) return;

  try {
    await notificationModel.createNotification(
      userId,
      title,
      body,
      type,
      referenceType,
      referenceId
    );
  } catch (error) {
    console.log("Notification error:", error.message);
  }
};

const isCancelledStatus = (status) => {
  const value = status?.toString().toLowerCase();
  return value === "cancelled" || value === "canceled";
};

const isPaidStatus = (paymentStatus) => {
  return paymentStatus?.toString().toLowerCase() === "paid";
};

/*
|--------------------------------------------------------------------------
| Venue payment - Mobile PaymentIntent
|--------------------------------------------------------------------------
*/

exports.createPaymentIntent = async (req, res) => {
  try {
    const { booking_id } = req.body;

    if (!booking_id) {
      return res.status(400).json({
        error: "Booking id is required",
      });
    }

    const [rows] = await pool.query(
      `
      SELECT *
      FROM venue_bookings
      WHERE id = ?
        AND client_id = ?
      LIMIT 1
      `,
      [booking_id, req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        error: "Booking not found",
      });
    }

    const booking = rows[0];

    if (booking.status !== "pending" && booking.status !== "confirmed") {
      return res.status(400).json({
        error: "Booking is not active",
      });
    }

    if (booking.deposit_paid === 1 || booking.deposit_paid === true) {
      return res.status(400).json({
        error: "Deposit already paid",
      });
    }

    const depositAmount = Math.round(Number(booking.total_price || 0) * 0.3 * 100);

    if (!depositAmount || depositAmount <= 0) {
      return res.status(400).json({
        error: "Invalid deposit amount",
      });
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount: depositAmount,
      currency: "usd",
      metadata: {
        type: "venue_booking_deposit",
        booking_id: booking_id.toString(),
        client_id: req.user.id.toString(),
      },
    });

    return res.json({
      clientSecret: paymentIntent.client_secret,
      client_secret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
      payment_intent_id: paymentIntent.id,
      amount: depositAmount,
    });
  } catch (err) {
    console.error("Create venue payment intent error:", err);

    return res.status(500).json({
      error: err.message,
    });
  }
};

exports.confirmPayment = async (req, res) => {
  const connection = await pool.getConnection();

  try {
    const { booking_id, payment_intent_id } = req.body;

    if (!booking_id || !payment_intent_id) {
      return res.status(400).json({
        error: "Booking id and payment intent id are required",
      });
    }

    const paymentIntent = await stripe.paymentIntents.retrieve(payment_intent_id);

    if (paymentIntent.status !== "succeeded") {
      return res.status(400).json({
        error: "Payment not completed",
      });
    }

    if (paymentIntent.metadata.booking_id !== booking_id.toString()) {
      return res.status(400).json({
        error: "Invalid booking relation",
      });
    }

    if (paymentIntent.metadata.client_id !== req.user.id.toString()) {
      return res.status(403).json({
        error: "Unauthorized payment",
      });
    }

    await connection.beginTransaction();

    const [rows] = await connection.query(
      `
      SELECT
        vb.*,
        v.owner_id,
        v.name AS venue_name
      FROM venue_bookings vb
      JOIN venues v ON v.id = vb.venue_id
      WHERE vb.id = ?
        AND vb.client_id = ?
      LIMIT 1
      FOR UPDATE
      `,
      [booking_id, req.user.id]
    );

    if (rows.length === 0) {
      await connection.rollback();

      return res.status(404).json({
        error: "Booking not found",
      });
    }

    const booking = rows[0];

    if (booking.deposit_paid === 1 || booking.deposit_paid === true) {
      await connection.rollback();

      return res.status(400).json({
        error: "Deposit already paid",
      });
    }

    const [takenRows] = await connection.query(
      `
      SELECT id
      FROM venue_bookings
      WHERE availability_id = ?
        AND id != ?
        AND deposit_paid = 1
        AND status IN ('pending', 'confirmed', 'completed')
      LIMIT 1
      FOR UPDATE
      `,
      [booking.availability_id, booking_id]
    );

    if (takenRows.length > 0) {
      await connection.query(
        `
        UPDATE venue_bookings
        SET status = 'cancelled'
        WHERE id = ?
        `,
        [booking_id]
      );

      await connection.commit();

      return res.status(409).json({
        error: "This slot has already been reserved by another paid booking",
      });
    }

    const depositAmount = Number(paymentIntent.amount || 0) / 100;

    await connection.query(
      `
      UPDATE venue_bookings
      SET deposit_paid = 1,
          deposit_amount = ?,
          stripe_payment_intent_id = ?
      WHERE id = ?
        AND client_id = ?
      `,
      [depositAmount, payment_intent_id, booking_id, req.user.id]
    );

    await connection.query(
      `
      UPDATE venue_availability
      SET is_booked = 1
      WHERE id = ?
      `,
      [booking.availability_id]
    );

    await connection.query(
      `
      UPDATE venue_bookings
      SET status = 'cancelled'
      WHERE availability_id = ?
        AND id != ?
        AND deposit_paid = 0
        AND status = 'pending'
      `,
      [booking.availability_id, booking_id]
    );

    await connection.commit();

    await notifyUserSafely(
      booking.owner_id,
      "New Booking Request",
      `A client paid the deposit for ${booking.venue_name}`,
      "booking",
      "venue_booking",
      booking.id
    );

    return res.json({
      message: "Deposit paid successfully",
    });
  } catch (err) {
    await connection.rollback();

    console.error("Confirm venue payment error:", err);

    return res.status(500).json({
      error: err.message,
    });
  } finally {
    connection.release();
  }
};

exports.refundDeposit = async (bookingId) => {
  const [rows] = await pool.query(
    `
    SELECT *
    FROM venue_bookings
    WHERE id = ?
    LIMIT 1
    `,
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
    `
    UPDATE venue_bookings
    SET deposit_paid = 0,
        deposit_amount = 0
    WHERE id = ?
    `,
    [bookingId]
  );
};

/*
|--------------------------------------------------------------------------
| Warehouse order payment - PaymentIntent
|--------------------------------------------------------------------------
*/

exports.createWarehousePaymentIntent = async (req, res) => {
  try {
    const { order_id } = req.body;

    if (!order_id) {
      return res.status(400).json({
        success: false,
        message: "Order id is required",
      });
    }

    const [[order]] = await pool.query(
      `
      SELECT *
      FROM warehouse_orders
      WHERE id = ?
        AND (client_id = ? OR photographer_id = ?)
      LIMIT 1
      `,
      [order_id, req.user.id, req.user.id]
    );

    if (!order) {
      return res.status(404).json({
        success: false,
        message: "Order not found",
      });
    }

    const status = order.status?.toString().toLowerCase() || "pending";
    const paymentStatus = order.payment_status?.toString().toLowerCase() || "unpaid";

    if (isCancelledStatus(status)) {
      return res.status(400).json({
        success: false,
        message: "Cancelled orders cannot be paid",
      });
    }

    if (isPaidStatus(paymentStatus) || status === "paid") {
      return res.status(400).json({
        success: false,
        message: "Order already paid",
      });
    }

    const amount = Math.round(Number(order.total_price || 0) * 100);

    if (!amount || amount <= 0) {
      return res.status(400).json({
        success: false,
        message: "Invalid order amount",
      });
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency: "usd",
      metadata: {
        type: "warehouse_order",
        order_id: order_id.toString(),
        user_id: req.user.id.toString(),
      },
    });

    return res.json({
      success: true,
      clientSecret: paymentIntent.client_secret,
      client_secret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
      payment_intent_id: paymentIntent.id,
      amount,
    });
  } catch (err) {
    console.error("Create warehouse payment intent error:", err);

    return res.status(500).json({
      success: false,
      message: "Failed to create warehouse payment intent",
      error: err.message,
    });
  }
};

exports.confirmWarehousePayment = async (req, res) => {
  const connection = await pool.getConnection();

  try {
    const { order_id, payment_intent_id } = req.body;

    if (!order_id || !payment_intent_id) {
      return res.status(400).json({
        success: false,
        message: "Order id and payment intent id are required",
      });
    }

    const paymentIntent = await stripe.paymentIntents.retrieve(payment_intent_id);

    if (paymentIntent.status !== "succeeded") {
      return res.status(400).json({
        success: false,
        message: "Payment not completed",
      });
    }

    if (paymentIntent.metadata.order_id !== order_id.toString()) {
      return res.status(400).json({
        success: false,
        message: "Invalid order relation",
      });
    }

    if (paymentIntent.metadata.user_id !== req.user.id.toString()) {
      return res.status(403).json({
        success: false,
        message: "Unauthorized payment",
      });
    }

    await connection.beginTransaction();

    const [[order]] = await connection.query(
      `
      SELECT *
      FROM warehouse_orders
      WHERE id = ?
        AND (client_id = ? OR photographer_id = ?)
      LIMIT 1
      FOR UPDATE
      `,
      [order_id, req.user.id, req.user.id]
    );

    if (!order) {
      await connection.rollback();

      return res.status(404).json({
        success: false,
        message: "Order not found",
      });
    }

    const status = order.status?.toString().toLowerCase() || "pending";
    const paymentStatus = order.payment_status?.toString().toLowerCase() || "unpaid";

    if (isCancelledStatus(status)) {
      await connection.rollback();

      return res.status(400).json({
        success: false,
        message: "Cancelled orders cannot be paid",
      });
    }

    if (isPaidStatus(paymentStatus)) {
      await connection.rollback();

      return res.status(400).json({
        success: false,
        message: "Order already paid",
      });
    }

    await connection.query(
      `
      UPDATE warehouse_orders
      SET payment_status = 'paid',
          stripe_payment_intent_id = ?,
          paid_at = NOW(),
          status = 'pending'
      WHERE id = ?
        AND (client_id = ? OR photographer_id = ?)
      `,
      [payment_intent_id, order_id, req.user.id, req.user.id]
    );

    await connection.commit();

    await notifyUserSafely(
      order.warehouse_owner_id,
      "New Warehouse Order Payment",
      `A customer paid warehouse order #${order_id}`,
      "warehouse_order",
      "warehouse_order",
      order_id
    );

    return res.json({
      success: true,
      message: "Warehouse order paid successfully",
    });
  } catch (err) {
    await connection.rollback();

    console.error("Confirm warehouse payment error:", err);

    return res.status(500).json({
      success: false,
      message: "Failed to confirm warehouse payment",
      error: err.message,
    });
  } finally {
    connection.release();
  }
};

/*
|--------------------------------------------------------------------------
| Venue payment - Web Checkout Session
|--------------------------------------------------------------------------
*/

exports.createVenueCheckoutSession = async (req, res) => {
  try {
    const bookingId = req.params.id;
    const { success_url, cancel_url } = req.body;

    if (!bookingId) {
      return res.status(400).json({
        success: false,
        message: "Booking id is required",
      });
    }

    const [rows] = await pool.query(
      `
      SELECT
        vb.*,
        v.name AS venue_name,
        v.owner_id
      FROM venue_bookings vb
      JOIN venues v ON v.id = vb.venue_id
      WHERE vb.id = ?
        AND vb.client_id = ?
      LIMIT 1
      `,
      [bookingId, req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Booking not found",
      });
    }

    const booking = rows[0];

    if (booking.status !== "pending" && booking.status !== "confirmed") {
      return res.status(400).json({
        success: false,
        message: "Booking is not active",
      });
    }

    if (booking.deposit_paid === 1 || booking.deposit_paid === true) {
      return res.status(400).json({
        success: false,
        message: "Deposit already paid",
      });
    }

    const depositAmount = Math.round(Number(booking.total_price || 0) * 0.3 * 100);

    if (!depositAmount || depositAmount <= 0) {
      return res.status(400).json({
        success: false,
        message: "Invalid deposit amount",
      });
    }

    const appUrl = process.env.FRONTEND_URL || "http://localhost:3000";

    const successUrl =
      success_url ||
      `${appUrl}/#/client-booking-details?payment=success&booking_id=${bookingId}&session_id={CHECKOUT_SESSION_ID}`;

    const cancelUrl =
      cancel_url ||
      `${appUrl}/#/client-booking-details?payment=cancelled&booking_id=${bookingId}`;

    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      payment_method_types: ["card"],
      line_items: [
        {
          price_data: {
            currency: "usd",
            product_data: {
              name: `Venue Booking Deposit - ${booking.venue_name}`,
            },
            unit_amount: depositAmount,
          },
          quantity: 1,
        },
      ],
      metadata: {
        type: "venue_booking_deposit",
        booking_id: bookingId.toString(),
        client_id: req.user.id.toString(),
      },
      success_url: successUrl,
      cancel_url: cancelUrl,
    });

    return res.json({
      success: true,
      url: session.url,
      session_id: session.id,
    });
  } catch (err) {
    console.error("Create venue checkout session error:", err);

    return res.status(500).json({
      success: false,
      message: "Failed to create checkout session",
      error: err.message,
    });
  }
};

exports.confirmVenueCheckoutSession = async (req, res) => {
  const connection = await pool.getConnection();

  try {
    const bookingId = req.params.id;
    const { session_id } = req.body;

    if (!bookingId) {
      return res.status(400).json({
        success: false,
        message: "Booking id is required",
      });
    }

    if (!session_id) {
      return res.status(400).json({
        success: false,
        message: "Checkout session id is required",
      });
    }

    const session = await stripe.checkout.sessions.retrieve(session_id);

    if (!session || session.payment_status !== "paid") {
      return res.status(400).json({
        success: false,
        message: "Payment is not completed yet",
      });
    }

    if (session.metadata?.booking_id !== bookingId.toString()) {
      return res.status(400).json({
        success: false,
        message: "Checkout session does not match this booking",
      });
    }

    if (session.metadata?.client_id !== req.user.id.toString()) {
      return res.status(403).json({
        success: false,
        message: "Unauthorized payment",
      });
    }

    await connection.beginTransaction();

    const [rows] = await connection.query(
      `
      SELECT
        vb.*,
        v.owner_id,
        v.name AS venue_name
      FROM venue_bookings vb
      JOIN venues v ON v.id = vb.venue_id
      WHERE vb.id = ?
        AND vb.client_id = ?
      LIMIT 1
      FOR UPDATE
      `,
      [bookingId, req.user.id]
    );

    if (rows.length === 0) {
      await connection.rollback();

      return res.status(404).json({
        success: false,
        message: "Booking not found",
      });
    }

    const booking = rows[0];

    if (booking.deposit_paid === 1 || booking.deposit_paid === true) {
      await connection.rollback();

      return res.status(400).json({
        success: false,
        message: "Deposit already paid",
      });
    }

    const [takenRows] = await connection.query(
      `
      SELECT id
      FROM venue_bookings
      WHERE availability_id = ?
        AND id != ?
        AND deposit_paid = 1
        AND status IN ('pending', 'confirmed', 'completed')
      LIMIT 1
      FOR UPDATE
      `,
      [booking.availability_id, bookingId]
    );

    if (takenRows.length > 0) {
      await connection.query(
        `
        UPDATE venue_bookings
        SET status = 'cancelled'
        WHERE id = ?
        `,
        [bookingId]
      );

      await connection.commit();

      return res.status(409).json({
        success: false,
        message: "This slot has already been reserved by another paid booking",
      });
    }

    const paymentIntentId =
      typeof session.payment_intent === "string"
        ? session.payment_intent
        : session.payment_intent?.id || session.id;

    const depositAmount = Number(session.amount_total || 0) / 100;

    await connection.query(
      `
      UPDATE venue_bookings
      SET deposit_paid = 1,
          deposit_amount = ?,
          stripe_payment_intent_id = ?
      WHERE id = ?
        AND client_id = ?
      `,
      [depositAmount, paymentIntentId, bookingId, req.user.id]
    );

    await connection.query(
      `
      UPDATE venue_availability
      SET is_booked = 1
      WHERE id = ?
      `,
      [booking.availability_id]
    );

    await connection.query(
      `
      UPDATE venue_bookings
      SET status = 'cancelled'
      WHERE availability_id = ?
        AND id != ?
        AND deposit_paid = 0
        AND status = 'pending'
      `,
      [booking.availability_id, bookingId]
    );

    await connection.commit();

    await notifyUserSafely(
      booking.owner_id,
      "New Booking Request",
      `A client paid the deposit for ${booking.venue_name}`,
      "booking",
      "venue_booking",
      booking.id
    );

    return res.json({
      success: true,
      message: "Deposit paid successfully",
    });
  } catch (err) {
    await connection.rollback();

    console.error("Confirm venue checkout session error:", err);

    return res.status(500).json({
      success: false,
      message: "Failed to confirm checkout payment",
      error: err.message,
    });
  } finally {
    connection.release();
  }
};