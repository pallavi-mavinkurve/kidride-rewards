import Foundation

protocol TelematicsService {
    func fetchRiderProfile() -> RiderProfile
    func fetchRidesForLastYear() -> [RideTelemetry]
    func fetchBadges(for rides: [RideTelemetry]) -> [Badge]
    func fetchGeofenceZones() -> [GeofenceZone]
    func fetchGeofenceAlerts() -> [GeofenceAlert]
    func fetchStoreItems() -> [StoreItem]
    func fetchHelpRequests() -> [HelpRequest]
    func submitRideTelemetry(_ input: RideSubmissionInput, by child: AppUser) async throws -> RideTelemetry
    func updateGeofenceZone(_ zone: GeofenceZone, active: Bool, by user: AppUser) async throws -> GeofenceZone
    func redeemStoreItem(_ item: StoreItem, by parent: AppUser) async throws -> WalletTransaction
    func acknowledgeGeofenceAlert(_ alert: GeofenceAlert, by parent: AppUser) async throws
    func requestHelp(message: String, urgency: HelpUrgency, by child: AppUser, location: RideLocation?) async throws -> HelpRequest
    func acknowledgeHelpRequest(_ request: HelpRequest, by parent: AppUser) async throws -> HelpRequest
}

struct MockTelematicsService: TelematicsService {
    func fetchRiderProfile() -> RiderProfile {
        RiderProfile(name: "Mia", age: 11, avatar: "figure.outdoor.cycle")
    }

    func fetchRidesForLastYear() -> [RideTelemetry] {
        let calendar = Calendar.current
        let today = Date()

        return (0..<365).compactMap { day in
            guard let date = calendar.date(byAdding: .day, value: -day, to: today) else {
                return nil
            }

            // Simulate 70% ride activity days in a year.
            guard Double.random(in: 0...1) < 0.7 else {
                return nil
            }

            let distance = Double.random(in: 0.8...7.2)
            let duration = Int((distance / Double.random(in: 7.0...12.0)) * 60.0)
            let avgSpeed = Double.random(in: 6.5...13.5)
            let maxSpeed = avgSpeed + Double.random(in: 2.0...6.0)

            let breakdown = SafetyBreakdown(
                speedZoneCompliance: Int.random(in: 80...100),
                suddenBrakingEvents: Int.random(in: 0...3),
                fallsDetected: Int.random(in: 0...1),
                maintenanceHealth: Int.random(in: 85...100),
                geofenceBreaches: Int.random(in: 0...1)
            )

            let safety = calculateSafetyScore(from: breakdown)
            let points = calculatePoints(distanceMiles: distance, safetyScore: safety)
            let coins = max(1, points / 10)

            return RideTelemetry(
                date: date,
                distanceMiles: distance,
                durationMinutes: duration,
                averageSpeedMph: avgSpeed,
                maxSpeedMph: maxSpeed,
                safetyBreakdown: breakdown,
                safetyScore: safety,
                pointsEarned: points,
                virtualCoinsEarned: coins
            )
        }
        .sorted(by: { $0.date > $1.date })
    }

    func fetchBadges(for rides: [RideTelemetry]) -> [Badge] {
        let totalDistance = rides.reduce(0.0) { $0 + $1.distanceMiles }
        let bestSafety = rides.map(\.safetyScore).max() ?? 0
        let totalCoins = rides.reduce(0) { $0 + $1.virtualCoinsEarned }

        return [
            Badge(
                title: "First Wheel Win",
                subtitle: "Complete your first tracked ride",
                icon: "star.fill",
                isUnlocked: !rides.isEmpty
            ),
            Badge(
                title: "Road Ranger",
                subtitle: "Ride 75 miles this year",
                icon: "figure.outdoor.cycle.circle.fill",
                isUnlocked: totalDistance >= 75
            ),
            Badge(
                title: "Safety Champ",
                subtitle: "Hit a 95+ safety score",
                icon: "checkmark.shield.fill",
                isUnlocked: bestSafety >= 95
            ),
            Badge(
                title: "Coin Collector",
                subtitle: "Earn 500 virtual coins",
                icon: "dollarsign.circle.fill",
                isUnlocked: totalCoins >= 500
            )
        ]
    }

    func fetchGeofenceZones() -> [GeofenceZone] {
        [
            GeofenceZone(id: "zone-home", name: "Home Safe Zone", radiusMeters: 650, active: true),
            GeofenceZone(id: "zone-school", name: "School Route", radiusMeters: 1200, active: true),
            GeofenceZone(id: "zone-park", name: "City Park", radiusMeters: 400, active: false)
        ]
    }

    func fetchGeofenceAlerts() -> [GeofenceAlert] {
        [
            GeofenceAlert(
                date: Date().addingTimeInterval(-3_600 * 4),
                zoneName: "School Route",
                message: "Mia exited the School Route geofence.",
                acknowledged: false
            ),
            GeofenceAlert(
                date: Date().addingTimeInterval(-3_600 * 28),
                zoneName: "Home Safe Zone",
                message: "Mia re-entered Home Safe Zone.",
                acknowledged: true
            )
        ]
    }

