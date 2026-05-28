const cron = require("node-cron");
const db = require("../config/db");
const notificationModel = require("../model/notificationModel");

const REMINDER_CRON = "*/5 * * * *"; // Every 5 minutes

function formatTime(timeValue) {
  if (!timeValue) return "";

  const value = timeValue.toString();

  if (value.length >= 5) {
    return value.substring(0, 5);
  }

  return value;
}

async function wasReminderSent(bookingId, userId, reminderType) {
  const [rows] = await db.query(
    `
    SELECT id
    FROM booking_reminder_logs
    WHERE booking_id = ?
      AND user_id = ?
      AND reminder_type = ?
    LIMIT 1
    `,
    [bookingId, userId, reminderType]
  );

  return rows.length > 0;
}

async function markReminderSent(bookingId, userId, reminderType) {
  await db.query(
    `
    INSERT IGNORE INTO booking_reminder_logs
      (booking_id, user_id, reminder_type)
    VALUES (?, ?, ?)
    `,
    [bookingId, userId, reminderType]
  );
}

async function sendReminderIfNeeded({
  bookingId,
  userId,
  title,
  body,
  reminderType,
  referenceType,
}) {
  if (!userId) return false;

  const alreadySent = await wasReminderSent(
    bookingId,
    userId,
    reminderType
  );

  if (alreadySent) return false;

  await notificationModel.createNotification(
    userId,
    title,
    body,
    "session_reminder",
    referenceType,
    bookingId
  );

  await markReminderSent(
    bookingId,
    userId,
    reminderType
  );

  return true;
}

// ════════════════════════════════════════════════════════════════════
// PHOTOGRAPHER BOOKING REMINDERS
// ════════════════════════════════════════════════════════════════════

async function getPhotographerBookingsForReminder({ minMinutes, maxMinutes }) {
  const [bookings] = await db.query(
    `
    SELECT 
      b.*,

      clientUser.id AS client_user_id,
      clientUser.full_name AS client_name,

      photographerUser.id AS photographer_user_id,
      photographerUser.full_name AS photographer_name,

      venueOwnerUser.id AS venue_owner_user_id,
      venueOwnerUser.full_name AS venue_owner_name,

      v.name AS venue_name

    FROM photographer_bookings b

    JOIN users clientUser
      ON b.client_id = clientUser.id

    JOIN photographers p
      ON b.photographer_id = p.photographer_id

    JOIN users photographerUser
      ON p.user_id = photographerUser.id

    LEFT JOIN venues v
      ON b.venue_id = v.id

    LEFT JOIN users venueOwnerUser
      ON v.owner_id = venueOwnerUser.id

    WHERE LOWER(b.status) IN ('confirmed', 'accepted', 'approved', 'paid')
      AND TIMESTAMPDIFF(
        MINUTE,
        NOW(),
        CONCAT(DATE(b.date), ' ', b.time)
      ) BETWEEN ? AND ?
    `,
    [minMinutes, maxMinutes]
  );

  return bookings;
}

async function processPhotographerReminderType({
  reminderType,
  label,
  minMinutes,
  maxMinutes,
}) {
  const bookings = await getPhotographerBookingsForReminder({
    minMinutes,
    maxMinutes,
  });

  let sentCount = 0;

  for (const booking of bookings) {
    const sessionType = booking.session_type || "photography";
    const time = formatTime(booking.time);
    const clientName = booking.client_name || "client";
    const photographerName = booking.photographer_name || "photographer";
    const venueName = booking.venue_name || "the venue";

    const clientSent = await sendReminderIfNeeded({
      bookingId: booking.id,
      userId: booking.client_user_id,
      reminderType: `photographer_${reminderType}`,
      referenceType: "photographer_booking",
      title: "Session Reminder ⏰",
      body: `Your ${sessionType} session is ${label} at ${time}.`,
    });

    if (clientSent) sentCount++;

    const photographerSent = await sendReminderIfNeeded({
      bookingId: booking.id,
      userId: booking.photographer_user_id,
      reminderType: `photographer_${reminderType}`,
      referenceType: "photographer_booking",
      title: "Session Reminder ⏰",
      body: `You have a ${sessionType} session ${label} at ${time} with ${clientName}.`,
    });

    if (photographerSent) sentCount++;

    const venueOwnerSent = await sendReminderIfNeeded({
      bookingId: booking.id,
      userId: booking.venue_owner_user_id,
      reminderType: `photographer_${reminderType}`,
      referenceType: "photographer_booking",
      title: "Venue Session Reminder ⏰",
      body: `You have a photography session booking at ${venueName} ${label} at ${time} for ${clientName} and ${photographerName}.`,
    });

    if (venueOwnerSent) sentCount++;
  }

  return {
    bookingsCount: bookings.length,
    sentCount,
  };
}

