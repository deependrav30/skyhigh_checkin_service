import { useEffect, useState } from 'react';
import { getSeatMap, holdSeat, confirmHold, cancelHold, joinWaitlist, cancelConfirmedSeat } from '../api';
import type { Seat, SeatMap } from '../types';
import './SeatMapView.css';

interface Props {
  flightId: string;
  passengerId: string;
  initialSeatMap?: SeatMap;
  onSeatConfirmed?: (hold: { holdId: string; seatId: string; expiresAt: string } | null) => void;
  existingSeat?: string | null;
}

export function SeatMapView({ flightId, passengerId, initialSeatMap, onSeatConfirmed, existingSeat }: Props) {
  const [seatMap, setSeatMap] = useState<SeatMap | null>(initialSeatMap || null);
  const [selectedSeat, setSelectedSeat] = useState<string | null>(null);
  const [currentHold, setCurrentHold] = useState<{ holdId: string; seatId: string; expiresAt: string } | null>(null);
  const [confirmedSeat, setConfirmedSeat] = useState<string | null>(existingSeat || null);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);
  const [countdown, setCountdown] = useState<number | null>(null);

  // Check for existing confirmed seat on mount
  useEffect(() => {
    if (existingSeat) {
      setConfirmedSeat(existingSeat);
      showMessage('success', `You already have seat ${existingSeat} confirmed!`);
    }
  }, [existingSeat]);

  const refreshSeatMap = async () => {
    try {
      const data = await getSeatMap(flightId);
      setSeatMap(data);
    } catch (err) {
      showMessage('error', 'Failed to refresh seat map');
    }
  };

  useEffect(() => {
    if (!initialSeatMap) {
      refreshSeatMap();
    }
    // Refresh every 1 second for real-time updates
    const interval = setInterval(refreshSeatMap, 1000);
    return () => clearInterval(interval);
  }, [flightId]);

  // Countdown timer for hold expiry
  useEffect(() => {
    if (!currentHold) {
      setCountdown(null);
      return;
    }

    const updateCountdown = () => {
      const expiresAt = new Date(currentHold.expiresAt).getTime();
      const now = Date.now();
      const remaining = Math.max(0, Math.floor((expiresAt - now) / 1000));
      setCountdown(remaining);

      if (remaining === 0) {
        setCurrentHold(null);
        setSelectedSeat(null);
        showMessage('error', 'Hold expired! Seat released.');
        // Force immediate refresh when hold expires
        refreshSeatMap();
      }
    };

    updateCountdown();
    const interval = setInterval(updateCountdown, 1000);
    return () => clearInterval(interval);
  }, [currentHold]);

  const showMessage = (type: 'success' | 'error', text: string) => {
    setMessage({ type, text });
    setTimeout(() => setMessage(null), 5000);
  };

  const handleHoldSeat = async (seatId: string) => {
    // Prevent selecting new seat if user already has a confirmed seat
    if (confirmedSeat) {
      showMessage('error', `You already have seat ${confirmedSeat} confirmed. Cancel it first to select a new seat.`);
      return;
    }
    
    setLoading(true);
    
    // Optimistic update: immediately update UI before API call
    const previousHold = currentHold;
    const optimisticHold = {
      holdId: `hold-${seatId}`,
      seatId: seatId,
      expiresAt: new Date(Date.now() + 120000).toISOString()
    };
    
    // Optimistically update seat map in UI
    if (seatMap) {
      const updatedSeats = seatMap.seats.map(seat => {
        if (seat.seatId === seatId) {
          return { ...seat, state: 'HELD' as const, heldBy: passengerId };
        }
        // Release previous hold in UI
        if (previousHold && seat.seatId === previousHold.seatId) {
          return { ...seat, state: 'AVAILABLE' as const, heldBy: null };
        }
        return seat;
      });
      setSeatMap({ ...seatMap, seats: updatedSeats });
    }
    
    setCurrentHold(optimisticHold);
    setSelectedSeat(seatId);
    
    try {
      // Now make the actual API call
      const result = await holdSeat(flightId, seatId, passengerId);
      
      // Update with real data from server
      setCurrentHold({
        holdId: result.holdId,
        seatId: result.seatId,
        expiresAt: result.holdExpiresAt
      });
      showMessage('success', `Seat ${seatId} held for 120 seconds!`);
      
      // Refresh to sync with server
      refreshSeatMap();
    } catch (err) {
      // Revert optimistic update on error
      if (previousHold) {
        setCurrentHold(previousHold);
        setSelectedSeat(previousHold.seatId);
      } else {
        setCurrentHold(null);
        setSelectedSeat(null);
      }
      // Refresh to get correct state from server
      refreshSeatMap();
      showMessage('error', err instanceof Error ? err.message : 'Failed to hold seat');
    } finally {
      setLoading(false);
    }
  };

  const handleConfirm = async () => {
    if (!currentHold) return;
    setLoading(true);
    try {
      await confirmHold(currentHold.holdId, passengerId);
      showMessage('success', `Seat ${currentHold.seatId} confirmed! Proceeding to baggage...`);
      
      // Proceed to baggage step
      if (onSeatConfirmed) {
        onSeatConfirmed(currentHold);
      }
      
      setCurrentHold(null);
      setSelectedSeat(null);
      await refreshSeatMap();
    } catch (err) {
      showMessage('error', err instanceof Error ? err.message : 'Failed to confirm seat');
    } finally {
      setLoading(false);
    }
  };

  const handleCancel = async () => {
    if (!currentHold) return;
    setLoading(true);
    try {
      await cancelHold(currentHold.holdId, passengerId);
      showMessage('success', 'Seat hold cancelled');
      setCurrentHold(null);
      setSelectedSeat(null);
      await refreshSeatMap();
    } catch (err) {
      showMessage('error', err instanceof Error ? err.message : 'Failed to cancel hold');
    } finally {
      setLoading(false);
    }
  };

  const handleJoinWaitlist = async () => {
    setLoading(true);
    try {
      await joinWaitlist(flightId, passengerId, { seatType: 'any' });
      showMessage('success', 'Added to waitlist! We\'ll notify you when a seat becomes available.');
    } catch (err) {
      showMessage('error', err instanceof Error ? err.message : 'Failed to join waitlist');
    } finally {
      setLoading(false);
    }
  };

  const handleCancelConfirmedSeat = async () => {
    if (!confirmedSeat) return;
    
    if (!confirm(`Are you sure you want to cancel seat ${confirmedSeat}? You will need to select a new seat.`)) {
      return;
    }
    
    setLoading(true);
    try {
      await cancelConfirmedSeat(flightId, confirmedSeat, passengerId, 'User requested cancellation');
      
      // Optimistically update the seat map
      if (seatMap) {
        const updatedSeats = seatMap.seats.map(seat => {
          if (seat.seatId === confirmedSeat) {
            return { ...seat, state: 'AVAILABLE' as const, heldBy: null };
          }
          return seat;
        });
        setSeatMap({ ...seatMap, seats: updatedSeats });
      }
      
      showMessage('success', `Seat ${confirmedSeat} cancelled. You can now select a new seat.`);
      setConfirmedSeat(null);
      await refreshSeatMap();
    } catch (err) {
      showMessage('error', err instanceof Error ? err.message : 'Failed to cancel seat');
    } finally {
      setLoading(false);
    }
  };

  const getSeatClass = (seat: Seat): string => {
    const classes = ['seat'];
    if (seat.seatId === selectedSeat) classes.push('selected');
    
    switch (seat.state) {
      case 'AVAILABLE':
        classes.push('available');
        break;
      case 'HELD':
        classes.push('held');
        break;
      case 'CONFIRMED':
        classes.push('confirmed');
        break;
    }
    
    return classes.join(' ');
  };

  if (!seatMap) {
    return <div className="loading">Loading seat map...</div>;
  }

  // Group seats by row number and organize with aisles
  const rows = new Map<number, Seat[]>();
  seatMap.seats.forEach(seat => {
    const rowNum = parseInt(seat.seatId.match(/\d+/)?.[0] || '1');
    if (!rows.has(rowNum)) rows.set(rowNum, []);
    rows.get(rowNum)!.push(seat);
  });

  // Render a row with proper aisle spacing
  const renderRow = (rowNum: number, seats: Seat[]) => {
    const sortedSeats = seats.sort((a, b) => a.seatId.localeCompare(b.seatId));
    const isBusinessClass = rowNum <= 3;
    
    // Business: A C | D F, Economy: A B C | D E F
    const leftSeats = isBusinessClass ? ['A', 'C'] : ['A', 'B', 'C'];
    const rightSeats = isBusinessClass ? ['D', 'F'] : ['D', 'E', 'F'];
    
    const left = sortedSeats.filter(s => leftSeats.includes(s.seatId.replace(/\d+/, '')));
    const right = sortedSeats.filter(s => rightSeats.includes(s.seatId.replace(/\d+/, '')));
    
    return (
      <div key={rowNum} className={`seat-row ${isBusinessClass ? 'business-class' : 'economy-class'}`}>
        <div className="row-label">{rowNum}</div>
        <div className="seats-left">
          {left.map(seat => (
            <button
              key={seat.seatId}
              className={getSeatClass(seat)}
              onClick={() => seat.state === 'AVAILABLE' && handleHoldSeat(seat.seatId)}
              disabled={loading || seat.state !== 'AVAILABLE'}
              title={`Seat ${seat.seatId} - ${seat.state}`}
            >
              {seat.seatId}
            </button>
          ))}
        </div>
        <div className="aisle"></div>
        <div className="seats-right">
          {right.map(seat => (
            <button
              key={seat.seatId}
              className={getSeatClass(seat)}
              onClick={() => seat.state === 'AVAILABLE' && handleHoldSeat(seat.seatId)}
              disabled={loading || seat.state !== 'AVAILABLE'}
              title={`Seat ${seat.seatId} - ${seat.state}`}
            >
              {seat.seatId}
            </button>
          ))}
        </div>
        <div className="row-label">{rowNum}</div>
      </div>
    );
  };

  return (
    <div className="seat-map-view">
      <div className="header">
        <h2>Select Your Seat - Flight {flightId}</h2>
        <button className="btn-refresh" onClick={refreshSeatMap}>
          🔄 Refresh
        </button>
      </div>

      {message && (
        <div className={`message message-${message.type}`}>
          {message.text}
        </div>
      )}

      {confirmedSeat && (
        <div className="confirmed-seat-status">
          <div className="confirmed-info">
            <strong>✓ Your Confirmed Seat: {confirmedSeat}</strong>
            <p>You already have a seat assigned. If you want to select a different seat, you must cancel this one first.</p>
          </div>
          <div className="confirmed-actions">
            <button
              className="btn-cancel"
              onClick={handleCancelConfirmedSeat}
              disabled={loading}
            >
              ✕ Cancel Seat {confirmedSeat}
            </button>
          </div>
        </div>
      )}

      {currentHold && countdown !== null && countdown > 0 && (
        <div className="hold-status">
          <div className="hold-info">
            <strong>🕒 Seat {currentHold.seatId} held</strong>
            <span className="countdown">{countdown}s remaining</span>
          </div>
          <div className="hold-actions">
            <button
              className="btn-confirm"
              onClick={handleConfirm}
              disabled={loading}
            >
              ✓ Confirm Seat
            </button>
            {onSeatConfirmed && (
              <button
                className="btn-primary"
                onClick={() => onSeatConfirmed(currentHold)}
                disabled={loading}
              >
                Continue with Hold →
              </button>
            )}
            <button
              className="btn-cancel"
              onClick={handleCancel}
              disabled={loading}
            >
              ✕ Cancel Hold
            </button>
          </div>
        </div>
      )}

      <div className="legend">
        <div className="legend-item">
          <div className="seat-icon available"></div>
          <span>Available</span>
        </div>
        <div className="legend-item">
          <div className="seat-icon held"></div>
          <span>Held</span>
        </div>
        <div className="legend-item">
          <div className="seat-icon confirmed"></div>
          <span>Confirmed</span>
        </div>
      </div>

      <div className="seat-grid">
        <div className="cabin-label business">Business Class</div>
        {Array.from(rows.entries())
          .filter(([rowNum]) => rowNum <= 3)
          .sort(([a], [b]) => a - b)
          .map(([rowNum, seats]) => renderRow(rowNum, seats))}
        
        <div className="cabin-divider"></div>
        <div className="cabin-label economy">Economy Class</div>
        
        {Array.from(rows.entries())
          .filter(([rowNum]) => rowNum > 3)
          .sort(([a], [b]) => a - b)
          .map(([rowNum, seats]) => renderRow(rowNum, seats))}
      </div>

      <div className="actions">
        <button
          className="btn-waitlist"
          onClick={handleJoinWaitlist}
          disabled={loading || currentHold !== null}
        >
          Join Waitlist
        </button>
      </div>
    </div>
  );
}
