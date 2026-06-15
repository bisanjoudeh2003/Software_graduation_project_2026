const mysql = require("mysql2");

const pool = mysql.createPool({
  host: "localhost",
  port: 3306,
  user: "root",
  password: "root1234@@",
  database: "lensia_db2",
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
    dateStrings: true,
timezone: "local",
});

console.log("Connected to local MySQL");

module.exports = pool.promise();

