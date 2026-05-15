const express = require("express");
const router = express.Router();

const db = require("../config/db");
const notificationModel = require("../model/notificationModel");
const authMiddleware = require("../middleware/authMiddleware");
const upload = require("../middleware/uploadMiddleware");

const warehouseOrderController = require("../controller/warehouseOrderController");
const warehouseImageController = require("../controller/warehouseImageController");
const warehouseCartController = require("../controller/warehouseCartController");

function requireWarehouseOwner(req, res, next) {
  if (!req.user || req.user.role !== "warehouse_owner") {
    return res.status(403).json({
      success: false,
      message: "Access denied. Warehouse owner only.",
    });
  }

  next();
}

function toBooleanNumber(value) {
  if (value === true || value === 1 || value === "1" || value === "true") {
    return 1;
  }

  return 0;
}

function safeJson(value) {
  if (!value) return null;

  if (typeof value === "string") {
    try {
      JSON.parse(value);
      return value;
    } catch (e) {
      return JSON.stringify({ raw: value });
    }
  }

  return JSON.stringify(value);
}

function parseJsonValue(value) {
  if (!value) return null;

  if (typeof value === "object") return value;

  try {
    return JSON.parse(value);
  } catch (_) {
    return value;
  }
}

async function attachProductImages(products) {
  if (!Array.isArray(products) || products.length === 0) {
    return [];
  }

  const productIds = products.map((p) => p.id);

  const [images] = await db.query(
    `
    SELECT product_id, image_url
    FROM warehouse_product_images
    WHERE product_id IN (?)
    ORDER BY id ASC
    `,
    [productIds]
  );

  const imagesMap = {};

  for (const image of images) {
    if (!imagesMap[image.product_id]) {
      imagesMap[image.product_id] = [];
    }

    imagesMap[image.product_id].push(image.image_url);
  }

  return products.map((product) => ({
    ...product,
    images: imagesMap[product.id] || [],
  }));
}

function getOrderReceiverId(order) {
  return order.client_id || order.photographer_id || null;
}

function statusNotification(status, orderId, ownerResponse) {
  const cleanStatus = status.toString().toLowerCase();

  if (cleanStatus === "approved") {
    return {
      title: "Warehouse Order Approved",
      message: `Your warehouse order #${orderId} has been approved.`,
    };
  }

  if (cleanStatus === "rejected") {
    return {
      title: "Warehouse Order Rejected",
      message:
        ownerResponse && ownerResponse.trim()
          ? `Your warehouse order #${orderId} was rejected. Reason: ${ownerResponse}`
          : `Your warehouse order #${orderId} was rejected.`,
    };
  }

  if (cleanStatus === "completed" || cleanStatus === "delivered") {
    return {
      title: "Warehouse Order Delivered",
      message: `Your warehouse order #${orderId} has been delivered.`,
    };
  }

  if (cleanStatus === "cancelled" || cleanStatus === "canceled") {
    return {
      title: "Warehouse Order Cancelled",
      message: `Your warehouse order #${orderId} has been cancelled by the warehouse owner.`,
    };
  }

  return {
    title: "Warehouse Order Update",
    message: `Your warehouse order #${orderId} has been updated.`,
  };
}

/*
|--------------------------------------------------------------------------
| Public routes
|--------------------------------------------------------------------------
*/

router.get("/products/public", async (req, res) => {
  try {
    const [productsRows] = await db.query(
      `
      SELECT
        p.*,
        u.full_name AS owner_name,
        u.profile_image AS owner_image
      FROM warehouse_products p
      JOIN users u ON p.warehouse_owner_id = u.id
      WHERE p.is_active = 1
        AND p.status != 'hidden'
      ORDER BY p.id DESC
      `
    );

    const products = await attachProductImages(productsRows);

    res.json({
      success: true,
      products,
    });
  } catch (error) {
    console.error("Get public warehouse products error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to load warehouse products",
      error: error.message,
    });
  }
});

/*
|--------------------------------------------------------------------------
| Auth required routes
|--------------------------------------------------------------------------
*/

router.use(authMiddleware);

/*
|--------------------------------------------------------------------------
| Cart routes
|--------------------------------------------------------------------------
*/

router.get("/cart", warehouseCartController.getCart);

