import { useState } from 'react';
import { loginWithPNR } from '../api';
import type { CheckinSession } from '../types';
import './PNRLogin.css';

interface Props {
  onLogin: (session: CheckinSession) => void;
}

export function PNRLogin({ onLogin }: Props) {
  const [pnr, setPnr] = useState('');
  const [lastName, setLastName] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const session = await loginWithPNR(pnr, lastName);
      onLogin(session);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  const useDummyDetails = () => {
    setPnr('DEMO123');
    setLastName('demo');
  };

  return (
    <div className="pnr-login">
      <div className="login-card">
        <h1>✈️ SkyHigh Check-In</h1>
        <p className="subtitle">Enter your booking details to check in</p>
        
        <div className="demo-accounts">
          <p><strong>Demo Accounts (use lastName: demo):</strong></p>
          <div className="demo-pnrs">
            <span className="demo-pnr" onClick={() => { setPnr('DEMO123'); setLastName('demo'); }}>DEMO123</span>
            <span className="demo-pnr" onClick={() => { setPnr('DEMO456'); setLastName('demo'); }}>DEMO456</span>
            <span className="demo-pnr" onClick={() => { setPnr('DEMO789'); setLastName('demo'); }}>DEMO789</span>
            <span className="demo-pnr" onClick={() => { setPnr('DEMOA1B'); setLastName('demo'); }}>DEMOA1B</span>
            <span className="demo-pnr" onClick={() => { setPnr('DEMOC2D'); setLastName('demo'); }}>DEMOC2D</span>
            <span className="demo-pnr" onClick={() => { setPnr('DEMOE3F'); setLastName('demo'); }}>DEMOE3F</span>
          </div>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="pnr">PNR / Booking Reference</label>
            <input
              id="pnr"
              type="text"
              value={pnr}
              onChange={(e) => setPnr(e.target.value.toUpperCase())}
              placeholder="e.g., ABC123"
              required
              disabled={loading}
            />
          </div>

          <div className="form-group">
            <label htmlFor="lastName">Last Name</label>
            <input
              id="lastName"
              type="text"
              value={lastName}
              onChange={(e) => setLastName(e.target.value)}
              placeholder="As per booking"
              required
              disabled={loading}
            />
          </div>

          {error && <div className="error-message">{error}</div>}

          <button type="submit" className="btn-primary" disabled={loading}>
            {loading ? 'Checking...' : 'Check In'}
          </button>

          <button
            type="button"
            className="btn-secondary"
            onClick={useDummyDetails}
            disabled={loading}
          >
            Use Demo Details
          </button>
        </form>

        <div className="info-box">
          <p>💡 <strong>Demo Mode:</strong> Click "Use Demo Details" for instant testing</p>
        </div>
      </div>
    </div>
  );
}
