import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

struct FirestoreTelematicsService: TelematicsService {
    private let fallback = MockTelematicsService()

    func fetchRiderProfile() -> RiderProfile {
        #if canImport(FirebaseFirestore)
        let data = fetchFirstDocument(collection: "rider_profiles")
        if
            let name = data?["name"] as? String,
            let age = data?["age"] as? Int,
            let avatar = data?["avatar"] as? String
        {
            return RiderProfile(name: name, age: age, avatar: avatar)
        }
        #endif
        return fallback.fetchRiderProfile()
    }

    func fetchRidesForLastYear() -> [RideTelemetry] {
        #if canImport(FirebaseFirestore)
        let docs = fetchDocuments(collection: "ride_telemetry")
        let rides = docs.compactMap(mapRide)
        if !rides.isEmpty {
            return rides.sorted(by: { $0.date > $1.date })
        }
        #endif
        return fallback.fetchRidesForLastYear()
    }

    func fetchBadges(for rides: [RideTelemetry]) -> [Badge] {
        // Badge rules are computed server-side in production; local fallback for now.
        fallback.fetchBadges(for: rides)
    }

    func fetchGeofenceZones() -> [GeofenceZone] {
        #if canImport(FirebaseFirestore)
        let docs = fetchDocuments(collection: "geofence_zones")
        let zones = docs.compactMap { data -> GeofenceZone? in
            guard
                let name = data["name"] as? String,
                let radius = data["radiusMeters"] as? Int,
                let active = data["active"] as? Bool
            else {
                return nil
            }
            let id = data["__id"] as? String ?? UUID().uuidString
            return GeofenceZone(id: id, name: name, radiusMeters: radius, active: active)
        }
        if !zones.isEmpty {
            return zones
        }
        #endif
        return fallback.fetchGeofenceZones()
    }

    func fetchGeofenceAlerts() -> [GeofenceAlert] {
        #if canImport(FirebaseFirestore)
        let docs = fetchDocuments(collection: "geofence_alerts")
        let alerts = docs.compactMap { data -> GeofenceAlert? in
            guard
                let zoneName = data["zoneName"] as? String,
                let message = data["message"] as? String,
                let acknowledged = data["acknowledged"] as? Bool
            else {
                return nil
            }

            let date: Date
            if let ts = data["timestamp"] as? Timestamp {
                date = ts.dateValue()
            } else if let rawDate = data["timestamp"] as? Date {
                date = rawDate
            } else {
                date = Date()
            }
            return GeofenceAlert(
                id: data["__id"] as? String ?? UUID().uuidString,
                date: date,
                zoneName: zoneName,
                message: message,
                acknowledged: acknowledged
            )
        }
        if !alerts.isEmpty {
            return alerts.sorted(by: { $0.date > $1.date })
        }
        #endif
        return fallback.fetchGeofenceAlerts()
    }

    func fetchStoreItems() -> [StoreItem] {
        #if canImport(FirebaseFirestore)
        let docs = fetchDocuments(collection: "store_items")
        let items = docs.compactMap { data -> StoreItem? in
            guard
                let title = data["title"] as? String,
                let description = data["description"] as? String,
                let coinCost = data["coinCost"] as? Int,
                let icon = data["icon"] as? String
            else {
                return nil
            }
            return StoreItem(
                id: data["__id"] as? String ?? UUID().uuidString,
                title: title,
                description: description,
                coinCost: coinCost,
                icon: icon
            )
        }
        if !items.isEmpty {
            return items
        }
        #endif
        return fallback.fetchStoreItems()
    }

    func fetchHelpRequests() -> [HelpRequest] {
        #if canImport(FirebaseFirestore)
        let docs = fetchDocuments(collection: "help_requests")
        let requests = docs.compactMap { data -> HelpRequest? in
            guard
                let familyId = data["familyId"] as? String,
                let childUserId = data["childUserId"] as? String,
                let message = data["message"] as? String,
                let statusRaw = data["status"] as? String,
                let status = HelpRequestStatus(rawValue: statusRaw)
            else {
                return nil
            }
            let urgencyRaw = data["urgency"] as? String ?? HelpUrgency.medium.rawValue
            let urgency = HelpUrgency(rawValue: urgencyRaw) ?? .medium
            let requestedAt = dateFromAny(data["requestedAt"]) ?? Date()
            let location = mapLocation(data: data)

            return HelpRequest(
                id: data["__id"] as? String ?? UUID().uuidString,
                familyId: familyId,
                childUserId: childUserId,
                requestedAt: requestedAt,
                message: message,
                urgency: urgency,
                location: location,
                status: status
            )
        }
        if !requests.isEmpty {
            return requests.sorted(by: { $0.requestedAt > $1.requestedAt })
        }
        #endif
        return fallback.fetchHelpRequests()
    }