router.post("/cart", warehouseCartController.addToCart);

router.put("/cart/:id", warehouseCartController.updateCartItem);

router.delete("/cart/:id", warehouseCartController.removeCartItem);

router.delete("/cart", warehouseCartController.clearCart);

router.post("/orders/from-cart", warehouseCartController.createOrdersFromCart);

/*
|--------------------------------------------------------------------------
| My orders routes
|--------------------------------------------------------------------------
*/

router.get("/my-orders", warehouseOrderController.getMyOrders);

router.get("/my-orders/:id", warehouseOrderController.getMyOrderById);

router.put("/my-orders/:id/cancel", async (req, res) => {
  try {
    const userId = req.user.id;
    const orderId = req.params.id;

    const [[order]] = await db.query(
      `
      SELECT *
      FROM warehouse_orders
      WHERE id = ?
        AND (client_id = ? OR photographer_id = ?)
      LIMIT 1
      `,
      [orderId, userId, userId]
    );

    if (!order) {
      return res.status(404).json({
        success: false,
        message: "Order not found",
      });
    }

    const status = order.status?.toString().toLowerCase() || "pending";
    const paymentStatus =
      order.payment_status?.toString().toLowerCase() || "unpaid";

    if (
      status === "approved" ||
      status === "completed" ||
      status === "delivered" ||
      paymentStatus === "paid"
    ) {
      return res.status(400).json({
        success: false,
        message: "Paid, approved, or completed orders cannot be cancelled",
      });
    }

    if (status === "cancelled" || status === "canceled") {
      return res.status(400).json({
        success: false,
        message: "Order is already cancelled",
      });
    }

    await db.query(
      `
      UPDATE warehouse_orders
      SET status = 'cancelled'
      WHERE id = ?
        AND (client_id = ? OR photographer_id = ?)
      `,
      [orderId, userId, userId]
    );

    try {
      await notificationModel.createNotification(
        order.warehouse_owner_id,
        "Warehouse Order Cancelled",
        `Order #${orderId} was cancelled by the customer.`,
        "warehouse_order"
      );
    } catch (notificationError) {
      console.log(
        "Cancel warehouse order notification error:",
        notificationError.message
      );
    }

    res.json({
      success: true,
      message: "Order cancelled successfully",
    });
  } catch (error) {
    console.error("Cancel warehouse order error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to cancel order",
      error: error.message,
    });
  }
});

router.put("/my-orders/:id/paid", async (req, res) => {
  try {
    const userId = req.user.id;
    const orderId = req.params.id;
    const { payment_intent_id } = req.body;

    if (!payment_intent_id) {
      return res.status(400).json({
        success: false,
        message: "Payment intent id is required",
      });
    }

    const [[order]] = await db.query(
      `
      SELECT *
      FROM warehouse_orders
      WHERE id = ?
        AND (client_id = ? OR photographer_id = ?)
      LIMIT 1
      `,
      [orderId, userId, userId]
    );

    if (!order) {
      return res.status(404).json({
        success: false,
        message: "Order not found",
      });
    }

    if (order.status === "cancelled" || order.status === "canceled") {
      return res.status(400).json({
        success: false,
        message: "Cancelled orders cannot be paid",
      });
    }

    await db.query(
      `
      UPDATE warehouse_orders
      SET
        payment_status = 'paid',
        stripe_payment_intent_id = ?,
        paid_at = NOW(),
        status = 'pending'
      WHERE id = ?
        AND (client_id = ? OR photographer_id = ?)
      `,
      [payment_intent_id, orderId, userId, userId]
    );

    try {
      await notificationModel.createNotification(
        order.warehouse_owner_id,
        "Warehouse Order Paid",
        `Order #${orderId} has been paid and is ready for review.`,
        "warehouse_order"
      );
    } catch (notificationError) {
      console.log(
        "Warehouse manual paid notification error:",
        notificationError.message
      );
    }

    try {
      await notificationModel.createNotification(
        userId,
        "Payment Completed",
        `Your payment for warehouse order #${orderId} was completed successfully.`,
        "warehouse_order"
      );
    } catch (notificationError) {
      console.log(
        "Customer manual paid notification error:",
        notificationError.message
      );
    }

    res.json({
      success: true,
      message: "Order marked as paid successfully",
    });
  } catch (error) {
    console.error("Mark warehouse order paid error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to update payment status",
      error: error.message,
    });
  }
});

