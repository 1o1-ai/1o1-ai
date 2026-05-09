const { Pool } = require("pg");

const pool = new Pool({
  host:     process.env.PGHOST     || "localhost",
  port:     parseInt(process.env.PGPORT || "5432"),
  database: process.env.PGDATABASE || "manjulab_bom",
  user:     process.env.PGUSER     || "postgres",
  password: process.env.PGPASSWORD || "",
  max:      20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

pool.on("error", (err) => {
  console.error("Unexpected error on idle PostgreSQL client", err);
});

module.exports = pool;
