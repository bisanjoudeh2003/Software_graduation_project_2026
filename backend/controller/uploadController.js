const userModel = require("../model/userModel");   // أضف هذا السطر

exports.uploadImage = async (req,res) => {

try{

     console.log("FILE:", req.file);      // ← أضف هاد
    console.log("USER:", req.user); 

if(!req.file){
return res.status(400).json({
message:"No file uploaded"
});
}

const imageUrl = req.file.path;   // رابط الصورة من Cloudinary

/// جلب userId من التوكن
const userId = req.user.id;

/// تحديث صورة البروفايل في جدول users
await userModel.updateProfileImage(userId, imageUrl);

res.json({

image_url: imageUrl

});

}catch(error){

res.status(500).json({
error:error.message
});

}

};
exports.uploadCoverImage = async (req, res) => {

  try {

    if (!req.file) {
      return res.status(400).json({
        message: "No file uploaded"
      });
    }

    const imageUrl = req.file.path;
    const userId = req.user.id;

    await userModel.uploadCoverImage(userId, imageUrl);

    res.json({
      cover_image: imageUrl
    });

  } catch (error) {

    res.status(500).json({
      error: error.message
    });

  }

}; 


// حذف صورة البروفايل
exports.deleteProfileImage = async (req, res) => {

  try {

    const userId = req.user.id;

    await userModel.deleteProfileImage(userId);

    res.json({
      message: "Profile image removed"
    });

  } catch (error) {

    res.status(500).json({
      error: error.message
    });

  }

};

// حذف صورة الغلاف
exports.deleteCoverImage = async (req, res) => {

  try {

    const userId = req.user.id;

    await userModel.deleteCoverImage(userId);

    res.json({
      message: "Cover image removed"
    });

  } catch (error) {

    res.status(500).json({
      error: error.message
    });

  }

};

exports.uploadPortfolioMedia = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        message: "No file uploaded"
      });
    }

    const mediaUrl = req.file.path;
    const mimeType = req.file.mimetype;
  const mediaType = mediaUrl.includes("/video/upload/") ? "video" : "image";

    console.log("FILE MIMETYPE:", mimeType);
    console.log("MEDIA URL:", mediaUrl);
    console.log("MEDIA TYPE:", mediaType);

    res.json({
      media_url: mediaUrl,
      media_type: mediaType
    });

  } catch (error) {
    res.status(500).json({
      error: error.message
    });
  }
};


