const notificationModel =
require("../model/venueNotificationModel");

const pool = require("../config/db");
const admin = require("../config/firebase");

exports.getNotifications = async (req,res)=>{

try{

const notifications =
await notificationModel.getNotifications(req.user.id);

res.json(notifications);

}catch(error){

res.status(500).json({error:error.message});

}

};

exports.markRead = async (req,res)=>{

try{

await notificationModel.markRead(req.params.id);

res.json({message:"marked read"});

}catch(error){

res.status(500).json({error:error.message});

}

};

exports.sendNotification = async (data)=>{

const {userId,title,message,type} = data;

const notification =
await notificationModel.createNotification({
venue_owner_id:userId,
title,
message,
type
});

const [tokens] = await pool.query(
"SELECT token FROM device_tokens WHERE user_id=?",
[userId]
);

for(let t of tokens){

await admin.messaging().send({

token:t.token,

notification:{
title,
body:message
},

data:{
type:type,
notificationId:String(notification.id)
}

});

}

};

exports.sendNotification = async (data)=>{

const {userId,title,message,type} = data;

const notification =
await notificationModel.createNotification({
venue_owner_id:userId,
title,
message,
type
});

/// REALTIME
if(global.io){
global.io.emit("notification",notification);
}

/// PUSH
const [tokens] = await pool.query(
"SELECT token FROM device_tokens WHERE user_id=?",
[userId]
);

for(let t of tokens){

await admin.messaging().send({

token:t.token,

notification:{
title:title,
body:message
},

data:{
type:type,
notificationId:String(notification.id)
}

});

}

};