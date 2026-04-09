import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel

    var body: some View {
        TabView {
            HomeDashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }

            RideHistoryView()
                .tabItem {
                    Label("Rides", systemImage: "bicycle")
                }

            RewardsView()
                .tabItem {
                    Label("Rewards", systemImage: "rosette")
                }

            SafetyCenterView()
                .tabItem {
                    Label("Safety", systemImage: "cross.case.fill")
                }

            ParentShareView()
                .tabItem {
                    Label(viewModel.isParent ? "Parent Hub" : "Family", systemImage: "person.2.fill")
                }
        }
        .tint(AppTheme.navy)
    }
}
