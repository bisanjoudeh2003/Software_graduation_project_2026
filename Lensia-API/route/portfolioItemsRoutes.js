const express = require("express");
const router = express.Router();
const controller = require("../controller/portfolioItemsController");

router.get("/:portfolioId", controller.getItems);
router.post("/", controller.createItem);
router.put("/:id", controller.updateItem);
router.delete("/:id", controller.deleteItem);

module.exports = router;