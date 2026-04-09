import SwiftUI

struct RideHistoryView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            List {
                if let message = viewModel.actionMessage {
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.navy)
                        .listRowBackground(AppTheme.softBlue.opacity(0.15))
                }

                if let live = viewModel.liveRideSession, viewModel.isRideTracking {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Live Ride Tracking")
                            .font(.headline)
                            .foregroundStyle(AppTheme.navy)
                        HStack {
                            Label("\(live.distanceMiles, specifier: "%.2f") mi", systemImage: "location.fill")
                            Label("\(live.durationMinutes) min", systemImage: "timer")
                            Label("\(live.currentSpeedMph, specifier: "%.1f") mph", systemImage: "speedometer")
                        }
                        .font(.caption)
                        Text("Sudden braking events: \(live.suddenBrakingEvents)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(AppTheme.cardBackground)
                }

                ForEach(viewModel.filteredRides) { ride in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(ride.date, style: .date)
                                .font(.headline)
                            Spacer()
                            Label("\(ride.pointsEarned) pts", systemImage: "bolt.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.navy)
                        }

                        HStack(spacing: 14) {
                            Label("\(ride.distanceMiles, specifier: "%.1f") miles", systemImage: "location.fill")
                            Label("\(ride.durationMinutes) min", systemImage: "timer")
                            Label("\(ride.maxSpeedMph, specifier: "%.1f") mph", systemImage: "speedometer")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            Label("Braking \(ride.safetyBreakdown.suddenBrakingEvents)", systemImage: "exclamationmark.triangle.fill")
                            Label("Falls \(ride.safetyBreakdown.fallsDetected)", systemImage: "figure.fall")
                            Label("Geo \(ride.safetyBreakdown.geofenceBreaches)", systemImage: "mappin.and.ellipse")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                        ProgressView(value: Double(ride.safetyScore), total: 100) {
                            Text("Safety \(ride.safetyScore)/100")
                                .font(.caption.weight(.medium))
                        }
                        .tint(ride.safetyScore > 90 ? .green : AppTheme.softBlue)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(AppTheme.cardBackground)
                }
            }
            .navigationTitle("\(viewModel.selectedRange.rawValue) Rides")
            .scrollContentBackground(.hidden)
            .background(AppTheme.appBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.userRole == .child {
                        Button(viewModel.isRideTracking ? "Stop & Save" : "Start Ride") {
                            if viewModel.isRideTracking {
                                viewModel.stopAndSubmitTrackedRide()
                            } else {
                                viewModel.startRideTracking()
                            }
                        }
                        .foregroundStyle(viewModel.isRideTracking ? .red : AppTheme.navy)
                    }
                }
            }
        }
    }
}
