const pool = require("../config/db");

exports.addImage = async (venueId,imageUrl)=>{

const [result] = await pool.query(

`INSERT INTO venue_images
(venue_id,image_url)
VALUES (?,?)`,

[venueId,imageUrl]

);

const [image] = await pool.query(
"SELECT * FROM venue_images WHERE id=?",
[result.insertId]
);

return image[0];

};


/// GET IMAGES
exports.getVenueImages = async (venueId)=>{

const [rows] = await pool.query(

`SELECT * FROM venue_images
WHERE venue_id=?`,

[venueId]

);

return rows;

};


/// DELETE IMAGE
exports.deleteImage = async (id)=>{

await pool.query(

`DELETE FROM venue_images
WHERE id=?`,

[id]

);

};