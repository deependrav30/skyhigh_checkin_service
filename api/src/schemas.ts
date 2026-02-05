import { Type } from '@sinclair/typebox';

export const SeatState = Type.Union([
  Type.Literal('AVAILABLE'),
  Type.Literal('HELD'),
  Type.Literal('CONFIRMED'),
  Type.Literal('CANCELLED')
]);

export const Seat = Type.Object({
  seatId: Type.String(),
  state: SeatState,
  heldBy: Type.Optional(Type.Union([Type.String(), Type.Null()])),
  holdExpiresAt: Type.Optional(Type.Union([Type.String({ format: 'date-time' }), Type.Null()]))
});

export const SeatMapResponse = Type.Object({
  flightId: Type.String(),
  lastUpdated: Type.String({ format: 'date-time' }),
  seats: Type.Array(Seat)
});

export const PnrLoginRequest = Type.Object({
  pnr: Type.String(),
  lastName: Type.String()
});

export const PnrLoginResponse = Type.Object({
  checkinId: Type.String(),
  flightId: Type.String(),
  passenger: Type.Object({
    firstName: Type.String(),
    lastName: Type.String()
  }),
  seatMap: SeatMapResponse,
  currentSeat: Type.Optional(Type.Union([Type.String(), Type.Null()]))
});

export const HoldRequest = Type.Object({
  passengerId: Type.String()
});

export const HoldResponse = Type.Object({
  holdId: Type.String(),
  seatId: Type.String(),
  flightId: Type.String(),
  state: Type.Literal('HELD'),
  holdExpiresAt: Type.String({ format: 'date-time' })
});

export const ConfirmResponse = Type.Object({
  seatId: Type.String(),
  flightId: Type.String(),
  state: Type.Literal('CONFIRMED')
});

export const CancelRequest = Type.Object({
  reason: Type.Optional(Type.String()),
  actorRole: Type.Optional(Type.Union([Type.Literal('passenger'), Type.Literal('agent')]))
});

export const CancelResponse = Type.Object({
  seatId: Type.String(),
  flightId: Type.String(),
  state: Type.Union([Type.Literal('CANCELLED'), Type.Literal('AVAILABLE')])
});

export const WaitlistRequest = Type.Object({
  passengerId: Type.String(),
  preferences: Type.Optional(Type.Record(Type.String(), Type.Any()))
});

export const WaitlistResponse = Type.Object({
  entryId: Type.String(),
  flightId: Type.String(),
  status: Type.Union([Type.Literal('QUEUED'), Type.Literal('ASSIGNED')])
});

export const BaggageRequest = Type.Object({
  weightKg: Type.Number()
});

export const BaggageResponse = Type.Object({
  checkinId: Type.String(),
  state: Type.Union([Type.Literal('IN_PROGRESS'), Type.Literal('WAITING_FOR_PAYMENT'), Type.Literal('COMPLETED')]),
  paymentIntentId: Type.Optional(Type.Union([Type.String(), Type.Null()]))
});

export const PaymentWebhookRequest = Type.Object({
  intentId: Type.String(),
  status: Type.Union([Type.Literal('succeeded'), Type.Literal('failed')]),
  providerIdempotencyKey: Type.Optional(Type.String())
});

export const PaymentWebhookResponse = Type.Object({
  intentId: Type.String(),
  status: Type.Union([Type.Literal('succeeded'), Type.Literal('failed')]),
  checkinId: Type.Optional(Type.String())
});
