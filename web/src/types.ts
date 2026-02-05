export type SeatState = 'AVAILABLE' | 'HELD' | 'CONFIRMED';

export interface Seat {
  seatId: string;
  state: SeatState;
  heldBy: string | null;
  holdExpiresAt: string | null;
}

export interface SeatMap {
  flightId: string;
  lastUpdated: string;
  seats: Seat[];
}

export interface CheckinSession {
  checkinId: string;
  flightId: string;
  passenger: {
    firstName: string;
    lastName: string;
  };
  seatMap: SeatMap;
  currentSeat?: string | null;
}

export interface HoldResponse {
  holdId: string;
  seatId: string;
  flightId: string;
  state: SeatState;
  holdExpiresAt: string;
}

export interface BaggageRequest {
  weight: number;
}

export interface PaymentIntent {
  intentId: string;
  amount: number;
  status: 'PENDING' | 'COMPLETED' | 'FAILED';
}
