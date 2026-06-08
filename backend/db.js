const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');

const dbPath = path.join(__dirname, process.env.DATABASE_FILE || 'downloads.db');

// Ensure database parent directories exist
const dbDir = path.dirname(dbPath);
if (!fs.existsSync(dbDir)) {
  fs.mkdirSync(dbDir, { recursive: true });
}

let initPromise;

const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Error opening database:', err.message);
  } else {
    console.log('Connected to SQLite database at:', dbPath);
  }
});

function initializeDb() {
  if (initPromise) return initPromise;
  
  initPromise = new Promise((resolve, reject) => {
    db.run(`
      CREATE TABLE IF NOT EXISTS downloads (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        progress REAL DEFAULT 0.0,
        speed REAL DEFAULT 0.0,
        status TEXT DEFAULT 'pending',
        eta TEXT,
        downloadedBytes INTEGER DEFAULT 0,
        totalBytes INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    `, (err) => {
      if (err) {
        console.error('Error creating downloads table:', err.message);
        reject(err);
      } else {
        console.log('Database table initialized successfully.');
        // Reset any active downloads to paused/failed on server restart
        db.run("UPDATE downloads SET status = 'paused', speed = 0 WHERE status = 'downloading' OR status = 'pending'", (err2) => {
          if (err2) reject(err2);
          else resolve();
        });
      }
    });
  });
  
  return initPromise;
}

function run(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function (err) {
      if (err) {
        reject(err);
      } else {
        resolve({ lastID: this.lastID, changes: this.changes });
      }
    });
  });
}

function get(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.get(sql, params, (err, row) => {
      if (err) {
        reject(err);
      } else {
        resolve(row);
      }
    });
  });
}

function all(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => {
      if (err) {
        reject(err);
      } else {
        resolve(rows);
      }
    });
  });
}

module.exports = {
  db,
  initializeDb,
  run,
  get,
  all,
};