/*
|--------------------------------------------------------------------------
| Warehouse owner only routes
|--------------------------------------------------------------------------
*/

router.use(requireWarehouseOwner);

/*
|--------------------------------------------------------------------------
| Warehouse owner received orders
|--------------------------------------------------------------------------
*/

router.get("/owner/orders", async (req, res) => {
  try {
    const ownerId = req.user.id;

    const [ordersRows] = await db.query(
      `
      SELECT
        wo.*,

        CASE
          WHEN wo.photographer_id IS NOT NULL THEN 'photographer'
          WHEN wo.client_id IS NOT NULL THEN 'client'
          ELSE 'unknown'
        END AS requester_role,

        CASE
          WHEN wo.photographer_id IS NOT NULL THEN photographer.id
          WHEN wo.client_id IS NOT NULL THEN client.id
          ELSE NULL
        END AS requester_user_id,

        CASE
          WHEN wo.photographer_id IS NOT NULL THEN photographer.full_name
          WHEN wo.client_id IS NOT NULL THEN client.full_name
          ELSE NULL
        END AS requester_name,

        CASE
          WHEN wo.photographer_id IS NOT NULL THEN photographer.email
          WHEN wo.client_id IS NOT NULL THEN client.email
          ELSE NULL
        END AS requester_email,

        CASE
          WHEN wo.photographer_id IS NOT NULL THEN photographer.profile_image
          WHEN wo.client_id IS NOT NULL THEN client.profile_image
          ELSE NULL
        END AS requester_profile_image,

        CASE
          WHEN wo.photographer_id IS NOT NULL THEN photographer.cover_image
          WHEN wo.client_id IS NOT NULL THEN client.cover_image
          ELSE NULL
        END AS requester_cover_image,

        CASE
          WHEN wo.photographer_id IS NOT NULL THEN photographer.bio
          WHEN wo.client_id IS NOT NULL THEN client.bio
          ELSE NULL
        END AS requester_bio,

        client.id AS client_user_id,
        client.full_name AS client_name,
        client.email AS client_email,
        client.profile_image AS client_profile_image,
        client.cover_image AS client_cover_image,
        client.bio AS client_bio,
        client.role AS client_role,

        photographer.id AS photographer_user_id,
        photographer.full_name AS photographer_name,
        photographer.email AS photographer_email,
        photographer.profile_image AS photographer_profile_image,
        photographer.cover_image AS photographer_cover_image,
        photographer.bio AS photographer_bio,
        photographer.role AS photographer_role

      FROM warehouse_orders wo
      LEFT JOIN users client ON wo.client_id = client.id
      LEFT JOIN users photographer ON wo.photographer_id = photographer.id
      WHERE wo.warehouse_owner_id = ?
      ORDER BY wo.id DESC
      `,
      [ownerId]
    );

    if (ordersRows.length === 0) {
      return res.json({
        success: true,
        orders: [],
      });
    }

    const orderIds = ordersRows.map((order) => order.id);

    const [itemsRows] = await db.query(
      `
      SELECT
        oi.*,
        p.name AS product_name,
        p.category,
        p.image_url,
        p.product_type,
        p.preview_type
      FROM warehouse_order_items oi
      JOIN warehouse_products p ON oi.product_id = p.id
      WHERE oi.order_id IN (?)
      ORDER BY oi.id ASC
      `,
      [orderIds]
    );

    const itemsMap = {};

    for (const item of itemsRows) {
      if (!itemsMap[item.order_id]) {
        itemsMap[item.order_id] = [];
      }

      itemsMap[item.order_id].push({
        ...item,
        custom_details: parseJsonValue(item.custom_details),
      });
    }

    const orders = ordersRows.map((order) => ({
      ...order,
      items: itemsMap[order.id] || [],
    }));

    res.json({
      success: true,
      orders,
    });
  } catch (error) {
    console.error("Get warehouse owner orders error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to load warehouse owner orders",
      error: error.message,
    });
  }
});

