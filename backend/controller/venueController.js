const venueModel = require("../model/venueModel");
const pool = require("../config/db");
const notificationModel = require("../model/notificationModel");

exports.getAvailableVenuesForPhotographerBooking = async (req, res) => {
  try {
    const { date, time, duration_hours } = req.query;

    if (!date || !time || !duration_hours) {
      return res.status(400).json({
        message: "date, time, and duration_hours are required",
      });
    }

    const venues = await venueModel.getAvailableVenuesForSlot(
      date,
      time,
      duration_hours
    );

    res.json({ venues });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const toRad = (value) => (value * Math.PI) / 180;

const getDistanceKm = (lat1, lng1, lat2, lng2) => {
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
};

function cleanText(value) {
  if (value === null || value === undefined) return "";
  const text = value.toString().trim();
  if (!text || text === "null") return "";
  return text;
}

function venueNameForNotification(venue) {
  const name = cleanText(venue?.name);

  if (!name) return "New venue";

  return name.length > 60 ? `${name.substring(0, 60)}...` : name;
}

exports.getNearbyVenues = async (req, res) => {
  try {
    const { lat, lng } = req.query;

    if (!lat || !lng) {
      return res.status(400).json({
        message: "lat and lng are required",
      });
    }

    const clientLat = parseFloat(lat);
    const clientLng = parseFloat(lng);

    if (isNaN(clientLat) || isNaN(clientLng)) {
      return res.status(400).json({
        message: "Invalid lat or lng",
      });
    }

    const venues = await venueModel.getVenuesWithCoordinates();

    const withDistance = venues.map((v) => {
      const distance_km = getDistanceKm(
        clientLat,
        clientLng,
        parseFloat(v.latitude),
        parseFloat(v.longitude)
      );

      return {
        ...v,
        distance_km: Number(distance_km.toFixed(1)),
      };
    });

    withDistance.sort((a, b) => a.distance_km - b.distance_km);

    res.json({
      venues: withDistance.slice(0, 5),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

exports.createVenue = async (req, res) => {
  try {
    if (req.user.role !== "venue_owner") {
      return res.status(403).json({
        message: "Only venue owners can create venues",
      });
    }

    const data = {
      ...req.body,
      owner_id: req.user.id,
    };

    const venue = await venueModel.createVenue(data);

    try {
      await notificationModel.createNotificationForAdmins(
        "New Venue Review",
        `A new venue "${venueNameForNotification(
          venue
        )}" is waiting for admin approval.`,
        "admin_venue_review",
        "venue",
        venue.id
      );
    } catch (notificationError) {
      console.log(
        "Admin new venue review notification error:",
        notificationError.message
      );
    }

    res.json({
      success: true,
      message: "Venue submitted successfully and is waiting for admin review.",
      venue,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getOwnerVenues = async (req, res) => {
  try {
    const venues = await venueModel.getOwnerVenues(req.user.id);

    res.json(venues);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.deleteVenue = async (req, res) => {
  try {
    const venueId = req.params.id;

    await venueModel.deleteVenue(venueId);

    res.json({ message: "Venue deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getVenueDetails = async (req, res) => {
  try {
    const venueId = req.params.id;

    const venue = await venueModel.getVenueDetails(venueId);

    res.json(venue);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.searchVenues = async (req, res) => {
  try {
    const query = req.query.q;
    const ownerId = req.user.id;

    const venues = await venueModel.searchVenues(query, ownerId);

    res.json(venues);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.updateVenue = async (req, res) => {
  try {
    const {
      name,
      description,
      location,
      latitude,
      longitude,
      price_per_hour,
    } = req.body;

    await venueModel.updateVenue(
      req.params.id,
      name,
      description,
      location,
      latitude,
      longitude,
      price_per_hour
    );

    res.json({ message: "Venue updated" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.getAllVenues = async (req, res) => {
  try {
    const venues = await venueModel.getAllVenues();

    res.json(venues);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.searchAllVenues = async (req, res) => {
  try {
    const { q } = req.query;

    const venues = await venueModel.searchAllVenues(q);

    res.json(venues);
  } catch (err) {
    res.status(500).json({
      error: err.message,
    });
  }
};

exports.deleteReview = async (req, res) => {
  try {
    const [check] = await pool.query(
      `
      SELECT r.id
      FROM reviews r
      JOIN venues v ON v.id = r.venue_id
      WHERE r.id = ?
        AND v.owner_id = ?
      `,
      [req.params.id, req.user.id]
    );

    if (check.length === 0) {
      return res.status(403).json({ error: "Unauthorized" });
    }

    await pool.query("DELETE FROM reviews WHERE id = ?", [req.params.id]);

    res.json({ message: "Review deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};