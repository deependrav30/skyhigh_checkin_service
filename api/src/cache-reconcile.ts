import { pool } from './db.js';
import { redis } from './cache.js';
import { getSeatMap } from './seat-service.js';

const RECONCILE_INTERVAL_MS = 60_000;

export async function reconcileSeatMaps() {
  const flights = await pool.query<{ flight_id: string }>('SELECT DISTINCT flight_id FROM seats');
  for (const row of flights.rows) {
    await getSeatMap(row.flight_id); // rebuilds cache
  }
}

export function startReconciler() {
  const run = async () => {
    try {
      await reconcileSeatMaps();
    } catch (err) {
      console.error('Reconcile error', err);
    } finally {
      setTimeout(run, RECONCILE_INTERVAL_MS);
    }
  };
  run();
}
