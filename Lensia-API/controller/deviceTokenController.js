const pool = require("../config/db");

exports.saveToken = async (req,res)=>{

try{

const {token} = req.body;

await pool.query(
`INSERT INTO device_tokens (user_id,token)
VALUES (?,?)`,
[req.user.id,token]
);

res.json({message:"token saved"});

}catch(error){

res.status(500).json({error:error.message});

}

};