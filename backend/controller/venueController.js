const venueModel = require("../model/venueModel");

exports.createVenue = async (req, res) => {

  try {

    if (req.user.role !== "venue_owner") {
      return res.status(403).json({
        message: "Only venue owners can create venues"
      });
    }

    const data = {
      ...req.body,
      owner_id: req.user.id
    };

    const venue = await venueModel.createVenue(data);

    res.json(venue);

  } catch (err) {

    res.status(500).json({ error: err.message });

  }

};

exports.getOwnerVenues = async (req, res) => {

  const venues = await venueModel.getOwnerVenues(req.user.id);

  res.json(venues);

};

exports.deleteVenue = async (req,res)=>{

  const venueId = req.params.id;

  await venueModel.deleteVenue(venueId);

  res.json({message:"Venue deleted"});

};
exports.getVenueDetails = async (req,res)=>{

  const venueId = req.params.id;

  const venue = await venueModel.getVenueDetails(venueId);

  res.json(venue);

};
exports.searchVenues = async (req,res)=>{

const query = req.query.q;
const ownerId = req.user.id;

const venues = await venueModel.searchVenues(query,ownerId);

res.json(venues);

};

exports.updateVenue = async (req, res) => {
  try {
    const { name, description, location, latitude, longitude, price_per_hour } = req.body;

    await venueModel.updateVenue(
      req.params.id,
      name,
      description,
      location,
      latitude,    // ✅ مضاف
      longitude,   // ✅ مضاف
      price_per_hour
    );

    res.json({ message: "Venue updated" });

  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
exports.getAllVenues = async (req,res)=>{

const venues = await venueModel.getAllVenues();

res.json(venues);

};
exports.searchAllVenues = async (req,res)=>{

try{

const {q} = req.query;

const venues = await venueModel.searchAllVenues(q);

res.json(venues);

}catch(err){

res.status(500).json({
error:err.message
});

}

};