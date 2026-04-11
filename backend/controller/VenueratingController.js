const pool = require("../config/db");

exports.addReview = async (req,res)=>{

  const {venue_id, rating, comment} = req.body;
  const client_id = req.user.id;

  await pool.query(
    `INSERT INTO reviews (client_id,venue_id,rating,comment)
     VALUES (?,?,?,?)`,
    [client_id,venue_id,rating,comment]
  );

  await pool.query(
  `UPDATE venues
   SET rating_avg = (
     SELECT AVG(rating)
     FROM reviews
     WHERE venue_id = ?
   )
   WHERE id = ?`,
   [venue_id,venue_id]
  );

  res.json({message:"Review added"});

};