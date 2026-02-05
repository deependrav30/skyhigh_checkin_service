import { FastifyInstance } from 'fastify';

// Simple burst detector: if more than threshold in window, block for blockMs.
export function registerBurstGuard(app: FastifyInstance, opts: { threshold: number; windowMs: number; blockMs: number }) {
  const hits = new Map<string, { count: number; first: number; blockedUntil: number }>();

  app.addHook('preHandler', async (req, reply) => {
    const key = req.ip || 'unknown';
    const now = Date.now();
    const entry = hits.get(key) || { count: 0, first: now, blockedUntil: 0 };

    if (entry.blockedUntil > now) {
      return reply.code(429).send({ error: 'temporarily blocked' });
    }

    if (now - entry.first > opts.windowMs) {
      entry.count = 0;
      entry.first = now;
    }

    entry.count += 1;
    if (entry.count > opts.threshold) {
      entry.blockedUntil = now + opts.blockMs;
      hits.set(key, entry);
      return reply.code(429).send({ error: 'burst limit exceeded' });
    }

    hits.set(key, entry);
  });
}
