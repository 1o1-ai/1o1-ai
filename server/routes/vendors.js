const express = require("express");
const rateLimit = require("express-rate-limit");
const router = express.Router();
const pool = require("../db");

// Rate limiter: 100 req/min per IP
const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many requests, please try again later." },
});
router.use(limiter);

// ------------------------------------------------------------------
// GET /api/vendors  – list all vendors
// ------------------------------------------------------------------
router.get("/", async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT id, name, website FROM vendors ORDER BY name"
    );
    res.json(result.rows);
  } catch (err) {
    console.error("GET /vendors error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

// ------------------------------------------------------------------
// GET /api/vendors/:vendorId/models  – list models for a vendor by ID
// ------------------------------------------------------------------
router.get("/:vendorId/models", async (req, res) => {
  try {
    const { vendorId } = req.params;
    const result = await pool.query(
      `SELECT id, name, specs_json
       FROM models
       WHERE vendor_id = $1
       ORDER BY name`,
      [vendorId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error("GET /vendors/:vendorId/models error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

module.exports = router;
