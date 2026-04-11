const express = require("express");
const router = express.Router();
const controller = require("../controller/photographerPortfolioController");

router.get("/:photographerId", controller.getPortfolio);
router.post("/", controller.createPortfolio);
router.put("/:id", controller.updatePortfolio);

module.exports = router;