    func updateGeofenceZone(_ zone: GeofenceZone, active: Bool, by user: AppUser) async throws -> GeofenceZone {
        #if canImport(FirebaseFirestore)
        let data: [String: Any] = [
            "name": zone.name,
            "radiusMeters": zone.radiusMeters,
            "active": active,
            "familyId": user.familyId,
            "updatedBy": user.id,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await setDocument(collection: "geofence_zones", documentId: zone.id, data: data)
        return GeofenceZone(id: zone.id, name: zone.name, radiusMeters: zone.radiusMeters, active: active)
        #endif
        return try await fallback.updateGeofenceZone(zone, active: active, by: user)
    }

    func submitRideTelemetry(_ input: RideSubmissionInput, by child: AppUser) async throws -> RideTelemetry {
        #if canImport(FirebaseFunctions)
        let payload: [String: Any] = [
            "familyId": child.familyId,
            "childUserId": child.id,
            "distanceMiles": input.distanceMiles,
            "durationMinutes": input.durationMinutes,
            "averageSpeedMph": input.averageSpeedMph,
            "maxSpeedMph": input.maxSpeedMph,
            "speedZoneCompliance": input.safetyBreakdown.speedZoneCompliance,
            "suddenBrakingEvents": input.safetyBreakdown.suddenBrakingEvents,
            "fallsDetected": input.safetyBreakdown.fallsDetected,
            "maintenanceHealth": input.safetyBreakdown.maintenanceHealth,
            "geofenceBreaches": input.safetyBreakdown.geofenceBreaches
        ]
        let response = try await callFunction(name: "submitRideTelemetry", data: payload)

        let safetyScore = response["safetyScore"] as? Int ?? 85
        let pointsEarned = response["pointsEarned"] as? Int ?? 40
        let virtualCoinsEarned = response["virtualCoinsEarned"] as? Int ?? 4

        return RideTelemetry(
            date: Date(),
            distanceMiles: input.distanceMiles,
            durationMinutes: input.durationMinutes,
            averageSpeedMph: input.averageSpeedMph,
            maxSpeedMph: input.maxSpeedMph,
            safetyBreakdown: input.safetyBreakdown,
            safetyScore: safetyScore,
            pointsEarned: pointsEarned,
            virtualCoinsEarned: virtualCoinsEarned
        )
        #endif
        return try await fallback.submitRideTelemetry(input, by: child)
    }

    func redeemStoreItem(_ item: StoreItem, by parent: AppUser) async throws -> WalletTransaction {
        #if canImport(FirebaseFunctions)
        guard let childUserId = parent.managedChildUserId else {
            throw AuthError.childProfileNotLinked
        }
        let payload: [String: Any] = [
            "childUserId": childUserId,
            "coinCost": item.coinCost,
            "itemTitle": item.title
        ]
        let response = try await callFunction(name: "redeemReward", data: payload)
        let transactionId = response["transactionId"] as? String ?? "tx-\(UUID().uuidString)"
        return WalletTransaction(
            id: transactionId,
            date: Date(),
            amount: -item.coinCost,
            reason: "Parent redeemed \(item.title)"
        )
        #endif
        return try await fallback.redeemStoreItem(item, by: parent)
    }

    func acknowledgeGeofenceAlert(_ alert: GeofenceAlert, by parent: AppUser) async throws {
        #if canImport(FirebaseFunctions)
        _ = try await callFunction(
            name: "acknowledgeGeofenceAlert",
            data: ["alertId": alert.id]
        )
        return
        #endif
        try await fallback.acknowledgeGeofenceAlert(alert, by: parent)
    }

    func requestHelp(message: String, urgency: HelpUrgency, by child: AppUser, location: RideLocation?) async throws -> HelpRequest {
        #if canImport(FirebaseFunctions)
        var payload: [String: Any] = [
            "message": message,
            "urgency": urgency.rawValue
        ]
        if let location {
            payload["latitude"] = location.latitude
            payload["longitude"] = location.longitude
            payload["horizontalAccuracyMeters"] = location.horizontalAccuracyMeters
        }
        let response = try await callFunction(name: "requestHelp", data: payload)
        let requestId = response["requestId"] as? String ?? "help-\(UUID().uuidString)"

        return HelpRequest(
            id: requestId,
            familyId: child.familyId,
            childUserId: child.id,
            requestedAt: Date(),
            message: message,
            urgency: urgency,
            location: location,
            status: .pending
        )
        #endif
        return try await fallback.requestHelp(message: message, urgency: urgency, by: child, location: location)
    }

    func acknowledgeHelpRequest(_ request: HelpRequest, by parent: AppUser) async throws -> HelpRequest {
        #if canImport(FirebaseFunctions)
        _ = try await callFunction(
            name: "acknowledgeHelpRequest",
            data: ["requestId": request.id]
        )
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
        #endif
        return try await fallback.acknowledgeHelpRequest(request, by: parent)
    }
}

#if canImport(FirebaseFirestore)
private extension FirestoreTelematicsService {
    func fetchFirstDocument(collection: String) -> [String: Any]? {
        fetchDocuments(collection: collection).first
    }

