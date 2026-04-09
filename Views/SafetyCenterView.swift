import SwiftUI

struct SafetyCenterView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.isChild {
                        childEmergencyCard
                    } else if viewModel.isParent {
                        parentHelpQueueCard
                    }
                }
                .padding()
            }
            .background(AppTheme.appBackground)
            .navigationTitle("Safety Center")
        }
    }

    private var childEmergencyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Emergency Help")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.navy)

            TextField("What happened? (optional)", text: $viewModel.helpMessageDraft, axis: .vertical)
                .lineLimit(2...4)
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Picker("Urgency", selection: $viewModel.helpUrgency) {
                ForEach(HelpUrgency.allCases) { urgency in
                    Text(urgency.rawValue.capitalized).tag(urgency)
                }
            }
            .pickerStyle(.segmented)

            Button {
                viewModel.requestHelpNow()
            } label: {
                Label("Request Help Now", systemImage: "exclamationmark.bubble.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppTheme.navy.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private var parentHelpQueueCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Help Requests")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.navy)

            ForEach(viewModel.helpRequests) { request in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(request.message)
                            .font(.subheadline.weight(.semibold))
                        Text("\(request.urgency.rawValue.capitalized) priority • \(request.requestedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let location = request.location {
                            Text("Lat \(String(format: "%.4f", location.latitude)), Lng \(String(format: "%.4f", location.longitude))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        if let location = request.location {
                            Button("Open in Maps") {
                                openURL(mapURL(for: location))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(AppTheme.softBlue)

                            Button("Get Directions") {
                                openURL(directionsURL(for: location))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(AppTheme.softBlue)
                        }

                        if request.status == .pending {
                            Button("Acknowledge") {
                                viewModel.acknowledgeHelpRequest(request)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(AppTheme.navy)
                        } else {
                            Text(request.status.rawValue.capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(8)
                .background(AppTheme.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func mapURL(for location: RideLocation) -> URL {
        var components = URLComponents(string: "http://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(location.latitude),\(location.longitude)"),
            URLQueryItem(name: "q", value: "Kid Help Location")
        ]
        if let url = components?.url {
            return url
        }
        return URL(string: "http://maps.apple.com/") ?? URL(fileURLWithPath: "/")
    }

    private func directionsURL(for location: RideLocation) -> URL {
        var components = URLComponents(string: "http://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "daddr", value: "\(location.latitude),\(location.longitude)"),
            URLQueryItem(name: "dirflg", value: "d")
        ]
        if let url = components?.url {
            return url
        }
        return URL(string: "http://maps.apple.com/") ?? URL(fileURLWithPath: "/")
    }
}
