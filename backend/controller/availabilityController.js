const availabilityModel = require("../model/availabilityModel");
const photographerModel = require("../model/photographerModel");

// helper: نجيب photographer_id من التوكن
const getPhotographerId = async (userId) => {
  const photographer = await photographerModel.getPhotographerByUserId(userId);
  if (!photographer) throw new Error("PHOTOGRAPHER_NOT_FOUND");
  return photographer.photographer_id;
};

// ── Weekly Schedule ──────────────────────────────────────────────

// في availabilityController.js
exports.getMySchedule = async (req, res) => {
  try {
    const photographerId = await getPhotographerId(req.user.id);

    const schedule = await availabilityModel.getWeeklySchedule(photographerId);
    const blocked  = await availabilityModel.getBlockedSlots(photographerId);  // ← أضف هاد

    res.json({ schedule, blocked });  // ← رجّع الاثنين مع بعض
  } catch (err) {
    if (err.message === "PHOTOGRAPHER_NOT_FOUND")
      return res.status(404).json({ message: "Photographer profile not found" });
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};
exports.upsertWeeklyDay = async (req, res) => {
  try {
    const photographerId = await getPhotographerId(req.user.id);
    const { day_of_week, start_time, end_time } = req.body;

    if (day_of_week === undefined || day_of_week === null || !start_time || !end_time)
      return res.status(400).json({ message: "day_of_week, start_time, end_time are required" });

    if (day_of_week < 0 || day_of_week > 6)
      return res.status(400).json({ message: "day_of_week must be 0-6" });

    await availabilityModel.upsertWeeklyDay(photographerId, day_of_week, start_time, end_time);
    res.json({ message: "Schedule updated successfully" });
  } catch (err) {
    if (err.message === "PHOTOGRAPHER_NOT_FOUND")
      return res.status(404).json({ message: "Photographer profile not found" });
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

exports.deleteWeeklyDay = async (req, res) => {
  try {
    const photographerId = await getPhotographerId(req.user.id);
    const { day_of_week } = req.params;
    await availabilityModel.deleteWeeklyDay(photographerId, day_of_week);
    res.json({ message: "Day removed from schedule" });
  } catch (err) {
    if (err.message === "PHOTOGRAPHER_NOT_FOUND")
      return res.status(404).json({ message: "Photographer profile not found" });
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

// ── Blocked Slots ────────────────────────────────────────────────

exports.getMyBlockedSlots = async (req, res) => {
  try {
    const photographerId = await getPhotographerId(req.user.id);
    const blocked = await availabilityModel.getBlockedSlots(photographerId);
    res.json({ blocked });
  } catch (err) {
    if (err.message === "PHOTOGRAPHER_NOT_FOUND")
      return res.status(404).json({ message: "Photographer profile not found" });
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

exports.addBlockedSlot = async (req, res) => {
  try {
    const photographerId = await getPhotographerId(req.user.id);
    const { blocked_date, start_time, end_time, reason } = req.body;

    if (!blocked_date)
      return res.status(400).json({ message: "blocked_date is required" });

    // لو بعث start بدون end أو العكس
    if ((start_time && !end_time) || (!start_time && end_time))
      return res.status(400).json({ message: "Provide both start_time and end_time or neither" });

    const result = await availabilityModel.addBlockedSlot(
      photographerId, blocked_date, start_time, end_time, reason
    );

    res.status(201).json({
      message: "Slot blocked successfully",
      id: result.insertId
    });
  } catch (err) {
    if (err.message === "PHOTOGRAPHER_NOT_FOUND")
      return res.status(404).json({ message: "Photographer profile not found" });
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

exports.deleteBlockedSlot = async (req, res) => {
  try {
    const photographerId = await getPhotographerId(req.user.id);
    const { id } = req.params;
    const result = await availabilityModel.deleteBlockedSlot(photographerId, id);

    if (result.affectedRows === 0)
      return res.status(404).json({ message: "Slot not found" });

    res.json({ message: "Slot removed successfully" });
  } catch (err) {
    if (err.message === "PHOTOGRAPHER_NOT_FOUND")
      return res.status(404).json({ message: "Photographer profile not found" });
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

// ── Public ───────────────────────────────────────────────────────

exports.getPublicAvailability = async (req, res) => {
  try {
    const { photographerId } = req.params;

    // ← تحقق إنو المصور موجود
    const exists = await availabilityModel.checkPhotographerExists(photographerId);
    if (!exists)
      return res.status(404).json({ message: "Photographer not found" });

    const data = await availabilityModel.getPublicAvailability(photographerId);
    res.json(data);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};