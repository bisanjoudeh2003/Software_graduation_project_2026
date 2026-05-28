const db = require("../config/db");
const userActivityLogModel = require("../model/userActivityLogModel");

function toNumber(value, fallback = 0) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function safeJson(value) {
  if (value === undefined || value === null || value === "") return null;

  if (typeof value === "string") {
    const trimmed = value.trim();

    if (!trimmed || trimmed === "null" || trimmed === "undefined") {
      return null;
    }

    try {
      JSON.parse(trimmed);
      return trimmed;
    } catch (_) {
      return JSON.stringify({ raw: trimmed });
    }
  }

  try {
    return JSON.stringify(value);
  } catch (_) {
    return JSON.stringify({ raw: value.toString() });
  }
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

const logUserActivity = async ({
  actorId,
  targetUserId,
  action,
  category = "warehouse",
  description,
  metadata = null,
}) => {
  try {
    await userActivityLogModel.logActivity({
      actorId,
      targetUserId,
      action,
      category,
      description,
      metadata,
    });
  } catch (err) {
    console.error("User activity log error:", err.message);
  }
};

async function attachImagesToCartItems(items) {
  if (!items || items.length === 0) return [];

  const productIds = items.map((item) => item.product_id);

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

  for (const img of images) {
    if (!imagesMap[img.product_id]) {
      imagesMap[img.product_id] = [];
    }

    imagesMap[img.product_id].push(img.image_url);
  }

  return items.map((item) => ({
    ...item,
    custom_details: parseJsonValue(item.custom_details),
    images: imagesMap[item.product_id] || [],
  }));
}

async function getCartRows(userId) {
  const [rows] = await db.query(
    `
    SELECT
      ci.id AS cart_item_id,
      ci.user_id,
      ci.product_id,
      ci.quantity,
      ci.custom_details,
      ci.reference_image_url,

      p.name,
      p.category,
      p.description,
      p.price,
      p.image_url,
      p.product_type,
      p.preview_type,
      p.allow_preview,
      p.stock_quantity,
      p.status,
      p.is_active,
      p.warehouse_owner_id,

      u.full_name AS owner_name
    FROM warehouse_cart_items ci
    JOIN warehouse_products p ON ci.product_id = p.id
    JOIN users u ON p.warehouse_owner_id = u.id
    WHERE ci.user_id = ?
      AND p.is_active = 1
      AND p.status != 'hidden'
    ORDER BY ci.id DESC
    `,
    [userId]
  );

  return attachImagesToCartItems(rows);
}

exports.getCart = async (req, res) => {
  try {
    const userId = req.user.id;

    const cart = await getCartRows(userId);

    const total = cart.reduce((sum, item) => {
      const price = toNumber(item.price);
      const qty = toNumber(item.quantity);
      return sum + price * qty;
    }, 0);

    const count = cart.reduce((sum, item) => {
      return sum + toNumber(item.quantity);
    }, 0);

    res.json({
      success: true,
      cart,
      count,
      total,
    });
  } catch (error) {
    console.error("Get warehouse cart error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to load cart",
      error: error.message,
    });
  }
};

