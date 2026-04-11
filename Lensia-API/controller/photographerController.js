const photographerModel = require("../model/photographerModel");

exports.getPhotographer = (req, res) => {
  const { id } = req.params;

  photographerModel.getPhotographerById(id, (err, result) => {
    if (err) return res.status(500).json(err);

    if (result.length === 0) {
      return res.json([]); // ما عنده بروفايل
    }

    res.json(result[0]);
  });
};


// إنشاء بروفايل
exports.createPhotographer = (req, res) => {
  const { user_id, bio, experience_years, price_per_hour } = req.body;

  if (!user_id) {
    return res.status(400).json({ message: "user_id is required" });
  }

  photographerModel.createPhotographer(
    { user_id, bio, experience_years, price_per_hour },
    (err, result) => {
      if (err) return res.status(500).json(err);

      res.status(201).json({
        message: "Profile created successfully",
        photographer_id: result.insertId,
      });
    }
  );
};

// تعديل بروفايل
exports.updatePhotographer = (req, res) => {
  const { id } = req.params;

  photographerModel.updatePhotographer(id, req.body, (err) => {
    if (err) return res.status(500).json(err);

    res.json({ message: "Profile updated successfully" });
  });
};

// تعديل عنصر بورتفوليو
exports.updatePortfolio = (req, res) => {
  const { id } = req.params;

  portfolioModel.updatePortfolioItem(id, req.body, (err) => {
    if (err) return res.status(500).json(err);

    res.json({ message: "Portfolio item updated successfully" });
  });
};