const express = require("express");
const router = express.Router();
const photographerController = require("../controller/photographerController");

router.get("/:id", photographerController.getPhotographer);
router.post("/", photographerController.createPhotographer);
router.put("/:id", photographerController.updatePhotographer);

module.exports = router;