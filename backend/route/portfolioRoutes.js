const express = require("express");
const router = express.Router();

const portfolioController = require("../controller/portfolioController");
const authMiddleware = require("../middleware/authMiddleware");
const roleMiddleware = require("../middleware/roleMiddleware");


/// GET MY PORTFOLIO

router.get(
 "/me",
 authMiddleware,
 roleMiddleware(["photographer"]),
 portfolioController.getMyPortfolio
);


/// CREATE PORTFOLIO

router.post(
 "/",
 authMiddleware,
 roleMiddleware(["photographer"]),
 portfolioController.createPortfolio
);


/// CATEGORIES

router.post(
 "/category",
 authMiddleware,
 roleMiddleware(["photographer"]),
 portfolioController.createCategory
);

router.delete(
 "/category/:id",
 authMiddleware,
 roleMiddleware(["photographer"]),
 portfolioController.deleteCategory
);


/// ALBUMS

router.post(
 "/album",
 authMiddleware,
 roleMiddleware(["photographer"]),
 portfolioController.createAlbum
);

router.put(
 "/album/:id",
 authMiddleware,
 roleMiddleware(["photographer"]),
 portfolioController.updateAlbum
);

router.delete(
 "/album/:id",
 authMiddleware,
 roleMiddleware(["photographer"]),
 portfolioController.deleteAlbum
);


/// PORTFOLIO ITEMS (photos / videos)

router.post(
 "/item",
 authMiddleware,
 roleMiddleware(["photographer"]),
 portfolioController.addPortfolioItem
);

router.delete(
 "/item/:id",
 authMiddleware,
 roleMiddleware(["photographer"]),
 portfolioController.deletePortfolioItem
);


/// FEATURED IMAGE

router.put(
 "/item/featured/:id",
 authMiddleware,
 roleMiddleware(["photographer"]),
 portfolioController.setFeatured
);


/// REORDER IMAGES
router.put(
 "/items/reorder",
 authMiddleware,
 roleMiddleware(["photographer"]),
 portfolioController.reorderItems
);

router.put(
 "/item/unfeatured/:id",
 authMiddleware,
 roleMiddleware(["photographer"]),
 portfolioController.removeFeatured
);

router.get(
 "/full/:portfolio_id",
 portfolioController.getFullPortfolio
);

router.get(
 "/items/album/:id",
 authMiddleware,
 roleMiddleware(["photographer"]),
 portfolioController.getItemsByAlbum
);



router.put(
  "/item/:id",
  authMiddleware,
  roleMiddleware(["photographer"]),
  portfolioController.updatePortfolioItem
);

router.get(
  "/album/:id",
  authMiddleware,
  roleMiddleware(["photographer"]),
  portfolioController.getAlbumById
);



module.exports = router;