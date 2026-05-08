//
//  TaskeeApp.swift
//  Taskee
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import SwiftUI
import SwiftData
import UIKit
import Combine

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
    @State private var isCheckingAcceptance = false
    @State private var pendingSyncTask: Task<Void, Never>?
    @State private var hasCompletedInitialSetup = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            FamilyMember.self,
            RewardRedemption.self,
            SurpriseGift.self,
            ShoppingItem.self,
            ChatMessage.self,
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
                notificationManager.onPickupAcknowledged = { childName in
                    acknowledgePickup(childName: childName)
                }
                Task {
                    async let tier: Void = subscriptionManager.refreshTier()
                    async let products: Void = subscriptionManager.loadProducts()
                    _ = await (tier, products)
                    if subscriptionManager.tier != .free && !authManager.familyCode.isEmpty {
                        await cloudKitManager.pushFamilyTier(subscriptionManager.tier.rawValue, familyCode: authManager.familyCode)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                UNUserNotificationCenter.current().setBadgeCount(0)
                guard !authManager.familyCode.isEmpty, hasCompletedInitialSetup else { return }
                Task {
                    await ensureZoneAndSync()
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

                guard !authManager.familyCode.isEmpty, !hasCompletedInitialSetup else { return }
                await performInitialSync(familyCode: authManager.familyCode)
            }
            .onReceive(NotificationCenter.default.publisher(for: .cloudKitDataChanged)) { _ in
                guard !authManager.familyCode.isEmpty else { return }
                pendingSyncTask?.cancel()
                pendingSyncTask = Task {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    await ensureZoneAndSync()
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
                await cloudKitManager.ensureFamilyZoneAccess(familyCode: authManager.familyCode, appleUserID: authManager.appleUserID)
                await cloudKitManager.syncAll(context: sharedModelContainer.mainContext, familyCode: authManager.familyCode, onNewTasks: scheduleRemindersForSyncedTasks)
            }
        }
    }

    private func restoreUserIfNeeded() async {
        guard authManager.isLoggedIn, authManager.role.isEmpty, !authManager.appleUserID.isEmpty else { return }

        isCheckingExistingUser = true

        if let existing = await cloudKitManager.lookupExistingMember(appleUserID: authManager.appleUserID) {
            authManager.userName = existing.name
            authManager.avatar = existing.avatar
            authManager.familyCode = existing.familyCode
            authManager.hasCompletedOnboarding = true
            authManager.role = existing.memberRole
            isCheckingExistingUser = false

            await performInitialSync(familyCode: existing.familyCode)
        } else {
            isCheckingExistingUser = false
        }
    }

    private func ensureZoneAndSync() async {
        let familyCode = authManager.familyCode
        guard !familyCode.isEmpty else { return }
        if !cloudKitManager.hasFamilyZone {
            await cloudKitManager.ensureFamilyZoneAccess(familyCode: familyCode, appleUserID: authManager.appleUserID)
        }
        let result = await cloudKitManager.syncAll(context: sharedModelContainer.mainContext, familyCode: familyCode, onNewTasks: scheduleRemindersForSyncedTasks)
        handleSyncChanges(result.changes)
        if let familyTier = await cloudKitManager.fetchFamilyTier(familyCode: familyCode) {
            subscriptionManager.setFamilyTier(familyTier)
        }
        scheduleDailySummary()
    }

    private func performInitialSync(familyCode: String) async {
        guard !familyCode.isEmpty, !hasCompletedInitialSetup else { return }
        hasCompletedInitialSetup = true

        await cloudKitManager.ensureFamilyZoneAccess(familyCode: familyCode, appleUserID: authManager.appleUserID)

        let migrationContext = sharedModelContainer.mainContext
        await cloudKitManager.migratePublicToPrivateZone(context: migrationContext, familyCode: familyCode)

        let context = sharedModelContainer.mainContext
        await cloudKitManager.syncAll(context: context, familyCode: familyCode, onNewTasks: scheduleRemindersForSyncedTasks)

        async let backfill: Void = cloudKitManager.backfillCreatedBy(context: context, familyCode: familyCode, userName: authManager.userName, appleUserID: authManager.appleUserID)
        async let tierFetch = cloudKitManager.fetchFamilyTier(familyCode: familyCode)
        async let subs: Void = cloudKitManager.setupSubscriptions(familyCode: familyCode, appleUserID: authManager.appleUserID, role: authManager.role)
        async let acceptance: Void = checkChildAcceptance()

        if let familyTier = await tierFetch {
            subscriptionManager.setFamilyTier(familyTier)
        }
        _ = await (backfill, subs, acceptance)
        scheduleDailySummary()
    }

    private func scheduleDailySummary() {
        let allTasks = (try? sharedModelContainer.mainContext.fetch(FetchDescriptor<Item>())) ?? []
        notificationManager.scheduleDailySummary(tasks: allTasks, userName: authManager.userName)
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

    private func acknowledgePickup(childName: String) {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<FamilyMember>()
        guard let members = try? context.fetch(descriptor) else { return }

        guard let childMember = members.first(where: { $0.name == childName && $0.isChild }) else { return }

        childMember.lastPickupAckAt = Date()
        childMember.lastPickupAckBy = authManager.userName

        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushMember(childMember, familyCode: familyCode) }
    }

    private func handleSyncChanges(_ changes: [CloudKitManager.SyncChange]) {
        let myName = authManager.userName
        let myRole = authManager.role

        for change in changes {
            switch change {
            case .taskApproved(let taskName, let assignedTo, let reward, let hasGift):
                guard assignedTo == myName else { continue }
                let rewardText = reward > 0 ? " You earned \(Int(reward)) coins!" : ""
                let giftHint = hasGift ? " You have a surprise gift waiting!" : ""
                notificationManager.deliverBeepNotification(
                    title: "Task Approved!",
                    body: "\"\(taskName)\" has been approved.\(rewardText)\(giftHint)",
                    category: "TASK_APPROVED"
                )

            case .taskRejected(let taskName, let assignedTo):
                guard assignedTo == myName else { continue }
                notificationManager.deliverBeepNotification(
                    title: "Task Needs Redo",
                    body: "Your task \"\(taskName)\" was sent back. Please try again.",
                    category: "TASK_REJECTED"
                )

            case .taskInReview(let taskName, let childName):
                guard myRole == "parent" else { continue }
                notificationManager.deliverBeepNotification(
                    title: "Task Submitted for Review",
                    body: "\(childName) completed \"\(taskName)\"",
                    category: "TASK_REVIEW",
                    senderName: childName
                )

            case .taskAssigned(let taskName, let assignedTo, let createdBy):
                guard assignedTo == myName, createdBy != myName else { continue }
                notificationManager.deliverBeepNotification(
                    title: "New Task Assigned",
                    body: createdBy.isEmpty ? taskName : "\(createdBy) assigned \"\(taskName)\" to you",
                    category: "TASK_ASSIGNED",
                    senderName: createdBy
                )

            case .taskReminded(let taskName, let assignedTo):
                guard assignedTo == myName else { continue }
                notificationManager.deliverBeepNotification(
                    title: "Task Reminder",
                    body: "Don't forget: \"\(taskName)\"",
                    category: "TASK_REMINDER"
                )

            case .redemptionRequested(let description, let childName, let coins):
                guard myRole == "parent" else { continue }
                notificationManager.deliverBeepNotification(
                    title: "Reward Request",
                    body: "\(childName) wants to redeem \(coins) coins for \"\(description)\"",
                    category: "REWARD_REQUEST",
                    senderName: childName
                )

            case .redemptionApproved(let description, let childName):
                guard childName == myName else { continue }
                notificationManager.deliverBeepNotification(
                    title: "Reward Approved!",
                    body: "Your request for \"\(description)\" has been approved!",
                    category: "REWARD_APPROVED"
                )

            case .redemptionRejected(let description, let childName, let reason):
                guard childName == myName else { continue }
                let reasonText = reason.isEmpty ? "" : " Reason: \(reason)"
                notificationManager.deliverBeepNotification(
                    title: "Reward Request Declined",
                    body: "Your request for \"\(description)\" was declined.\(reasonText)",
                    category: "REWARD_REJECTED"
                )

            case .redemptionFulfilled(let description, let childName):
                guard myRole == "parent" else { continue }
                notificationManager.deliverBeepNotification(
                    title: "Reward Received",
                    body: "\(childName) confirmed receiving: \"\(description)\"",
                    category: "REWARD_FULFILLED",
                    senderName: childName
                )

            case .memberAccepted(let name, _):
                guard name == myName else { continue }
                notificationManager.deliverBeepNotification(
                    title: "Welcome to the Family!",
                    body: "Your request to join has been approved!",
                    category: "MEMBER_ACCEPTED"
                )

            case .memberRequested(let name):
                guard myRole == "parent" else { continue }
                notificationManager.deliverBeepNotification(
                    title: "New Family Member Request",
                    body: "\(name) wants to join your family",
                    category: "MEMBER_REQUEST",
                    senderName: name
                )

            case .pickupRequested(let childName):
                guard myRole == "parent" else { continue }
                notificationManager.sendPickupNotification(childName: childName)

            case .pickupAcknowledged(let parentName):
                guard myRole == "child" else { continue }
                notificationManager.deliverBeepNotification(
                    title: "On the way!",
                    body: "\(parentName) is coming to pick you up!",
                    category: "PICKUP_ACK",
                    senderName: parentName
                )

            case .chatReceived(let senderName, let text):
                guard senderName != myName else { continue }
                let preview = text.count > 50 ? String(text.prefix(50)) + "…" : text
                notificationManager.deliverBeepNotification(
                    title: "💬 \(senderName)",
                    body: preview,
                    category: "FAMILY_CHAT",
                    senderName: senderName
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
