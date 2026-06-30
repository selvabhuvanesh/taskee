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
    /// Closure set by TaskeeApp to perform sync in the background.
    /// Returns the sync changes so we can fire local notifications before iOS suspends us.
    var backgroundSync: (() async -> [CloudKitManager.SyncChange])?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let backgroundSync else {
            // Fallback: post notification for foreground handling
            NotificationCenter.default.post(name: .cloudKitDataChanged, object: nil)
            completionHandler(.newData)
            return
        }

        // Perform actual sync within the background execution window (~30s)
        // so notifications fire before iOS suspends the app.
        Task {
            let changes = await backgroundSync()
            completionHandler(changes.isEmpty ? .noData : .newData)
        }
    }
}

@main
struct TaskeeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var authManager = AuthManager()
    @State private var notificationManager = NotificationManager()
    @State private var subscriptionManager = SubscriptionManager()
    @State private var cloudKitManager = CloudKitManager()
    @State private var calendarManager = CalendarManager()
    @State private var showOnboarding = false
    @State private var isCheckingExistingUser = false
    @State private var hasStartedRestore = false
    @State private var isCheckingAcceptance = false
    @State private var pendingSyncTask: Task<Void, Never>?
    @State private var hasCompletedInitialSetup = false
    @State private var showSplash = !ScreenshotHelper.isScreenshotMode

    private static let currentSchemaVersion = 7

    var sharedModelContainer: ModelContainer = {
        if ScreenshotHelper.isScreenshotMode {
            return ScreenshotHelper.makeInMemoryContainer()
        }

        let schema = Schema([
            Item.self,
            FamilyMember.self,
            RewardRedemption.self,
            SurpriseGift.self,
            ShoppingItem.self,
            ChatMessage.self,
            AnnualReminder.self,
            FamilyProject.self,
            ProjectIdea.self,
            ProjectVote.self,
            WishListItem.self,
            Goal.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        let savedVersion = UserDefaults.standard.integer(forKey: "schemaVersion")
        if savedVersion != currentSchemaVersion {
            deleteStoreFiles()
            UserDefaults.standard.set(currentSchemaVersion, forKey: "schemaVersion")
        }

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            deleteStoreFiles()
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try! ModelContainer(for: schema, configurations: [inMemory])
            }
        }
    }()

    private static func deleteStoreFiles() {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let appSupport = urls.first else { return }
        let storeURL = appSupport.appendingPathComponent("default.store")
        try? FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
        try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
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
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    } else if authManager.role.isEmpty {
                        RoleSelectionView()
                    } else if authManager.role == "parent" || authManager.role == "individual" {
                        ContentView()
                    } else if authManager.isPendingApproval {
                        PendingApprovalView(isCheckingAcceptance: $isCheckingAcceptance) {
                            Task { await checkChildAcceptance() }
                        }
                    } else {
                        ChildDashboardView()
                    }
                }

                if showSplash {
                    SplashView()
                        .ignoresSafeArea()
                        .zIndex(1)
                }
            }
            .environment(authManager)
            .environment(notificationManager)
            .environment(subscriptionManager)
            .environment(cloudKitManager)
            .environment(calendarManager)
            .onAppear {
                if ScreenshotHelper.isScreenshotMode {
                    ScreenshotHelper.populateMockData(context: sharedModelContainer.mainContext)
                    showSplash = false
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) { showSplash = false }
                }
            }
            .task {
                guard !ScreenshotHelper.isScreenshotMode else { return }

                notificationManager.requestPermission()
                notificationManager.onPickupAcknowledged = { childName in
                    acknowledgePickup(childName: childName)
                }

                // Wire up background sync so AppDelegate can sync + deliver
                // notifications within the background execution window.
                appDelegate.backgroundSync = { [self] in
                    await self.performBackgroundSync()
                }

                subscriptionManager.onTierChanged = { newTier in
                    guard !authManager.familyCode.isEmpty else { return }
                    Task {
                        await cloudKitManager.pushFamilyTier(newTier.rawValue, familyCode: authManager.familyCode)
                    }
                }
                Task { await subscriptionManager.listenForTransactions() }

                async let tierRefresh: Void = subscriptionManager.refreshTier()
                async let productsLoad: Void = subscriptionManager.loadProducts()
                async let availCheck: Void = cloudKitManager.checkAvailability()
                _ = await (tierRefresh, productsLoad, availCheck)

                if subscriptionManager.tier != .free && !authManager.familyCode.isEmpty {
                    Task { await cloudKitManager.pushFamilyTier(subscriptionManager.tier.rawValue, familyCode: authManager.familyCode) }
                }

                await restoreUserIfNeeded()

                Task.detached(priority: .utility) {
                    SoundManager.shared.installNotificationSound()
                    await MainActor.run {
                        notificationManager.cleanupOrphanedVoiceFiles()
                    }
                }

                guard !authManager.familyCode.isEmpty, !hasCompletedInitialSetup else { return }
                await performInitialSync(familyCode: authManager.familyCode)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                guard !ScreenshotHelper.isScreenshotMode else { return }
                guard !showSplash else { return }
                guard !authManager.familyCode.isEmpty, hasCompletedInitialSetup else { return }
                Task {
                    await ensureZoneAndSync()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .cloudKitDataChanged)) { _ in
                guard !ScreenshotHelper.isScreenshotMode else { return }
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
                .environment(calendarManager)
            }
            .onChange(of: authManager.isLoggedIn) { old, loggedIn in
                guard old != loggedIn, loggedIn, !ScreenshotHelper.isScreenshotMode else { return }
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
        guard !hasStartedRestore else { return }
        hasStartedRestore = true

        isCheckingExistingUser = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            if isCheckingExistingUser { isCheckingExistingUser = false }
        }

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
        sweepMissedTasks()
        sweepCoachingMissedTasks()
    }

    /// Called by AppDelegate from background silent push.
    /// Performs sync and fires notifications within the ~30s background window.
    @MainActor
    private func performBackgroundSync() async -> [CloudKitManager.SyncChange] {
        let familyCode = authManager.familyCode
        guard !familyCode.isEmpty else { return [] }
        if !cloudKitManager.hasFamilyZone {
            await cloudKitManager.ensureFamilyZoneAccess(familyCode: familyCode, appleUserID: authManager.appleUserID)
        }
        let result = await cloudKitManager.syncAll(context: sharedModelContainer.mainContext, familyCode: familyCode, onNewTasks: scheduleRemindersForSyncedTasks)
        handleSyncChanges(result.changes)
        sweepMissedTasks()
        sweepCoachingMissedTasks()
        return result.changes
    }

    private func performInitialSync(familyCode: String) async {
        guard !familyCode.isEmpty, !hasCompletedInitialSetup else { return }
        hasCompletedInitialSetup = true

        await cloudKitManager.ensureFamilyZoneAccess(familyCode: familyCode, appleUserID: authManager.appleUserID)

        let context = sharedModelContainer.mainContext
        async let migration: Void = cloudKitManager.migratePublicToPrivateZone(context: context, familyCode: familyCode)
        async let subscriptions: Void = cloudKitManager.setupSubscriptions(familyCode: familyCode, appleUserID: authManager.appleUserID, role: authManager.role)
        _ = await (migration, subscriptions)

        await cloudKitManager.syncAll(context: context, familyCode: familyCode, onNewTasks: scheduleRemindersForSyncedTasks)

        async let tierFetch: String? = cloudKitManager.fetchFamilyTier(familyCode: familyCode)
        async let backfill: Void = cloudKitManager.backfillCreatedBy(context: context, familyCode: familyCode, userName: authManager.userName, appleUserID: authManager.appleUserID)
        async let acceptance: Void = checkChildAcceptance()
        let fetchedTier = await tierFetch
        _ = await (backfill, acceptance)

        if let familyTier = fetchedTier {
            subscriptionManager.setFamilyTier(familyTier)
        }
        scheduleDailySummary()
        sweepMissedTasks()
    }

    private func scheduleDailySummary() {
        let allTasks = (try? sharedModelContainer.mainContext.fetch(FetchDescriptor<Item>())) ?? []
        notificationManager.scheduleDailySummary(tasks: allTasks, userName: authManager.userName)
    }

    private func sweepMissedTasks() {
        let context = sharedModelContainer.mainContext
        let allTasks = (try? context.fetch(FetchDescriptor<Item>())) ?? []
        let now = Date()

        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let missed = allTasks.filter { task in
            task.isOpen && !task.isArchived && task.targetDate < oneWeekAgo
        }
        guard !missed.isEmpty else { return }

        for task in missed {
            task.status = "missed"
            notificationManager.cancelTaskReminder(taskId: task.id)
        }

        let familyCode = authManager.familyCode
        Task {
            for task in missed {
                await cloudKitManager.pushTask(task, familyCode: familyCode)
            }
        }

        let grouped = Dictionary(grouping: missed) { $0.assignedTo }
        for (assignee, tasks) in grouped {
            let names = tasks.prefix(3).map { $0.name }
            var body = names.map { "• \($0)" }.joined(separator: "\n")
            if tasks.count > 3 {
                body += "\n...and \(tasks.count - 3) more"
            }
            let title = assignee.isEmpty
                ? "\(tasks.count) task\(tasks.count == 1 ? "" : "s") missed"
                : "\(tasks.count) task\(tasks.count == 1 ? "" : "s") missed by \(assignee)"
            notificationManager.deliverBeepNotification(
                title: title,
                body: body,
                category: "TASK_MISSED"
            )
        }
    }

    private func sweepCoachingMissedTasks() {
        let context = sharedModelContainer.mainContext
        let allTasks = (try? context.fetch(FetchDescriptor<Item>())) ?? []
        let allGoals = (try? context.fetch(FetchDescriptor<Goal>())) ?? []
        let now = Date()

        // Coaching tasks that are past due (1 day grace period instead of 7)
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let coachingGoalIds = Set(allGoals.filter { $0.isCoaching && $0.isActive }.map { $0.id.uuidString })

        let missedCoaching = allTasks.filter { task in
            (task.isOpen || task.isInProgress) && !task.isArchived
            && !task.goalId.isEmpty && coachingGoalIds.contains(task.goalId)
            && task.targetDate < oneDayAgo
        }

        for task in missedCoaching {
            task.status = "missed"
            notificationManager.sendCoachingMissedAlert(
                taskName: task.name,
                childName: task.assignedTo
            )
        }

        if !missedCoaching.isEmpty {
            try? context.save()
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

struct SplashView: View {
    @State private var opacity: Double = 0

    private var appIcon: UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let name = files.last {
            return UIImage(named: name)
        }
        return UIImage(named: "AppIcon")
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.5, blue: 0.5),
                    Color(red: 0.15, green: 0.3, blue: 0.45),
                    Color(red: 0.3, green: 0.1, blue: 0.4),
                    Color(red: 0.35, green: 0.05, blue: 0.45)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if let icon = appIcon {
                VStack(spacing: 16) {
                    Image(uiImage: icon)
                        .resizable()
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)

                    Text("Taskoot")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("by FamiLogic LLC")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) { opacity = 1 }
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

                Text("Your request to join the family has been sent. Ask your parent to open Taskoot and approve your request.")
                    .font(.subheadline.weight(.bold))
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
                        .font(.subheadline.weight(.bold))
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