// ════════════════════════════════════════════════════════════════════
// VENUE BOOKING REMINDERS
// ════════════════════════════════════════════════════════════════════

async function getVenueBookingsForReminder({ minMinutes, maxMinutes }) {
  const [bookings] = await db.query(
    `
    SELECT
      vb.*,

      clientUser.id AS client_user_id,
      clientUser.full_name AS client_name,

      venueOwnerUser.id AS venue_owner_user_id,
      venueOwnerUser.full_name AS venue_owner_name,

      v.name AS venue_name,
      v.location AS venue_location

    FROM venue_bookings vb

    JOIN users clientUser
      ON vb.client_id = clientUser.id

    JOIN venues v
      ON vb.venue_id = v.id

    JOIN users venueOwnerUser
      ON v.owner_id = venueOwnerUser.id

    WHERE LOWER(vb.status) IN ('confirmed')
      AND vb.deposit_paid = 1
      AND TIMESTAMPDIFF(
        MINUTE,
        NOW(),
        CONCAT(DATE(vb.booking_date), ' ', vb.start_time)
      ) BETWEEN ? AND ?
    `,
    [minMinutes, maxMinutes]
  );

  return bookings;
}

async function processVenueReminderType({
  reminderType,
  label,
  minMinutes,
  maxMinutes,
}) {
  const bookings = await getVenueBookingsForReminder({
    minMinutes,
    maxMinutes,
  });

  let sentCount = 0;

  for (const booking of bookings) {
    const time = formatTime(booking.start_time);
    const clientName = booking.client_name || "client";
    const venueName = booking.venue_name || "the venue";

    const clientSent = await sendReminderIfNeeded({
      bookingId: booking.id,
      userId: booking.client_user_id,
      reminderType: `venue_${reminderType}`,
      referenceType: "venue_booking",
      title: "Venue Booking Reminder ⏰",
      body: `Reminder: your booking at ${venueName} is ${label} at ${time}.`,
    });

    if (clientSent) sentCount++;

    const ownerSent = await sendReminderIfNeeded({
      bookingId: booking.id,
      userId: booking.venue_owner_user_id,
      reminderType: `venue_${reminderType}`,
      referenceType: "venue_booking",
      title: "Venue Booking Reminder ⏰",
      body: `Reminder: you have a venue booking ${label} at ${time} for ${clientName}.`,
    });

    if (ownerSent) sentCount++;
  }

  return {
    bookingsCount: bookings.length,
    sentCount,
  };
}

// ════════════════════════════════════════════════════════════════════
// MAIN CRON JOB
// ════════════════════════════════════════════════════════════════════

const startReminderJob = () => {
  cron.schedule(REMINDER_CRON, async () => {
    try {
      const photographerOneDayResult =
        await processPhotographerReminderType({
          reminderType: "one_day",
          label: "tomorrow",
          minMinutes: 23 * 60,
          maxMinutes: 25 * 60,
        });

      const photographerOneHourResult =
        await processPhotographerReminderType({
          reminderType: "one_hour",
          label: "in 1 hour",
          minMinutes: 50,
          maxMinutes: 70,
        });

      const venueOneDayResult =
        await processVenueReminderType({
          reminderType: "one_day",
          label: "tomorrow",
          minMinutes: 23 * 60,
          maxMinutes: 25 * 60,
        });

      const venueOneHourResult =
        await processVenueReminderType({
          reminderType: "one_hour",
          label: "in 1 hour",
          minMinutes: 50,
          maxMinutes: 70,
        });

      console.log(
        [
          "Reminder job ran",
          `photographer one_day: ${photographerOneDayResult.sentCount} sent / ${photographerOneDayResult.bookingsCount} bookings`,
          `photographer one_hour: ${photographerOneHourResult.sentCount} sent / ${photographerOneHourResult.bookingsCount} bookings`,
          `venue one_day: ${venueOneDayResult.sentCount} sent / ${venueOneDayResult.bookingsCount} bookings`,
          `venue one_hour: ${venueOneHourResult.sentCount} sent / ${venueOneHourResult.bookingsCount} bookings`,
        ].join(" — ")
      );
    } catch (err) {
      console.error("Reminder job error:", err);
    }
  });
};

module.exports = {
  startReminderJob,
};