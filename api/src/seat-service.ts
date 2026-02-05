import { PoolClient } from 'pg';
import { pool } from './db.js';
import { redis } from './cache.js';

const SEATMAP_TTL_SECONDS = 60;

export type SeatRecord = {
  seat_id: string;
  flight_id: string;
  state: 'AVAILABLE' | 'HELD' | 'CONFIRMED' | 'CANCELLED';
  held_by: string | null;
  hold_expires_at: string | null;
};

export async function getSeatMap(flightId: string) {
  const cacheKey = `seatmap:${flightId}`;
  const cached = await redis.get(cacheKey);
  if (cached) {
    return JSON.parse(cached);
  }
  const { rows } = await pool.query<SeatRecord>(
    'SELECT seat_id, flight_id, state, held_by, hold_expires_at FROM seats WHERE flight_id = $1 ORDER BY seat_id',
    [flightId]
  );
  const payload = {
    flightId,
    lastUpdated: new Date().toISOString(),
    seats: rows.map((r: any) => ({
      seatId: r.seat_id,
      state: r.state,
      heldBy: r.held_by,
      holdExpiresAt: r.hold_expires_at
    }))
  };
  await redis.set(cacheKey, JSON.stringify(payload), 'EX', SEATMAP_TTL_SECONDS);
  return payload;
}

async function refreshSeatMapCache(flightId: string) {
  await getSeatMap(flightId); // recalculates and sets cache
}

export async function holdSeat(flightId: string, seatId: string, passengerId: string) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    // First, cancel any existing holds by this passenger (enforce one hold per passenger)
    await client.query(
      `UPDATE seats
       SET state='AVAILABLE', held_by=NULL, hold_expires_at=NULL, version=version+1, updated_at=now()
       WHERE flight_id=$1 AND held_by=$2 AND state='HELD' AND seat_id != $3`,
      [flightId, passengerId, seatId]
    );
    
    // Now create the new hold
    const holdRes = await client.query<SeatRecord>(
      `UPDATE seats
       SET state='HELD', held_by=$3, hold_expires_at=now() + interval '120 seconds', version=version+1, updated_at=now()
       WHERE flight_id=$1 AND seat_id=$2 AND state='AVAILABLE'
       RETURNING seat_id, flight_id, state, held_by, hold_expires_at`,
      [flightId, seatId, passengerId]
    );
    if (holdRes.rowCount === 0) {
      await client.query('ROLLBACK');
      return null;
    }
    await insertSeatEvent(client, seatId, flightId, 'HELD', passengerId, {
      hold_expires_at: holdRes.rows[0].hold_expires_at
    });
    await client.query('COMMIT');
    await refreshSeatMapCache(flightId);
    return holdRes.rows[0];
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

