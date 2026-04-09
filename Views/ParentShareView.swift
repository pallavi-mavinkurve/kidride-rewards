import SwiftUI

struct ParentShareView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel

    var body: some View {
        let summary = viewModel.parentSummary

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let actionMessage = viewModel.actionMessage {
                        Text(actionMessage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.navy)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(AppTheme.softBlue.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    if !viewModel.isParent {
                        Text("Parent-only controls are visible when you sign in as Parent.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Parent Dashboard (\(summary.range.rawValue))")
                            .font(.title3.bold())
                            .foregroundStyle(AppTheme.navy)
                        summaryRow("Child", summary.childName, "person.fill")
                        summaryRow("Rides", "\(summary.rideCount)", "bicycle")
                        summaryRow("Distance", "\(String(format: "%.1f", summary.distanceMiles)) miles", "map")
                        summaryRow("Safety", "\(summary.averageSafetyScore)/100", "checkmark.shield.fill")
                        summaryRow("Points", "\(summary.totalPoints)", "bolt.fill")
                        summaryRow("Coins", "\(summary.totalCoins)", "dollarsign.circle.fill")
                        summaryRow("Unlocked badges", "\(summary.unlockedBadges)", "rosette")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: AppTheme.navy.opacity(0.05), radius: 8, x: 0, y: 4)

                    geofenceSection
                    storeSection
                    alertsSection

                    ShareLink(item: viewModel.parentShareText) {
                        Label("Share \(summary.range.rawValue) Report", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.navy)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .padding()
            .navigationTitle("Parents")
            .background(AppTheme.appBackground)
        }
    }

    private var geofenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Geofencing Controls")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)
            ForEach(viewModel.geofenceZones) { zone in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(zone.name)
                            .font(.subheadline.weight(.semibold))
                        Text("\(zone.radiusMeters)m radius")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: zoneBinding(zone))
                        .labelsHidden()
                        .disabled(!viewModel.isParent)
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var storeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Parent Rewards Store")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)
            ForEach(viewModel.storeItems) { item in
                HStack {
                    Label(item.title, systemImage: item.icon)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(item.coinCost) coins")
                        .font(.caption.weight(.semibold))
                    Button("Buy") {
                        viewModel.buy(item)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.navy)
                    .disabled(!viewModel.isParent || viewModel.currentCoinsBalance < item.coinCost)
                }
                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Geofence Alerts")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)
            ForEach(viewModel.geofenceAlerts) { alert in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(alert.message)
                                .font(.subheadline.weight(.medium))
                            Text("\(alert.zoneName) • \(alert.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if alert.acknowledged {
                            Text("Done")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.green)
                        } else if viewModel.isParent {
                            Button("Acknowledge") {
                                viewModel.acknowledgeAlert(alert)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(AppTheme.navy)
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func summaryRow(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }

    private func zoneBinding(_ zone: GeofenceZone) -> Binding<Bool> {
        Binding(
            get: { zone.active },
            set: { _ in viewModel.toggleZoneActive(zone) }
        )
    }
}