router.get("/owner/orders/:id", async (req, res) => {
  try {
    const ownerId = req.user.id;
    const orderId = req.params.id;

    const [[order]] = await db.query(
      `
      SELECT
        wo.*,

        CASE
          WHEN wo.photographer_id IS NOT NULL THEN 'photographer'
          WHEN wo.client_id IS NOT NULL THEN 'client'
          ELSE 'unknown'
        END AS requester_role,

        CASE
          WHEN wo.photographer_id IS NOT NULL THEN photographer.id
          WHEN wo.client_id IS NOT NULL THEN client.id
          ELSE NULL
        END AS requester_user_id,

        CASE
          WHEN wo.photographer_id IS NOT NULL THEN photographer.full_name
          WHEN wo.client_id IS NOT NULL THEN client.full_name
          ELSE NULL
        END AS requester_name,

        CASE
          WHEN wo.photographer_id IS NOT NULL THEN photographer.email
          WHEN wo.client_id IS NOT NULL THEN client.email
          ELSE NULL
        END AS requester_email,

        CASE
          WHEN wo.photographer_id IS NOT NULL THEN photographer.profile_image
          WHEN wo.client_id IS NOT NULL THEN client.profile_image
          ELSE NULL
        END AS requester_profile_image,

        CASE
          WHEN wo.photographer_id IS NOT NULL THEN photographer.cover_image
          WHEN wo.client_id IS NOT NULL THEN client.cover_image
          ELSE NULL
        END AS requester_cover_image,

        CASE
          WHEN wo.photographer_id IS NOT NULL THEN photographer.bio
          WHEN wo.client_id IS NOT NULL THEN client.bio
          ELSE NULL
        END AS requester_bio,

        client.id AS client_user_id,
        client.full_name AS client_name,
        client.email AS client_email,
        client.profile_image AS client_profile_image,
        client.cover_image AS client_cover_image,
        client.bio AS client_bio,
        client.role AS client_role,

        photographer.id AS photographer_user_id,
        photographer.full_name AS photographer_name,
        photographer.email AS photographer_email,
        photographer.profile_image AS photographer_profile_image,
        photographer.cover_image AS photographer_cover_image,
        photographer.bio AS photographer_bio,
        photographer.role AS photographer_role

      FROM warehouse_orders wo
      LEFT JOIN users client ON wo.client_id = client.id
      LEFT JOIN users photographer ON wo.photographer_id = photographer.id
      WHERE wo.id = ?
        AND wo.warehouse_owner_id = ?
      LIMIT 1
      `,
      [orderId, ownerId]
    );

    if (!order) {
      return res.status(404).json({
        success: false,
        message: "Order not found",
      });
    }

    const [items] = await db.query(
      `
      SELECT
        oi.*,
        p.name AS product_name,
        p.category,
        p.image_url,
        p.product_type,
        p.preview_type
      FROM warehouse_order_items oi
      JOIN warehouse_products p ON oi.product_id = p.id
      WHERE oi.order_id = ?
      ORDER BY oi.id ASC
      `,
      [orderId]
    );

    res.json({
      success: true,
      order: {
        ...order,
        items: items.map((item) => ({
          ...item,
          custom_details: parseJsonValue(item.custom_details),
        })),
      },
    });
  } catch (error) {
    console.error("Get warehouse owner order details error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to load order details",
      error: error.message,
    });
  }
});

