const model = require("../model/portfolioItemsModel");

// GET
exports.getItems = (req, res) => {
  const { portfolioId } = req.params;

  model.getItemsByPortfolio(portfolioId, (err, result) => {
    if (err) return res.status(500).json(err);
    res.json(result);
  });
};

// POST
exports.createItem = (req, res) => {
  model.createItem(req.body, (err, result) => {
    if (err) return res.status(500).json(err);

    res.status(201).json({
      message: "Item created successfully",
      id: result.insertId,
    });
  });
};

// PUT
exports.updateItem = (req, res) => {
  const { id } = req.params;

  model.updateItem(id, req.body, (err) => {
    if (err) return res.status(500).json(err);

    res.json({ message: "Item updated successfully" });
  });
};

// DELETE
exports.deleteItem = (req, res) => {
  const { id } = req.params;

  model.deleteItem(id, (err) => {
    if (err) return res.status(500).json(err);

    res.json({ message: "Item deleted successfully" });
  });
};