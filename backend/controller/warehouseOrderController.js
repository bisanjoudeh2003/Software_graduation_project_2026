const db = require("../config/db");

function parseJsonValue(value) {
  if (!value) return null;

  if (typeof value === "object") return value;

  try {
    return JSON.parse(value);
  } catch (_) {
    return value;
  }
}

exports.getMyOrders = async (req, res) => {
  try {
    const userId = req.user.id;

    const [orders] = await db.query(
      `
      SELECT *
      FROM warehouse_orders
      WHERE client_id = ? OR photographer_id = ?
      ORDER BY id DESC
      `,
      [userId, userId]
    );

    if (orders.length === 0) {
      return res.json({
        success: true,
        orders: [],
      });
    }

    const orderIds = orders.map((o) => o.id);

    const [items] = await db.query(
      `
      SELECT
        oi.*,
        p.name,
        p.category,
        p.image_url,
        p.product_type
      FROM warehouse_order_items oi
      JOIN warehouse_products p ON oi.product_id = p.id
      WHERE oi.order_id IN (?)
      ORDER BY oi.id ASC
      `,
      [orderIds]
    );

    const map = {};

    for (const item of items) {
      if (!map[item.order_id]) {
        map[item.order_id] = [];
      }

      map[item.order_id].push({
        ...item,
        custom_details: parseJsonValue(item.custom_details),
      });
    }

    const finalOrders = orders.map((order) => ({
      ...order,
      items: map[order.id] || [],
    }));

    res.json({
      success: true,
      orders: finalOrders,
    });
  } catch (error) {
    console.error("Get my warehouse orders error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to load orders",
      error: error.message,
    });
  }
};

exports.getMyOrderById = async (req, res) => {
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

    const [items] = await db.query(
      `
      SELECT
        oi.*,
        p.name,
        p.category,
        p.image_url,
        p.product_type
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
    console.error("Get warehouse order details error:", error);

    res.status(500).json({
      success: false,
      message: "Failed to load order details",
      error: error.message,
    });
  }
};