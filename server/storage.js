import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const { Pool } = pg;
const here = path.dirname(fileURLToPath(import.meta.url));
const dataDir = process.env.DATA_DIR || path.join(here, 'data');
const filePath = path.join(dataDir, 'accounts.json');
let pool = null;
let accounts = {};

function hashPassword(password, saltHex) {
  const salt = saltHex ? Buffer.from(saltHex, 'hex') : crypto.randomBytes(16);
  const hash = crypto.scryptSync(password, salt, 64);
  return { salt: salt.toString('hex'), hash: hash.toString('hex') };
}

function validPassword(password, saltHex, hashHex) {
  const actual = Buffer.from(hashPassword(password, saltHex).hash, 'hex');
  const expected = Buffer.from(hashHex, 'hex');
  return actual.length === expected.length && crypto.timingSafeEqual(actual, expected);
}

export async function initializeStorage() {
  if (process.env.DATABASE_URL) {
    pool = new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl: process.env.DATABASE_SSL === 'false' ? false : { rejectUnauthorized: false },
      max: 5,
      idleTimeoutMillis: 5000,
      connectionTimeoutMillis: 10000
    });
    await pool.query(`
      CREATE TABLE IF NOT EXISTS fablebrink_users (
        username_key VARCHAR(16) PRIMARY KEY,
        username VARCHAR(16) NOT NULL,
        salt CHAR(32) NOT NULL,
        password_hash CHAR(128) NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    console.log('[storage] PostgreSQL ready');
    return;
  }

  fs.mkdirSync(dataDir, { recursive: true });
  try {
    accounts = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (error) {
    if (error.code !== 'ENOENT') console.error('[storage] Could not read local accounts file:', error.message);
    accounts = {};
  }
  console.log('[storage] Local JSON storage ready (development only)');
}

export async function registerUser(username, password) {
  const usernameKey = username.toLowerCase();
  const credentials = hashPassword(password);
  if (pool) {
    try {
      await pool.query(
        'INSERT INTO fablebrink_users (username_key, username, salt, password_hash) VALUES ($1, $2, $3, $4)',
        [usernameKey, username, credentials.salt, credentials.hash]
      );
      return { ok: true };
    } catch (error) {
      if (error.code === '23505') return { ok: false, code: 'username_taken' };
      throw error;
    }
  }

  if (accounts[usernameKey]) return { ok: false, code: 'username_taken' };
  accounts[usernameKey] = { username, salt: credentials.salt, hash: credentials.hash, createdAt: new Date().toISOString() };
  const temporary = `${filePath}.tmp`;
  fs.writeFileSync(temporary, JSON.stringify(accounts, null, 2), { mode: 0o600 });
  fs.renameSync(temporary, filePath);
  return { ok: true };
}

export async function verifyUser(username, password) {
  const usernameKey = username.toLowerCase();
  let record = null;
  if (pool) {
    const result = await pool.query(
      'SELECT username, salt, password_hash FROM fablebrink_users WHERE username_key = $1 LIMIT 1',
      [usernameKey]
    );
    record = result.rows[0] || null;
    if (!record) return { ok: false };
    return { ok: validPassword(password, record.salt, record.password_hash), username: record.username };
  }
  record = accounts[usernameKey] || null;
  if (!record) return { ok: false };
  return { ok: validPassword(password, record.salt, record.hash), username: record.username };
}

export async function closeStorage() {
  if (pool) await pool.end();
}
