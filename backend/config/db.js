const mysql = require('mysql2');

const pool = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: 'ra662003',
  database: 'lensia',
  port: 3306
});

console.log("Connected to MySQL");

module.exports = pool.promise();