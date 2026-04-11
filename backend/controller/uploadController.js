const userModel = require("../model/userModel");

exports.uploadImage = async (req,res) => {

try{

if(!req.file){

return res.status(400).json({
message:"No file uploaded"
});

}

const imageUrl = req.file.path;

const userId = req.user.id;

await userModel.updateProfileImage(
  userId,
  imageUrl
);

res.json({

image_url: imageUrl

});

}catch(error){

res.status(500).json({
error:error.message
});

}

};