import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

final class FirebaseAuthService: AuthService {
    private let fallback = MockAuthService()

    func signIn(email: String, password: String, role: UserRole) async throws -> AppUser {
        #if canImport(FirebaseAuth)
        let authResult = try await signInFirebase(email: email, password: password)
        let user = authResult.user
        var familyId = "FAM-1001"
        var resolvedRole = role
        var managedChildUserId: String?
        #if canImport(FirebaseFirestore)
        familyId = await fetchFamilyId(for: user.uid) ?? familyId
        resolvedRole = await fetchRole(for: user.uid) ?? resolvedRole
        managedChildUserId = await fetchManagedChildUserId(for: user.uid)
        #endif
        guard resolvedRole == role else {
            throw AuthError.invalidCredentials
        }
        return AppUser(
            id: user.uid,
            name: user.displayName ?? fallbackName(for: role),
            email: user.email ?? email.lowercased(),
            role: resolvedRole,
            familyId: familyId,
            managedChildUserId: managedChildUserId
        )
        #endif

        return try await fallback.signIn(email: email, password: password, role: role)
    }

    func register(name: String, email: String, password: String, role: UserRole, familyCode: String?) async throws -> AppUser {
        #if canImport(FirebaseAuth)
        let authResult = try await createFirebaseUser(email: email, password: password)
        let user = authResult.user

        if let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest() {
            changeRequest.displayName = name
            do {
                try await commitProfile(changeRequest: changeRequest)
            } catch {
                // Non-fatal for auth; display name can be updated later.
            }
        }

        let appUser = AppUser(
            id: user.uid,
            name: name,
            email: user.email ?? email.lowercased(),
            role: role,
            familyId: normalizedFamilyId(for: role, familyCode: familyCode),
            managedChildUserId: nil
        )

        #if canImport(FirebaseFirestore)
        await upsertUserProfile(user: appUser)
        #endif
        return appUser
        #endif

        return try await fallback.register(
            name: name,
            email: email,
            password: password,
            role: role,
            familyCode: familyCode
        )
    }

    func signOut() async {
        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
        } catch {
            // Keep UX resilient in demo mode if Firebase sign-out fails.
        }
        #endif
        await fallback.signOut()
    }

    private func fallbackName(for role: UserRole) -> String {
        role == .parent ? "Parent User" : "Child User"
    }

    private func fallbackEmail(for role: UserRole) -> String {
        role == .parent ? "parent@kidride.app" : "child@kidride.app"
    }

    private func normalizedFamilyId(for role: UserRole, familyCode: String?) -> String {
        if role == .parent {
            return familyCode?.uppercased() ?? "FAM-\(Int.random(in: 3000...9999))"
        }
        return familyCode?.uppercased() ?? "FAM-1001"
    }
}

#if canImport(FirebaseAuth)
private extension FirebaseAuthService {
    func signInFirebase(email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: AuthError.unknown)
                }
            }
        }
    }

    func createFirebaseUser(email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: AuthError.unknown)
                }
            }
        }
    }

    func commitProfile(changeRequest: UserProfileChangeRequest) async throws {
        try await withCheckedThrowingContinuation { continuation in
            changeRequest.commitChanges { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
#endif

#if canImport(FirebaseFirestore)
private extension FirebaseAuthService {
    func upsertUserProfile(user: AppUser) async {
        let data: [String: Any] = [
            "displayName": user.name,
            "email": user.email,
            "role": user.role.rawValue,
            "familyId": user.familyId,
            "managedChildUserId": user.managedChildUserId as Any,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        do {
            try await withCheckedThrowingContinuation { continuation in
                Firestore.firestore()
                    .collection("users")
                    .document(user.id)
                    .setData(data, merge: true) { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
            }
        } catch {
            // Keep registration flow resilient even if profile sync is delayed.
        }
    }

    func fetchFamilyId(for uid: String) async -> String? {
        await fetchUserProfile(uid: uid)?["familyId"] as? String
    }

    func fetchRole(for uid: String) async -> UserRole? {
        guard let raw = await fetchUserProfile(uid: uid)?["role"] as? String else {
            return nil
        }
        return UserRole(rawValue: raw)
    }

    func fetchManagedChildUserId(for uid: String) async -> String? {
        await fetchUserProfile(uid: uid)?["managedChildUserId"] as? String
    }

    func fetchUserProfile(uid: String) async -> [String: Any]? {
        await withCheckedContinuation { continuation in
            Firestore.firestore().collection("users").document(uid).getDocument { snapshot, _ in
                continuation.resume(returning: snapshot?.data())
            }
        }
    }
}
#endif
