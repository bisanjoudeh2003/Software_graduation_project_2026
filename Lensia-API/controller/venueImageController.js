const venueImageModel = require("../model/venueImageModel");

exports.addVenueImages = async (req,res)=>{

  try{

    const venue_id = req.body.venue_id;
    const files = req.files;

    if(!files || files.length === 0){
      return res.status(400).json({message:"No images uploaded"});
    }

    const images = [];

    for(const file of files){

      const image = await venueImageModel.addImage(
        venue_id,
        file.path   // cloudinary url
      );

      images.push(image);

    }

    res.json({
      message:"Images uploaded",
      images
    });

  }catch(err){

    res.status(500).json({error:err.message});

  }

};


exports.deleteVenueImage = async (req,res)=>{

try{

const id = req.params.id;

await venueImageModel.deleteImage(id);

res.json({
message:"Image deleted"
});

}catch(err){

res.status(500).json({error:err.message});

}

};

exports.getVenueImages = async (req, res) => {
  try {
    const venueId = req.params.venueId;
    const images = await venueImageModel.getVenueImages(venueId);
    res.json(images);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};