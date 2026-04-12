const cloudinary = require("cloudinary").v2;

cloudinary.config({

  cloud_name: "dulmkwpec",
  api_key: "372691244236991",
  api_secret: "uARgcZKPEYJUKqYyyTjnAyNt938"

});

module.exports = cloudinary;