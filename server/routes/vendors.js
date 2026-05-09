const express = require("express");
const router = express.Router();
const pool = require("../db");

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
// GET /api/models?vendor=<vendor_name>  – list models for a vendor
// ------------------------------------------------------------------
router.get("/models", async (req, res) => {
  try {
    const { vendor } = req.query;
    if (!vendor) {
      return res.status(400).json({ error: "vendor query param is required" });
    }
    const result = await pool.query(
      `SELECT m.id, m.name, m.specs_json
       FROM models m
       JOIN vendors v ON v.id = m.vendor_id
       WHERE v.name ILIKE $1
       ORDER BY m.name`,
      [vendor]
    );
    res.json(result.rows);
  } catch (err) {
    console.error("GET /vendors/models error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

// ------------------------------------------------------------------
// GET /api/vendors/:vendorId/models  – alternative path
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
