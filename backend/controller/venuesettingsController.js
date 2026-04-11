const settingsModel = require("../model/venuesettingsModel");
const userModel = require("../model/userModel");

exports.getSettings = async (req,res)=>{

try{

const userId = req.user.id;

const settings = await settingsModel.getSettings(userId);

res.json(settings);

}catch(err){

res.status(500).json({error:err.message});

}

};


exports.toggleNotifications = async (req,res)=>{

try{

const userId = req.user.id;

const {enabled} = req.body;

await settingsModel.toggleNotifications(userId,enabled);

res.json({message:"Notifications updated"});

}catch(err){

res.status(500).json({error:err.message});

}

};


exports.toggleDarkMode = async (req,res)=>{

try{

const userId = req.user.id;

const {enabled} = req.body;

await settingsModel.toggleDarkMode(userId,enabled);

res.json({message:"Dark mode updated"});

}catch(err){

res.status(500).json({error:err.message});

}

};



exports.deleteAccount = async (req,res) => {

try{

const userId = req.user.id;

await userModel.deleteUser(userId);

res.json({
message:"Account deleted"
});

}catch(error){

res.status(500).json({
error:error.message
});

}

};