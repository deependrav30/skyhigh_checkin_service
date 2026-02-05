import fs from 'fs';
import path from 'path';
import { pool } from './db.js';

const migrationsDir = path.resolve(process.cwd(), '..', 'migrations');

async function ensureMigrationsTable() {
  await pool.query(
    `CREATE TABLE IF NOT EXISTS schema_migrations (
      version TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );`
  );
}

async function appliedVersions(): Promise<Set<string>> {
  const res = await pool.query('SELECT version FROM schema_migrations');
  return new Set(res.rows.map((r: any) => r.version as string));
}

async function applyMigration(version: string, sql: string) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(sql);
    await client.query('INSERT INTO schema_migrations(version) VALUES ($1)', [version]);
    await client.query('COMMIT');
    console.log(`Applied migration ${version}`);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function run() {
  await ensureMigrationsTable();
  const done = await appliedVersions();
  const files = fs
    .readdirSync(migrationsDir)
    .filter((f) => f.endsWith('.sql'))
    .sort();

  for (const file of files) {
    if (done.has(file)) {
      continue;
    }
    const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
    await applyMigration(file, sql);
  }
  await pool.end();
}

run().catch((err) => {
  console.error('Migration failed', err);
  process.exit(1);
});
