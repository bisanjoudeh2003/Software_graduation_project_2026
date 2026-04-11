const express      = require("express");
const router       = express.Router();
const auth         = require("../middleware/authMiddleware");
const stripeCtrl   = require("../controller/stripeController");

router.post("/payments/create-intent", auth, stripeCtrl.createPaymentIntent);
router.post("/payments/confirm",       auth, stripeCtrl.confirmPayment);

module.exports = router;