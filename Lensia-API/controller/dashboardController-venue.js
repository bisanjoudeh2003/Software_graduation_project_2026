const dashboardModel = require("../model/dashboardModel-venue");

exports.getDashboard = async (req, res) => {
  try {
    const ownerId = req.user.id;
    const data = await dashboardModel.getDashboard(ownerId);

    res.json({
      name:          data.name          ?? "",
      profile_image: data.profile_image ?? "",
      totalBookings: Number(data.totalBookings ?? 0),
      revenue:       Number(data.revenue ?? 0),
      bookings:      data.bookings ?? [],
    });

  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};