const photographerModel = require("../model/photographerModel");
const portfolioModel = require("../model/portfolioModel");

exports.getMyProfile = async (req, res) => {
  try {
    const userId = req.user.id;

    const photographer = await photographerModel.getPhotographerByUserId(userId);

    if (!photographer) {
      return res.status(404).json({
        message: "You don't have a photographer profile yet"
      });
    }

    /// فحص البورتفوليو
    const portfolio = await portfolioModel.getPortfolioByUserId(userId);

    /// حساب نسبة اكتمال البروفايل
    let completion = 0;
    let missing = [];

    if (photographer.profile_image) completion += 15; else missing.push("profile image");
    if (photographer.bio) completion += 15; else missing.push("bio");
    if (photographer.location) completion += 10; else missing.push("location");
    if (photographer.specialties) completion += 10; else missing.push("specialties");
    if (photographer.experience_years) completion += 10; else missing.push("experience");
    if (photographer.price_per_hour) completion += 10; else missing.push("price");
    if (portfolio && portfolio.length > 0) completion += 30; else missing.push("portfolio");

    completion = Math.min(completion, 100);

    res.json({
      ...photographer,
      completion,
      missing
    });

  } catch (err) {
    console.error(err);
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
      specialties
    } = req.body;

    const existing =
      await photographerModel.getPhotographerByUserId(user_id);

    if (existing) {

      return res.status(400).json({
        message: "You already have a profile. Use update instead."
      });

    }

    const result =
      await photographerModel.createPhotographer({
        user_id,
        bio,
        experience_years,
        price_per_hour,
        location,
        specialties
      });

    res.status(201).json({
      message: "Profile created successfully",
      photographer_id: result.insertId
    });

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

};


exports.updatePhotographer = async (req, res) => {

  try {

    const userId = req.user.id;

    const photographer =
      await photographerModel.getPhotographerByUserId(userId);

    if (!photographer) {

      return res.status(404).json({
        message: "Photographer profile not found"
      });

    }

    const photographer_id = photographer.photographer_id;

    const updates = { ...req.body };

    delete updates.photographer_id;
    delete updates.user_id;
    delete updates.rating_avg;
    delete updates.rating_count;

    if (Object.keys(updates).length === 0) {

      return res.status(400).json({
        message: "No valid fields to update"
      });

    }

  await photographerModel.updatePhotographer(
  photographer_id,
  userId,
  updates
);

    res.json({
      message: "Profile updated successfully"
    });

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

};

