import { useState } from 'react';
import { PNRLogin } from './components/PNRLogin';
import { SeatMapView } from './components/SeatMapView';
import { BaggageFlow } from './components/BaggageFlow';
import type { CheckinSession } from './types';
import './App.css';

type Step = 'login' | 'seat-selection' | 'baggage' | 'complete';

function App() {
  const [step, setStep] = useState<Step>('login');
  const [session, setSession] = useState<CheckinSession | null>(null);
  const [seatHold, setSeatHold] = useState<{ holdId: string; seatId: string; expiresAt: string } | null>(null);

  const handleLogin = (checkinSession: CheckinSession) => {
    setSession(checkinSession);
    setStep('seat-selection');
  };

  const handleSeatConfirmed = (hold: { holdId: string; seatId: string; expiresAt: string } | null) => {
    setSeatHold(hold);
    setStep('baggage');
  };

  const handleBaggageComplete = () => {
    setStep('complete');
  };

  const handleRestart = () => {
    setStep('login');
    setSession(null);
  };

  return (
    <div className="app">
      {step === 'login' && <PNRLogin onLogin={handleLogin} />}

      {step === 'seat-selection' && session && (
        <div className="main-content">
          <div className="progress-bar">
            <div className="progress-step active">1. Select Seat</div>
            <div className="progress-step">2. Baggage</div>
            <div className="progress-step">3. Complete</div>
          </div>
          <SeatMapView
            flightId={session.flightId}
            passengerId={session.checkinId}
            initialSeatMap={session.seatMap}
            onSeatConfirmed={handleSeatConfirmed}
            existingSeat={session.currentSeat}
          />
          <div className="step-actions">
            <button className="btn-secondary" onClick={handleRestart}>
              ← Start Over
            </button>
          </div>
        </div>
      )}

      {step === 'baggage' && session && (
        <div className="main-content">
          <div className="progress-bar">
            <div className="progress-step completed">1. Select Seat</div>
            <div className="progress-step active">2. Baggage</div>
            <div className="progress-step">3. Complete</div>
          </div>
          <BaggageFlow
            checkinId={session.checkinId}
            seatHold={seatHold}
            onComplete={handleBaggageComplete}
          />
        </div>
      )}

      {step === 'complete' && session && (
        <div className="complete-screen">
          <div className="complete-card">
            <div className="success-icon">✓</div>
            <h1>Check-In Complete!</h1>
            <p className="success-message">
              You're all set, {session.passenger.firstName}!
            </p>
            <div className="details-box">
              <div className="detail-row">
                <span>Flight</span>
                <strong>{session.flightId}</strong>
              </div>
              <div className="detail-row">
                <span>PNR</span>
                <strong>DEMO123</strong>
              </div>
              <div className="detail-row">
                <span>Status</span>
                <strong className="status-confirmed">CONFIRMED</strong>
              </div>
            </div>
            <button className="btn-primary" onClick={handleRestart}>
              Start New Check-In
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
