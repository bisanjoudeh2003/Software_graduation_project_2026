const photographerAvailabilityModel =
require("../model/photographerAvailabilityModel");


// add availability
exports.addAvailability = async (req, res) => {

  try {

    if (req.user.role !== "photographer") {
      return res.status(403).json({
        message: "Only photographers can add availability"
      });
    }

    const availability =
      await photographerAvailabilityModel.addAvailability(req.body);

    res.json(availability);

  } catch (error) {

    res.status(500).json({
      error: error.message
    });

  }

};


// get availability
exports.getAvailability = async (req, res) => {

  try {

    const { photographerId } = req.params;

    const availability =
      await photographerAvailabilityModel.getAvailability(photographerId);

    res.json(availability);

  } catch (error) {

    res.status(500).json({
      error: error.message
    });

  }

};