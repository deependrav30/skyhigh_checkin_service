import { useState, useEffect } from 'react';
import { submitBaggage, confirmHold, completePayment } from '../api';
import type { PaymentIntent } from '../types';
import './BaggageFlow.css';

interface Props {
  checkinId: string;
  seatHold?: { holdId: string; seatId: string; expiresAt: string } | null;
  onComplete: () => void;
}

export function BaggageFlow({ checkinId, seatHold, onComplete }: Props) {
  const [weight, setWeight] = useState('');
  const [loading, setLoading] = useState(false);
  const [paymentIntent, setPaymentIntent] = useState<PaymentIntent | null>(null);
  const [message, setMessage] = useState<{ type: 'success' | 'error' | 'info'; text: string } | null>(null);
  const [paymentInProgress, setPaymentInProgress] = useState(false);
  const [countdown, setCountdown] = useState<number | null>(null);

  // Track countdown if hold exists (requirement #4: keep lock during payment)
  useEffect(() => {
    if (!seatHold) {
      setCountdown(null);
      return;
    }

    const updateCountdown = () => {
      const expiresAt = new Date(seatHold.expiresAt).getTime();
      const now = Date.now();
      const remaining = Math.max(0, Math.floor((expiresAt - now) / 1000));
      setCountdown(remaining);

      // If payment is in progress, lock is preserved (requirement #4)
      if (remaining === 0 && !paymentInProgress) {
        setMessage({
          type: 'error',
          text: 'Seat hold expired! Please restart check-in.'
        });
      }
    };

    updateCountdown();
    const interval = setInterval(updateCountdown, 1000);
    return () => clearInterval(interval);
  }, [seatHold, paymentInProgress]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setMessage(null);

    try {
      const result = await submitBaggage(checkinId, Number(weight));
      
      if (result.paymentRequired && result.paymentIntent) {
        setPaymentIntent(result.paymentIntent);
        setMessage({
          type: 'info',
          text: `Baggage overweight! Additional charge: $${result.paymentIntent.amount}. Please complete payment.`
        });
      } else {
        setMessage({
          type: 'success',
          text: 'Baggage checked in successfully! ✓'
        });
        setTimeout(() => {
          onComplete();
        }, 2000);
      }
    } catch (err) {
      setMessage({
        type: 'error',
        text: err instanceof Error ? err.message : 'Failed to submit baggage'
      });
    } finally {
      setLoading(false);
    }
  };

  const handlePaymentSimulation = async () => {
    if (!paymentIntent) return;
    
    setPaymentInProgress(true);
    setLoading(true);
    
    try {
      // Complete payment first
      await completePayment(paymentIntent.intentId);
      
      // Confirm seat hold if it exists
      if (seatHold) {
        await confirmHold(seatHold.holdId, checkinId);
      }
      
      setMessage({
        type: 'success',
        text: 'Payment processed! Check-in complete. ✓'
      });
      
      setTimeout(() => {
        setPaymentInProgress(false);
        setLoading(false);
        onComplete();
      }, 2000);
    } catch (err) {
      setPaymentInProgress(false);
      setLoading(false);
      setMessage({
        type: 'error',
        text: err instanceof Error ? err.message : 'Failed to process payment'
      });
    }
  };

  const handleSkip = async () => {
    try {
      // Confirm seat hold if it exists
      if (seatHold) {
        await confirmHold(seatHold.holdId, checkinId);
      }
      onComplete();
    } catch (err) {
      setMessage({
        type: 'error',
        text: err instanceof Error ? err.message : 'Failed to confirm seat'
      });
    }
  };

  return (
    <div className="baggage-flow">
      <div className="baggage-card">
        <h2>Baggage Information</h2>
        <p className="subtitle">Enter your baggage weight to continue</p>

        {seatHold && countdown !== null && countdown > 0 && (
          <div className="hold-status">
            <div className="hold-info">
              <strong>🕒 Seat {seatHold.seatId} held</strong>
              <span className="countdown">{countdown}s remaining</span>
            </div>
          </div>
        )}

        {seatHold && countdown === 0 && !paymentInProgress && (
          <div className="message message-error">
            ⚠️ Seat hold expired! Please restart check-in.
          </div>
        )}

        {!paymentIntent ? (
          <form onSubmit={handleSubmit}>
            <div className="form-group">
              <label htmlFor="weight">Baggage Weight (kg)</label>
              <input
                id="weight"
                type="number"
                value={weight}
                onChange={(e) => setWeight(e.target.value)}
                placeholder="e.g., 23"
                min="0"
                max="50"
                step="0.1"
                required
                disabled={loading}
              />
              <small className="hint">Maximum allowance: 25kg. Overweight charges ($50) apply above this limit.</small>
            </div>

            {message && (
              <div className={`message message-${message.type}`}>
                {message.text}
              </div>
            )}

            <button type="submit" className="btn-primary" disabled={loading}>
              {loading ? 'Processing...' : 'Submit Baggage'}
            </button>

            <button
              type="button"
              className="btn-secondary"
              onClick={handleSkip}
              disabled={loading}
            >
              Skip for Now
            </button>
          </form>
        ) : (
          <div className="payment-section">
            <div className="payment-info">
              <div className="charge-box">
                <span>Overweight Charge</span>
                <strong>${paymentIntent.amount}</strong>
              </div>
              
              {message && (
                <div className={`message message-${message.type}`}>
                  {message.text}
                </div>
              )}

              <div className="payment-notice">
                <p>💳 In a real scenario, you would be redirected to a payment gateway.</p>
                <p>For this demo, click below to simulate payment completion.</p>
              </div>
            </div>

            <button
              className="btn-payment"
              onClick={handlePaymentSimulation}
              disabled={loading || paymentInProgress}
            >
              {paymentInProgress ? 'Processing...' : `Simulate Payment ($${paymentIntent.amount})`}
            </button>

            <button
              className="btn-secondary"
              onClick={handleSkip}
            >
              Cancel & Skip
            </button>
          </div>
        )}

        <div className="info-box">
          <p>💡 <strong>Tip:</strong> Try entering weight over 25kg to test the payment flow!</p>
        </div>
      </div>
    </div>
  );
}
