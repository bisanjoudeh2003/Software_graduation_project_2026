const model = require("../model/photographerPortfolioModel");

// GET
exports.getPortfolio = (req, res) => {
  const { photographerId } = req.params;

  model.getPortfolioByPhotographer(photographerId, (err, result) => {
    if (err) return res.status(500).json(err);

    if (result.length === 0) {
      return res.json([]);
    }

    res.json(result[0]);
  });
};

// POST
exports.createPortfolio = (req, res) => {
  model.createPortfolio(req.body, (err, result) => {
    if (err) return res.status(500).json(err);

    res.status(201).json({
      message: "Portfolio created successfully",
      id: result.insertId,
    });
  });
};

// PUT
exports.updatePortfolio = (req, res) => {
  const { id } = req.params;

  model.updatePortfolio(id, req.body, (err) => {
    if (err) return res.status(500).json(err);

    res.json({ message: "Portfolio updated successfully" });
  });
};