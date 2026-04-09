import Combine
import Foundation

final class DashboardViewModel: ObservableObject {
    @Published private(set) var signedInUser: AppUser?
    @Published var selectedRange: TimeRange = .weekly
    @Published var authErrorMessage: String?
    @Published var isAuthenticating = false
    @Published var actionMessage: String?
    @Published var helpMessageDraft = ""
    @Published var helpUrgency: HelpUrgency = .high
    @Published private(set) var profile: RiderProfile
    @Published private(set) var rides: [RideTelemetry]
    @Published private(set) var badges: [Badge]
    @Published private(set) var geofenceZones: [GeofenceZone]
    @Published private(set) var geofenceAlerts: [GeofenceAlert]
    @Published private(set) var helpRequests: [HelpRequest]
    @Published private(set) var storeItems: [StoreItem]
    @Published private(set) var transactions: [WalletTransaction]
    @Published private(set) var loyalty: LoyaltyProgress
    @Published private(set) var liveRideSession: LiveRideSession?

    private let authService: AuthService
    private let service: TelematicsService
    private let rideIngestion: RideIngestionService
    private var cancellables: Set<AnyCancellable> = []

    init(service: TelematicsService, authService: AuthService) {
        self.service = service
        self.authService = authService
        self.rideIngestion = RideIngestionService()

        let profile = service.fetchRiderProfile()
        let rides = service.fetchRidesForLastYear()
        let badges = service.fetchBadges(for: rides)
        let zones = service.fetchGeofenceZones()
        let alerts = service.fetchGeofenceAlerts()
        let helpRequests = service.fetchHelpRequests()
        let storeItems = service.fetchStoreItems()

        self.profile = profile
        self.rides = rides
        self.badges = badges
        self.geofenceZones = zones
        self.geofenceAlerts = alerts
        self.helpRequests = helpRequests
        self.storeItems = storeItems
        self.transactions = []
        self.loyalty = DashboardViewModel.buildLoyaltyProgress(from: rides, selectedRange: .weekly)

        rideIngestion.$liveSession
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                self?.liveRideSession = session
            }
            .store(in: &cancellables)
    }

    var isAuthenticated: Bool {
        signedInUser != nil
    }

    var userRole: UserRole? {
        signedInUser?.role
    }

    var isParent: Bool {
        userRole == .parent
    }

    var isChild: Bool {
        userRole == .child
    }

    var isRideTracking: Bool {
        rideIngestion.isTracking
    }

    var filteredRides: [RideTelemetry] {
        let fromDate = Calendar.current.date(byAdding: .day, value: -selectedRange.days + 1, to: Date()) ?? Date()
        return rides.filter { $0.date >= fromDate }
    }

    var currentCoinsBalance: Int {
        let earned = rides.reduce(0) { $0 + $1.virtualCoinsEarned }
        let spent = transactions.reduce(0) { $0 + max(0, -$1.amount) }
        return max(0, earned - spent)
    }

    func signIn(email: String, password: String, role: UserRole) {
        isAuthenticating = true
        authErrorMessage = nil

        Task { @MainActor in
            do {
                let user = try await authService.signIn(email: email, password: password, role: role)
                signedInUser = user
                recalculate()
            } catch {
                authErrorMessage = (error as? LocalizedError)?.errorDescription ?? AuthError.unknown.errorDescription
            }
            isAuthenticating = false
        }
    }

    func register(name: String, email: String, password: String, role: UserRole, familyCode: String?) {
        isAuthenticating = true
        authErrorMessage = nil

        Task { @MainActor in
            do {
                let user = try await authService.register(
                    name: name,
                    email: email,
                    password: password,
                    role: role,
                    familyCode: familyCode
                )
                signedInUser = user
                recalculate()
                if role == .parent {
                    actionMessage = "Parent account created. Share family code \(user.familyId) with your child."
                }
            } catch {
                authErrorMessage = (error as? LocalizedError)?.errorDescription ?? AuthError.unknown.errorDescription
            }
            isAuthenticating = false
        }
    }

    func signOut() {
        Task { @MainActor in
            await authService.signOut()
            signedInUser = nil
            actionMessage = nil
        }
    }

    func updateRange(_ range: TimeRange) {
        selectedRange = range
        recalculate()
    }

    func logDemoRideForCurrentChild() {
        guard let user = signedInUser, user.role == .child else { return }

        let input = RideSubmissionInput(
            distanceMiles: Double.random(in: 1.2...6.8),
            durationMinutes: Int.random(in: 10...44),
            averageSpeedMph: Double.random(in: 7.0...12.0),
            maxSpeedMph: Double.random(in: 12.0...19.0),
            safetyBreakdown: SafetyBreakdown(
                speedZoneCompliance: Int.random(in: 84...100),
                suddenBrakingEvents: Int.random(in: 0...2),
                fallsDetected: Int.random(in: 0...1),
                maintenanceHealth: Int.random(in: 86...100),
                geofenceBreaches: Int.random(in: 0...1)
            )
        )

        Task { @MainActor in
            do {
                let newRide = try await service.submitRideTelemetry(input, by: user)
                rides.insert(newRide, at: 0)
                badges = service.fetchBadges(for: rides)
                recalculate()
                actionMessage = "Ride submitted. +\(newRide.pointsEarned) points, +\(newRide.virtualCoinsEarned) coins."
            } catch {
                actionMessage = "Unable to submit ride telemetry."
            }
        }
    }

    func startRideTracking() {
        guard isChild else { return }
        rideIngestion.startTracking()
        actionMessage = "Ride tracking started."
    }

    func stopAndSubmitTrackedRide() {
        guard let user = signedInUser, user.role == .child else { return }
        guard let input = rideIngestion.stopTrackingAndBuildSubmission() else {
            actionMessage = "No ride session found to submit."
            return
        }

        Task { @MainActor in
            do {
                let newRide = try await service.submitRideTelemetry(input, by: user)
                rides.insert(newRide, at: 0)
                badges = service.fetchBadges(for: rides)
                recalculate()
                actionMessage = "Ride saved with safety score \(newRide.safetyScore)."
            } catch {
                actionMessage = "Unable to submit tracked ride."
            }
        }
    }

    func buy(_ item: StoreItem) {
        guard
            isParent,
            currentCoinsBalance >= item.coinCost,
            let parent = signedInUser
        else { return }

        Task { @MainActor in
            do {
                let tx = try await service.redeemStoreItem(item, by: parent)
                transactions.insert(tx, at: 0)
                actionMessage = "Purchase complete: \(item.title)"
            } catch {
                actionMessage = "Unable to process purchase."
            }
        }
    }

    func toggleZoneActive(_ zone: GeofenceZone) {
        guard isParent, let parent = signedInUser else { return }

        Task { @MainActor in
            do {
                let updated = try await service.updateGeofenceZone(zone, active: !zone.active, by: parent)
                geofenceZones = geofenceZones.map { current in
                    guard current.id == zone.id else { return current }
                    return updated
                }
                actionMessage = "\(updated.name) \(updated.active ? "enabled" : "disabled")."
            } catch {
                actionMessage = "Unable to update geofence."
            }
        }
    }

    func acknowledgeAlert(_ alert: GeofenceAlert) {
        guard isParent, let parent = signedInUser else { return }
        guard !alert.acknowledged else { return }

        Task { @MainActor in
            do {
                try await service.acknowledgeGeofenceAlert(alert, by: parent)
                geofenceAlerts = geofenceAlerts.map { existing in
                    guard existing.id == alert.id else { return existing }
                    return GeofenceAlert(
                        id: existing.id,
                        date: existing.date,
                        zoneName: existing.zoneName,
                        message: existing.message,
                        acknowledged: true
                    )
                }
                actionMessage = "Alert acknowledged."
            } catch {
                actionMessage = "Unable to acknowledge alert."
            }
        }
    }

    func requestHelpNow() {
        guard let child = signedInUser, child.role == .child else { return }

        let location = liveRideSession?.latestLocation
        let message = helpMessageDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        Task { @MainActor in
            do {
                let request = try await service.requestHelp(
                    message: message.isEmpty ? "I need help right now." : message,
                    urgency: helpUrgency,
                    by: child,
                    location: location
                )
                helpRequests.insert(request, at: 0)
                helpMessageDraft = ""
                actionMessage = "Help request sent to your parents."
            } catch {
                actionMessage = "Unable to send help request."
            }
        }
    }

    func acknowledgeHelpRequest(_ request: HelpRequest) {
        guard let parent = signedInUser, parent.role == .parent else { return }
        guard request.status == .pending else { return }

        Task { @MainActor in
            do {
                let updated = try await service.acknowledgeHelpRequest(request, by: parent)
                helpRequests = helpRequests.map { item in
                    guard item.id == updated.id else { return item }
                    return updated
                }
                actionMessage = "Help request acknowledged."
            } catch {
                actionMessage = "Unable to acknowledge help request."
            }
        }
    }

    var periodDistanceMiles: Double {
        filteredRides.reduce(0.0) { $0 + $1.distanceMiles }
    }

    var periodAverageSafetyScore: Int {
        guard !filteredRides.isEmpty else { return 0 }
        let total = filteredRides.reduce(0) { $0 + $1.safetyScore }
        return total / filteredRides.count
    }

    var parentSummary: ParentSummary {
        ParentSummary(
            childName: profile.name,
            range: selectedRange,
            distanceMiles: periodDistanceMiles,
            rideCount: filteredRides.count,
            averageSafetyScore: periodAverageSafetyScore,
            totalPoints: loyalty.periodPoints,
            totalCoins: loyalty.periodCoins,
            unlockedBadges: badges.filter(\.isUnlocked).count
        )
    }

    var parentShareText: String {
        let summary = parentSummary
        return """
        \(summary.childName)'s \(summary.range.rawValue) E-Bike Report
        - Rides: \(summary.rideCount)
        - Distance: \(String(format: "%.1f", summary.distanceMiles)) miles
        - Average safety score: \(summary.averageSafetyScore)/100
        - Points: \(summary.totalPoints)
        - Virtual currency: \(summary.totalCoins) coins
        - Unlocked badges: \(summary.unlockedBadges)
        """
    }

    var pointsByDay: [(day: String, points: Int)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return filteredRides
            .sorted(by: { $0.date < $1.date })
            .map { (formatter.string(from: $0.date), $0.pointsEarned) }
    }

    private func recalculate() {
        loyalty = DashboardViewModel.buildLoyaltyProgress(from: rides, selectedRange: selectedRange)
    }

    private static func buildLoyaltyProgress(from rides: [RideTelemetry], selectedRange: TimeRange) -> LoyaltyProgress {
        let fromDate = Calendar.current.date(byAdding: .day, value: -selectedRange.days + 1, to: Date()) ?? Date()
        let periodRides = rides.filter { $0.date >= fromDate }
        let totalPoints = rides.reduce(0) { $0 + $1.pointsEarned }
        let periodPoints = periodRides.reduce(0) { $0 + $1.pointsEarned }
        let periodCoins = periodRides.reduce(0) { $0 + $1.virtualCoinsEarned }

        let currentTier: (name: String, floor: Int, next: Int) = {
            switch totalPoints {
            case 0..<500: return ("Explorer", 0, 500)
            case 500..<1200: return ("Trailblazer", 500, 1200)
            case 1200..<2500: return ("Champion", 1200, 2500)
            default: return ("Legend", 2500, 2500)
            }
        }()

        let pointsToNextTier = max(0, currentTier.next - totalPoints)

        let streak = calculateStreakDays(from: rides)

        return LoyaltyProgress(
            totalPoints: totalPoints,
            tierName: currentTier.name,
            pointsToNextTier: pointsToNextTier,
            periodPoints: periodPoints,
            periodCoins: periodCoins,
            rideStreakDays: streak
        )
    }

    private static func calculateStreakDays(from rides: [RideTelemetry]) -> Int {
        let calendar = Calendar.current
        let rideDays = Set(rides.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var cursor = calendar.startOfDay(for: Date())

        while rideDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }

        return streak
    }
}
