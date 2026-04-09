import SwiftUI

@main
struct KidRideRewardsApp: App {
    @StateObject private var viewModel: DashboardViewModel

    init() {
        FirebaseBootstrap.configureIfAvailable()

        // Flip to `.mock` if you want fully local development mode.
        let container = BackendFactory.make(provider: .firebase)
        _viewModel = StateObject(
            wrappedValue: DashboardViewModel(
                service: container.telematicsService,
                authService: container.authService
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .environmentObject(viewModel)
        }
    }
}
