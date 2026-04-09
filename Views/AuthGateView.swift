import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel

    var body: some View {
        Group {
            if viewModel.isAuthenticated {
                RootTabView()
            } else {
                SignInView()
            }
        }
    }
}

private struct SignInView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel
    @State private var mode: AuthMode = .signIn
    @State private var selectedRole: UserRole = .parent
    @State private var name = ""
    @State private var email = "taylor@kidride.app"
    @State private var password = "password123"
    @State private var familyCode = "FAM-1001"

    var body: some View {
        ZStack {
            LinearGradient(colors: [AppTheme.navy, AppTheme.deepNavy], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("KidRide Rewards")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("Safe rides earn points, badges, and virtual currency for kids and families.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))

                    Picker("Mode", selection: $mode) {
                        Text("Sign In").tag(AuthMode.signIn)
                        Text("Register").tag(AuthMode.register)
                    }
                    .pickerStyle(.segmented)
                    .colorScheme(.dark)

                    Picker("Role", selection: $selectedRole) {
                        Text("Parent").tag(UserRole.parent)
                        Text("Child").tag(UserRole.child)
                    }
                    .pickerStyle(.segmented)
                    .colorScheme(.dark)

                    VStack(spacing: 10) {
                        if mode == .register {
                            authField("Name", text: $name, icon: "person.fill")
                        }
                        authField("Email", text: $email, icon: "envelope.fill")
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Password", text: $password)
                            .padding()
                            .background(.white.opacity(0.12))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        if mode == .register || selectedRole == .child {
                            authField("Family Code", text: $familyCode, icon: "person.2.badge.gearshape.fill")
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        }
                    }

                    if let authError = viewModel.authErrorMessage {
                        Text(authError)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.8, blue: 0.8))
                    }

                    Button {
                        submit()
                    } label: {
                        HStack {
                            if viewModel.isAuthenticating {
                                ProgressView()
                                    .tint(AppTheme.navy)
                            }
                            Text(mode == .signIn ? "Continue" : "Create Account")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundStyle(AppTheme.navy)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(viewModel.isAuthenticating)

                    Text("Demo credentials: taylor@kidride.app / password123 or mia@kidride.app / password123")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(24)
            }
        }
    }

    @ViewBuilder
    private func authField(_ title: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.8))
            TextField(title, text: text)
                .foregroundStyle(.white)
        }
        .padding()
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func submit() {
        switch mode {
        case .signIn:
            viewModel.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                role: selectedRole
            )
        case .register:
            viewModel.register(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                role: selectedRole,
                familyCode: familyCode.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
}

private enum AuthMode {
    case signIn
    case register
}
