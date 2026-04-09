import Foundation

enum BackendProvider {
    case mock
    case firebase
}

struct AppContainer {
    let telematicsService: TelematicsService
    let authService: AuthService
}

enum BackendFactory {
    static func make(provider: BackendProvider) -> AppContainer {
        switch provider {
        case .mock:
            return AppContainer(
                telematicsService: MockTelematicsService(),
                authService: MockAuthService()
            )
        case .firebase:
            return AppContainer(
                telematicsService: FirestoreTelematicsService(),
                authService: FirebaseAuthService()
            )
        }
    }
}
