const portfolioModel = require("../model/portfolioModel");
const categoryModel = require("../model/portfolioCategoriesModel");
const albumModel = require("../model/portfolioAlbumsModel");
const itemModel = require("../model/portfolioItemsModel");
const photographerModel = require("../model/photographerModel");


/// GET MY PORTFOLIO

exports.getMyPortfolio = async (req, res) => {

  try {

    const userId = req.user.id;

    const photographer =
      await photographerModel.getPhotographerByUserId(userId);

    if (!photographer) {

      return res.status(404).json({
        message: "Photographer profile not found"
      });

    }

    const portfolio =
      await portfolioModel.getPortfolioByPhotographer(
        photographer.photographer_id
      );

    if (!portfolio) {

      return res.status(404).json({
        message: "Portfolio not created yet"
      });

    }

    res.json(portfolio);

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

};



/// CREATE PORTFOLIO

exports.createPortfolio = async (req, res) => {

  try {

    const userId = req.user.id;

    const photographer =
      await photographerModel.getPhotographerByUserId(userId);

    if (!photographer) {

      return res.status(404).json({
        message: "Photographer profile not found"
      });

    }

    const existing =
      await portfolioModel.getPortfolioByPhotographer(
        photographer.photographer_id
      );

    if (existing) {

      return res.status(400).json({
        message: "Portfolio already exists"
      });

    }

    const { title, description } = req.body;

    const result =
      await portfolioModel.createPortfolio({

        photographer_id: photographer.photographer_id,
        title,
        description

      });

    res.status(201).json({

      message: "Portfolio created",
      portfolio_id: result.insertId

    });

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

};



/// CREATE CATEGORY

exports.createCategory = async (req, res) => {

  try {

    const { portfolio_id, name } = req.body;

    const result =
      await categoryModel.createCategory({
        portfolio_id,
        name
      });

    res.status(201).json({
      message: "Category created",
      id: result.insertId
    });

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

};



/// DELETE CATEGORY
exports.deleteCategory = async (req, res) => {

  try {

    const id = req.params.id;

    const result = await categoryModel.deleteCategory(id);

    /// إذا لم يتم حذف شيء

    if (result.affectedRows === 0) {

      return res.status(404).json({
        message: "Category not found"
      });

    }

    res.json({
      message: "Category deleted successfully"
    });

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

};


/// CREATE ALBUM
exports.createAlbum = async (req, res) => {

  try {

    const { portfolio_id, category_id, title, description, cover_image } = req.body;

    /// ❌ منع التكرار
    const existingAlbums =
      await albumModel.getAlbumsByPortfolio(portfolio_id);

    const exists = existingAlbums.find(
      a => a.title.toLowerCase() === title.toLowerCase()
    );

    if (exists) {
      return res.status(400).json({
        message: "Album name already exists"
      });
    }

    /// ✅ إنشاء الألبوم مع الكفر
    const result =
      await albumModel.createAlbum({

        portfolio_id,
        category_id,
        title,
        description,
        cover_image   // 🔥 أهم سطر

      });

    res.status(201).json({
      message: "Album created",
      album_id: result.insertId
    });

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

};

/// UPDATE ALBUM

exports.updateAlbum = async (req, res) => {

  try {

    const albumId = req.params.id;

    const updates = { ...req.body };

    /// الحقول المسموحة فقط

    const allowedFields = [
      "category_id",
      "title",
      "description",
      "cover_image"
    ];

    Object.keys(updates).forEach(key => {
      if (!allowedFields.includes(key)) {
        delete updates[key];
      }
    });

    if (Object.keys(updates).length === 0) {

      return res.status(400).json({
        message: "No valid fields to update"
      });

    }

    const result = await albumModel.updateAlbum(
      albumId,
      updates
    );

    /// إذا الألبوم غير موجود

    if (result.affectedRows === 0) {

      return res.status(404).json({
        message: "Album not found"
      });

    }

    res.json({
      message: "Album updated successfully"
    });

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

};



/// DELETE ALBUM

exports.deleteAlbum = async (req, res) => {

  try {

    const albumId = req.params.id;

    const result = await albumModel.deleteAlbum(albumId);

    /// التحقق إذا الألبوم غير موجود

    if (result.affectedRows === 0) {

      return res.status(404).json({
        message: "Album not found"
      });

    }

    res.json({
      message: "Album deleted successfully"
    });

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

};


exports.addPortfolioItem = async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      portfolio_id, album_id, category_id,
      title, description, media_url, media_type
    } = req.body;

    const photographer = await photographerModel.getPhotographerByUserId(userId);
    if (!photographer) {
      return res.status(404).json({ message: "Photographer profile not found" });
    }

    const portfolio = await portfolioModel.getPortfolioById(portfolio_id);
    if (!portfolio || portfolio.photographer_id !== photographer.photographer_id) {
      return res.status(404).json({ message: "Portfolio not found" });
    }

    // ✅ تحقق من الألبوم فقط لو بعتوه
    if (album_id) {
      const album = await albumModel.getAlbumById(album_id);
      if (!album || album.portfolio_id !== portfolio_id) {
        return res.status(404).json({ message: "Album not found in this portfolio" });
      }
    }

    // ✅ تحقق من الكاتيقوري فقط لو بعتوه
    if (category_id) {
      const category = await categoryModel.getCategoryById(category_id);
      if (!category || category.portfolio_id !== portfolio_id) {
        return res.status(404).json({ message: "Category not found in this portfolio" });
      }
    }

    const result = await itemModel.createPortfolioItem({
      portfolio_id,
      album_id:    album_id    || null,
      category_id: category_id || null,
      title,
      description,
      media_url,
      media_type
    });

    res.status(201).json({
      message: "Portfolio item added successfully",
      item_id: result.insertId
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

/// SET FEATURED IMAGE
exports.setFeatured = async (req, res) => {

  try {

    const id = req.params.id;

    const item = await itemModel.getItemById(id);

    if (!item) {
      return res.status(404).json({
        message: "Portfolio item not found"
      });
    }

    if (item.is_featured) {
      return res.status(400).json({
        message: "Item is already featured"
      });
    }

    const featuredItems =
      await itemModel.getFeaturedItems(item.portfolio_id);

    const MAX_FEATURED = 6;

    if (featuredItems.length >= MAX_FEATURED) {
      return res.status(400).json({
        message: "Maximum featured items reached (6)"
      });
    }

    await itemModel.setFeatured(id);

    res.json({
      message: "Item marked as featured"
    });

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

};

/// REORDER ITEMS
exports.reorderItems = async (req, res) => {

  try {

    const { items } = req.body;

    if (!items || !Array.isArray(items)) {
      return res.status(400).json({
        message: "Items array is required"
      });
    }

    for (const item of items) {

      const existing =
        await itemModel.getItemById(item.id);

      if (!existing) {
        return res.status(404).json({
          message: `Item ${item.id} not found`
        });
      }

    }

    await itemModel.reorderItems(items);

    res.json({
      message: "Items reordered"
    });

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

};

/// DELETE PORTFOLIO ITEM

exports.deletePortfolioItem = async (req, res) => {

  try {

    const itemId = req.params.id;

    const result = await itemModel.deleteItem(itemId);

    /// التحقق إذا العنصر غير موجود

    if (result.affectedRows === 0) {

      return res.status(404).json({
        message: "Portfolio item not found"
      });

    }

    res.json({
      message: "Portfolio item deleted successfully"
    });

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

};


exports.removeFeatured = async (req, res) => {

  try {

    const id = req.params.id;

    const item = await itemModel.getItemById(id);

    if (!item) {
      return res.status(404).json({
        message: "Portfolio item not found"
      });
    }

    await itemModel.removeFeatured(id);

    res.json({
      message: "Item removed from featured"
    });

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

};


exports.getFullPortfolio = async (req, res) => {

  try {

    const portfolioId = req.params.portfolio_id;

    const portfolio =
      await portfolioModel.getPortfolioById(portfolioId);

    if (!portfolio) {
      return res.status(404).json({
        message: "Portfolio not found"
      });
    }

    const categories =
      await categoryModel.getCategoriesByPortfolio(portfolioId);


      const albums =
  await albumModel.getAlbumsWithCount(portfolioId);

    const items =
      await itemModel.getPortfolioItems(portfolioId);

    const featured =
      await itemModel.getFeaturedItems(portfolioId);

    res.json({
      portfolio,
      categories,
      albums,
      items,
      featured
    });

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

};

/// GET ITEMS BY ALBUM

exports.getItemsByAlbum = async (req, res) => {

  try {

    const albumId = req.params.id;

    const album = await albumModel.getAlbumById(albumId);

    if (!album) {
      return res.status(404).json({
        message: "Album not found"
      });
    }

    const items = await itemModel.getItemsByAlbum(albumId);

    res.json(items);

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

};



exports.updatePortfolioItem = async (req, res) => {

  try {

    const { id } = req.params;

    // 🔹 تحقق من وجود العنصر
    const item = await itemModel.getItemById(id);

    if (!item) {
      return res.status(404).json({
        message: "Portfolio item not found"
      });
    }

    // 🔹 الحقول المسموحة فقط
    const allowedFields = [
      "title",
      "description",
      "is_featured",
      "media_url",
      "media_type"
    ];

    const updates = {};

    for (let key of allowedFields) {
      if (req.body[key] !== undefined) {
        updates[key] = req.body[key];
      }
    }

    // ❌ إذا ما في ولا field
    if (Object.keys(updates).length === 0) {
      return res.status(400).json({
        message: "No valid fields provided"
      });
    }

    // 🔹 Validation
    if (
      updates.media_type &&
      !["image", "video"].includes(updates.media_type)
    ) {
      return res.status(400).json({
        message: "Invalid media type"
      });
    }

    // 🔹 التعديل
    await itemModel.updateItem(id, updates);

    res.json({
      message: "Portfolio item updated successfully"
    });

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

};


exports.getAlbumById = async (req, res) => {
  try {
    const albumId = req.params.id;

    const album = await albumModel.getAlbumById(albumId);

    if (!album) {
      return res.status(404).json({
        message: "Album not found",
      });
    }

    res.json(album);

  } catch (err) {
    console.error(err);
    res.status(500).json({
      message: "Server error",
    });
  }
};