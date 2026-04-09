import Charts
import SwiftUI

struct HomeDashboardView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroSection
                    rangePicker

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricCard(
                            title: "\(viewModel.selectedRange.rawValue) Points",
                            value: "\(viewModel.loyalty.periodPoints)",
                            icon: "bolt.fill",
                            accent: AppTheme.softBlue
                        )
                        MetricCard(
                            title: "Virtual Currency",
                            value: "\(viewModel.loyalty.periodCoins) coins",
                            icon: "dollarsign.circle.fill",
                            accent: AppTheme.navy
                        )
                        MetricCard(
                            title: "Ride Streak",
                            value: "\(viewModel.loyalty.rideStreakDays) days",
                            icon: "flame.fill",
                            accent: AppTheme.softBlue
                        )
                        MetricCard(
                            title: "Safety Score",
                            value: "\(viewModel.periodAverageSafetyScore)/100",
                            icon: "checkmark.shield.fill",
                            accent: AppTheme.navy
                        )
                    }

                    pointsChartSection

                    Text("Lifetime tier: \(viewModel.loyalty.tierName) · \(viewModel.loyalty.pointsToNextTier) points to next tier")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.navy.opacity(0.75))
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .navigationTitle("KidRide Rewards")
            .background(AppTheme.appBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isAuthenticated {
                        Button("Sign Out") {
                            viewModel.signOut()
                        }
                        .foregroundStyle(AppTheme.navy)
                    }
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.profile.avatar)
                    .font(.title3)
                    .foregroundStyle(.white)
                Text("Hi \(viewModel.profile.name)!")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            Text("Safe miles = points + badges + virtual currency")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppTheme.navy, AppTheme.deepNavy],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppTheme.navy.opacity(0.15), radius: 12, x: 0, y: 6)
    }

    private var rangePicker: some View {
        Picker("Range", selection: $viewModel.selectedRange) {
            ForEach(TimeRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.selectedRange) { _, newValue in
            viewModel.updateRange(newValue)
        }
    }

    private var pointsChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(viewModel.selectedRange.rawValue) Points Trend")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)
            Chart(Array(viewModel.pointsByDay.enumerated()), id: \.offset) { _, entry in
                BarMark(
                    x: .value("Day", entry.day),
                    y: .value("Points", entry.points)
                )
                .foregroundStyle(AppTheme.softBlue.gradient)
                .cornerRadius(4)
            }
            .frame(height: 200)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppTheme.navy.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}