exports.addToCart = async (req, res) => {
  try {
    const userId = req.user.id;

    const {
      product_id,
      quantity,
      custom_details,
      reference_image_url,
    } = req.body;

    const productId = Number(product_id);
    const qty = Math.max(1, Number(quantity || 1));

    if (!productId) {
      return res.status(400).json({
        success: false,
        message: "Product id is required",
      });
    }

    const [[product]] = await db.query(
      `
      SELECT *
      FROM warehouse_products
      WHERE id = ?
        AND is_active = 1
        AND status != 'hidden'
      LIMIT 1
      `,
      [productId]
    );

    if (!product) {
      return res.status(404).json({
        success: false,
        message: "Product not found",
      });
    }

    if (
      product.product_type === "ready" &&
      (product.status === "out_of_stock" || Number(product.stock_quantity) <= 0)
    ) {
      return res.status(400).json({
        success: false,
        message: "This product is out of stock",
      });
    }

    if (
      product.product_type === "ready" &&
      Number(product.stock_quantity) < qty
    ) {
      return res.status(400).json({
        success: false,
        message: "Not enough stock available",
      });
    }

    const customJson = safeJson(custom_details);

    if (product.product_type === "custom" && !customJson) {
      return res.status(400).json({
        success: false,
        message: "Custom details are required for custom products",
      });
    }

    if (product.product_type === "ready" && !customJson) {
      const [[existing]] = await db.query(
        `
        SELECT id, quantity
        FROM warehouse_cart_items
        WHERE user_id = ?
          AND product_id = ?
          AND custom_details IS NULL
        LIMIT 1
        `,
        [userId, productId]
      );

      if (existing) {
        const newQty = Number(existing.quantity) + qty;

        if (Number(product.stock_quantity) < newQty) {
          return res.status(400).json({
            success: false,
            message: "Not enough stock available",
          });
        }

        await db.query(
          `
          UPDATE warehouse_cart_items
          SET quantity = ?
          WHERE id = ?
          `,
          [newQty, existing.id]
        );

        return res.json({
          success: true,
          message: "Cart quantity updated",
        });
      }
    }

    await db.query(
      `
      INSERT INTO warehouse_cart_items
      (
        user_id,
        product_id,
        quantity,
        custom_details,
        reference_image_url
      )
      VALUES (?, ?, ?, ?, ?)
      `,
      [
        userId,
        productId,
        qty,
        customJson,
        reference_image_url || null,
      ]
    );

    res.status(201).json({
      success: true,
      message: "Product added to cart",
    });
  } catch (error) {
    console.error("Add warehouse cart item error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to add product to cart",
      error: error.message,
    });
  }
};

exports.updateCartItem = async (req, res) => {
  try {
    const userId = req.user.id;
    const cartItemId = req.params.id;
    const qty = Math.max(1, Number(req.body.quantity || 1));

    const [[item]] = await db.query(
      `
      SELECT
        ci.*,
        p.product_type,
        p.stock_quantity,
        p.status
      FROM warehouse_cart_items ci
      JOIN warehouse_products p ON ci.product_id = p.id
      WHERE ci.id = ?
        AND ci.user_id = ?
      LIMIT 1
      `,
      [cartItemId, userId]
    );

    if (!item) {
      return res.status(404).json({
        success: false,
        message: "Cart item not found",
      });
    }

    if (
      item.product_type === "ready" &&
      (item.status === "out_of_stock" || Number(item.stock_quantity) < qty)
    ) {
      return res.status(400).json({
        success: false,
        message: "Not enough stock available",
      });
    }

    await db.query(
      `
      UPDATE warehouse_cart_items
      SET quantity = ?
      WHERE id = ?
        AND user_id = ?
      `,
      [qty, cartItemId, userId]
    );

    res.json({
      success: true,
      message: "Cart item updated",
    });
  } catch (error) {
    console.error("Update warehouse cart item error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to update cart item",
      error: error.message,
    });
  }
};

exports.removeCartItem = async (req, res) => {
  try {
    const userId = req.user.id;
    const cartItemId = req.params.id;

    const [result] = await db.query(
      `
      DELETE FROM warehouse_cart_items
      WHERE id = ?
        AND user_id = ?
      `,
      [cartItemId, userId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "Cart item not found",
      });
    }

    res.json({
      success: true,
      message: "Cart item removed",
    });
  } catch (error) {
    console.error("Remove warehouse cart item error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to remove cart item",
      error: error.message,
    });
  }
};

exports.clearCart = async (req, res) => {
  try {
    const userId = req.user.id;

    await db.query(
      `
      DELETE FROM warehouse_cart_items
      WHERE user_id = ?
      `,
      [userId]
    );

    res.json({
      success: true,
      message: "Cart cleared",
    });
  } catch (error) {
    console.error("Clear warehouse cart error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to clear cart",
      error: error.message,
    });
  }
};

