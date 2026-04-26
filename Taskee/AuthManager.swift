//
//  AuthManager.swift
//  Taskee
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import Foundation

@Observable
final class AuthManager {
    var isLoggedIn: Bool {
        didSet { UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn") }
    }

    var phoneNumber: String {
        didSet { UserDefaults.standard.set(phoneNumber, forKey: "phoneNumber") }
    }

    // "parent", "child", or "" (not yet selected)
    var role: String {
        didSet { UserDefaults.standard.set(role, forKey: "userRole") }
    }

    var userName: String {
        didSet { UserDefaults.standard.set(userName, forKey: "userName") }
    }

    var familyCode: String {
        didSet { UserDefaults.standard.set(familyCode, forKey: "familyCode") }
    }

    var avatar: String {
        didSet { UserDefaults.standard.set(avatar, forKey: "userAvatar") }
    }

    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    // In production, replace with Firebase Auth phone verification.
    private(set) var generatedOTP: String = ""

    init() {
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        self.phoneNumber = UserDefaults.standard.string(forKey: "phoneNumber") ?? ""
        self.role = UserDefaults.standard.string(forKey: "userRole") ?? ""
        self.userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        self.familyCode = UserDefaults.standard.string(forKey: "familyCode") ?? ""
        self.avatar = UserDefaults.standard.string(forKey: "userAvatar") ?? "person.circle.fill"
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    func sendOTP(to phone: String) {
        self.phoneNumber = phone
        self.generatedOTP = String(format: "%06d", Int.random(in: 0...999999))
        print("[Taskee] OTP for \(phone): \(generatedOTP)")
    }

    func verifyOTP(_ code: String) -> Bool {
        code == generatedOTP
    }

    func generateFamilyCode() {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        familyCode = String((0..<6).map { _ in chars.randomElement()! })
    }

    func logout() {
        isLoggedIn = false
        phoneNumber = ""
        role = ""
        userName = ""
        familyCode = ""
        avatar = "person.circle.fill"
        hasCompletedOnboarding = false
    }
}
