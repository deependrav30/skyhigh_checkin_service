import { assignWaitlist, expireHolds } from './seat-service.js';
import { startReconciler } from './cache-reconcile.js';

const HOLD_EXPIRY_INTERVAL_MS = 5_000;
const WAITLIST_INTERVAL_MS = 5_000;

async function loop(fn: () => Promise<unknown>, name: string, interval: number) {
  const run = async () => {
    try {
      const res = await fn();
      if (typeof res === 'number') {
        console.log(`[worker] ${name} processed ${res}`);
      }
    } catch (err) {
      console.error(`[worker] ${name} error`, err);
    } finally {
      setTimeout(run, interval);
    }
  };
  run();
}

loop(expireHolds, 'expireHolds', HOLD_EXPIRY_INTERVAL_MS);
loop(assignWaitlist, 'assignWaitlist', WAITLIST_INTERVAL_MS);
startReconciler();