router.put("/owner/orders/:id/status", async (req, res) => {
  try {
    const ownerId = req.user.id;
    const orderId = req.params.id;
    const { status, owner_response } = req.body;

    const allowedStatuses = [
      "pending",
      "approved",
      "rejected",
      "completed",
      "cancelled",
      "canceled",
      "delivered",
    ];

    if (!allowedStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: "Invalid order status",
      });
    }

    const [[order]] = await db.query(
      `
      SELECT *
      FROM warehouse_orders
      WHERE id = ?
        AND warehouse_owner_id = ?
      LIMIT 1
      `,
      [orderId, ownerId]
    );

    if (!order) {
      return res.status(404).json({
        success: false,
        message: "Order not found",
      });
    }

    const currentStatus = order.status?.toString().toLowerCase() || "pending";

    if (currentStatus === "cancelled" || currentStatus === "canceled") {
      return res.status(400).json({
        success: false,
        message: "Cancelled orders cannot be updated",
      });
    }

    await db.query(
      `
      UPDATE warehouse_orders
      SET
        status = ?,
        owner_response = ?
      WHERE id = ?
        AND warehouse_owner_id = ?
      `,
      [status, owner_response || null, orderId, ownerId]
    );

    const receiverId = getOrderReceiverId(order);

    if (receiverId) {
      const notification = statusNotification(
        status,
        orderId,
        owner_response || null
      );

      try {
        await notificationModel.createNotification(
          receiverId,
          notification.title,
          notification.message,
          "warehouse_order"
        );
      } catch (notificationError) {
        console.log(
          "Warehouse owner status notification error:",
          notificationError.message
        );
      }
    }

    res.json({
      success: true,
      message: "Order status updated successfully",
    });
  } catch (error) {
    console.error("Update warehouse owner order status error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to update order status",
      error: error.message,
    });
  }
});

/*
|--------------------------------------------------------------------------
| Product image upload
|--------------------------------------------------------------------------
*/

router.post(
  "/products/:productId/image",
  upload.single("image"),
  warehouseImageController.uploadProductImage
);

router.post(
  "/products/:productId/images",
  upload.array("images", 10),
  warehouseImageController.uploadProductImages
);

/*
|--------------------------------------------------------------------------
| Dashboard stats
|--------------------------------------------------------------------------
*/

router.get("/dashboard", async (req, res) => {
  try {
    const ownerId = req.user.id;

    const [[productStats]] = await db.query(
      `
      SELECT
        COUNT(*) AS total_products,
        SUM(CASE WHEN status = 'available' AND is_active = 1 THEN 1 ELSE 0 END) AS available_products,
        SUM(CASE WHEN product_type = 'custom' THEN 1 ELSE 0 END) AS custom_products,
        SUM(CASE WHEN allow_preview = 1 THEN 1 ELSE 0 END) AS preview_products,
        SUM(CASE WHEN stock_quantity <= 0 AND product_type = 'ready' THEN 1 ELSE 0 END) AS out_of_stock_products
      FROM warehouse_products
      WHERE warehouse_owner_id = ?
      `,
      [ownerId]
    );

    const [[orderStats]] = await db.query(
      `
      SELECT
        COUNT(*) AS total_orders,
        SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS pending_orders,
        SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) AS approved_orders,
        SUM(CASE WHEN status = 'completed' OR status = 'delivered' THEN 1 ELSE 0 END) AS completed_orders,
        SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) AS rejected_orders,
        SUM(CASE WHEN status = 'cancelled' OR status = 'canceled' THEN 1 ELSE 0 END) AS cancelled_orders,
        SUM(CASE WHEN payment_status = 'paid' THEN 1 ELSE 0 END) AS paid_orders
      FROM warehouse_orders
      WHERE warehouse_owner_id = ?
      `,
      [ownerId]
    );

    res.json({
      success: true,
      stats: {
        total_products: Number(productStats.total_products || 0),
        available_products: Number(productStats.available_products || 0),
        custom_products: Number(productStats.custom_products || 0),
        preview_products: Number(productStats.preview_products || 0),
        out_of_stock_products: Number(productStats.out_of_stock_products || 0),

        total_orders: Number(orderStats.total_orders || 0),
        pending_orders: Number(orderStats.pending_orders || 0),
        paid_orders: Number(orderStats.paid_orders || 0),
        approved_orders: Number(orderStats.approved_orders || 0),
        completed_orders: Number(orderStats.completed_orders || 0),
        rejected_orders: Number(orderStats.rejected_orders || 0),
        cancelled_orders: Number(orderStats.cancelled_orders || 0),
      },
    });
  } catch (error) {
    console.error("Warehouse dashboard error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to load dashboard",
      error: error.message,
    });
  }
});

/*
|--------------------------------------------------------------------------
| Get my products
|--------------------------------------------------------------------------
*/

router.get("/products", async (req, res) => {
  try {
    const ownerId = req.user.id;

    const [productsRows] = await db.query(
      `
      SELECT *
      FROM warehouse_products
      WHERE warehouse_owner_id = ?
        AND is_active = 1
      ORDER BY id DESC
      `,
      [ownerId]
    );

    const products = await attachProductImages(productsRows);

    res.json({
      success: true,
      products,
    });
  } catch (error) {
    console.error("Get warehouse owner products error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to get products",
      error: error.message,
    });
  }
});

