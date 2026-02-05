import Fastify from 'fastify';
import cors from '@fastify/cors';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import rateLimit from '@fastify/rate-limit';
import { TypeBoxTypeProvider } from '@fastify/type-provider-typebox';
import { Type, type Static } from '@sinclair/typebox';
import { cancelHold, confirmHold, getSeatMap, holdSeat, cancelConfirmedSeat } from './seat-service.js';
import {
  BaggageRequest,
  BaggageResponse,
  CancelRequest,
  CancelResponse,
  ConfirmResponse,
  HoldRequest,
  HoldResponse,
  PaymentWebhookRequest,
  PaymentWebhookResponse,
  PnrLoginRequest,
  PnrLoginResponse,
  SeatMapResponse,
  WaitlistRequest,
  WaitlistResponse
} from './schemas.js';
import { pool } from './db.js';
import { createPaymentIntent, resumePayment } from './payment.js';
import { registerBurstGuard } from './rate-limit.js';
import { config } from './config.js';

const buildServer = () => {
  const app = Fastify({ logger: true }).withTypeProvider<TypeBoxTypeProvider>();

  app.register(cors, {
    origin: true
  });

  app.register(swagger, {
    openapi: {
      info: {
        title: 'SkyHigh Core API',
        version: '0.1.0'
      }
    }
  });

  app.register(swaggerUi, {
    routePrefix: '/docs'
  });

  app.register(rateLimit, {
    global: false,
    max: 60,
    timeWindow: '1 minute'
  });

  registerBurstGuard(app, { threshold: 30, windowMs: 5_000, blockMs: 10 * 60_000 });

  const demoFlightId = 'FL-123';
  
  // Demo PNR credentials mapping
  const demoPNRs: Record<string, { lastName: string }> = {
    'DEMO123': { lastName: 'demo' },
    'DEMO456': { lastName: 'demo' },
    'DEMO789': { lastName: 'demo' },
    'DEMOA1B': { lastName: 'demo' },
    'DEMOC2D': { lastName: 'demo' },
    'DEMOE3F': { lastName: 'demo' }
  };

  app.post('/auth/pnr-login', {
    schema: {
      body: PnrLoginRequest,
      response: {
        200: PnrLoginResponse
      }
    }
  }, async (request, reply) => {
    const { pnr, lastName } = request.body;
    const demoAccount = demoPNRs[pnr];
    if (!demoAccount || lastName.toLowerCase() !== demoAccount.lastName) {
      return reply.code(401).send({ error: 'Invalid PNR or last name' });
    }
    
    // Query checkin by passenger_id (which is the PNR)
    const checkinRes = await pool.query(
      'SELECT checkin_id FROM checkins WHERE passenger_id=$1 AND flight_id=$2 LIMIT 1',
      [pnr, demoFlightId]
    );
    
    if (checkinRes.rowCount === 0) {
      return reply.code(404).send({ error: 'Checkin not found' });
    }
    
    const checkinId = checkinRes.rows[0].checkin_id;
    
    // Check if user already has a confirmed seat
    const seatRes = await pool.query(
      'SELECT seat_id FROM seats WHERE flight_id=$1 AND held_by=$2 AND state=$3 LIMIT 1',
      [demoFlightId, checkinId, 'CONFIRMED']
    );
    
    const currentSeat = seatRes.rowCount > 0 ? seatRes.rows[0].seat_id : null;
    
    const seatMapPayload = await getSeatMap(demoFlightId) as Static<typeof SeatMapResponse>;
    return {
      checkinId,
      flightId: demoFlightId,
      passenger: { firstName: 'Demo', lastName: 'User' },
      seatMap: seatMapPayload,
      currentSeat
    };
  });

  app.get('/flights/:flightId/seatmap', {
    schema: {
      params: Type.Object({ flightId: Type.String() }),
      response: {
        200: SeatMapResponse
      }
    },
    config: {
      rateLimit: { max: 60, timeWindow: '1 minute' }
    }
  }, async (request) => {
    const { flightId } = request.params as { flightId: string };
    return getSeatMap(flightId);
  });

  app.post('/flights/:flightId/seats/:seatId/hold', {
    schema: {
      params: Type.Object({
        flightId: Type.String(),
        seatId: Type.String()
      }),
      body: HoldRequest,
      response: {
        200: HoldResponse,
        409: Type.Object({ error: Type.String() })
      }
    },
    config: {
      rateLimit: { max: 20, timeWindow: '1 minute' }
    }
  }, async (request, reply) => {
    const { seatId, flightId } = request.params as { seatId: string; flightId: string };
    const result = await holdSeat(flightId, seatId, request.body.passengerId);
    if (!result) {
      return reply.code(409).send({ error: 'Seat not available' });
    }
    return {
      holdId: `hold-${seatId}`,
      seatId,
      flightId,
      state: 'HELD',
      holdExpiresAt: result.hold_expires_at
    };
  });

  app.post('/holds/:holdId/confirm', {
    schema: {
      params: Type.Object({ holdId: Type.String() }),
      body: Type.Object({ passengerId: Type.String() }),
      response: {
        200: ConfirmResponse,
        404: Type.Object({ error: Type.String() })
      }
    }
  }, async (request, reply) => {
    const { holdId } = request.params as { holdId: string };
    const { passengerId } = request.body as { passengerId: string };
    const res = await confirmHold(holdId, passengerId);
    if (!res) {
      return reply.code(404).send({ error: 'Hold not found or expired' });
    }
    return { seatId: res.seat_id, flightId: res.flight_id, state: 'CONFIRMED' };
  });

  app.post('/holds/:holdId/cancel', {
    schema: {
      params: Type.Object({ holdId: Type.String() }),
      body: CancelRequest,
      response: {
        200: CancelResponse
      }
    }
  }, async (request) => {
    const { holdId } = request.params as { holdId: string };
    const result = await cancelHold(holdId, request.body?.actorRole, request.body?.reason);
    return {
      seatId: result?.seat_id || holdId.replace('hold-', ''),
      flightId: result?.flight_id || demoFlightId,
      state: 'AVAILABLE'
    };
  });

  app.post('/flights/:flightId/seats/:seatId/cancel', {
    schema: {
      params: Type.Object({ 
        flightId: Type.String(),
        seatId: Type.String()
      }),
      body: Type.Object({ 
        passengerId: Type.String(),
        reason: Type.Optional(Type.String())
      }),
      response: {
        200: CancelResponse,
        404: Type.Object({ error: Type.String() })
      }
    }
  }, async (request, reply) => {
    const { flightId, seatId } = request.params as { flightId: string; seatId: string };
    const { passengerId, reason } = request.body as { passengerId: string; reason?: string };
    
    try {
      const result = await cancelConfirmedSeat(seatId, flightId, passengerId, reason);
      return {
        seatId: result.seat_id,
        flightId: result.flight_id,
        state: 'AVAILABLE'
      };
    } catch (err) {
      return reply.code(404).send({ error: err instanceof Error ? err.message : 'Failed to cancel seat' });
    }
  });

  app.post('/flights/:flightId/waitlist', {
    schema: {
      params: Type.Object({ flightId: Type.String() }),
      body: WaitlistRequest,
      response: {
        200: WaitlistResponse
      }
    }
  }, async (request) => {
    const { flightId } = request.params as { flightId: string };
    const { passengerId, preferences } = request.body;
    const res = await pool.query(
      'INSERT INTO waitlist(flight_id, user_id, seat_preferences, status) VALUES ($1,$2,$3,$4) RETURNING waitlist_id',
      [flightId, passengerId, preferences || {}, 'QUEUED']
    );
    return { entryId: res.rows[0].waitlist_id, flightId, status: 'QUEUED' };
  });

  app.post('/checkins/:checkinId/baggage', {
    schema: {
      params: Type.Object({ checkinId: Type.String() }),
      body: BaggageRequest,
      response: {
        200: BaggageResponse
      }
    }
  }, async (request) => {
    const { checkinId } = request.params as { checkinId: string };
    const { weightKg } = request.body;
    if (weightKg > 25) {
      const intentId = await createPaymentIntent(checkinId, 50); // demo surcharge
      await pool.query('UPDATE checkins SET state=$2, baggage_weight=$3, payment_intent_id=$4 WHERE checkin_id=$1', [
        checkinId,
        'WAITING_FOR_PAYMENT',
        weightKg,
        intentId
      ]);
      return { checkinId, state: 'WAITING_FOR_PAYMENT', paymentIntentId: intentId };
    }
    await pool.query('UPDATE checkins SET state=$2, baggage_weight=$3 WHERE checkin_id=$1', [
      checkinId,
      'COMPLETED',
      weightKg
    ]);
    return { checkinId, state: 'COMPLETED', paymentIntentId: null };
  });

  app.post('/payments/webhook', {
    schema: {
      body: PaymentWebhookRequest,
      response: {
        200: PaymentWebhookResponse
      }
    }
  }, async (request) => {
    const { intentId, status } = request.body;
    const res = await resumePayment(intentId, status === 'succeeded' ? 'succeeded' : 'failed');
    return { intentId, status, checkinId: res?.checkinId };
  });

  app.get('/health', async () => ({ status: 'ok' }));
  app.get('/ready', async () => ({ status: 'ok' }));

  return app;
};

const start = async () => {
  const app = buildServer();
  try {
    await app.listen({ port: config.apiPort, host: config.apiHost });
    app.log.info(`Server listening on ${config.apiHost}:${config.apiPort}`);
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
};

start();
