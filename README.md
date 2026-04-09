# KidRide Rewards - SwiftUI Starter

A modern SwiftUI starter app for a kid e-bike gamification experience with:

- Points and loyalty progression
- Badge achievements
- Daily telematics dashboards
- Parent-friendly shareable summaries
- Navy blue and white modern design system

## Features in this starter

- Child/parent auth screens with email/password and registration
- Dashboard with period selector (`Weekly`, `Monthly`, `Quarterly`, `Yearly`)
- Safety score, badges, points, and virtual currency for selected period
- Telematics model with GPS speed-zone compliance, sudden braking, falls, maintenance health, and geofence breaches
- Points based on safe daily miles and safety multipliers
- Parent hub with geofencing controls, geofence alerts, and in-app reward purchases from virtual currency
- GPS ride tracking (start/stop ride ingestion in app)
- Safety Center with emergency help requests for kids and parent acknowledgment flow
- Shareable parent report via `ShareLink`
- Mock service layer ready to swap with real APIs

### Demo auth (mock fallback)

- Parent: `taylor@kidride.app` / `password123`
- Child: `mia@kidride.app` / `password123`
- Child registration uses family code: `FAM-1001`

## Run in Xcode

1. Open Xcode.
2. Create a new **iOS App** project named `KidRideRewards`.
3. Set interface to **SwiftUI** and language to **Swift**.
4. Replace the generated files with the files from this folder:
   - `KidRideRewardsApp.swift`
   - `Models/`
   - `Services/`
   - `ViewModels/`
   - `Views/`
5. Ensure deployment target is **iOS 17+** (for best compatibility with this starter).
6. Build and run.

## Firebase setup in Xcode

1. Add Swift Package dependency:
   - `https://github.com/firebase/firebase-ios-sdk`
2. Add products to your app target:
   - `FirebaseCore`
   - `FirebaseAuth`
   - `FirebaseFirestore`
   - `FirebaseFunctions`
3. Add your `GoogleService-Info.plist` to the app target.
4. Keep `KidRideRewardsApp.swift` using `BackendFactory.make(provider: .firebase)`.
5. If Firebase is not configured yet, the app gracefully falls back to mock services.
6. Create Firestore collections from `docs/firebase-schema.md`.
7. Add location usage key in your app `Info.plist`:
   - `NSLocationWhenInUseUsageDescription` (required for ride ingestion).

## Recommended backend

Use **Firebase**:

- **Firebase Auth**: parent and child account sign-in
- **Cloud Firestore**: rider profiles, rides, badges, wallet, geofence configs, alerts
- **Cloud Functions**: server-side point calculation, badge unlock logic, purchase validation
- **Firebase Cloud Messaging**: geofence and safety push alerts to parents

This is the best fit for real-time mobile features and secure parent-controlled rewards.

## Auth model to implement (production)

- Parent account owns one or more child profiles
- Child has restricted app permissions (no purchases/geofence edits)
- Parent can configure geofences, receive alerts, and redeem virtual currency purchases
- Enforce role checks in Cloud Functions before any wallet deduction or geofence mutation
- Firestore rules starter: `firebase/firestore.rules`
- Firestore indexes starter: `firebase/firestore.indexes.json`
- Firestore schema reference: `docs/firebase-schema.md`
- Cloud Functions reference: `docs/cloud-functions.md`

## Next integration steps

- Replace `MockTelematicsService` and `MockAuthService` with Firebase-backed services
- Persist geofence zones and alert acknowledgements in Firestore
- Add Stripe/App Store payments if parents can buy extra currency packs
- Add privacy controls and consent settings
- Add push notifications for streaks and milestones
- Add cloud sync for family devices

## Cloud Functions (included scaffold)

- Source lives in `functions/` (TypeScript)
- Includes callable functions for ride scoring, reward redemption, alert acknowledgment
- Includes Firestore triggers for badge recomputation and geofence push alerts
- iOS `RideHistory` now includes a child-only `Log Ride` action that calls `submitRideTelemetry`
- Deploy with:
  - `cd functions && npm install`
  - `npm run deploy`
