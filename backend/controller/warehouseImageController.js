const db = require("../config/db");

function getUploadedFiles(req) {
  if (Array.isArray(req.files)) return req.files;
  if (req.file) return [req.file];
  return [];
}

async function verifyProductOwner(productId, ownerId) {
  const [[product]] = await db.query(
    `
    SELECT id, image_url
    FROM warehouse_products
    WHERE id = ?
      AND warehouse_owner_id = ?
      AND is_active = 1
    LIMIT 1
    `,
    [productId, ownerId]
  );

  return product || null;
}

exports.uploadProductImages = async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;
    const productId = req.params.productId;

    if (userRole !== "warehouse_owner") {
      return res.status(403).json({
        success: false,
        message: "Access denied. Warehouse owner only.",
      });
    }

    const files = getUploadedFiles(req);

    if (files.length === 0) {
      return res.status(400).json({
        success: false,
        message: "No files uploaded",
      });
    }

    const product = await verifyProductOwner(productId, userId);

    if (!product) {
      return res.status(404).json({
        success: false,
        message: "Product not found or you do not own this product",
      });
    }

    const imageUrls = files
      .map((file) => file.path || file.secure_url || file.url)
      .filter(Boolean);

    if (imageUrls.length === 0) {
      return res.status(400).json({
        success: false,
        message: "Uploaded files do not contain image URLs",
      });
    }

    for (const imageUrl of imageUrls) {
      await db.query(
        `
        INSERT INTO warehouse_product_images
        (product_id, image_url)
        VALUES (?, ?)
        `,
        [productId, imageUrl]
      );
    }

    if (!product.image_url) {
      await db.query(
        `
        UPDATE warehouse_products
        SET image_url = ?
        WHERE id = ?
          AND warehouse_owner_id = ?
        `,
        [imageUrls[0], productId, userId]
      );
    }

    res.json({
      success: true,
      message: "Product images uploaded successfully",
      images: imageUrls,
      main_image: product.image_url || imageUrls[0],
    });
  } catch (error) {
    console.error("Upload warehouse product images error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to upload product images",
      error: error.message,
    });
  }
};

exports.uploadProductImage = async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;
    const productId = req.params.productId;

    if (userRole !== "warehouse_owner") {
      return res.status(403).json({
        success: false,
        message: "Access denied. Warehouse owner only.",
      });
    }

    const files = getUploadedFiles(req);

    if (files.length === 0) {
      return res.status(400).json({
        success: false,
        message: "No file uploaded",
      });
    }

    const product = await verifyProductOwner(productId, userId);

    if (!product) {
      return res.status(404).json({
        success: false,
        message: "Product not found or you do not own this product",
      });
    }

    const imageUrl = files[0].path || files[0].secure_url || files[0].url;

    if (!imageUrl) {
      return res.status(400).json({
        success: false,
        message: "Uploaded file does not contain image URL",
      });
    }

    await db.query(
      `
      INSERT INTO warehouse_product_images
      (product_id, image_url)
      VALUES (?, ?)
      `,
      [productId, imageUrl]
    );

    await db.query(
      `
      UPDATE warehouse_products
      SET image_url = ?
      WHERE id = ?
        AND warehouse_owner_id = ?
      `,
      [imageUrl, productId, userId]
    );

    res.json({
      success: true,
      message: "Product image uploaded successfully",
      image_url: imageUrl,
    });
  } catch (error) {
    console.error("Upload warehouse product image error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to upload product image",
      error: error.message,
    });
  }
};