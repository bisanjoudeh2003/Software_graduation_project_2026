const express = require("express");
const router = express.Router();
const auth = require("../middleware/authMiddleware");
const photographerStripeCtrl = require("../controller/photographerStripeController");

router.post(
  "/ph-payments/create-intent",
  auth,
  photographerStripeCtrl.createPhotographerPaymentIntent
);

router.post(
  "/ph-payments/confirm",
  auth,
  photographerStripeCtrl.confirmPhotographerPayment
);

module.exports = router;