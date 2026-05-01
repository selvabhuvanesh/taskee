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
        NotificationCenter.default.post(name: .checkPickupNotification, object: nil)
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
    @State private var isCheckingAcceptance = false
    @State private var pendingSyncTask: Task<Void, Never>?

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            FamilyMember.self,
            RewardRedemption.self,
            SurpriseGift.self,
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
                let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try! ModelContainer(for: schema, configurations: [inMemory])
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
                } else if authManager.isPendingApproval {
                    PendingApprovalView(isCheckingAcceptance: $isCheckingAcceptance) {
                        Task { await checkChildAcceptance() }
                    }
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
                SoundManager.shared.installNotificationSound()
                UNUserNotificationCenter.current().setBadgeCount(0)
                Task {
                    await subscriptionManager.refreshTier()
                    await subscriptionManager.loadProducts()
                    if subscriptionManager.tier != .free && !authManager.familyCode.isEmpty {
                        await cloudKitManager.pushFamilyTier(subscriptionManager.tier.rawValue, familyCode: authManager.familyCode)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                UNUserNotificationCenter.current().setBadgeCount(0)
                guard !authManager.familyCode.isEmpty else { return }
                Task {
                    let context = ModelContext(sharedModelContainer)
                    await cloudKitManager.syncAll(context: context, familyCode: authManager.familyCode, onNewTasks: scheduleRemindersForSyncedTasks)
                    if let familyTier = await cloudKitManager.fetchFamilyTier(familyCode: authManager.familyCode) {
                        subscriptionManager.setFamilyTier(familyTier)
                    }
                }
            }
            .task {
                subscriptionManager.onTierChanged = { newTier in
                    guard !authManager.familyCode.isEmpty else { return }
                    Task {
                        await cloudKitManager.pushFamilyTier(newTier.rawValue, familyCode: authManager.familyCode)
                    }
                }
                await subscriptionManager.listenForTransactions()
            }
            .task {
                await cloudKitManager.checkAvailability()
                await restoreUserIfNeeded()

                guard !authManager.familyCode.isEmpty else { return }
                let context = ModelContext(sharedModelContainer)
                await cloudKitManager.syncAll(context: context, familyCode: authManager.familyCode, onNewTasks: scheduleRemindersForSyncedTasks)
                await cloudKitManager.backfillCreatedBy(context: context, familyCode: authManager.familyCode, userName: authManager.userName, appleUserID: authManager.appleUserID)
                if let familyTier = await cloudKitManager.fetchFamilyTier(familyCode: authManager.familyCode) {
                    subscriptionManager.setFamilyTier(familyTier)
                }
                await cloudKitManager.setupSubscriptions(familyCode: authManager.familyCode, appleUserID: authManager.appleUserID, role: authManager.role)
                await checkChildAcceptance()
            }
            .onReceive(NotificationCenter.default.publisher(for: .checkPickupNotification)) { _ in
                guard authManager.role == "parent", !authManager.familyCode.isEmpty else { return }
                Task {
                    if let pickup = await cloudKitManager.fetchLatestPickup(familyCode: authManager.familyCode) {
                        notificationManager.sendPickupNotification(childName: pickup.childName)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .cloudKitDataChanged)) { _ in
                guard !authManager.familyCode.isEmpty else { return }
                pendingSyncTask?.cancel()
                pendingSyncTask = Task {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    let context = ModelContext(sharedModelContainer)
                    await cloudKitManager.syncAll(context: context, familyCode: authManager.familyCode, onNewTasks: scheduleRemindersForSyncedTasks)
                    if let familyTier = await cloudKitManager.fetchFamilyTier(familyCode: authManager.familyCode) {
                        subscriptionManager.setFamilyTier(familyTier)
                    }
                    await checkChildAcceptance()
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

    private func checkChildAcceptance() async {
        guard authManager.isPendingApproval, !authManager.appleUserID.isEmpty else { return }

        isCheckingAcceptance = true
        let accepted = await cloudKitManager.checkMemberAccepted(appleUserID: authManager.appleUserID)
        isCheckingAcceptance = false

        if accepted {
            authManager.isPendingApproval = false
            if !authManager.familyCode.isEmpty {
                let context = ModelContext(sharedModelContainer)
                await cloudKitManager.syncAll(context: context, familyCode: authManager.familyCode, onNewTasks: scheduleRemindersForSyncedTasks)
            }
        }
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
            await cloudKitManager.syncAll(context: context, familyCode: existing.familyCode, onNewTasks: scheduleRemindersForSyncedTasks)
            if let familyTier = await cloudKitManager.fetchFamilyTier(familyCode: existing.familyCode) {
                subscriptionManager.setFamilyTier(familyTier)
            }
            await cloudKitManager.setupSubscriptions(familyCode: existing.familyCode, appleUserID: authManager.appleUserID, role: existing.memberRole)
        }
    }

    private func scheduleRemindersForSyncedTasks(_ tasks: [CloudKitManager.SyncedTask]) {
        let myName = authManager.userName
        for task in tasks {
            notificationManager.scheduleTaskReminder(
                taskId: task.id,
                taskName: task.name,
                assignedTo: task.assignedTo,
                dueDate: task.targetDate
            )
            if task.assignedTo == myName {
                notificationManager.sendTaskAssignedNotification(
                    taskName: task.name,
                    assignerName: task.createdBy
                )
            }
        }
    }
}

struct PendingApprovalView: View {
    @Environment(AuthManager.self) private var authManager
    @Binding var isCheckingAcceptance: Bool
    var onRefresh: () -> Void

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "hourglass.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse, options: .repeating)

                Text("Waiting for Parent Approval")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("Your request to join the family has been sent. Ask your parent to open Taskee and approve your request.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    onRefresh()
                } label: {
                    HStack(spacing: 8) {
                        if isCheckingAcceptance {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Check Again")
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(.orange, in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isCheckingAcceptance)

                Spacer()

                Button {
                    authManager.logout()
                } label: {
                    Text("Sign Out")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.bottom, 32)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                onRefresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            onRefresh()
        }
    }
}
