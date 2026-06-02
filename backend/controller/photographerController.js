const photographerModel = require("../model/photographerModel");
const portfolioModel = require("../model/portfolioModel");
const notificationModel = require("../model/notificationModel");

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
  if (!text || text === "null" || text === "undefined") return "";
  return text;
}

function photographerNameForNotification(user) {
  const name = cleanText(user?.full_name || user?.name);

  if (!name) return "A photographer";

  return name.length > 60 ? `${name.substring(0, 60)}...` : name;
}

exports.getNearbyPhotographers = async (req, res) => {
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

    const photographers =
      await photographerModel.getPhotographersWithCoordinates();

    const withDistance = photographers.map((p) => {
      const distance_km = getDistanceKm(
        clientLat,
        clientLng,
        parseFloat(p.latitude),
        parseFloat(p.longitude)
      );

      return {
        ...p,
        distance_km: Number(distance_km.toFixed(1)),
      };
    });

    withDistance.sort((a, b) => a.distance_km - b.distance_km);

    res.json({
      photographers: withDistance.slice(0, 5),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

exports.getMyProfile = async (req, res) => {
  try {
    const userId = req.user.id;

    const photographer = await photographerModel.getPhotographerByUserId(userId);

    if (!photographer) {
      return res.status(404).json({
        message: "You don't have a photographer profile yet",
      });
    }

    const portfolio = await portfolioModel.getPortfolioByUserId(userId);

    let completion = 0;
    let missing = [];

    if (photographer.profile_image) completion += 15;
    else missing.push("profile image");

    if (photographer.bio) completion += 15;
    else missing.push("bio");

    if (photographer.location) completion += 10;
    else missing.push("location");

    if (photographer.specialties) completion += 10;
    else missing.push("specialties");

    if (photographer.experience_years) completion += 10;
    else missing.push("experience");

    if (photographer.price_per_hour) completion += 10;
    else missing.push("price");

    if (portfolio && portfolio.length > 0) completion += 30;
    else missing.push("portfolio");

    completion = Math.min(completion, 100);

    const adminVisibility = photographer.admin_visibility || "hidden";
    const portfolioReviewed =
      photographer.portfolio_reviewed === 1 ||
      photographer.portfolio_reviewed === true ||
      photographer.portfolio_reviewed === "1";

    const adminFlagged =
      photographer.admin_flagged === 1 ||
      photographer.admin_flagged === true ||
      photographer.admin_flagged === "1";

    let reviewStatus = "under_review";

    if (adminFlagged) {
      reviewStatus = "flagged";
    } else if (portfolioReviewed && adminVisibility === "visible") {
      reviewStatus = "approved_visible";
    } else if (portfolioReviewed && adminVisibility === "hidden") {
      reviewStatus = "reviewed_hidden";
    } else {
      reviewStatus = "under_review";
    }

    res.json({
      ...photographer,
      completion,
      missing,
      admin_review_status: {
        status: reviewStatus,
        admin_visibility: adminVisibility,
        portfolio_reviewed: portfolioReviewed,
        reviewed_at: photographer.reviewed_at || null,
        admin_flagged: adminFlagged,
        admin_flag_reason: photographer.admin_flag_reason || null,
      },
    });
  } catch (err) {
    console.error("getMyProfile error:", err);
    res.status(500).json({ message: "Server error" });
  }
};

exports.createPhotographer = async (req, res) => {
  try {
    const user_id = req.user.id;

    const {
      bio,
      experience_years,
      price_per_hour,
      location,
      specialties,
      latitude,
      longitude,
    } = req.body;

    const existing = await photographerModel.getPhotographerByUserId(user_id);

    if (existing) {
      return res.status(400).json({
        message: "You already have a profile. Use update instead.",
      });
    }

    if (!location || latitude == null || longitude == null) {
      return res.status(400).json({
        message: "Location, latitude, and longitude are required",
      });
    }

    const result = await photographerModel.createPhotographer({
      user_id,
      bio,
      experience_years,
      price_per_hour,
      location,
      specialties,
      latitude,
      longitude,
    });

    try {
      await notificationModel.createNotificationForAdmins(
        "New Photographer Review",
        `${photographerNameForNotification(
          req.user
        )} created a photographer profile waiting for admin review.`,
        "admin_photographer_review",
        "photographer",
        result.insertId
      );
    } catch (notificationError) {
      console.log(
        "Admin photographer create notification error:",
        notificationError.message
      );
    }

    res.status(201).json({
      message: "Profile created successfully and is waiting for admin review.",
      photographer_id: result.insertId,
    });
  } catch (err) {
    console.error(err);

    res.status(500).json({
      message: "Server error",
    });
  }
};

exports.updatePhotographer = async (req, res) => {
  try {
    const userId = req.user.id;

    const photographer = await photographerModel.getPhotographerByUserId(userId);

    if (!photographer) {
      return res.status(404).json({
        message: "Photographer profile not found",
      });
    }

    const photographer_id = photographer.photographer_id;

    const updates = { ...req.body };

    delete updates.photographer_id;
    delete updates.user_id;
    delete updates.rating_avg;
    delete updates.rating_count;
    delete updates.admin_visibility;
    delete updates.portfolio_reviewed;
    delete updates.reviewed_at;
    delete updates.admin_flagged;
    delete updates.admin_flag_reason;

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({
        message: "No valid fields to update",
      });
    }

    await photographerModel.updatePhotographer(
      photographer_id,
      userId,
      updates
    );

    try {
      await notificationModel.createNotificationForAdmins(
        "Photographer Profile Updated",
        `${photographerNameForNotification(
          req.user
        )} updated their photographer profile and may need admin review.`,
        "admin_photographer_review",
        "photographer",
        photographer_id
      );
    } catch (notificationError) {
      console.log(
        "Admin photographer update notification error:",
        notificationError.message
      );
    }

    res.json({
      message: "Profile updated successfully",
    });
  } catch (err) {
    console.error(err);

    res.status(500).json({
      message: "Server error",
    });
  }
};

exports.getPhotographerById = async (req, res) => {
  try {
    const { id } = req.params;

    const photographer = await photographerModel.getPhotographerByUserId(id);

    if (!photographer) {
      return res.status(404).json({ message: "Photographer not found" });
    }

    res.json(photographer);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

exports.getAllPhotographers = async (req, res) => {
  try {
    const photographers = await photographerModel.getAllPhotographers();
    res.json(photographers);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

exports.getAvailablePhotographersForSession = async (req, res) => {
  try {
    const { date, time, duration_hours, session_type } = req.query;

    if (!date || !time || !duration_hours || !session_type) {
      return res.status(400).json({
        message: "date, time, duration_hours, and session_type are required",
      });
    }

    const photographers =
      await photographerModel.getAvailablePhotographersForSession({
        date,
        time,
        duration_hours: Number(duration_hours),
        session_type,
      });

    res.json({
      photographers,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({
      message: "Server error",
    });
  }
};