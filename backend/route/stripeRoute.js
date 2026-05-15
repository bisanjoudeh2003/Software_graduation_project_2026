const express = require("express");
const router = express.Router();

const auth = require("../middleware/authMiddleware");
const stripeCtrl = require("../controller/stripeController");



router.post(
  "/payments/create-intent",
  auth,
  stripeCtrl.createPaymentIntent
);

router.post(
  "/payments/confirm",
  auth,
  stripeCtrl.confirmPayment
);

/*
|--------------------------------------------------------------------------
| Warehouse payments
|--------------------------------------------------------------------------
| Main endpoints:
| POST /api/payments/create-warehouse-payment-intent
| POST /api/payments/confirm-warehouse-payment
|--------------------------------------------------------------------------
*/

router.post(
  "/payments/create-warehouse-payment-intent",
  auth,
  stripeCtrl.createWarehousePaymentIntent
);

router.post(
  "/payments/confirm-warehouse-payment",
  auth,
  stripeCtrl.confirmWarehousePayment
);


router.post(
  "/create-warehouse-payment-intent",
  auth,
  stripeCtrl.createWarehousePaymentIntent
);

router.post(
  "/confirm-warehouse-payment",
  auth,
  stripeCtrl.confirmWarehousePayment
);

module.exports = router;