const express = require("express");
const rateLimit = require("express-rate-limit");
const router = express.Router();
const pool = require("../db");

// Rate limiter shared by all component routes (100 req/min per IP)
const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many requests, please try again later." },
});
router.use(limiter);

// ------------------------------------------------------------------
// GET /api/components  – list all components
// ------------------------------------------------------------------
router.get("/", async (req, res) => {
  try {
    const { section, status } = req.query;
    let query = `
      SELECT id, section, component, subcomponent, vendor, model,
             specs, quantity, unit_cost, total_cost, notes, status,
             updated_at
      FROM components
    `;
    const params = [];
    const conditions = [];

    if (section) {
      params.push(section);
      conditions.push(`section = $${params.length}`);
    }
    if (status) {
      params.push(status);
      conditions.push(`status = $${params.length}`);
    }
    if (conditions.length) {
      query += " WHERE " + conditions.join(" AND ");
    }
    query += " ORDER BY section, component, id";

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error("GET /components error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

// ------------------------------------------------------------------
// POST /api/components  – create a new component
// ------------------------------------------------------------------
router.post("/", async (req, res) => {
  try {
    const {
      section,
      component,
      subcomponent = null,
      vendor = null,
      model = null,
      specs = null,
      quantity = 1,
      unit_cost = 0,
      notes = null,
      status = "Missing",
    } = req.body;

    if (!section || !component) {
      return res.status(400).json({ error: "section and component are required" });
    }

    const result = await pool.query(
      `INSERT INTO components
         (section, component, subcomponent, vendor, model, specs,
          quantity, unit_cost, notes, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING *`,
      [
        section,
        component,
        subcomponent,
        vendor,
        model,
        specs ? JSON.stringify(specs) : null,
        quantity,
        unit_cost,
        notes,
        status,
      ]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error("POST /components error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

// ------------------------------------------------------------------
// GET /api/components/summary  – section totals + grand total
// NOTE: must be defined BEFORE /:id routes so Express doesn't treat
//       the literal string "summary" as a dynamic id parameter.
// ------------------------------------------------------------------
router.get("/summary", async (_req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        section,
        COUNT(*)                        AS component_count,
        SUM(quantity)                   AS total_qty,
        SUM(total_cost)                 AS section_total
      FROM components
      GROUP BY section
      ORDER BY section
    `);
    const grand = result.rows.reduce(
      (acc, r) => acc + parseFloat(r.section_total || 0),
      0
    );
    res.json({ sections: result.rows, grand_total: grand });
  } catch (err) {
    console.error("GET /components/summary error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

// ------------------------------------------------------------------
// PUT /api/components/:id  – update a component
// ------------------------------------------------------------------
router.put("/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const {
      section,
      component,
      subcomponent,
      vendor,
      model,
      specs,
      quantity,
      unit_cost,
      notes,
      status,
    } = req.body;

    const existing = await pool.query("SELECT * FROM components WHERE id=$1", [id]);
    if (existing.rowCount === 0) {
      return res.status(404).json({ error: "Component not found" });
    }
    const cur = existing.rows[0];

    const result = await pool.query(
      `UPDATE components SET
         section      = $1,
         component    = $2,
         subcomponent = $3,
         vendor       = $4,
         model        = $5,
         specs        = $6,
         quantity     = $7,
         unit_cost    = $8,
         notes        = $9,
         status       = $10,
         updated_at   = NOW()
       WHERE id = $11
       RETURNING *`,
      [
        section      ?? cur.section,
        component    ?? cur.component,
        subcomponent ?? cur.subcomponent,
        vendor       ?? cur.vendor,
        model        ?? cur.model,
        specs        !== undefined ? JSON.stringify(specs) : cur.specs,
        quantity     ?? cur.quantity,
        unit_cost    ?? cur.unit_cost,
        notes        ?? cur.notes,
        status       ?? cur.status,
        id,
      ]
    );
    res.json(result.rows[0]);
  } catch (err) {
    console.error("PUT /components/:id error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

// ------------------------------------------------------------------
// DELETE /api/components/:id  – remove a component
// ------------------------------------------------------------------
router.delete("/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      "DELETE FROM components WHERE id=$1 RETURNING id",
      [id]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Component not found" });
    }
    res.json({ deleted: true, id: parseInt(id) });
  } catch (err) {
    console.error("DELETE /components/:id error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

module.exports = router;
