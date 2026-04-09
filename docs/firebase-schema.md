# Firebase Data Model

## Collections

### `users/{uid}`
- `role`: `"parent"` | `"child"`
- `familyId`: string
- `managedChildUserId`: string | null (for parent accounts)
- `displayName`: string
- `email`: string
- `createdAt`: timestamp

### `rider_profiles/{profileId}`
- `familyId`: string
- `childUserId`: string
- `name`: string
- `age`: number
- `avatar`: string

### `ride_telemetry/{rideId}`
- `familyId`: string
- `childUserId`: string
- `date`: timestamp
- `distanceMiles`: number
- `durationMinutes`: number
- `averageSpeedMph`: number
- `maxSpeedMph`: number
- `speedZoneCompliance`: number (0-100)
- `suddenBrakingEvents`: number
- `fallsDetected`: number
- `maintenanceHealth`: number (0-100)
- `geofenceBreaches`: number
- `safetyScore`: number (0-100)
- `pointsEarned`: number
- `virtualCoinsEarned`: number

### `badges/{badgeId}`
- `familyId`: string
- `childUserId`: string
- `title`: string
- `subtitle`: string
- `icon`: string
- `isUnlocked`: boolean
- `unlockedAt`: timestamp | null

### `wallets/{walletId}`
- `familyId`: string
- `childUserId`: string
- `balanceCoins`: number
- `updatedAt`: timestamp

### `wallet_transactions/{transactionId}`
- `familyId`: string
- `childUserId`: string
- `parentUserId`: string | null
- `amount`: number
- `type`: `"earn"` | `"redeem"`
- `reason`: string
- `createdAt`: timestamp

### `geofence_zones/{zoneId}`
- `familyId`: string
- `name`: string
- `radiusMeters`: number
- `active`: boolean
- `centerLat`: number
- `centerLng`: number
- `updatedBy`: string
- `updatedAt`: timestamp

### `geofence_alerts/{alertId}`
- `familyId`: string
- `childUserId`: string
- `zoneName`: string
- `message`: string
- `acknowledged`: boolean
- `timestamp`: timestamp

### `store_items/{itemId}`
- `title`: string
- `description`: string
- `coinCost`: number
- `icon`: string
- `active`: boolean

### `help_requests/{requestId}`
- `familyId`: string
- `childUserId`: string
- `message`: string
- `urgency`: `"high"` | `"medium"` | `"low"`
- `status`: `"pending"` | `"acknowledged"` | `"resolved"`
- `requestedAt`: timestamp
- `latitude`: number | null
- `longitude`: number | null
- `horizontalAccuracyMeters`: number | null

## Server-side logic (Cloud Functions)

- Calculate safety score and points from telemetry payloads.
- Grant badges after score/mileage/coin thresholds.
- Validate parent-only reward redemptions and deduct wallet.
- Generate geofence alerts and push notifications to parent devices.
- Route emergency help requests from children to parent devices.
