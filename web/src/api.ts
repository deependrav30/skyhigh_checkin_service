const API_BASE = 'http://localhost:3002';

export async function loginWithPNR(pnr: string, lastName: string) {
  const response = await fetch(`${API_BASE}/auth/pnr-login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ pnr, lastName })
  });
  if (!response.ok) throw new Error('Login failed');
  return response.json();
}

export async function getSeatMap(flightId: string) {
  const response = await fetch(`${API_BASE}/flights/${flightId}/seatmap`);
  if (!response.ok) throw new Error('Failed to fetch seat map');
  return response.json();
}

export async function holdSeat(flightId: string, seatId: string, passengerId: string) {
  const response = await fetch(`${API_BASE}/flights/${flightId}/seats/${seatId}/hold`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ passengerId })
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message || 'Failed to hold seat');
  }
  return response.json();
}

export async function confirmHold(holdId: string, passengerId: string) {
  const response = await fetch(`${API_BASE}/holds/${holdId}/confirm`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ passengerId })
  });
  if (!response.ok) throw new Error('Failed to confirm seat');
  return response.json();
}

export async function cancelHold(holdId: string, passengerId: string) {
  const response = await fetch(`${API_BASE}/holds/${holdId}/cancel`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ passengerId })
  });
  if (!response.ok) throw new Error('Failed to cancel hold');
  return response.json();
}

export async function cancelConfirmedSeat(flightId: string, seatId: string, passengerId: string, reason?: string) {
  const response = await fetch(`${API_BASE}/flights/${flightId}/seats/${seatId}/cancel`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ passengerId, reason })
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || 'Failed to cancel seat');
  }
  return response.json();
}

export async function joinWaitlist(flightId: string, passengerId: string, preferences: { seatType?: string }) {
  const response = await fetch(`${API_BASE}/flights/${flightId}/waitlist`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ passengerId, preferences })
  });
  if (!response.ok) throw new Error('Failed to join waitlist');
  return response.json();
}

export async function submitBaggage(checkinId: string, weight: number) {
  const response = await fetch(`${API_BASE}/checkins/${checkinId}/baggage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ weightKg: weight })
  });
  if (!response.ok) throw new Error('Failed to submit baggage');
  const data = await response.json();
  
  // Transform API response to match frontend expectation
  if (data.state === 'WAITING_FOR_PAYMENT') {
    return {
      paymentRequired: true,
      paymentIntent: {
        intentId: data.paymentIntentId,
        amount: 50, // Hardcoded for now, should come from API
        status: 'PENDING' as const
      },
      state: data.state
    };
  }
  
  return {
    paymentRequired: false,
    state: data.state
  };
}

export async function completePayment(intentId: string) {
  const response = await fetch(`${API_BASE}/payments/webhook`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ intentId, status: 'succeeded' })
  });
  if (!response.ok) throw new Error('Payment failed');
  return response.json();
}
