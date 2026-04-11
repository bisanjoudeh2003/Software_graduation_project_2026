const pool = require("../config/db");


// add availability
exports.addAvailability = async (data) => {

  const { photographer_id, date, start_time, end_time } = data;

  const [result] = await pool.query(
`INSERT INTO availability
(photographer_id,date,start_time,end_time)
VALUES (?,?,?,?)`,
  [photographer_id, date, start_time, end_time]
  );

  const [availability] = await pool.query(
    "SELECT * FROM availability WHERE id=?",
    [result.insertId]
  );

  return availability[0];
};


// get availability
exports.getAvailability = async (photographerId) => {

  const [rows] = await pool.query(
`SELECT *
FROM availability
WHERE photographer_id=?
AND is_booked=false`,
  [photographerId]
  );

  return rows;
};