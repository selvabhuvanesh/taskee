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

    var appleUserID: String {
        didSet { UserDefaults.standard.set(appleUserID, forKey: "appleUserID") }
    }

    var email: String {
        didSet { UserDefaults.standard.set(email, forKey: "userEmail") }
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

    var isPendingApproval: Bool {
        didSet { UserDefaults.standard.set(isPendingApproval, forKey: "isPendingApproval") }
    }

    init() {
        if ScreenshotHelper.isScreenshotMode {
            let role = ScreenshotHelper.screenshotRole
            self.isLoggedIn = true
            self.role = role
            self.familyCode = "FAM123"
            self.hasCompletedOnboarding = true
            self.isPendingApproval = false
            if role == "parent" {
                self.appleUserID = "mock-parent-001"
                self.userName = "Sarah"
                self.email = "sarah@example.com"
                self.avatar = "av02"
            } else {
                self.appleUserID = "mock-child-001"
                self.userName = "Alex"
                self.email = "alex@example.com"
                self.avatar = "av05"
            }
            return
        }
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        self.appleUserID = UserDefaults.standard.string(forKey: "appleUserID") ?? ""
        self.email = UserDefaults.standard.string(forKey: "userEmail") ?? ""
        self.role = UserDefaults.standard.string(forKey: "userRole") ?? ""
        self.userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        self.familyCode = UserDefaults.standard.string(forKey: "familyCode") ?? ""
        self.avatar = UserDefaults.standard.string(forKey: "userAvatar") ?? "star.fill"
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.isPendingApproval = UserDefaults.standard.bool(forKey: "isPendingApproval")
    }

    func handleAppleSignIn(userID: String, fullName: PersonNameComponents?, email: String?) {
        self.appleUserID = userID
        if let name = fullName, let given = name.givenName {
            self.userName = [given, name.familyName].compactMap { $0 }.joined(separator: " ")
        }
        if let email {
            self.email = email
        }
        self.isLoggedIn = true
    }

    func generateFamilyCode() {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        familyCode = String((0..<6).map { _ in chars.randomElement()! })
    }

    func logout() {
        isLoggedIn = false
        appleUserID = ""
        email = ""
        role = ""
        userName = ""
        familyCode = ""
        avatar = "star.fill"
        hasCompletedOnboarding = false
        isPendingApproval = false
    }
}