    func fetchStoreItems() -> [StoreItem] {
        [
            StoreItem(
                id: "item-bike-light",
                title: "Bike Light Upgrade",
                description: "Rechargeable safety light set",
                coinCost: 130,
                icon: "lightbulb.max.fill"
            ),
            StoreItem(
                id: "item-weekend-pass",
                title: "Weekend Ride Pass",
                description: "Special family trail access",
                coinCost: 220,
                icon: "map.fill"
            ),
            StoreItem(
                id: "item-stickers",
                title: "Helmet Sticker Pack",
                description: "Fun reflective sticker set",
                coinCost: 60,
                icon: "sparkles"
            )
        ]
    }

    func fetchHelpRequests() -> [HelpRequest] {
        [
            HelpRequest(
                id: "help-1",
                familyId: "FAM-1001",
                childUserId: "child-mia",
                requestedAt: Date().addingTimeInterval(-3600 * 10),
                message: "Bike chain got stuck near school.",
                urgency: .medium,
                location: RideLocation(latitude: 37.3347, longitude: -122.0089, horizontalAccuracyMeters: 21),
                status: .acknowledged
            )
        ]
    }

    func updateGeofenceZone(_ zone: GeofenceZone, active: Bool, by user: AppUser) async throws -> GeofenceZone {
        guard user.role == .parent else {
            throw AuthError.invalidCredentials
        }
        return GeofenceZone(id: zone.id, name: zone.name, radiusMeters: zone.radiusMeters, active: active)
    }

    func submitRideTelemetry(_ input: RideSubmissionInput, by child: AppUser) async throws -> RideTelemetry {
        guard child.role == .child else {
            throw AuthError.invalidCredentials
        }

        let safety = calculateSafetyScore(from: input.safetyBreakdown)
        let points = calculatePoints(distanceMiles: input.distanceMiles, safetyScore: safety)
        let coins = max(1, points / 10)

        return RideTelemetry(
            date: Date(),
            distanceMiles: input.distanceMiles,
            durationMinutes: input.durationMinutes,
            averageSpeedMph: input.averageSpeedMph,
            maxSpeedMph: input.maxSpeedMph,
            safetyBreakdown: input.safetyBreakdown,
            safetyScore: safety,
            pointsEarned: points,
            virtualCoinsEarned: coins
        )
    }

    func redeemStoreItem(_ item: StoreItem, by parent: AppUser) async throws -> WalletTransaction {
        guard parent.role == .parent else {
            throw AuthError.invalidCredentials
        }
        return WalletTransaction(
            id: "tx-\(UUID().uuidString)",
            date: Date(),
            amount: -item.coinCost,
            reason: "Parent redeemed \(item.title)"
        )
    }

    func acknowledgeGeofenceAlert(_ alert: GeofenceAlert, by parent: AppUser) async throws {
        guard parent.role == .parent else {
            throw AuthError.invalidCredentials
        }
        _ = alert
    }

    func requestHelp(message: String, urgency: HelpUrgency, by child: AppUser, location: RideLocation?) async throws -> HelpRequest {
        guard child.role == .child else {
            throw AuthError.invalidCredentials
        }
        return HelpRequest(
            id: "help-\(UUID().uuidString)",
            familyId: child.familyId,
            childUserId: child.id,
            requestedAt: Date(),
            message: message.isEmpty ? "Need help right now." : message,
            urgency: urgency,
            location: location,
            status: .pending
        )
    }

    func acknowledgeHelpRequest(_ request: HelpRequest, by parent: AppUser) async throws -> HelpRequest {
        guard parent.role == .parent else {
            throw AuthError.invalidCredentials
        }
        return HelpRequest(
            id: request.id,
            familyId: request.familyId,
            childUserId: request.childUserId,
            requestedAt: request.requestedAt,
            message: request.message,
            urgency: request.urgency,
            location: request.location,
            status: .acknowledged
        )
    }

    private func calculateSafetyScore(from breakdown: SafetyBreakdown) -> Int {
        let brakingPenalty = breakdown.suddenBrakingEvents * 4
        let fallPenalty = breakdown.fallsDetected * 22
        let geofencePenalty = breakdown.geofenceBreaches * 8
        let maintenancePenalty = max(0, 92 - breakdown.maintenanceHealth)

        let weighted = Int(
            Double(breakdown.speedZoneCompliance) * 0.5 +
            Double(breakdown.maintenanceHealth) * 0.25 +
            Double(100 - brakingPenalty) * 0.15 +
            Double(100 - geofencePenalty - fallPenalty - maintenancePenalty) * 0.10
        )

        return min(100, max(45, weighted))
    }

    private func calculatePoints(distanceMiles: Double, safetyScore: Int) -> Int {
        let safetyMultiplier = max(0.7, Double(safetyScore) / 100.0)
        let base = distanceMiles * 22.0
        return Int(base * safetyMultiplier)
    }
}
