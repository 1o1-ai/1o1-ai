require("dotenv").config();
const express = require("express");
const cors = require("cors");

const componentsRouter = require("./routes/components");
const vendorsRouter = require("./routes/vendors");

const app = express();
const PORT = process.env.PORT || 4000;

// ── Middleware ────────────────────────────────────────────────────
app.use(cors({ origin: process.env.CLIENT_ORIGIN || "http://localhost:5173" }));
app.use(express.json());

// ── Routes ────────────────────────────────────────────────────────
app.use("/api/components", componentsRouter);
app.use("/api/vendors",    vendorsRouter);

// GET /api/models?vendor=  (convenience alias kept at root for the frontend)
app.get("/api/models", async (req, res) => {
  const { vendor } = req.query;
  if (!vendor) return res.status(400).json({ error: "vendor query param required" });
  const pool = require("./db");
  try {
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
    console.error("GET /api/models error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

// ── Health check ─────────────────────────────────────────────────
app.get("/api/health", (_req, res) => {
  res.json({ status: "ok", service: "bom-server", ts: new Date().toISOString() });
});

// ── 404 fallback ─────────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({ error: "Not found" });
});

// ── Start ─────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`BoM server running on http://localhost:${PORT}`);
});

module.exports = app;
