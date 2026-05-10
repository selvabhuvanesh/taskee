//
//  LoginView.swift
//  Taskee
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var errorMessage: String?
    #if DEBUG
    @State private var devName = ""
    #endif

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                Spacer()

                header

                Spacer().frame(height: 48)

                signInButton

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 16)
                }

                #if DEBUG
                devLoginSection
                #endif

                Spacer()

                termsText
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(calmAccent)

            Text("taskoot")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)

            Text("Welcome! The fun way for families to manage tasks, earn coins, and celebrate together.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private var signInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                handleAuthorization(authorization)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 52)
        .cornerRadius(16)
        .shadow(color: .white.opacity(0.15), radius: 10, y: 5)
    }

    private var termsText: some View {
        Text("We use Sign in with Apple to keep your account secure.")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.3))
            .multilineTextAlignment(.center)
    }

    #if DEBUG
    private var devLoginSection: some View {
        VStack(spacing: 12) {
            Divider()
                .background(.white.opacity(0.2))
                .padding(.top, 24)

            Text("DEV LOGIN")
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)

            TextField("Enter name", text: $devName)
                .font(.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(12)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
                )

            Button {
                let name = devName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                authManager.handleAppleSignIn(
                    userID: "dev-\(name.lowercased())",
                    fullName: {
                        var c = PersonNameComponents()
                        c.givenName = name
                        return c
                    }(),
                    email: "\(name.lowercased())@dev.taskee"
                )
            } label: {
                Text("Sign In as \(devName.isEmpty ? "..." : devName)")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        devName.trimmingCharacters(in: .whitespaces).isEmpty
                            ? AnyShapeStyle(.white.opacity(0.1))
                            : AnyShapeStyle(.orange),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .foregroundStyle(.white)
            }
            .disabled(devName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
    #endif

    private func handleAuthorization(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Unable to process credentials."
            return
        }

        authManager.handleAppleSignIn(
            userID: credential.user,
            fullName: credential.fullName,
            email: credential.email
        )
    }
}

#Preview {
    LoginView()
        .environment(AuthManager())
}