    func fetchDocuments(collection: String) -> [[String: Any]] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [[String: Any]] = []

        Firestore.firestore().collection(collection).getDocuments { snapshot, _ in
            result = snapshot?.documents.map { doc in
                var data = doc.data()
                data["__id"] = doc.documentID
                return data
            } ?? []
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 2.0)
        return result
    }

    func mapRide(data: [String: Any]) -> RideTelemetry? {
        guard
            let distanceMiles = data["distanceMiles"] as? Double,
            let durationMinutes = data["durationMinutes"] as? Int,
            let averageSpeedMph = data["averageSpeedMph"] as? Double,
            let maxSpeedMph = data["maxSpeedMph"] as? Double,
            let safetyScore = data["safetyScore"] as? Int,
            let pointsEarned = data["pointsEarned"] as? Int,
            let virtualCoinsEarned = data["virtualCoinsEarned"] as? Int
        else {
            return nil
        }
        let date: Date
        if let ts = data["date"] as? Timestamp {
            date = ts.dateValue()
        } else if let rawDate = data["date"] as? Date {
            date = rawDate
        } else {
            date = Date()
        }

        let breakdown = SafetyBreakdown(
            speedZoneCompliance: data["speedZoneCompliance"] as? Int ?? 90,
            suddenBrakingEvents: data["suddenBrakingEvents"] as? Int ?? 0,
            fallsDetected: data["fallsDetected"] as? Int ?? 0,
            maintenanceHealth: data["maintenanceHealth"] as? Int ?? 95,
            geofenceBreaches: data["geofenceBreaches"] as? Int ?? 0
        )

        return RideTelemetry(
            date: date,
            distanceMiles: distanceMiles,
            durationMinutes: durationMinutes,
            averageSpeedMph: averageSpeedMph,
            maxSpeedMph: maxSpeedMph,
            safetyBreakdown: breakdown,
            safetyScore: safetyScore,
            pointsEarned: pointsEarned,
            virtualCoinsEarned: virtualCoinsEarned
        )
    }

    func dateFromAny(_ raw: Any?) -> Date? {
        if let ts = raw as? Timestamp {
            return ts.dateValue()
        }
        if let date = raw as? Date {
            return date
        }
        return nil
    }

    func mapLocation(data: [String: Any]) -> RideLocation? {
        guard
            let latitude = data["latitude"] as? Double,
            let longitude = data["longitude"] as? Double
        else {
            return nil
        }
        let accuracy = data["horizontalAccuracyMeters"] as? Double ?? 0
        return RideLocation(latitude: latitude, longitude: longitude, horizontalAccuracyMeters: accuracy)
    }

    func setDocument(collection: String, documentId: String, data: [String: Any]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            Firestore.firestore()
                .collection(collection)
                .document(documentId)
                .setData(data, merge: true) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
        }
    }

    #if canImport(FirebaseFunctions)
    func callFunction(name: String, data: [String: Any]) async throws -> [String: Any] {
        try await withCheckedThrowingContinuation { continuation in
            Functions.functions().httpsCallable(name).call(data) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = result?.data as? [String: Any] ?? [:]
                continuation.resume(returning: value)
            }
        }
    }
    #endif
}
#endif
