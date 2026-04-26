//
//  LoginView.swift
//  Taskee
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var phoneNumber = ""
    @State private var showOTPView = false

    private var isPhoneValid: Bool {
        let digits = phoneNumber.filter(\.isNumber)
        return digits.count >= 10
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    Spacer()

                    header

                    Spacer().frame(height: 48)

                    phoneInput

                    Spacer()

                    sendOTPButton

                    Spacer().frame(height: 16)

                    termsText
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(isPresented: $showOTPView) {
                OTPView(phoneNumber: phoneNumber)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue)

            Text("Taskee")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)

            Text("Enter your phone number to get started")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }

    private var phoneInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phone Number")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 12) {
                Image(systemName: "phone.fill")
                    .foregroundStyle(.blue)

                TextField("+1 (555) 000-0000", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            .padding(14)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private var sendOTPButton: some View {
        Button {
            authManager.sendOTP(to: phoneNumber)
            showOTPView = true
        } label: {
            Text("Send OTP")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    isPhoneValid ? AnyShapeStyle(.blue) : AnyShapeStyle(.white.opacity(0.1)),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(.white)
        }
        .disabled(!isPhoneValid)
        .shadow(color: isPhoneValid ? .blue.opacity(0.4) : .clear, radius: 10, y: 5)
    }

    private var termsText: some View {
        Text("We'll send you a one-time verification code.")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.3))
            .multilineTextAlignment(.center)
    }
}

struct OTPView: View {
    @Environment(AuthManager.self) private var authManager
    let phoneNumber: String

    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedIndex: Int?
    @State private var errorMessage: String?
    @State private var canResend = false
    @State private var countdown = 30

    private var otpCode: String {
        otpDigits.joined()
    }

    private var isComplete: Bool {
        otpCode.count == 6 && otpDigits.allSatisfy { !$0.isEmpty }
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                Spacer()

                otpHeader

                Spacer().frame(height: 40)

                otpFields

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 12)
                }

                Text("Dev OTP: \(authManager.generatedOTP)")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.top, 12)

                Spacer().frame(height: 20)

                resendRow

                Spacer()

                verifyButton
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            focusedIndex = 0
            startCountdown()
        }
    }

    private var otpHeader: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 52))
                .foregroundStyle(.blue)

            Text("Verify Your Number")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("Enter the 6-digit code sent to\n\(phoneNumber)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }

    private var otpFields: some View {
        HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { index in
                TextField("", text: $otpDigits[index])
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 54)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                focusedIndex == index ? .blue : .white.opacity(0.15),
                                lineWidth: focusedIndex == index ? 2 : 1
                            )
                    )
                    .focused($focusedIndex, equals: index)
                    .onChange(of: otpDigits[index]) { _, newValue in
                        handleDigitChange(at: index, value: newValue)
                    }
            }
        }
    }

    private var resendRow: some View {
        HStack {
            Text("Didn't receive the code?")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))

            if canResend {
                Button("Resend") {
                    authManager.sendOTP(to: phoneNumber)
                    otpDigits = Array(repeating: "", count: 6)
                    errorMessage = nil
                    canResend = false
                    countdown = 30
                    startCountdown()
                    focusedIndex = 0
                }
                .font(.caption.weight(.semibold))
            } else {
                Text("Resend in \(countdown)s")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)
            }
        }
    }

    private var verifyButton: some View {
        Button {
            if authManager.verifyOTP(otpCode) {
                errorMessage = nil
                authManager.isLoggedIn = true
            } else {
                errorMessage = "Invalid code. Please try again."
                otpDigits = Array(repeating: "", count: 6)
                focusedIndex = 0
            }
        } label: {
            Text("Verify")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    isComplete ? AnyShapeStyle(.blue) : AnyShapeStyle(.white.opacity(0.1)),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(.white)
        }
        .disabled(!isComplete)
        .shadow(color: isComplete ? .blue.opacity(0.4) : .clear, radius: 10, y: 5)
    }

    private func handleDigitChange(at index: Int, value: String) {
        let filtered = value.filter(\.isNumber)
        if filtered.count > 1 {
            otpDigits[index] = String(filtered.last!)
        }
        if !otpDigits[index].isEmpty && index < 5 {
            focusedIndex = index + 1
        }
    }

    private func startCountdown() {
        countdown = 30
        canResend = false
        Task {
            while countdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                countdown -= 1
            }
            canResend = true
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthManager())
}