export async function confirmHold(holdId: string, passengerId?: string) {
  const seatId = holdId.replace('hold-', '');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const res = await client.query<SeatRecord>(
      `UPDATE seats
       SET state='CONFIRMED', version=version+1, updated_at=now()
       WHERE seat_id=$1 AND state='HELD' AND (hold_expires_at IS NULL OR hold_expires_at > now())
         AND ($2::text IS NULL OR held_by=$2)
       RETURNING seat_id, flight_id, state, held_by, hold_expires_at`,
      [seatId, passengerId || null]
    );
    if (res.rowCount === 0) {
      await client.query('ROLLBACK');
      return null;
    }
    const row = res.rows[0];
    await insertSeatEvent(client, seatId, row.flight_id, 'CONFIRMED', passengerId || 'unknown');
    await client.query('COMMIT');
    await refreshSeatMapCache(row.flight_id);
    return row;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

export async function cancelHold(holdId: string, actor?: string, reason?: string) {
  const seatId = holdId.replace('hold-', '');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const res = await client.query<SeatRecord>(
      `UPDATE seats
       SET state='AVAILABLE', held_by=NULL, hold_expires_at=NULL, version=version+1, updated_at=now()
       WHERE seat_id=$1
       RETURNING seat_id, flight_id, state, held_by, hold_expires_at`,
      [seatId]
    );
    if (res.rowCount === 0) {
      await client.query('ROLLBACK');
      return null;
    }
    const row = res.rows[0];
    await insertSeatEvent(client, seatId, row.flight_id, 'CANCELLED', actor || 'unknown', { reason });
    await client.query('COMMIT');
    await refreshSeatMapCache(row.flight_id);
    return row;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

export async function cancelConfirmedSeat(seatId: string, flightId: string, passengerId: string, reason?: string) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    // Verify the seat is confirmed and belongs to the passenger
    const checkRes = await client.query<SeatRecord>(
      'SELECT * FROM seats WHERE seat_id=$1 AND flight_id=$2 AND held_by=$3 AND state=$4',
      [seatId, flightId, passengerId, 'CONFIRMED']
    );
    
    if (checkRes.rowCount === 0) {
      await client.query('ROLLBACK');
      throw new Error('Seat not found or not confirmed by this passenger');
    }
    
    // Cancel the seat
    const res = await client.query<SeatRecord>(
      `UPDATE seats
       SET state='AVAILABLE', held_by=NULL, hold_expires_at=NULL, version=version+1, updated_at=now()
       WHERE seat_id=$1 AND flight_id=$2
       RETURNING seat_id, flight_id, state, held_by, hold_expires_at`,
      [seatId, flightId]
    );
    
    const row = res.rows[0];
    await insertSeatEvent(client, seatId, flightId, 'CANCELLED', passengerId, { reason: reason || 'User cancelled confirmed seat' });
    await client.query('COMMIT');
    await refreshSeatMapCache(flightId);
    return row;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

export async function expireHolds() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const res = await client.query<SeatRecord>(
      `UPDATE seats
       SET state='AVAILABLE', held_by=NULL, hold_expires_at=NULL, version=version+1, updated_at=now()
       WHERE state='HELD' AND hold_expires_at IS NOT NULL AND hold_expires_at <= now()
       RETURNING seat_id, flight_id, state, held_by, hold_expires_at`
    );
    for (const row of res.rows) {
      await insertSeatEvent(client, row.seat_id, row.flight_id, 'EXPIRED', 'system');
      await refreshSeatMapCache(row.flight_id);
    }
    await client.query('COMMIT');
    return res.rowCount || 0;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

export async function assignWaitlist() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const wl = await client.query(
      `SELECT waitlist_id, flight_id, user_id, seat_preferences FROM waitlist WHERE status='QUEUED' ORDER BY created_at LIMIT 1`
    );
    if (wl.rowCount === 0) {
      await client.query('ROLLBACK');
      return false;
    }
    const entry = wl.rows[0];
    // Simple assignment: first AVAILABLE seat. Preference filtering can be added here.
    const seatRes = await client.query<SeatRecord>(
      `UPDATE seats
       SET state='CONFIRMED', held_by=$2, hold_expires_at=NULL, version=version+1, updated_at=now()
       WHERE flight_id=$1 AND state='AVAILABLE'
       ORDER BY seat_id
       LIMIT 1
       RETURNING seat_id, flight_id, state, held_by, hold_expires_at`,
      [entry.flight_id, entry.user_id]
    );
    if (seatRes.rowCount === 0) {
      await client.query('ROLLBACK');
      return false;
    }
    await client.query('UPDATE waitlist SET status=$2 WHERE waitlist_id=$1', [entry.waitlist_id, 'ASSIGNED']);
    await insertSeatEvent(client, seatRes.rows[0].seat_id, entry.flight_id, 'WAITLIST_ASSIGNED', entry.user_id);
    await client.query('COMMIT');
    await refreshSeatMapCache(entry.flight_id);
    return true;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function insertSeatEvent(
  client: PoolClient,
  seatId: string,
  flightId: string,
  eventType: string,
  actor?: string,
  metadata?: Record<string, unknown>
) {
  await client.query(
    'INSERT INTO seat_events(seat_id, flight_id, event_type, actor, metadata) VALUES ($1,$2,$3,$4,$5)',
    [seatId, flightId, eventType, actor || null, metadata || {}]
  );
}
