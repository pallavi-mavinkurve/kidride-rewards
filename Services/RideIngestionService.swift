import CoreLocation
import Foundation

final class RideIngestionService: NSObject, ObservableObject {
    @Published private(set) var isTracking = false
    @Published private(set) var liveSession: LiveRideSession?

    private let locationManager = CLLocationManager()
    private var startDate: Date?
    private var previousLocation: CLLocation?
    private var totalDistanceMeters: Double = 0
    private var maxSpeedMps: Double = 0
    private var suddenBrakingEvents = 0

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
    }

    func startTracking() {
        locationManager.requestWhenInUseAuthorization()
        startDate = Date()
        previousLocation = nil
        totalDistanceMeters = 0
        maxSpeedMps = 0
        suddenBrakingEvents = 0
        isTracking = true
        liveSession = LiveRideSession(
            distanceMiles: 0,
            durationMinutes: 0,
            currentSpeedMph: 0,
            maxSpeedMph: 0,
            suddenBrakingEvents: 0,
            latestLocation: nil
        )
        locationManager.startUpdatingLocation()
    }

    func stopTrackingAndBuildSubmission() -> RideSubmissionInput? {
        guard isTracking else { return nil }
        locationManager.stopUpdatingLocation()
        isTracking = false

        guard let startDate else {
            liveSession = nil
            return nil
        }

        let durationMinutes = max(1, Int(Date().timeIntervalSince(startDate) / 60))
        let distanceMiles = totalDistanceMeters * 0.000621371
        let averageSpeedMph = durationMinutes > 0 ? distanceMiles / (Double(durationMinutes) / 60.0) : 0
        let maxSpeedMph = maxSpeedMps * 2.23694
        let geofenceBreaches = 0

        let input = RideSubmissionInput(
            distanceMiles: max(0.1, distanceMiles),
            durationMinutes: durationMinutes,
            averageSpeedMph: max(0.5, averageSpeedMph),
            maxSpeedMph: max(1.0, maxSpeedMph),
            safetyBreakdown: SafetyBreakdown(
                speedZoneCompliance: estimateSpeedZoneCompliance(maxSpeedMph: maxSpeedMph),
                suddenBrakingEvents: suddenBrakingEvents,
                fallsDetected: 0,
                maintenanceHealth: 95,
                geofenceBreaches: geofenceBreaches
            )
        )

        liveSession = nil
        return input
    }

    private func updateLiveSession(with location: CLLocation) {
        guard let startDate else { return }
        let durationMinutes = max(0, Int(Date().timeIntervalSince(startDate) / 60))
        let distanceMiles = totalDistanceMeters * 0.000621371
        let currentSpeedMph = max(0, location.speed) * 2.23694
        let maxSpeedMph = maxSpeedMps * 2.23694
        let rideLocation = RideLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracyMeters: location.horizontalAccuracy
        )
        liveSession = LiveRideSession(
            distanceMiles: distanceMiles,
            durationMinutes: durationMinutes,
            currentSpeedMph: currentSpeedMph,
            maxSpeedMph: maxSpeedMph,
            suddenBrakingEvents: suddenBrakingEvents,
            latestLocation: rideLocation
        )
    }

    private func estimateSpeedZoneCompliance(maxSpeedMph: Double) -> Int {
        if maxSpeedMph <= 15 { return 98 }
        if maxSpeedMph <= 18 { return 92 }
        if maxSpeedMph <= 22 { return 86 }
        return 76
    }
}

extension RideIngestionService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking, let location = locations.last else { return }

        if let previousLocation {
            let delta = max(0, location.distance(from: previousLocation))
            totalDistanceMeters += delta

            let prevSpeed = max(0, previousLocation.speed)
            let currentSpeed = max(0, location.speed)
            let timeDelta = location.timestamp.timeIntervalSince(previousLocation.timestamp)
            if timeDelta > 0, timeDelta <= 3.0, (prevSpeed - currentSpeed) >= 3.5 {
                suddenBrakingEvents += 1
            }
        }

        maxSpeedMps = max(maxSpeedMps, max(0, location.speed))
        previousLocation = location
        updateLiveSession(with: location)
    }
}
