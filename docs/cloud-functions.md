# Cloud Functions Backend

This project includes Firebase Cloud Functions scaffolding in `functions/`.

## Implemented functions

- `submitRideTelemetry` (callable)
  - Child-only.
  - Validates ride payload.
  - Calculates safety score, points, and virtual coins server-side.
  - Writes `ride_telemetry`, wallet balance increment, and wallet transaction.

- `redeemReward` (callable)
  - Parent-only.
  - Validates family ownership.
  - Performs transactional coin deduction from child wallet.
  - Writes redemption transaction.

- `acknowledgeGeofenceAlert` (callable)
  - Parent-only.
  - Marks geofence alert as acknowledged.

- `requestHelp` (callable)
  - Child-only.
  - Creates emergency help request with optional location.
  - Notifies parent devices through trigger.

- `acknowledgeHelpRequest` (callable)
  - Parent-only.
  - Marks help request acknowledged.

- `processBadgesOnRide` (Firestore trigger)
  - Recomputes badges after every new ride and writes to `badges`.

- `notifyParentsOnGeofenceAlert` (Firestore trigger)
  - Sends FCM notifications to parent devices in the same family.
  - Reads tokens from `users/{uid}.deviceTokens`.

- `notifyParentsOnHelpRequest` (Firestore trigger)
  - Sends FCM emergency notification to parent devices.

## Setup

1. Install Firebase CLI:
   - `npm install -g firebase-tools`
2. Login:
   - `firebase login`
3. Select your Firebase project:
   - `firebase use --add`
4. Install functions dependencies:
   - `cd functions && npm install`
5. Build:
   - `npm run build`
6. Deploy:
   - `npm run deploy`

## Firestore auth contract

Every authenticated user must have a `users/{uid}` doc with:

- `role`: `"parent"` or `"child"`
- `familyId`: shared family identifier
- optional `displayName`, `email`, `deviceTokens`, `managedChildUserId`

## iOS integration contract

Use callable functions from app:

- Call `submitRideTelemetry` instead of writing score/points directly.
- Call `redeemReward` for parent purchase confirmation.
- Call `acknowledgeGeofenceAlert` when parent marks an alert as read.
- Call `requestHelp` when child taps emergency help.
- Call `acknowledgeHelpRequest` from parent Safety Center.
