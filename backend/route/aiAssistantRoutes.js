const express = require('express');
const router = express.Router();
const Groq = require('groq-sdk');

const db = require('../config/db');
const authMiddleware = require('../middleware/authMiddleware');

const groq = new Groq({
  apiKey: process.env.GROQ_API_KEY,
});

function getRoleContext(role) {
  if (role === 'client') {
    return `
User role: CLIENT.

Client can:
- Browse venues
- View venue details, map, reviews, and price
- Check venue availability
- Create venue bookings
- Pay 30% deposit using Stripe
- Message venue owners
- Manage favorites
- Track bookings
- Pay the remaining 70% in cash on the session day
`;
  }

  if (role === 'venue_owner') {
    return `
User role: VENUE OWNER.

Venue owner can:
- Add venues
- Edit venues
- Upload venue images
- Add availability
- Bulk add availability
- Manage bookings
- Confirm or reject pending bookings
- Cancel bookings with refund
- Mark bookings as completed after receiving the remaining cash
- Message clients
- View dashboard and reports
- Manage reviews
`;
  }

  if (role === 'photographer') {
    return `
User role: PHOTOGRAPHER.

Photographer can:
- View photographer bookings if available
- Manage photography-related work when the module is completed

Important:
Photographer features are still under development.
Do not invent features that are not implemented yet.
`;
  }

  if (role === 'warehouse_owner') {
    return `
User role: WAREHOUSE OWNER.

Warehouse owner will manage equipment stores for photographers.

Expected warehouse owner features:
- Add equipment items
- Edit equipment details
- Upload equipment images
- Set rental price
- Manage equipment availability
- Receive equipment rental bookings from photographers
- Confirm or reject equipment rental requests
- Track active and completed rentals
- Message photographers

Important:
This role is planned but not fully added to the system yet.
If the user asks about unavailable warehouse features, explain that they are still under development.
`;
  }

  return `
User role: UNKNOWN.

Explain Lensia in a general helpful way.
`;
}

const lensiaSystemPrompt = `
You are Lensia AI Assistant inside a Flutter app called Lensia.

Lensia is a venue, booking, photography, and equipment rental platform.
Frontend: Flutter.
Backend: Node.js, Express, MySQL.

Current roles:
- client
- venue_owner
- photographer
- warehouse_owner

Important venue booking flow:
1. Client books a venue.
2. Booking starts as pending.
3. Client pays 30% deposit using Stripe.
4. Venue owner confirms or rejects the booking.
5. If confirmed, client attends the session.
6. On session day, client pays the remaining 70% in cash.
7. Venue owner marks the booking as completed.
8. If client cancels, deposit is non-refundable.
9. If owner cancels, deposit refund is handled.

Answer rules:
- Always answer in English.
- Keep answers short, friendly, and practical.
- Explain exactly where the user should go in the app.
- Do not invent features that Lensia does not have.
- If something is not implemented yet, clearly say it is still under development.
- Keep the answer related to Lensia.
`;

router.get('/messages', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;

    let [sessions] = await db.query(
      'SELECT id FROM ai_chat_sessions WHERE user_id = ? ORDER BY id DESC LIMIT 1',
      [userId]
    );

    if (sessions.length === 0) {
      const [created] = await db.query(
        'INSERT INTO ai_chat_sessions (user_id) VALUES (?)',
        [userId]
      );

      sessions = [{ id: created.insertId }];
    }

    const sessionId = sessions[0].id;

    const [messages] = await db.query(
      `
      SELECT id, role, content, created_at
      FROM ai_chat_messages
      WHERE session_id = ? AND user_id = ?
      ORDER BY id ASC
      `,
      [sessionId, userId]
    );

    res.json({
      success: true,
      session_id: sessionId,
      messages,
    });
  } catch (error) {
    console.error('Get AI messages error:', error);

    res.status(500).json({
      success: false,
      message: 'Failed to get assistant messages',
    });
  }
});

router.post('/ask', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;
    const { message } = req.body;

    if (!message || !message.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Message is required',
      });
    }

    if (!process.env.GROQ_API_KEY) {
      return res.status(500).json({
        success: false,
        message: 'GROQ_API_KEY is missing in .env',
      });
    }

    let [sessions] = await db.query(
      'SELECT id FROM ai_chat_sessions WHERE user_id = ? ORDER BY id DESC LIMIT 1',
      [userId]
    );

    if (sessions.length === 0) {
      const [created] = await db.query(
        'INSERT INTO ai_chat_sessions (user_id) VALUES (?)',
        [userId]
      );

      sessions = [{ id: created.insertId }];
    }

    const sessionId = sessions[0].id;

    const cleanMessage = message.trim();

    await db.query(
      `
      INSERT INTO ai_chat_messages (session_id, user_id, role, content)
      VALUES (?, ?, 'user', ?)
      `,
      [sessionId, userId, cleanMessage]
    );

    const [historyRows] = await db.query(
      `
      SELECT role, content
      FROM ai_chat_messages
      WHERE session_id = ? AND user_id = ?
      ORDER BY id DESC
      LIMIT 10
      `,
      [sessionId, userId]
    );

    const historyMessages = historyRows
      .reverse()
      .map((item) => ({
        role: item.role === 'assistant' ? 'assistant' : 'user',
        content: item.content,
      }));

    const completion = await groq.chat.completions.create({
      model: 'llama-3.1-8b-instant',
      temperature: 0.4,
      max_tokens: 450,
      messages: [
        {
          role: 'system',
          content: `${lensiaSystemPrompt}\n\n${getRoleContext(userRole)}`,
        },
        ...historyMessages,
        {
          role: 'user',
          content: cleanMessage,
        },
      ],
    });

    const answer =
      completion.choices?.[0]?.message?.content?.trim() ||
      'Sorry, I could not generate a response right now.';

    await db.query(
      `
      INSERT INTO ai_chat_messages (session_id, user_id, role, content)
      VALUES (?, ?, 'assistant', ?)
      `,
      [sessionId, userId, answer]
    );

    res.json({
      success: true,
      answer,
    });
  } catch (error) {
    console.error('Ask Groq assistant error:', error);

    let statusCode = 500;
    let message = 'Assistant is currently unavailable';

    if (error?.status === 401) {
      statusCode = 401;
      message = 'Invalid Groq API key';
    } else if (error?.status === 429) {
      statusCode = 429;
      message = 'Groq rate limit reached. Please try again shortly.';
    } else if (error?.status === 400) {
      statusCode = 400;
      message = 'Invalid Groq request or model name';
    }

    res.status(statusCode).json({
      success: false,
      message,
    });
  }
});

router.delete('/clear', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;

    const [sessions] = await db.query(
      'SELECT id FROM ai_chat_sessions WHERE user_id = ? ORDER BY id DESC LIMIT 1',
      [userId]
    );

    if (sessions.length > 0) {
      await db.query(
        'DELETE FROM ai_chat_messages WHERE session_id = ? AND user_id = ?',
        [sessions[0].id, userId]
      );
    }

    res.json({
      success: true,
      message: 'Assistant chat cleared',
    });
  } catch (error) {
    console.error('Clear AI chat error:', error);

    res.status(500).json({
      success: false,
      message: 'Failed to clear assistant chat',
    });
  }
});

module.exports = router;