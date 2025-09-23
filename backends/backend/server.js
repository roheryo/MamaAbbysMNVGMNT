// backend/server.js
require("dotenv").config();
const express = require("express");
const cors = require("cors");
const bcrypt = require("bcrypt");

const { init, all, get, run } = require("./db");
const cors = require("cors");
const app = express();
app.use(cors({ origin: true }));
app.use(cors());
app.use(express.json());

// init DB schema
init();

// Health
app.get("/health", (req, res) => res.json({ ok: true }));

/// Auth - register
app.post("/auth/register", async (req, res) => {
  try {
    const { username, email, password } = req.body || {};
    console.log("Register attempt:", { username, email }); // debug
    if (!username || !email || !password) {
      return res
        .status(400)
        .json({ error: "username, email, and password are required" });
    }

    const existing = await get(
      "SELECT id FROM users WHERE username = ? OR email = ?",
      [username, email]
    );
    if (existing)
      return res
        .status(409)
        .json({ error: "username or email already exists" });

    const password_hash = await bcrypt.hash(password, 10);
    try {
      const result = await run(
        "INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)",
        [username, email, password_hash]
      );
      const created = await get(
        "SELECT id, username, email, created_at FROM users WHERE id = ?",
        [result.id]
      );
      return res.status(201).json(created);
    } catch (e) {
      const msg = `${e.message || e}`;
      console.error("Register INSERT error:", msg);
      if (msg.includes("UNIQUE constraint failed")) {
        return res
          .status(409)
          .json({ error: "username or email already exists" });
      }
      return res.status(500).json({ error: "internal_error" });
    }
  } catch (e) {
    console.error("Register error:", e);
    return res.status(500).json({ error: "internal_error" });
  }
});
// Todos - list
app.get("/todos", async (req, res) => {
  try {
    const rows = await all(
      "SELECT id, title, done, created_at FROM todos ORDER BY id DESC"
    );
    res.json(rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Todos - get by id
app.get("/todos/:id", async (req, res) => {
  try {
    const row = await get(
      "SELECT id, title, done, created_at FROM todos WHERE id = ?",
      [req.params.id]
    );
    if (!row) return res.status(404).json({ error: "Not found" });
    res.json(row);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Todos - create
app.post("/todos", async (req, res) => {
  try {
    const { title } = req.body || {};
    if (!title) return res.status(400).json({ error: "title is required" });
    const result = await run("INSERT INTO todos (title, done) VALUES (?, 0)", [
      title,
    ]);
    const created = await get(
      "SELECT id, title, done, created_at FROM todos WHERE id = ?",
      [result.id]
    );
    res.status(201).json(created);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Todos - update
app.put("/todos/:id", async (req, res) => {
  try {
    const id = req.params.id;
    const { title, done } = req.body || {};
    const existing = await get("SELECT id FROM todos WHERE id = ?", [id]);
    if (!existing) return res.status(404).json({ error: "Not found" });

    if (title !== undefined) {
      await run("UPDATE todos SET title = ? WHERE id = ?", [title, id]);
    }
    if (done !== undefined) {
      const doneVal = done ? 1 : 0;
      await run("UPDATE todos SET done = ? WHERE id = ?", [doneVal, id]);
    }
    const updated = await get(
      "SELECT id, title, done, created_at FROM todos WHERE id = ?",
      [id]
    );
    res.json(updated);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Todos - delete
app.delete("/todos/:id", async (req, res) => {
  try {
    const result = await run("DELETE FROM todos WHERE id = ?", [req.params.id]);
    if (result.changes === 0)
      return res.status(404).json({ error: "Not found" });
    res.status(204).send();
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`API listening on http://0.0.0.0:${PORT}`);
});