exports.createOrdersFromCart = async (req, res) => {
  const connection = await db.getConnection();

  try {
    const userId = req.user.id;

    const {
      needed_date,
      notes,
      photographer_id,
    } = req.body;

    await connection.beginTransaction();

    const [[currentUser]] = await connection.query(
      `
      SELECT id, role
      FROM users
      WHERE id = ?
      LIMIT 1
      `,
      [userId]
    );

    if (!currentUser) {
      await connection.rollback();

      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    const userRole = currentUser.role || req.user.role || "client";

    const [cartRows] = await connection.query(
      `
      SELECT
        ci.id AS cart_item_id,
        ci.product_id,
        ci.quantity,
        ci.custom_details,
        ci.reference_image_url,

        p.name,
        p.price,
        p.product_type,
        p.stock_quantity,
        p.status,
        p.warehouse_owner_id
      FROM warehouse_cart_items ci
      JOIN warehouse_products p ON ci.product_id = p.id
      WHERE ci.user_id = ?
        AND p.is_active = 1
        AND p.status != 'hidden'
      ORDER BY p.warehouse_owner_id ASC, ci.id ASC
      `,
      [userId]
    );

    if (cartRows.length === 0) {
      await connection.rollback();

      return res.status(400).json({
        success: false,
        message: "Cart is empty",
      });
    }

    for (const item of cartRows) {
      if (
        item.product_type === "ready" &&
        (item.status === "out_of_stock" ||
          Number(item.stock_quantity) < Number(item.quantity))
      ) {
        await connection.rollback();

        return res.status(400).json({
          success: false,
          message: `${item.name} does not have enough stock`,
        });
      }
    }

    const groupedByOwner = {};

    for (const item of cartRows) {
      const ownerId = item.warehouse_owner_id;

      if (!groupedByOwner[ownerId]) {
        groupedByOwner[ownerId] = [];
      }

      groupedByOwner[ownerId].push(item);
    }

    const createdOrders = [];

    for (const ownerId of Object.keys(groupedByOwner)) {
      const ownerItems = groupedByOwner[ownerId];

      const orderTotal = ownerItems.reduce((sum, item) => {
        return sum + Number(item.price || 0) * Number(item.quantity || 1);
      }, 0);

      const orderQuantity = ownerItems.reduce((sum, item) => {
        return sum + Number(item.quantity || 1);
      }, 0);

      let clientId = null;
      let photographerId = null;

      if (userRole === "photographer") {
        photographerId = userId;
        clientId = null;
      } else if (userRole === "client") {
        clientId = userId;
        photographerId = photographer_id || null;
      } else {
        clientId = userId;
        photographerId = photographer_id || null;
      }

      const [orderResult] = await connection.query(
        `
        INSERT INTO warehouse_orders
        (
          product_id,
          warehouse_owner_id,
          photographer_id,
          client_id,
          quantity,
          total_price,
          custom_details,
          reference_image_url,
          needed_date,
          status,
          payment_status,
          notes
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `,
        [
          null,
          ownerId,
          photographerId,
          clientId,
          orderQuantity,
          orderTotal,
          null,
          null,
          needed_date || null,
          "pending",
          "unpaid",
          notes || null,
        ]
      );

      const orderId = orderResult.insertId;

      createdOrders.push({
        order_id: orderId,
        warehouse_owner_id: Number(ownerId),
        items_count: ownerItems.length,
        quantity: orderQuantity,
        total_price: orderTotal,
        requester_role: userRole,
        payment_status: "unpaid",
        status: "pending",
      });

      for (const item of ownerItems) {
        const unitPrice = Number(item.price || 0);
        const qty = Number(item.quantity || 1);
        const totalPrice = unitPrice * qty;
        const itemCustomDetails = safeJson(item.custom_details);

        await connection.query(
          `
          INSERT INTO warehouse_order_items
          (
            order_id,
            product_id,
            quantity,
            unit_price,
            total_price,
            custom_details,
            reference_image_url
          )
          VALUES (?, ?, ?, ?, ?, ?, ?)
          `,
          [
            orderId,
            item.product_id,
            qty,
            unitPrice,
            totalPrice,
            itemCustomDetails,
            item.reference_image_url || null,
          ]
        );
      }
    }

    await connection.commit();

    await logUserActivity({
      actorId: userId,
      targetUserId: userId,
      action: "warehouse_order_created",
      category: "warehouse",
      description: "User created a warehouse order from cart.",
      metadata: {
        orders_count: createdOrders.length,
        orders: createdOrders.map((order) => ({
          order_id: order.order_id,
          warehouse_owner_id: order.warehouse_owner_id,
          quantity: order.quantity,
          total_price: order.total_price,
          requester_role: order.requester_role,
          payment_status: order.payment_status,
          status: order.status,
        })),
      },
    });

    res.status(201).json({
      success: true,
      message:
        createdOrders.length === 1
          ? "Order created successfully. Please complete payment."
          : "Orders created successfully. Please complete payment.",
      orders: createdOrders,
    });
  } catch (error) {
    await connection.rollback();

    console.error("Create warehouse order from cart error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to create order from cart",
      error: error.message,
    });
  } finally {
    connection.release();
  }
};