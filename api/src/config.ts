import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '..', '.env') });

export const config = {
  databaseUrl: process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5434/skyhigh',
  redisUrl: process.env.REDIS_URL || 'redis://localhost:6381',
  apiPort: Number(process.env.API_PORT || 3000),
  apiHost: process.env.API_HOST || '0.0.0.0'
};
