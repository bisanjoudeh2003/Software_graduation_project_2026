const db = require("../config/db");
const venueAvailabilityModel = require("../model/venueAvailabilityModel");

exports.addVenueAvailability = async (req, res) => {
  try {
    if (req.user.role !== "venue_owner") {
      return res.status(403).json({
        message: "Only venue owners can add venue availability",
      });
    }

    const availability = await venueAvailabilityModel.addAvailability(req.body);

    res.json(availability);
  } catch (error) {
    res.status(500).json({
      error: error.message,
    });
  }
};

exports.getVenueAvailability = async (req, res) => {
  try {
    const { venueId } = req.params;

    const availability = await venueAvailabilityModel.getAvailability(venueId);

    res.json(availability);
  } catch (error) {
    res.status(500).json({
      error: error.message,
    });
  }
};

exports.deleteAvailability = async (req, res) => {
  try {
    await venueAvailabilityModel.deleteAvailability(req.params.id);

    res.json({
      message: "deleted",
    });
  } catch (error) {
    res.status(500).json({
      error: error.message,
    });
  }
};

exports.updateAvailability = async (req, res) => {
  try {
    const { start_time, end_time } = req.body;

    await venueAvailabilityModel.updateAvailability(
      req.params.id,
      start_time,
      end_time
    );

    res.json({
      message: "updated",
    });
  } catch (error) {
    res.status(500).json({
      error: error.message,
    });
  }
};

exports.bulkAddAvailability = async (req, res) => {
  try {
    const {
      venue_id,
      start_date,
      end_date,
      days_of_week,
      start_time,
      end_time,
      exceptions = [],
    } = req.body;

    if (!req.user || req.user.role !== "venue_owner") {
      return res.status(403).json({
        error: "Only venue owners can add venue availability",
      });
    }

    if (!venue_id || !start_date || !end_date || !start_time || !end_time) {
      return res.status(400).json({
        error: "Missing required fields",
      });
    }

    if (!Array.isArray(days_of_week) || days_of_week.length === 0) {
      return res.status(400).json({
        error: "Please select at least one day",
      });
    }

    const [check] = await db.query(
      "SELECT id FROM venues WHERE id = ? AND owner_id = ? LIMIT 1",
      [venue_id, req.user.id]
    );

    if (check.length === 0) {
      return res.status(403).json({
        error: "Unauthorized",
      });
    }

    const start = new Date(start_date);
    const end = new Date(end_date);

    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      return res.status(400).json({
        error: "Invalid date range",
      });
    }

    if (start > end) {
      return res.status(400).json({
        error: "Start date must be before end date",
      });
    }

    let added = 0;
    let skipped = 0;

    const normalizedDays = days_of_week.map((d) => Number(d));
    const normalizedExceptions = Array.isArray(exceptions)
      ? exceptions.map((e) => e.toString())
      : [];

    const current = new Date(start);

    while (current <= end) {
      const dayOfWeek = current.getDay();
      const dateStr = current.toISOString().substring(0, 10);

      const isSelectedDay = normalizedDays.includes(dayOfWeek);
      const isException = normalizedExceptions.includes(dateStr);

      if (isSelectedDay && !isException) {
        const [existing] = await db.query(
          `
          SELECT id 
          FROM venue_availability
          WHERE venue_id = ?
            AND date = ?
            AND (
              (start_time < ? AND end_time > ?)
              OR
              (start_time < ? AND end_time > ?)
              OR
              (start_time >= ? AND end_time <= ?)
            )
          LIMIT 1
          `,
          [
            venue_id,
            dateStr,

            end_time,
            end_time,

            start_time,
            start_time,

            start_time,
            end_time,
          ]
        );

        if (existing.length === 0) {
          await db.query(
            `
            INSERT INTO venue_availability
            (venue_id, date, start_time, end_time, is_booked)
            VALUES (?, ?, ?, ?, 0)
            `,
            [venue_id, dateStr, start_time, end_time]
          );

          added++;
        } else {
          skipped++;
        }
      }

      current.setDate(current.getDate() + 1);
    }

    return res.json({
      message: `Done! Added ${added} slots, skipped ${skipped} conflicts or existing slots.`,
      added,
      skipped,
    });
  } catch (err) {
    console.error("Bulk add venue availability error:", err);

    return res.status(500).json({
      error: err.message,
    });
  }
};