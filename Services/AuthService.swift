import Foundation

protocol AuthService {
    func signIn(email: String, password: String, role: UserRole) async throws -> AppUser
    func register(name: String, email: String, password: String, role: UserRole, familyCode: String?) async throws -> AppUser
    func signOut() async
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case emailAlreadyInUse
    case invalidFamilyCode
    case childProfileNotLinked
    case weakPassword
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid credentials. Please try again."
        case .emailAlreadyInUse:
            return "This email is already registered."
        case .invalidFamilyCode:
            return "Family code is invalid."
        case .childProfileNotLinked:
            return "No child profile linked to this parent account."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

final class MockAuthService: AuthService {
    private var users: [String: (password: String, user: AppUser)] = [
        "mia@kidride.app": (
            password: "password123",
            user: AppUser(
                id: "child-mia",
                name: "Mia Carter",
                email: "mia@kidride.app",
                role: .child,
                familyId: "FAM-1001",
                managedChildUserId: nil
            )
        ),
        "taylor@kidride.app": (
            password: "password123",
            user: AppUser(
                id: "parent-taylor",
                name: "Taylor Carter",
                email: "taylor@kidride.app",
                role: .parent,
                familyId: "FAM-1001",
                managedChildUserId: "child-mia"
            )
        )
    ]
    private var validFamilyCodes: Set<String> = ["FAM-1001", "FAM-2002"]

    func signIn(email: String, password: String, role: UserRole) async throws -> AppUser {
        guard
            let entry = users[email.lowercased()],
            entry.password == password,
            entry.user.role == role
        else {
            throw AuthError.invalidCredentials
        }
        return entry.user
    }

    func register(name: String, email: String, password: String, role: UserRole, familyCode: String?) async throws -> AppUser {
        let normalizedEmail = email.lowercased()

        guard users[normalizedEmail] == nil else {
            throw AuthError.emailAlreadyInUse
        }
        guard password.count >= 6 else {
            throw AuthError.weakPassword
        }

        let resolvedFamilyId: String
        if role == .parent {
            let generated = familyCode?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? familyCode!.uppercased()
                : "FAM-\(Int.random(in: 3000...9999))"
            resolvedFamilyId = generated
            validFamilyCodes.insert(generated)
        } else {
            guard
                let familyCode,
                validFamilyCodes.contains(familyCode.uppercased())
            else {
                throw AuthError.invalidFamilyCode
            }
            resolvedFamilyId = familyCode.uppercased()
        }

        let user = AppUser(
            id: UUID().uuidString,
            name: name,
            email: normalizedEmail,
            role: role,
            familyId: resolvedFamilyId,
            managedChildUserId: nil
        )
        users[normalizedEmail] = (password: password, user: user)
        return user
    }

    func signOut() async {}
}
