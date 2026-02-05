import { pool } from './db.js';

type PaymentStatus = 'pending' | 'succeeded' | 'failed';

export async function createPaymentIntent(checkinId: string, amount: number, currency = 'USD') {
  const res = await pool.query(
    `INSERT INTO payment_intents (checkin_id, status, amount, currency)
     VALUES ($1,'pending',$2,$3) RETURNING intent_id`,
    [checkinId, amount, currency]
  );
  return res.rows[0].intent_id as string;
}

export async function resumePayment(intentId: string, status: PaymentStatus) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const intent = await client.query(
      'UPDATE payment_intents SET status=$2, updated_at=now() WHERE intent_id=$1 RETURNING checkin_id',
      [intentId, status]
    );
    if (intent.rowCount === 0) {
      await client.query('ROLLBACK');
      return null;
    }
    const checkinId = intent.rows[0].checkin_id as string;
    const newState = status === 'succeeded' ? 'COMPLETED' : 'WAITING_FOR_PAYMENT';
    await client.query('UPDATE checkins SET state=$2 WHERE checkin_id=$1', [checkinId, newState]);
    await client.query('COMMIT');
    return { checkinId, status: newState };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
