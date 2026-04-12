const cron = require('node-cron');
const db = require('../config/db');
const notificationModel = require('../model/notificationModel');

const startReminderJob = () => {
  cron.schedule('0 * * * *', async () => {
    try {
      const [bookings] = await db.query(`
        SELECT 
          b.*,
          u.id AS client_user_id,
          u.full_name AS client_name,
          pu.id AS photographer_user_id
        FROM photographer_bookings b
        JOIN users u ON b.client_id = u.id
        JOIN photographers p ON b.photographer_id = p.photographer_id
        JOIN users pu ON p.user_id = pu.id
        WHERE b.status = 'confirmed'
          AND b.reminder_sent = 0
          AND TIMESTAMPDIFF(HOUR, NOW(), CONCAT(DATE(b.date), ' ', b.time)) BETWEEN 20 AND 26
      `);

      for (const booking of bookings) {
        await notificationModel.createNotification(
          booking.client_user_id,
          'Session Reminder ⏰',
          `Your ${booking.session_type} session is tomorrow at ${booking.time}`,
          'session_reminder'
        );
        await notificationModel.createNotification(
          booking.photographer_user_id,
          'Session Reminder ⏰',
          `You have a ${booking.session_type} session tomorrow at ${booking.time} with ${booking.client_name}`,
          'session_reminder'
        );
        await db.query(
          `UPDATE photographer_bookings SET reminder_sent = 1 WHERE id = ?`,
          [booking.id]
        );
      }

      console.log(`Reminder job ran — ${bookings.length} reminder(s) sent`);
    } catch (err) {
      console.error('Reminder job error:', err);
    }
  });
};

module.exports = { startReminderJob };