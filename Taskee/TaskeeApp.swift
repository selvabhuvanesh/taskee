//
//  TaskeeApp.swift
//  Taskee
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import SwiftUI
import SwiftData
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        NotificationCenter.default.post(name: .cloudKitDataChanged, object: nil)
        completionHandler(.newData)
    }
}

@main
struct TaskeeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var authManager = AuthManager()
    @State private var notificationManager = NotificationManager()
    @State private var subscriptionManager = SubscriptionManager()
    @State private var cloudKitManager = CloudKitManager()
    @State private var showOnboarding = false
    @State private var isCheckingExistingUser = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            FamilyMember.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            if let appSupport = urls.first {
                let storeURL = appSupport.appendingPathComponent("default.store")
                try? FileManager.default.removeItem(at: storeURL)
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            }
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if !authManager.isLoggedIn {
                    LoginView()
                } else if isCheckingExistingUser {
                    ZStack {
                        AppBackground()
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.2)
                            Text("Loading your profile...")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                } else if authManager.role.isEmpty {
                    RoleSelectionView()
                } else if authManager.role == "parent" {
                    ContentView()
                } else {
                    ChildDashboardView()
                }
            }
            .environment(authManager)
            .environment(notificationManager)
            .environment(subscriptionManager)
            .environment(cloudKitManager)
            .onAppear {
                notificationManager.requestPermission()
                Task {
                    await subscriptionManager.refreshTier()
                    await subscriptionManager.loadProducts()
                }
            }
            .task {
                await subscriptionManager.listenForTransactions()
            }
            .task {
                await cloudKitManager.checkAvailability()
                await restoreUserIfNeeded()

                guard !authManager.familyCode.isEmpty else { return }
                let context = ModelContext(sharedModelContainer)
                await cloudKitManager.syncAll(context: context, familyCode: authManager.familyCode)
                await cloudKitManager.setupSubscriptions(familyCode: authManager.familyCode)
            }
            .onReceive(NotificationCenter.default.publisher(for: .cloudKitDataChanged)) { _ in
                guard !authManager.familyCode.isEmpty else { return }
                Task {
                    let context = ModelContext(sharedModelContainer)
                    await cloudKitManager.syncAll(context: context, familyCode: authManager.familyCode)
                }
            }
            .sheet(isPresented: $showOnboarding) {
                ParentOnboardingView {
                    authManager.hasCompletedOnboarding = true
                    showOnboarding = false
                }
                .environment(authManager)
                .environment(notificationManager)
                .environment(subscriptionManager)
                .environment(cloudKitManager)
            }
            .onChange(of: authManager.isLoggedIn) { _, loggedIn in
                guard loggedIn else { return }
                Task {
                    await cloudKitManager.checkAvailability()
                    await restoreUserIfNeeded()
                }
            }
            .onChange(of: authManager.role) { _, newRole in
                if newRole == "parent" && !authManager.hasCompletedOnboarding && authManager.familyCode.isEmpty {
                    showOnboarding = true
                }
            }
            .onAppear {
                if authManager.isLoggedIn && authManager.role == "parent" && !authManager.hasCompletedOnboarding && authManager.familyCode.isEmpty {
                    showOnboarding = true
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func restoreUserIfNeeded() async {
        guard authManager.isLoggedIn, authManager.role.isEmpty, !authManager.appleUserID.isEmpty else { return }

        isCheckingExistingUser = true
        defer { isCheckingExistingUser = false }

        if let existing = await cloudKitManager.lookupExistingMember(appleUserID: authManager.appleUserID) {
            authManager.userName = existing.name
            authManager.avatar = existing.avatar
            authManager.familyCode = existing.familyCode
            authManager.hasCompletedOnboarding = true
            authManager.role = existing.memberRole

            let context = ModelContext(sharedModelContainer)
            await cloudKitManager.syncAll(context: context, familyCode: existing.familyCode)
            await cloudKitManager.setupSubscriptions(familyCode: existing.familyCode)
        }
    }
}
