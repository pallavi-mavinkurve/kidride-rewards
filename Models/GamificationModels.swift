import Foundation

struct RiderProfile {
    let name: String
    let age: Int
    let avatar: String
}

enum UserRole: String, CaseIterable, Identifiable {
    case child
    case parent

    var id: String { rawValue }
}

struct AppUser {
    let id: String
    let name: String
    let email: String
    let role: UserRole
    let familyId: String
    let managedChildUserId: String?
}

enum TimeRange: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .weekly: return 7
        case .monthly: return 30
        case .quarterly: return 90
        case .yearly: return 365
        }
    }
}

struct SafetyBreakdown {
    let speedZoneCompliance: Int
    let suddenBrakingEvents: Int
    let fallsDetected: Int
    let maintenanceHealth: Int
    let geofenceBreaches: Int
}

struct RideSubmissionInput {
    let distanceMiles: Double
    let durationMinutes: Int
    let averageSpeedMph: Double
    let maxSpeedMph: Double
    let safetyBreakdown: SafetyBreakdown
}

struct RideLocation {
    let latitude: Double
    let longitude: Double
    let horizontalAccuracyMeters: Double
}

struct LiveRideSession {
    let distanceMiles: Double
    let durationMinutes: Int
    let currentSpeedMph: Double
    let maxSpeedMph: Double
    let suddenBrakingEvents: Int
    let latestLocation: RideLocation?
}

enum HelpRequestStatus: String {
    case pending
    case acknowledged
    case resolved
}

enum HelpUrgency: String, CaseIterable, Identifiable {
    case high
    case medium
    case low

    var id: String { rawValue }
}

struct HelpRequest: Identifiable {
    let id: String
    let familyId: String
    let childUserId: String
    let requestedAt: Date
    let message: String
    let urgency: HelpUrgency
    let location: RideLocation?
    let status: HelpRequestStatus
}

struct RideTelemetry: Identifiable {
    let id = UUID()
    let date: Date
    let distanceMiles: Double
    let durationMinutes: Int
    let averageSpeedMph: Double
    let maxSpeedMph: Double
    let safetyBreakdown: SafetyBreakdown
    let safetyScore: Int
    let pointsEarned: Int
    let virtualCoinsEarned: Int
}

struct Badge: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let isUnlocked: Bool
}

struct LoyaltyProgress {
    let totalPoints: Int
    let tierName: String
    let pointsToNextTier: Int
    let periodPoints: Int
    let periodCoins: Int
    let rideStreakDays: Int
}

struct ParentSummary {
    let childName: String
    let range: TimeRange
    let distanceMiles: Double
    let rideCount: Int
    let averageSafetyScore: Int
    let totalPoints: Int
    let totalCoins: Int
    let unlockedBadges: Int
}

struct GeofenceZone: Identifiable {
    let id: String
    let name: String
    let radiusMeters: Int
    let active: Bool

    init(id: String = UUID().uuidString, name: String, radiusMeters: Int, active: Bool) {
        self.id = id
        self.name = name
        self.radiusMeters = radiusMeters
        self.active = active
    }
}

struct GeofenceAlert: Identifiable {
    let id: String
    let date: Date
    let zoneName: String
    let message: String
    let acknowledged: Bool

    init(id: String = UUID().uuidString, date: Date, zoneName: String, message: String, acknowledged: Bool) {
        self.id = id
        self.date = date
        self.zoneName = zoneName
        self.message = message
        self.acknowledged = acknowledged
    }
}

struct StoreItem: Identifiable {
    let id: String
    let title: String
    let description: String
    let coinCost: Int
    let icon: String

    init(id: String = UUID().uuidString, title: String, description: String, coinCost: Int, icon: String) {
        self.id = id
        self.title = title
        self.description = description
        self.coinCost = coinCost
        self.icon = icon
    }
}

struct WalletTransaction: Identifiable {
    let id: String
    let date: Date
    let amount: Int
    let reason: String

    init(id: String = UUID().uuidString, date: Date, amount: Int, reason: String) {
        self.id = id
        self.date = date
        self.amount = amount
        self.reason = reason
    }
}
