const mysql = require('mysql2');

const pool = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: 'root1234@@',
  database: 'lensia_db2',
  port: 3306
});

console.log("Connected to MySQL");

module.exports = pool.promise();