import SwiftUI

struct RewardsView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wallet")
                            .font(.headline)
                            .foregroundStyle(AppTheme.navy)
                        Text("\(viewModel.currentCoinsBalance) coins available")
                            .font(.title3.bold())
                            .foregroundStyle(AppTheme.navy)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: AppTheme.navy.opacity(0.05), radius: 8, x: 0, y: 3)

                    ForEach(viewModel.badges) { badge in
                        HStack(spacing: 14) {
                            Image(systemName: badge.icon)
                                .font(.title2)
                                .foregroundStyle(badge.isUnlocked ? AppTheme.navy : .gray)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(badge.isUnlocked ? AppTheme.softBlue.opacity(0.2) : Color.gray.opacity(0.2))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(badge.title)
                                    .font(.headline)
                                Text(badge.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(badge.isUnlocked ? "Unlocked" : "Locked")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(badge.isUnlocked ? AppTheme.softBlue.opacity(0.2) : Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: AppTheme.navy.opacity(0.04), radius: 7, x: 0, y: 2)
                    }
                }
                .padding()
            }
            .navigationTitle("Badges & Rewards")
            .background(AppTheme.appBackground)
        }
    }
}