/*
|--------------------------------------------------------------------------
| Add product
|--------------------------------------------------------------------------
*/

router.post("/products", async (req, res) => {
  try {
    const ownerId = req.user.id;

    const {
      store_id,
      name,
      category,
      product_type,
      preview_type,
      description,
      image_url,
      price,
      stock_quantity,
      allow_custom_text,
      allow_color_choice,
      allow_size_choice,
      allow_event_date,
      allow_reference_image,
      custom_fields,
    } = req.body;

    if (!name || !name.toString().trim()) {
      return res.status(400).json({
        success: false,
        message: "Product name is required",
      });
    }

    const cleanProductType = product_type === "custom" ? "custom" : "ready";

    const cleanPreviewType =
      cleanProductType === "custom" &&
      preview_type &&
      preview_type !== "none" &&
      preview_type !== "null"
        ? preview_type.toString().trim()
        : null;

    const cleanAllowPreview =
      cleanProductType === "custom" && cleanPreviewType ? 1 : 0;

    const cleanPrice = Number(price || 0);
    const cleanStock = Number(stock_quantity || 0);

    let status = "available";

    if (cleanStock <= 0 && cleanProductType === "ready") {
      status = "out_of_stock";
    }

    const [result] = await db.query(
      `
      INSERT INTO warehouse_products
      (
        warehouse_owner_id,
        store_id,
        name,
        category,
        product_type,
        preview_type,
        allow_preview,
        description,
        image_url,
        price,
        stock_quantity,
        allow_custom_text,
        allow_color_choice,
        allow_size_choice,
        allow_event_date,
        allow_reference_image,
        custom_fields,
        status
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
      [
        ownerId,
        store_id || null,
        name.toString().trim(),
        category || null,
        cleanProductType,
        cleanPreviewType,
        cleanAllowPreview,
        description || null,
        image_url || null,
        cleanPrice,
        cleanStock,
        toBooleanNumber(allow_custom_text),
        toBooleanNumber(allow_color_choice),
        toBooleanNumber(allow_size_choice),
        toBooleanNumber(allow_event_date),
        toBooleanNumber(allow_reference_image),
        safeJson(custom_fields),
        status,
      ]
    );

    res.status(201).json({
      success: true,
      message: "Product added successfully",
      product_id: result.insertId,
    });
  } catch (error) {
    console.error("Add warehouse product error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to add product",
      error: error.message,
    });
  }
});

/*
|--------------------------------------------------------------------------
| Update product
|--------------------------------------------------------------------------
*/

router.put("/products/:id", async (req, res) => {
  try {
    const ownerId = req.user.id;
    const productId = req.params.id;

    const [[existingProduct]] = await db.query(
      `
      SELECT *
      FROM warehouse_products
      WHERE id = ?
        AND warehouse_owner_id = ?
      LIMIT 1
      `,
      [productId, ownerId]
    );

    if (!existingProduct) {
      return res.status(404).json({
        success: false,
        message: "Product not found",
      });
    }

    const {
      name,
      category,
      product_type,
      preview_type,
      description,
      image_url,
      price,
      stock_quantity,
      allow_custom_text,
      allow_color_choice,
      allow_size_choice,
      allow_event_date,
      allow_reference_image,
      custom_fields,
      status,
    } = req.body;

    const cleanProductType =
      product_type === undefined
        ? existingProduct.product_type
        : product_type === "custom"
          ? "custom"
          : "ready";

    const cleanPreviewType =
      preview_type === undefined
        ? existingProduct.preview_type
        : cleanProductType === "custom" &&
            preview_type &&
            preview_type !== "none" &&
            preview_type !== "null"
          ? preview_type.toString().trim()
          : null;

    const cleanAllowPreview =
      cleanProductType === "custom" && cleanPreviewType ? 1 : 0;

    const cleanStock =
      stock_quantity === undefined
        ? existingProduct.stock_quantity
        : Number(stock_quantity || 0);

    let cleanStatus =
      status === undefined ? existingProduct.status : status || "available";

    if (cleanProductType === "ready" && Number(cleanStock) <= 0) {
      cleanStatus = "out_of_stock";
    }

    const [result] = await db.query(
      `
      UPDATE warehouse_products
      SET
        name = ?,
        category = ?,
        product_type = ?,
        preview_type = ?,
        allow_preview = ?,
        description = ?,
        image_url = ?,
        price = ?,
        stock_quantity = ?,
        allow_custom_text = ?,
        allow_color_choice = ?,
        allow_size_choice = ?,
        allow_event_date = ?,
        allow_reference_image = ?,
        custom_fields = ?,
        status = ?
      WHERE id = ?
        AND warehouse_owner_id = ?
      `,
      [
        name === undefined ? existingProduct.name : name,
        category === undefined ? existingProduct.category : category,
        cleanProductType,
        cleanPreviewType,
        cleanAllowPreview,
        description === undefined ? existingProduct.description : description,
        image_url === undefined ? existingProduct.image_url : image_url,
        price === undefined ? existingProduct.price : Number(price || 0),
        cleanStock,
        allow_custom_text === undefined
          ? existingProduct.allow_custom_text
          : toBooleanNumber(allow_custom_text),
        allow_color_choice === undefined
          ? existingProduct.allow_color_choice
          : toBooleanNumber(allow_color_choice),
        allow_size_choice === undefined
          ? existingProduct.allow_size_choice
          : toBooleanNumber(allow_size_choice),
        allow_event_date === undefined
          ? existingProduct.allow_event_date
          : toBooleanNumber(allow_event_date),
        allow_reference_image === undefined
          ? existingProduct.allow_reference_image
          : toBooleanNumber(allow_reference_image),
        custom_fields === undefined
          ? existingProduct.custom_fields
          : safeJson(custom_fields),
        cleanStatus,
        productId,
        ownerId,
      ]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "Product not found",
      });
    }

    res.json({
      success: true,
      message: "Product updated successfully",
    });
  } catch (error) {
    console.error("Update warehouse product error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to update product",
      error: error.message,
    });
  }
});

/*
|--------------------------------------------------------------------------
| Delete product
|--------------------------------------------------------------------------
*/

router.delete("/products/:id", async (req, res) => {
  const connection = await db.getConnection();

  try {
    const ownerId = req.user.id;
    const productId = req.params.id;

    await connection.beginTransaction();

    const [[product]] = await connection.query(
      `
      SELECT *
      FROM warehouse_products
      WHERE id = ?
        AND warehouse_owner_id = ?
      LIMIT 1
      `,
      [productId, ownerId]
    );

    if (!product) {
      await connection.rollback();

      return res.status(404).json({
        success: false,
        message: "Product not found",
      });
    }

    const [[orderUsage]] = await connection.query(
      `
      SELECT COUNT(*) AS count
      FROM warehouse_order_items
      WHERE product_id = ?
      `,
      [productId]
    );

    const usedInOrders = Number(orderUsage.count || 0) > 0;

    if (usedInOrders) {
      await connection.query(
        `
        UPDATE warehouse_products
        SET is_active = 0,
            status = 'hidden'
        WHERE id = ?
          AND warehouse_owner_id = ?
        `,
        [productId, ownerId]
      );

      await connection.commit();

      return res.json({
        success: true,
        deleted_type: "soft_delete",
        message:
          "Product has existing orders, so it was hidden instead of permanently deleted.",
      });
    }

    await connection.query(
      `
      DELETE FROM warehouse_cart_items
      WHERE product_id = ?
      `,
      [productId]
    );

    await connection.query(
      `
      DELETE FROM warehouse_product_images
      WHERE product_id = ?
      `,
      [productId]
    );

    await connection.query(
      `
      DELETE FROM warehouse_products
      WHERE id = ?
        AND warehouse_owner_id = ?
      `,
      [productId, ownerId]
    );

    await connection.commit();

    res.json({
      success: true,
      deleted_type: "hard_delete",
      message: "Product permanently deleted successfully",
    });
  } catch (error) {
    await connection.rollback();

    console.error("Delete warehouse product error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to delete product",
      error: error.message,
    });
  } finally {
    connection.release();
  }
});

module.exports = router;