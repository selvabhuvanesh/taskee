//
//  ChildDashboardView.swift
//  Taskee
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import SwiftUI
import SwiftData

struct ChildDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Query(sort: \Item.targetDate) private var allTasks: [Item]
    @Query private var allMembers: [FamilyMember]
    @State private var showAll = false
    @State private var isExpanded = true
    @State private var showCalendarView = false
    @State private var selectedCalendarDate = Date()
    @State private var showAddTask = false
    @State private var showCelebration = false
    @State private var celebrationReward: Double = 0
    @State private var celebrationTitle = ""
    @State private var celebrationSubtitle = ""
    @State private var taskToComplete: Item?
    @State private var showTooEarlyAlert = false
    @State private var tooEarlyTask: Item?
    @State private var showPickupSent = false
    @State private var showPickupLimit = false
    @State private var showPickupAck = false
    @State private var pickupAckParentName = ""
    @State private var showNotificationCenter = false
    @State private var showRedeemSheet = false
    @State private var showRewardsHistory = false
    @State private var showMyGifts = false
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var showShareSheet = false
    @State private var showPrivacyPolicy = false
    @State private var showThemePicker = false
    @State private var childTheme = ChildTheme.load(for: "child")
    @State private var stickyNote: (message: String, color: Color)?
    @State private var unreadNotifCount = 0
    @State private var taskToDelete: Item?
    @State private var taskToEdit: Item?
    @State private var missedTaskToHandle: Item?
    @State private var showMissedOptions = false
    @State private var giftTaskToReveal: Item?
    @State private var showShoppingBag = false
    @State private var showFamilyChat = false
    @State private var showAIAssistant = false
    @AppStorage("isAIMode") private var isAIMode = true
    @State private var showFamilyProjects = false
    @State private var showWishList = false
    @Query private var shoppingItems: [ShoppingItem]
    @Query private var allProjects: [FamilyProject]
    @Query(sort: \ChatMessage.sentAt) private var chatMessages: [ChatMessage]
    @Query private var allGifts: [SurpriseGift]
    @State private var flyingCoins: [FlyingCoin] = []
    @State private var earningsCardCenter: CGPoint = .zero
    @State private var lastCompletedTaskCenter: CGPoint = .zero
    @State private var coinLandBounce = false
    @State private var showRecurringExtension = false
    @State private var recurringGroups: [RecurringTaskGroup] = []
    @Query private var allRedemptions: [RewardRedemption]
    @Query(sort: \Goal.createdAt) private var allGoals: [Goal]
    @State private var showGoalPicker = false
    @State private var showGoalsTab = false
    @State private var showStatsPopup = false

    private var myMember: FamilyMember? {
        allMembers.first { $0.appleUserID == authManager.appleUserID }
    }

    private var pickupAckTimestamp: Double {
        myMember?.lastPickupAckAt?.timeIntervalSince1970 ?? 0
    }

    private var myRedemptions: [RewardRedemption] {
        allRedemptions.filter { $0.childName == authManager.userName }
    }

    private var pendingRedemptionCoins: Int {
        myRedemptions.filter { $0.isPending }.reduce(0) { $0 + $1.coinAmount }
    }

    private var inReviewCoins: Int {
        allTasks
            .filter { $0.assignedTo == authManager.userName && $0.isInReview && $0.reward > 0 }
            .reduce(0) { $0 + Int($1.reward) }
    }

    private var awaitingApprovalCoins: Int {
        pendingRedemptionCoins + inReviewCoins
    }

    private var redeemedCoins: Int {
        var seen = Set<String>()
        var total = 0
        for r in myRedemptions where r.isApproved || r.isFulfilled || r.isPending {
            if seen.insert(r.id.uuidString).inserted { total += r.coinAmount }
        }
        return total
    }

    private var totalEarnedCoins: Int {
        let localSum = allTasks
            .filter { $0.assignedTo == authManager.userName && $0.isApproved && $0.reward > 0 }
            .reduce(0) { $0 + Int($1.reward) }
        let stored = Int(allMembers.first(where: { $0.appleUserID == authManager.appleUserID })?.totalEarned ?? 0)
        return max(localSum, stored)
    }

    private var collectableCoins: Int {
        max(0, totalEarnedCoins - redeemedCoins)
    }

    private var myUnredeemedGifts: Int {
        allGifts.filter { $0.childName == authManager.userName && !$0.isRedeemed }.count
    }

    private var todayOpenCount: Int {
        allTasks.filter {
            $0.assignedTo == authManager.userName && $0.isOpen && !$0.isArchived
            && Calendar.current.isDateInToday($0.targetDate)
        }.count
    }

    private var myTasks: [Item] {
        let assigned = allTasks.filter { $0.assignedTo == authManager.userName && !$0.isArchived }
        if showAll { return assigned }
        return assigned.filter { (!$0.isApproved && !$0.isMissed && !$0.isCancelled) || ($0.hasGift && !$0.giftRevealed) }
    }

    private var groupedTasks: [(key: String, tasks: [Item])] {
        let grouped = Dictionary(grouping: myTasks) { $0.dueDateLabel }
        let sorted = grouped
            .map { (key: $0.key, tasks: $0.value) }
            .sorted { first, second in
                guard let d1 = first.tasks.first?.targetDate,
                      let d2 = second.tasks.first?.targetDate else { return false }
                return d1 < d2
            }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let past = sorted.filter { ($0.tasks.first?.targetDate ?? .distantPast) < startOfToday }
        let current = sorted.filter { ($0.tasks.first?.targetDate ?? .distantPast) >= startOfToday }
        return past + current
    }

    private var childDashPastTaskCount: Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return myTasks.filter { $0.targetDate < startOfToday }.count
    }

    private var childDashTodayGroupIndex: Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return groupedTasks.firstIndex { ($0.tasks.first?.targetDate ?? .distantPast) >= startOfToday } ?? groupedTasks.count
    }

    private var childCalendarDayTasks: [Item] {
        let calendar = Calendar.current
        return myTasks
            .filter { calendar.isDate($0.targetDate, inSameDayAs: selectedCalendarDate) }
            .sorted { $0.targetDate < $1.targetDate }
    }

    var body: some View {
        if isAIMode {
            childAIModeView
        } else {
            AnyView(childNormalModeView)
        }
    }

    private var childAIModeView: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: childTheme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                AIAssistantView(allTasks: allTasks, allMembers: allMembers, isIndividual: false, theme: childTheme, isInline: true)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation { isAIMode = false }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Tasks")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.15), in: Capsule())
                    }
                }
            }
            .toolbarColorScheme(childTheme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, childTheme.colorScheme)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var childNormalModeView: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: childTheme.gradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    UserAvatarHeader(name: authManager.userName, avatar: authManager.avatar)
                        .padding(.top, 4)

                    tasksGoalsToggle
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: EarningsCardCenterKey.self,
                                    value: CGPoint(
                                        x: geo.frame(in: .named("childDashboard")).midX + geo.size.width * 0.25,
                                        y: geo.frame(in: .named("childDashboard")).minY + geo.size.height * 0.35
                                    )
                                )
                            }
                        )
                        .onPreferenceChange(EarningsCardCenterKey.self) { earningsCardCenter = $0 }

                    if showGoalsTab {
                        GoalsTabContent(
                            userName: authManager.userName,
                            audience: .child,
                            theme: childTheme,
                            showGoalPicker: $showGoalPicker
                        )
                    } else {
                        childTasksContent
                    }

                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 60)
                }

                CelebrationOverlay(
                    isActive: $showCelebration,
                    title: celebrationTitle,
                    subtitle: celebrationSubtitle,
                    rewardAmount: 0
                )

                FlyingCoinsOverlay(coins: $flyingCoins)

                Color.clear.frame(height: 0)
                    .alert("On the way!", isPresented: $showPickupAck) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("\(pickupAckParentName) is coming to pick you up!")
                    }

            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {
                    if let note = stickyNote {
                        StickyNoteView(message: note.message, color: note.color) {
                            withAnimation { stickyNote = nil }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    HStack(spacing: 14) {
                        pickupButton
                        familyChatButton
                        shoppingBagButton
                        familyProjectsButton
                        wishListButton
                        addTaskButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(childTheme.gradientColors.last?.opacity(0.85) ?? Color.black.opacity(0.5))
                            .overlay(
                                Capsule()
                                    .fill(.white.opacity(childTheme.isLight ? 0.3 : 0.08))
                            )
                            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    withAnimation { isAIMode = true }
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                        .shadow(color: .purple.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 80)
            }
            .coordinateSpace(name: "childDashboard")
            .onAppear {
                scheduleStickyNote(from: childTips)
            }
            .toolbarColorScheme(childTheme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, childTheme.colorScheme)
            .navigationTitle("\(authManager.userName)'s Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    filterToggle
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showNotificationCenter = true
                        } label: {
                            Image(systemName: "bell.fill")
                                .font(.subheadline)
                                .overlay(alignment: .topTrailing) {
                                    let badgeCount = unreadNotifCount + todayOpenCount
                                    if badgeCount > 0 {
                                        Text("\(badgeCount)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.primary)
                                            .frame(minWidth: 14, minHeight: 14)
                                            .background(.red, in: Circle())
                                            .offset(x: 6, y: -6)
                                    }
                                }
                        }

                        Menu {
                            Text(authManager.userName)
                            if !authManager.email.isEmpty {
                                Text(authManager.email)
                            }
                            Divider()
                            Button {
                                showEditProfile = true
                            } label: {
                                Label("Edit Profile", systemImage: "person.crop.circle.fill")
                            }
                            Button {
                                showThemePicker = true
                            } label: {
                                Label("Customize Theme", systemImage: "paintpalette.fill")
                            }
                            Button {
                                showSettings = true
                            } label: {
                                Label("Settings", systemImage: "gearshape.fill")
                            }
                            Button {
                                showShareSheet = true
                            } label: {
                                Label("Refer Your Friends", systemImage: "person.badge.plus")
                            }
                            Button {
                                showPrivacyPolicy = true
                            } label: {
                                Label("Privacy Policy", systemImage: "hand.raised.fill")
                            }
                            Divider()
                            Button(role: .destructive) {
                                authManager.logout()
                            } label: {
                                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            AvatarView(avatarId: authManager.avatar, size: 32)
                        }
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(theme: childTheme)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(theme: childTheme)
            }
            .sheet(isPresented: $showThemePicker) {
                ChildThemePickerView(theme: $childTheme)
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [ShareTextWithLink(text: childShareMessage, url: appStoreURL)])
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showStatsPopup) {
                NavigationStack {
                    ZStack {
                        LinearGradient(
                            colors: childTheme.gradientColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                        VStack(spacing: 16) {
                            earningsCard
                            QuestProgressBar(
                                quest: MonthlyQuest.compute(tasks: allTasks, userName: authManager.userName),
                                theme: childTheme
                            )
                        }
                        .padding(16)
                    }
                    .navigationTitle("My Stats")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showStatsPopup = false }
                                .foregroundStyle(.white)
                        }
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showNotificationCenter) {
                NotificationCenterView(theme: childTheme)
            }
            .sheet(isPresented: $showShoppingBag) {
                ShoppingBagView(theme: childTheme)
            }
            .sheet(isPresented: $showFamilyChat) {
                FamilyChatView(theme: childTheme)
            }
            .onAppear {
                if ScreenshotHelper.isScreenshotMode && ScreenshotHelper.shouldOpenChat {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showFamilyChat = true
                    }
                }
            }
            .sheet(isPresented: $showFamilyProjects) {
                FamilyProjectsListView(theme: childTheme)
            }
            .sheet(isPresented: $showWishList) {
                WishListView(theme: childTheme)
            }
            .sheet(isPresented: $showGoalPicker) {
                GoalPickerView(audience: .child, assignee: authManager.userName, theme: childTheme)
            }
            .onChange(of: showNotificationCenter) { _, showing in
                if !showing {
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastNotifReadTime")
                    unreadNotifCount = 0
                }
            }
            .onAppear {
                refreshUnreadCount()
            }
            .onChange(of: pickupAckTimestamp) { oldVal, newVal in
                guard newVal != oldVal, newVal > 0, Date(timeIntervalSince1970: newVal).timeIntervalSinceNow > -60 else { return }
                pickupAckParentName = myMember?.lastPickupAckBy ?? "A parent"
                showPickupAck = true
            }
            .sheet(isPresented: $showRedeemSheet) {
                RedeemRewardsView(availableCoins: collectableCoins, childName: authManager.userName, theme: childTheme)
            }
            .sheet(isPresented: $showRewardsHistory) {
                RewardsHistoryView(
                    redemptions: myRedemptions,
                    tasks: allTasks,
                    theme: childTheme,
                    childNameFilter: authManager.userName
                )
            }
            .sheet(isPresented: $showMyGifts) {
                MyGiftsView(childName: authManager.userName, theme: childTheme)
            }
            .sheet(isPresented: $showAddTask) {
                AddChildTaskView(
                    childName: authManager.userName,
                    parents: {
                        var seen = Set<String>()
                        return allMembers.filter { $0.isParent }.sorted { !$0.appleUserID.isEmpty && $1.appleUserID.isEmpty }.filter { seen.insert($0.name).inserted }
                    }(),
                    siblings: {
                        var seen = Set<String>()
                        return allMembers.filter { $0.isChild && $0.name != authManager.userName }.sorted { !$0.appleUserID.isEmpty && $1.appleUserID.isEmpty }.filter { seen.insert($0.name).inserted }
                    }(),
                    theme: childTheme
                )
            }
            .fullScreenCover(item: $giftTaskToReveal) { task in
                GiftRevealView(giftText: task.giftText) {
                    task.giftRevealed = true
                    let gift = SurpriseGift(
                        childName: authManager.userName,
                        giftDescription: task.giftText,
                        taskName: task.name
                    )
                    modelContext.insert(gift)
                    let snapshot = CloudKitManager.TaskSnapshot(task)
                    let familyCode = authManager.familyCode
                    Task { await cloudKitManager.pushTaskSnapshot(snapshot, familyCode: familyCode) }
                    giftTaskToReveal = nil
                }
            }
            .alert("Mark as Complete?", isPresented: Binding(
                get: { taskToComplete != nil },
                set: { if !$0 { taskToComplete = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    taskToComplete = nil
                }
                Button(taskToComplete?.createdByChild == true ? "Complete" : "Submit for Review") {
                    if let task = taskToComplete {
                        completeTask(task)
                    }
                    taskToComplete = nil
                }
            } message: {
                if let task = taskToComplete {
                    if task.createdByChild {
                        Text("Mark \"\(task.name)\" as complete? This cannot be undone.")
                    } else {
                        Text("Submit \"\(task.name)\" for parent approval? This cannot be undone.")
                    }
                }
            }
            .alert("Pickup Request Sent!", isPresented: $showPickupSent) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your parents have been notified that you want to be picked up in 5 minutes.")
            }
            .alert("Pickup Limit Reached", isPresented: $showPickupLimit) {
                Button("OK", role: .cancel) { }
            } message: {
                if let limit = subscriptionManager.maxPickupsPerDay {
                    Text("You've used all \(limit) pickup requests for today. Ask your parent to upgrade the plan for more pickups, or try again tomorrow!")
                }
            }
            .alert("Not Yet! ⏰", isPresented: $showTooEarlyAlert) {
                Button("Got It", role: .cancel) { tooEarlyTask = nil }
            } message: {
                if let task = tooEarlyTask {
                    Text("This task is scheduled for \(task.dueDateLabel). You can complete it when the day arrives!")
                }
            }
            .alert(
                taskToDelete.map { $0.isApproved || $0.isInReview } == true ? "Cannot Delete" : "Delete Task?",
                isPresented: Binding(
                    get: { taskToDelete != nil },
                    set: { if !$0 { taskToDelete = nil } }
                )
            ) {
                if let task = taskToDelete {
                    if task.isApproved || task.isInReview {
                        Button("OK", role: .cancel) { taskToDelete = nil }
                    } else if task.isRecurring {
                        Button("Delete This Task Only", role: .destructive) {
                            deleteTask(task)
                            taskToDelete = nil
                        }
                        Button("Delete All Recurring", role: .destructive) {
                            deleteAllRecurring(like: task)
                            taskToDelete = nil
                        }
                        Button("Cancel", role: .cancel) { taskToDelete = nil }
                    } else {
                        Button("Delete", role: .destructive) {
                            deleteTask(task)
                            taskToDelete = nil
                        }
                        Button("Cancel", role: .cancel) { taskToDelete = nil }
                    }
                }
            } message: {
                if let task = taskToDelete {
                    if task.isApproved || task.isInReview {
                        Text("This task is already \(task.isApproved ? "completed" : "in review") and cannot be deleted. Completed tasks are preserved to protect earned coins.")
                    } else if task.isRecurring {
                        let openCount = allTasks.filter {
                            $0.name == task.name && $0.assignedTo == task.assignedTo
                            && !$0.isApproved && !$0.isInReview && $0.isRecurring && !$0.isArchived
                        }.count
                        let completedCount = allTasks.filter {
                            $0.name == task.name && $0.assignedTo == task.assignedTo
                            && ($0.isApproved || $0.isInReview) && $0.isRecurring && !$0.isArchived
                        }.count
                        let msg = completedCount > 0
                            ? "\"\(task.name)\" is a recurring task with \(openCount) open instance\(openCount == 1 ? "" : "s"). \(completedCount) completed instance\(completedCount == 1 ? "" : "s") will be preserved."
                            : "\"\(task.name)\" is a recurring task with \(openCount) open instance\(openCount == 1 ? "" : "s"). Delete just this one or all of them?"
                        Text(msg)
                    } else {
                        Text("Are you sure you want to delete \"\(task.name)\"?")
                    }
                }
            }
            .sheet(item: $taskToEdit) { task in
                EditTaskView(
                    task: task,
                    children: allMembers.filter { $0.isChild && $0.name != authManager.userName },
                    otherParent: allMembers.first { $0.isParent },
                    theme: childTheme,
                    onDelete: task.createdByChild && task.isOpen ? { taskToDelete = task; taskToEdit = nil } : nil,
                    onMarkMissed: {
                        task.status = "missed"
                        let familyCode = authManager.familyCode
                        Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
                        taskToEdit = nil
                    },
                    canEdit: task.createdByChild
                )
            }
            .task {
                archiveOldTasks()
                checkRecurringExtension()
            }
            .sheet(isPresented: $showRecurringExtension) {
                RecurringExtensionSheet(
                    groups: recurringGroups,
                    theme: childTheme,
                    taskLimit: subscriptionManager.maxTasksPerMonth.map { max(0, $0 - subscriptionManager.tasksCreatedThisMonth(allTasks: allTasks)) },
                    onConfirm: { extendChildRecurringTasks() },
                    onDismiss: { RecurringTaskExtender.markDismissed() }
                )
            }
        }
        .confirmationDialog("This task was missed", isPresented: $showMissedOptions, titleVisibility: .visible) {
            Button("Reopen Task") {
                missedTaskToHandle?.status = "open"
                missedTaskToHandle = nil
            }
            Button("Mark as Closed") {
                missedTaskToHandle?.status = "approved"
                missedTaskToHandle = nil
            }
            Button("Cancel", role: .cancel) { missedTaskToHandle = nil }
        } message: {
            Text("Would you like to reopen this task or close it?")
        }
    }

    private func checkRecurringExtension() {
        guard RecurringTaskExtender.needsExtension() else { return }
        let myRecurring = allTasks.filter { $0.assignedTo == authManager.userName && $0.createdByChild }
        let groups = RecurringTaskExtender.findRecurringGroups(from: myRecurring)
        guard !groups.isEmpty else { return }
        recurringGroups = groups
        showRecurringExtension = true
    }

    private func extendChildRecurringTasks() {
        let remaining = subscriptionManager.maxTasksPerMonth.map {
            max(0, $0 - subscriptionManager.tasksCreatedThisMonth(allTasks: allTasks))
        }
        var totalCreated = 0

        for group in recurringGroups {
            let perGroupLimit: Int? = remaining.map { max(0, $0 - totalCreated) }
            if let limit = perGroupLimit, limit <= 0 { break }

            let dates = RecurringTaskExtender.generateExtensionDates(for: group, taskLimit: perGroupLimit)
            for date in dates {
                let task = Item(
                    name: group.name,
                    targetDate: date,
                    assignedTo: group.assignedTo,
                    reward: group.reward,
                    createdByChild: true,
                    isRecurring: true,
                    createdBy: authManager.userName,
                    createdByID: authManager.appleUserID
                )
                modelContext.insert(task)
                notificationManager.scheduleTaskReminder(
                    taskId: task.id,
                    taskName: group.name,
                    assignedTo: group.assignedTo,
                    dueDate: date
                )
                let familyCode = authManager.familyCode
                Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
                totalCreated += 1
            }
        }
        RecurringTaskExtender.markExtended()
    }

    private func refreshUnreadCount() {
        let lastRead = UserDefaults.standard.double(forKey: "lastNotifReadTime")
        let lastReadDate = lastRead > 0 ? Date(timeIntervalSince1970: lastRead) : Date.distantPast
        let myName = authManager.userName
        let all = notificationManager.savedNotifications()
        unreadNotifCount = all.filter { $0.createdAt > lastReadDate && ($0.senderName != myName || $0.senderName.isEmpty) }.count
    }

    private func archiveOldTasks() {
        guard !authManager.familyCode.isEmpty else { return }
        Task {
            await cloudKitManager.archiveOldTasks(context: modelContext, familyCode: authManager.familyCode)
        }
    }

    private func deleteTask(_ task: Item) {
        guard !task.isApproved && !task.isInReview else { return }
        notificationManager.cancelTaskReminder(taskId: task.id)
        let taskId = task.id
        withAnimation { modelContext.delete(task) }
        try? modelContext.save()
        Task {
            await cloudKitManager.deleteRemoteTask(taskId)
        }
    }

    private func deleteAllRecurring(like task: Item) {
        let matching = allTasks.filter {
            $0.name == task.name && $0.assignedTo == task.assignedTo
            && $0.isRecurring && !$0.isArchived
        }
        let toDelete = matching.filter { !$0.isApproved && !$0.isInReview }
        guard !toDelete.isEmpty else { return }
        var taskIDs: [UUID] = []
        for t in toDelete {
            notificationManager.cancelTaskReminder(taskId: t.id)
            taskIDs.append(t.id)
            withAnimation { modelContext.delete(t) }
        }
        try? modelContext.save()
        Task { await cloudKitManager.deleteRemoteTasks(taskIDs) }
    }

    private static let dayDoneMessages = [
        "You crushed it today! Time to relax and recharge.",
        "All done! Today was YOUR day — own it!",
        "Every task done. You're unstoppable!",
        "That's a wrap! You should be proud of yourself.",
        "Mission accomplished! Enjoy the rest of your day.",
        "Boom! Zero tasks left. What a champ!",
        "You showed up and got it done. That's what winners do!",
    ]

    private func completeTask(_ task: Item) {
        let wasLastToday = todayOpenCount == 1
            && Calendar.current.isDateInToday(task.targetDate)

        if task.createdByChild {
            task.status = "approved"
            celebrationTitle = "Task Complete!"
            celebrationSubtitle = ""
        } else {
            task.status = "inReview"
            notificationManager.sendTaskReviewNotification(
                taskName: task.name,
                childName: authManager.userName
            )
            celebrationTitle = "Submitted for Review!"
            celebrationSubtitle = "Waiting for parent approval"
        }

        if wasLastToday {
            celebrationTitle = "You're Done for the Day!"
            celebrationSubtitle = Self.dayDoneMessages.randomElement()!
        }

        let snapshot = CloudKitManager.TaskSnapshot(task)
        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushTaskSnapshot(snapshot, familyCode: familyCode) }
        SoundManager.shared.playApplause()
        celebrationReward = task.reward
        showCelebration = true
        launchFlyingCoins(count: Int(task.reward))
    }

    private func launchFlyingCoins(count: Int) {
        guard count > 0 else { return }
        let coinCount = min(count, 8)
        let source = lastCompletedTaskCenter
        let destination = earningsCardCenter

        var newCoins: [FlyingCoin] = []
        for i in 0..<coinCount {
            let offset = CGFloat(i - coinCount / 2) * 14
            let start = CGPoint(x: source.x + offset, y: source.y)
            newCoins.append(FlyingCoin(
                startPosition: start,
                endPosition: destination,
                delay: Double(i) * 0.25
            ))
        }
        flyingCoins = newCoins

        for (index, _) in newCoins.enumerated() {
            let delay = newCoins[index].delay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.15) {
                withAnimation(.easeInOut(duration: 1.2)) {
                    if index < flyingCoins.count {
                        flyingCoins[index].arrived = true
                    }
                }
            }
        }

        let totalFlyTime = Double(coinCount) * 0.25 + 1.2
        DispatchQueue.main.asyncAfter(deadline: .now() + totalFlyTime) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.4)) {
                coinLandBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    coinLandBounce = false
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + totalFlyTime + 0.8) {
            flyingCoins.removeAll()
        }
    }

    private var pickupButton: some View {
        Button {
            guard subscriptionManager.canSendPickup() else {
                showPickupLimit = true
                return
            }
            subscriptionManager.recordPickup()
            Task {
                if let member = allMembers.first(where: { $0.name == authManager.userName }) {
                    member.lastPickupAt = Date()
                    await cloudKitManager.pushMember(member, familyCode: authManager.familyCode)
                }
            }
            showPickupSent = true
        } label: {
            ZStack {
                Image(systemName: "car.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: -1, y: -2)
                Image(systemName: "clock.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.yellow)
                    .offset(x: 10, y: 8)
            }
            .frame(width: 44, height: 44)
            .background(.cyan.opacity(0.5), in: Circle())
        }
    }

    private var addTaskButton: some View {
        Button {
            showAddTask = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.teal, in: Circle())
        }
    }

    private var familyChatButton: some View {
        Button {
            showFamilyChat = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.blue.opacity(0.5), in: Circle())

                let lastRead = UserDefaults.standard.double(forKey: "lastChatReadTime")
                let unread = chatMessages.filter { $0.sentAt.timeIntervalSince1970 > lastRead && $0.senderAppleUserID != authManager.appleUserID }.count
                if unread > 0 {
                    Text("\(unread)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(.red, in: Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
        .accessibilityIdentifier("familyChatButton")
    }

    private var shoppingBagButton: some View {
        Button {
            showShoppingBag = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.orange.opacity(0.5), in: Circle())

                let unboughtCount = shoppingItems.filter { !$0.isBought }.count
                if unboughtCount > 0 {
                    Text("\(unboughtCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(.red, in: Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
    }

    private var familyProjectsButton: some View {
        Button {
            showFamilyProjects = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.teal.opacity(0.5), in: Circle())

                let activeCount = allProjects.filter { !$0.isCompleted }.count
                if activeCount > 0 {
                    Text("\(activeCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(.red, in: Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
    }

    private var wishListButton: some View {
        Button {
            showWishList = true
        } label: {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.purple.opacity(0.5), in: Circle())
        }
    }


    private var statsIconPill: some View {
        Button { showStatsPopup = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
                Text("\(collectableCoins)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                Text("\(awaitingApprovalCoins)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(childTheme.cardBackground, in: Capsule())
        }
    }

    private var earningsCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        Text("\(collectableCoins)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                            .contentTransition(.numericText())
                    }
                    Text("Ready to Redeem")
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(childTheme.tertiaryTextColor)
                    .frame(width: 1, height: 50)

                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                            .scaleEffect(coinLandBounce ? 1.3 : 1.0)
                        Text("\(awaitingApprovalCoins)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                            .scaleEffect(coinLandBounce ? 1.3 : 1.0)
                            .contentTransition(.numericText())
                    }
                    Text("Awaiting Approval")
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 12) {
                Button {
                    showRedeemSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill")
                            .font(.caption)
                        Text("Collect Rewards")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(collectableCoins > 0 ? .orange : childTheme.cardBackgroundLight, in: RoundedRectangle(cornerRadius: 10))
                }
                .disabled(collectableCoins <= 0)

                Button {
                    showMyGifts = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill")
                            .font(.caption)
                            .foregroundStyle(.pink)
                        Text("Gifts")
                            .font(.caption.weight(.semibold))
                        if myUnredeemedGifts > 0 {
                            Text("\(myUnredeemedGifts)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.primary)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(.pink, in: Circle())
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    showRewardsHistory = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                        Text("History")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(18)
        .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.green.opacity(0.2), lineWidth: 1)
        )
    }

    private var filterToggle: some View {
        Button {
            withAnimation(.snappy) {
                showAll.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: showAll ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                Text(showAll ? "All Tasks" : "Active")
                    .font(.subheadline)
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 12) {
                Spacer().frame(height: 80)
                Image(systemName: showAll ? "tray" : "checkmark.circle")
                    .font(.system(size: 56))
                    .foregroundStyle(.primary.opacity(0.3))
                Text(showAll ? "No tasks yet" : "All done!")
                    .font(childTheme.font(.title3))
                    .foregroundStyle(.primary.opacity(0.7))
                Text(showAll ? "Your parent hasn't assigned any tasks yet." : "You've completed all your active tasks.")
                    .font(childTheme.font(.subheadline))
                    .foregroundStyle(.primary.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
        }
        .refreshable {
            guard !authManager.familyCode.isEmpty else { return }
            await cloudKitManager.syncAll(context: modelContext, familyCode: authManager.familyCode) { tasks in
                for task in tasks {
                    notificationManager.scheduleTaskReminder(taskId: task.id, taskName: task.name, assignedTo: task.assignedTo, dueDate: task.targetDate)
                }
            }
        }
    }

    private var tasksGoalsToggle: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showGoalsTab = false }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checklist")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Tasks")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(showGoalsTab ? childTheme.secondaryTextColor : childTheme.textColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(showGoalsTab ? Color.clear : childTheme.cardBackground, in: Capsule())
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showGoalsTab = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Goals")
                        .font(.subheadline.weight(.bold))
                    let activeCount = allGoals.filter { $0.assignedTo == authManager.userName && $0.isActive }.count
                    if activeCount > 0 {
                        Text("\(activeCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(.teal, in: Circle())
                    }
                }
                .foregroundStyle(showGoalsTab ? childTheme.textColor : childTheme.secondaryTextColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(showGoalsTab ? childTheme.cardBackground : Color.clear, in: Capsule())
            }

            Spacer()

            if !showGoalsTab {
                statsIconPill
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var childTasksContent: some View {
        if showCalendarView {
            dashboardViewModeToggle
            WeekCalendarStrip(
                selectedDate: $selectedCalendarDate,
                tasks: myTasks,
                theme: childTheme
            )
            if childCalendarDayTasks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 40))
                        .foregroundStyle(.primary.opacity(0.3))
                    Text("No tasks on this day")
                        .font(.headline)
                        .foregroundStyle(.primary.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(childCalendarDayTasks) { task in
                        childTaskRow(task: task)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
        } else if myTasks.isEmpty {
            dashboardViewModeToggle
            emptyState
        } else {
            dashboardViewModeToggle
            taskList
        }
    }

    private var dashboardViewModeToggle: some View {
        HStack {
            if !showCalendarView {
                Button {
                    withAnimation(.snappy) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                            .font(.system(size: 12, weight: .semibold))
                        Text(isExpanded ? "Collapse" : "Expand")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(childTheme.secondaryTextColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(childTheme.cardBackgroundLight, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button {
                withAnimation(.snappy) { showCalendarView.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showCalendarView ? "list.bullet" : "calendar")
                        .font(.system(size: 12, weight: .semibold))
                    Text(showCalendarView ? "List" : "Calendar")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(childTheme.secondaryTextColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(childTheme.cardBackgroundLight, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var taskList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(groupedTasks.enumerated()), id: \.element.key) { index, group in
                            if index == childDashTodayGroupIndex && childDashPastTaskCount > 0 {
                                PastTasksDivider(count: childDashPastTaskCount)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                if isExpanded {
                                    Text(group.key)
                                        .font(childTheme.font(.subheadline).weight(.semibold))
                                        .foregroundStyle(.primary.opacity(0.6))
                                        .padding(.leading, 4)

                                    ForEach(group.tasks) { task in
                                        childTaskRow(task: task)
                                            .draggable(TaskTransfer(id: task.id))
                                    }
                                } else {
                                    GroupCard(dateLabel: group.key, count: group.tasks.count, theme: childTheme)
                                }
                            }
                            .id(group.key)
                            .dropDestination(for: TaskTransfer.self) { items, _ in
                                guard let transfer = items.first,
                                      let refDate = group.tasks.first?.targetDate else { return false }
                                return dashboardHandleTaskDrop(taskId: transfer.id, toDate: refDate)
                            } isTargeted: { _ in }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation { proxy.scrollTo("Today", anchor: .top) }
                }
            }
            .onChange(of: showAll) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation { proxy.scrollTo("Today", anchor: .top) }
                }
            }
        }
        .refreshable {
            guard !authManager.familyCode.isEmpty else { return }
            await cloudKitManager.syncAll(context: modelContext, familyCode: authManager.familyCode) { tasks in
                for task in tasks {
                    notificationManager.scheduleTaskReminder(taskId: task.id, taskName: task.name, assignedTo: task.assignedTo, dueDate: task.targetDate)
                }
            }
            refreshUnreadCount()
        }
    }

    private func dashboardHandleTaskDrop(taskId: UUID, toDate referenceDate: Date) -> Bool {
        guard let task = allTasks.first(where: { $0.id == taskId }) else { return false }
        rescheduleTask(task, toSameDayAs: referenceDate)
        notificationManager.cancelTaskReminder(taskId: task.id)
        notificationManager.scheduleTaskReminder(
            taskId: task.id,
            taskName: task.name,
            assignedTo: task.assignedTo,
            dueDate: task.targetDate
        )
        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
        return true
    }

    private func scheduleStickyNote(from tips: [String]) {
        let delay = Double.random(in: 120...300)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard stickyNote == nil else { return }
            let msg = tips.randomElement() ?? ""
            let clr = stickyNoteColors.randomElement() ?? .yellow
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                stickyNote = (message: msg, color: clr)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                withAnimation { stickyNote = nil }
                scheduleStickyNote(from: tips)
            }
        }
    }

    private func statusColor(for task: Item) -> Color {
        if task.isApproved { return .green }
        if task.isInReview { return .orange }
        if task.isMissed { return .red }
        if task.isCancelled { return .gray }
        return childTheme.tertiaryTextColor
    }

    private func statusLabel(for task: Item) -> String {
        if task.isApproved { return "Done" }
        if task.isInReview { return "Review" }
        if task.isMissed { return "Missed" }
        if task.isCancelled { return "Cancelled" }
        return "To Do"
    }

    private func childTaskRow(task: Item) -> some View {
        HStack(spacing: 14) {
            Button {
                if task.isMissed {
                    missedTaskToHandle = task
                    showMissedOptions = true
                    return
                }
                guard task.isOpen else { return }
                if !task.canComplete {
                    tooEarlyTask = task
                    showTooEarlyAlert = true
                } else {
                    taskToComplete = task
                }
            } label: {
                VStack(spacing: 3) {
                    ZStack {
                        Circle()
                            .strokeBorder(statusColor(for: task), lineWidth: 2)
                            .frame(width: 32, height: 32)

                        if task.isApproved {
                            Circle()
                                .fill(.green)
                                .frame(width: 32, height: 32)
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.primary)
                        } else if task.isInReview {
                            Circle()
                                .fill(.orange)
                                .frame(width: 32, height: 32)
                            Image(systemName: "clock")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                        } else if task.isMissed {
                            Circle()
                                .fill(.red)
                                .frame(width: 32, height: 32)
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.primary)
                        } else if task.isCancelled {
                            Circle()
                                .fill(.gray)
                                .frame(width: 32, height: 32)
                            Image(systemName: "minus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                    }
                    Text(statusLabel(for: task))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .disabled(task.isApproved || task.isCancelled)

            Button {
                taskToEdit = task
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(task.emoji) \(task.name)")
                            .font(childTheme.font(.body))
                            .lineLimit(1)
                            .strikethrough(task.isApproved || task.isCancelled)
                            .foregroundStyle(task.isApproved || task.isCancelled ? childTheme.tertiaryTextColor : childTheme.textColor)

                        HStack(spacing: 6) {
                            if task.isMissed {
                                Text("Missed")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.red)
                            } else if task.isInReview {
                                Text("In Review")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            } else if task.isApproved {
                                Text("Approved")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            } else if task.isCancelled {
                                Text("Cancelled")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.gray)
                            }

                            Text(task.targetDate, format: .dateTime.hour().minute())
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)

                            if task.reward > 0 {
                                Text("•")
                                    .foregroundStyle(.primary.opacity(0.3))
                                CoinDisplay(count: Int(task.reward), earned: task.isApproved)
                            }

                            if task.belongsToProject {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(.indigo, in: Circle())
                            }

                            if task.belongsToGoal {
                                Image(systemName: "target")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(.teal, in: Circle())
                            }

                            if task.hasGift {
                                Image(systemName: task.giftRevealed ? "gift.circle.fill" : "gift.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(task.isApproved && !task.giftRevealed ? Color(red: 1.0, green: 0.2, blue: 0.5) : Color(red: 1.0, green: 0.2, blue: 0.5).opacity(0.7))
                                    .overlay(
                                        Image(systemName: task.giftRevealed ? "gift.circle" : "gift")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.primary.opacity(0.6))
                                    )
                                    .symbolEffect(.pulse, options: .repeating, isActive: task.isApproved && !task.giftRevealed)
                            }
                        }
                        .lineLimit(1)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if task.hasGift && task.isApproved && !task.giftRevealed {
                Button {
                    giftTaskToReveal = task
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Open")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
            }

            if task.createdByChild && task.isOpen {
                Button {
                    taskToDelete = task
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(.red.opacity(0.7), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .opacity(task.isApproved || task.isCancelled ? 0.7 : 1)
        .background(.primary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    task.isMissed ? .red.opacity(0.3) : task.isCancelled ? .gray.opacity(0.3) : task.isInReview ? .orange.opacity(0.3) : childTheme.tertiaryTextColor,
                    lineWidth: 1
                )
        )
        .contextMenu {
            if task.isOpen || task.isInReview {
                Button {
                    task.status = "missed"
                    let familyCode = authManager.familyCode
                    Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
                } label: {
                    Label("Mark as Missed", systemImage: "exclamationmark.triangle")
                }
                Button(role: .destructive) {
                    task.status = "cancelled"
                    let familyCode = authManager.familyCode
                    Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
                } label: {
                    Label("Cancel Task", systemImage: "xmark.circle")
                }
            }
            if task.isMissed || task.isCancelled {
                Button {
                    task.status = "open"
                    let familyCode = authManager.familyCode
                    Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
                } label: {
                    Label("Reopen Task", systemImage: "arrow.uturn.backward")
                }
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onChange(of: taskToComplete?.id) { _, newId in
                        if newId == task.id {
                            let frame = geo.frame(in: .named("childDashboard"))
                            lastCompletedTaskCenter = CGPoint(x: frame.midX, y: frame.midY)
                        }
                    }
            }
        )
    }
}

// MARK: - Add Task View (Child)

struct AddChildTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    @Query(sort: \Item.targetDate) private var allTasks: [Item]
    let childName: String
    let parents: [FamilyMember]
    var siblings: [FamilyMember] = []
    var theme: ChildTheme = ChildTheme.load(for: "child")

    @State private var taskName = ""
    @State private var targetDate = roundedToNext5Minutes()
    @State private var assignedTo = ""
    @State private var recurrenceType: RecurrenceType = .none
    @State private var occurrences = 10
    @State private var selectedWeekdays: Set<Int> = []
    @State private var selectedTemplate: TaskTemplate?
    @State private var useSmartScheduler = false
    @State private var smartInput = ""
    @State private var parsedTask: ParsedTask?
    @State private var showQuotaAlert = false
    @State private var showDictionary = false

    private var isValid: Bool {
        !taskName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var recurrenceUnitLabel: String {
        switch recurrenceType {
        case .none: return ""
        case .daily: return occurrences == 1 ? "day" : "days"
        case .weekly: return occurrences == 1 ? "week" : "weeks"
        case .monthly: return occurrences == 1 ? "month" : "months"
        }
    }

    private var stepperMax: Int {
        switch recurrenceType {
        case .daily: return 90
        case .weekly: return 52
        case .monthly: return 12
        case .none: return 52
        }
    }

    private func applyTemplate(_ template: TaskTemplate) {
        selectedTemplate = template
        taskName = template.name
        recurrenceType = template.suggestedRecurrence
        switch template.suggestedRecurrence {
        case .daily: occurrences = 10
        case .weekly:
            occurrences = 4
            if selectedWeekdays.isEmpty {
                let weekday = Calendar.current.component(.weekday, from: targetDate)
                selectedWeekdays.insert(weekday)
            }
        case .monthly: occurrences = 4
        case .none: break
        }
    }

    private func applyDictionaryEntry(_ entry: TaskDictionaryEntry) {
        taskName = entry.name
        recurrenceType = entry.recurrence
        switch entry.recurrence {
        case .daily: occurrences = 10
        case .weekly:
            occurrences = 4
            if selectedWeekdays.isEmpty {
                let weekday = Calendar.current.component(.weekday, from: targetDate)
                selectedWeekdays.insert(weekday)
            }
        case .monthly: occurrences = 4
        case .none: break
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: theme.gradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 20)

                        Picker("Mode", selection: $useSmartScheduler) {
                            Text("Form").tag(false)
                            Text("Smart Scheduler").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .colorScheme(.dark)

                        if useSmartScheduler {
                            smartSchedulerSection
                        } else {

                        if let remaining = subscriptionManager.tasksRemaining(allTasks: allTasks) {
                            VStack(spacing: 6) {
                                HStack(spacing: 8) {
                                    Image(systemName: remaining == 0 ? "xmark.circle.fill" : remaining <= 10 ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                        .foregroundStyle(remaining == 0 ? .red : remaining <= 10 ? .orange : .cyan)
                                    Text(remaining == 0 ? "Task limit reached" : "\(remaining) tasks remaining this month")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.primary.opacity(0.85))
                                    Spacer()
                                }

                                if remaining <= 10 {
                                    Text(remaining == 0 ? "Ask your parent to upgrade the plan to add more tasks." : "Running low — ask your parent to upgrade for more tasks.")
                                        .font(.caption2)
                                        .foregroundStyle(.orange.opacity(0.8))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(12)
                            .background(
                                (remaining == 0 ? Color.red.opacity(0.1) : remaining <= 10 ? Color.orange.opacity(0.1) : Color.cyan.opacity(0.08)),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        remaining == 0 ? .red.opacity(0.2) : remaining <= 10 ? .orange.opacity(0.2) : .cyan.opacity(0.15),
                                        lineWidth: 1
                                    )
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Task Name")
                                    .font(.caption)
                                    .foregroundStyle(.primary.opacity(0.5))
                                Spacer()
                                Button {
                                    showDictionary = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "book.fill")
                                            .font(.system(size: 12))
                                        Text("Task Dictionary")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .foregroundStyle(calmAccent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(calmAccent.opacity(0.15), in: Capsule())
                                }
                            }

                            TextField("What do you need to do?", text: $taskName)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .padding(14)
                                .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(recurrenceType == .none ? "Due Date" : "Start Date")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.5))

                            FiveMinuteDatePicker(selection: $targetDate, minimumDate: Date())
                            .frame(height: 44)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(.primary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.primary.opacity(0.2), lineWidth: 1)
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Assign To")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.5))

                            VStack(spacing: 8) {
                                assignChip(name: childName, isSelected: assignedTo.isEmpty || assignedTo == childName) {
                                    assignedTo = ""
                                }

                                ForEach(parents) { parent in
                                    assignChip(name: parent.name, isSelected: assignedTo == parent.name) {
                                        assignedTo = parent.name
                                    }
                                }

                                ForEach(siblings) { sibling in
                                    assignChip(name: sibling.name, isSelected: assignedTo == sibling.name) {
                                        assignedTo = sibling.name
                                    }
                                }
                            }
                        }

                        childRecurrenceSection

                        } // end else (form mode)

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
            }
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if !subscriptionManager.canCreateMoreTasks(allTasks: allTasks) || !subscriptionManager.canCreateTask {
                            showQuotaAlert = true
                            return
                        }
                        let dates = generateTaskDates()
                        let trimmedName = taskName.trimmingCharacters(in: .whitespaces)
                        let target = assignedTo.isEmpty ? childName : assignedTo
                        let recurring = recurrenceType != .none
                        var createdTasks: [Item] = []
                        for date in dates {
                            let task = Item(
                                name: trimmedName,
                                targetDate: date,
                                assignedTo: target,
                                reward: 0,
                                createdByChild: true,
                                isRecurring: recurring,
                                createdBy: childName,
                                createdByID: authManager.appleUserID
                            )
                            modelContext.insert(task)
                            createdTasks.append(task)
                            subscriptionManager.recordTaskCreation()
                            notificationManager.scheduleTaskReminder(
                                taskId: task.id,
                                taskName: trimmedName,
                                assignedTo: target,
                                dueDate: date
                            )
                        }
                        let familyCode = authManager.familyCode
                        Task {
                            for task in createdTasks {
                                await cloudKitManager.pushTask(task, familyCode: familyCode)
                            }
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showDictionary) {
            TaskDictionaryView(theme: theme) { entry in
                applyDictionaryEntry(entry)
            }
        }
        .alert("Task Limit Reached", isPresented: $showQuotaAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if !subscriptionManager.canCreateMoreTasks(allTasks: allTasks) {
                if let limit = subscriptionManager.maxTasksPerMonth {
                    Text("You've used all \(limit) tasks for this month. Ask your parent to upgrade the plan for more tasks, or wait until next month.")
                }
            } else {
                Text("You're creating tasks too quickly. Please wait a moment and try again.")
            }
        }
    }

    private var templatePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Templates")
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.7))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(taskTemplates) { template in
                        Button {
                            applyTemplate(template)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: template.icon)
                                    .font(.title3)
                                    .foregroundStyle(selectedTemplate?.name == template.name ? .white : template.color)
                                Text(template.name)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(selectedTemplate?.name == template.name ? .white : theme.secondaryTextColor)
                                    .lineLimit(1)
                            }
                            .frame(width: 90, height: 70)
                            .background(
                                selectedTemplate?.name == template.name ? template.color.opacity(0.6) : theme.cardBackgroundLight,
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        selectedTemplate?.name == template.name ? template.color : theme.cardBackgroundLight,
                                        lineWidth: 1
                                    )
                            )
                        }
                    }
                }
            }
        }
    }

    private var childRecurrenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recurrence")
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.5))

            Picker("Recurrence", selection: $recurrenceType) {
                ForEach(RecurrenceType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .colorScheme(.dark)
            .onChange(of: recurrenceType) { _, newValue in
                switch newValue {
                case .daily: occurrences = 10
                case .weekly:
                    occurrences = 4
                    if selectedWeekdays.isEmpty {
                        let weekday = Calendar.current.component(.weekday, from: targetDate)
                        selectedWeekdays.insert(weekday)
                    }
                case .monthly: occurrences = 4
                case .none: break
                }
            }

            if recurrenceType != .none {
                if recurrenceType == .weekly {
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { day in
                            Button {
                                if selectedWeekdays.contains(day) {
                                    if selectedWeekdays.count > 1 {
                                        selectedWeekdays.remove(day)
                                    }
                                } else {
                                    selectedWeekdays.insert(day)
                                }
                            } label: {
                                Text(weekdayLabels[day - 1])
                                    .font(.caption.weight(.bold))
                                    .frame(width: 36, height: 36)
                                    .background(
                                        selectedWeekdays.contains(day) ? calmAccent : theme.cardBackground,
                                        in: Circle()
                                    )
                                    .foregroundStyle(selectedWeekdays.contains(day) ? .white : theme.secondaryTextColor)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                Stepper(value: $occurrences, in: 2...stepperMax) {
                    HStack {
                        Text("Repeat for")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(occurrences) \(recurrenceUnitLabel)")
                            .foregroundStyle(.primary.opacity(0.7))
                    }
                    .font(.subheadline)
                }
                .tint(.primary)
                .padding(12)
                .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                )

                let taskCount = generateTaskDates().count
                Text("Will create \(taskCount) task\(taskCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.cyan.opacity(0.8))
            }
        }
    }

    private var smartSchedulerSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.yellow)
                    Text("Describe your task in plain English")
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.5))
                }

                TextField("e.g. Read a book tomorrow 4pm daily", text: $smartInput, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .padding(14)
                    .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                    )
                    .onSubmit { parseSmartInput() }

                Button {
                    parseSmartInput()
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Parse")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(smartInput.trimmingCharacters(in: .whitespaces).isEmpty ? theme.cardBackgroundLight : calmAccent, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(smartInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let parsed = parsedTask {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Parsed Result")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(12)
                    .background(.green.opacity(0.1))

                    VStack(spacing: 12) {
                        smartRow(icon: "pencil.line", label: "Task", value: parsed.name.isEmpty ? "—" : parsed.name)
                        smartRow(icon: "calendar", label: "Date", value: parsed.hasDate ? parsed.targetDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()) : "Not detected — defaults to now")
                        smartRow(icon: "person.fill", label: "Assign To", value: parsed.assignedTo.isEmpty ? childName : parsed.assignedTo)
                        smartRow(icon: "repeat", label: "Recurrence", value: parsed.recurrence.rawValue)
                    }
                    .padding(12)
                }
                .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.green.opacity(0.2), lineWidth: 1)
                )

                Button {
                    applyParsedTask(parsed)
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Task")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(parsed.name.isEmpty ? theme.cardBackgroundLight : calmAccent, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(parsed.name.isEmpty)
            }
        }
    }

    private func smartRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.5))
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.5))
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    private func parseSmartInput() {
        let memberNames = parents.map { $0.name }
        let parser = SmartTaskParser(familyMembers: memberNames)
        withAnimation { parsedTask = parser.parse(smartInput) }
    }

    private func applyParsedTask(_ parsed: ParsedTask) {
        taskName = parsed.name
        targetDate = parsed.targetDate
        assignedTo = parsed.assignedTo
        recurrenceType = parsed.recurrence

        if !subscriptionManager.canCreateMoreTasks(allTasks: allTasks) || !subscriptionManager.canCreateTask {
            showQuotaAlert = true
            return
        }

        let dates = generateTaskDates()
        let trimmedName = taskName.trimmingCharacters(in: .whitespaces)
        let recurring = recurrenceType != .none

        for date in dates {
            let task = Item(
                name: trimmedName,
                targetDate: date,
                assignedTo: childName,
                reward: 0,
                status: "open",
                createdByChild: true,
                isRecurring: recurring,
                createdBy: childName,
                createdByID: authManager.appleUserID
            )
            modelContext.insert(task)

            notificationManager.scheduleTaskReminder(
                taskId: task.id,
                taskName: task.name,
                assignedTo: task.assignedTo,
                dueDate: task.targetDate
            )

            if !authManager.familyCode.isEmpty {
                let snapshot = CloudKitManager.TaskSnapshot(task)
                Task {
                    await cloudKitManager.pushTaskSnapshot(snapshot, familyCode: authManager.familyCode)
                }
            }
        }

        dismiss()
    }

    private func generateTaskDates() -> [Date] {
        let calendar = Calendar.current

        switch recurrenceType {
        case .none:
            return [targetDate]

        case .daily:
            return (0..<occurrences).compactMap { i in
                calendar.date(byAdding: .day, value: i, to: targetDate)
            }

        case .weekly:
            guard !selectedWeekdays.isEmpty else { return [targetDate] }
            var dates: [Date] = []
            let timeComponents = calendar.dateComponents([.hour, .minute], from: targetDate)
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: targetDate)?.start ?? targetDate

            for week in 0..<occurrences {
                guard let weekBase = calendar.date(byAdding: .weekOfYear, value: week, to: weekStart) else { continue }
                let baseWeekday = calendar.component(.weekday, from: weekBase)

                for day in selectedWeekdays.sorted() {
                    let dayOffset = (day - baseWeekday + 7) % 7
                    guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekBase) else { continue }

                    var components = calendar.dateComponents([.year, .month, .day], from: dayDate)
                    components.hour = timeComponents.hour
                    components.minute = timeComponents.minute

                    if let finalDate = calendar.date(from: components), finalDate >= targetDate {
                        dates.append(finalDate)
                    }
                }
            }
            return dates

        case .monthly:
            return (0..<occurrences).compactMap { i in
                calendar.date(byAdding: .month, value: i, to: targetDate)
            }
        }
    }

    private func assignChip(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? calmAccent : theme.tertiaryTextColor)
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(12)
            .background(
                isSelected ? calmAccent.opacity(0.15) : theme.cardBackground,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? calmAccent.opacity(0.4) : theme.cardBackground,
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - Redeem Rewards View

struct RedeemRewardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    let availableCoins: Int
    let childName: String
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")

    @State private var selectedType = "toy"
    @State private var coinAmount = ""
    @State private var description = ""

    private var amount: Int {
        Int(coinAmount) ?? 0
    }

    private var isValid: Bool {
        amount > 0 && amount <= availableCoins && !description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 12)

                        VStack(spacing: 8) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.yellow)

                            Text("\(availableCoins) coins available")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)

                            Text("Choose how you'd like to use your coins!")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.7))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("What would you like?")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.7))

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], spacing: 10) {
                                ForEach(redemptionTypes, id: \.0) { type in
                                    Button {
                                        selectedType = type.0
                                    } label: {
                                        VStack(spacing: 6) {
                                            Image(systemName: type.2)
                                                .font(.title3)
                                            Text(type.1)
                                                .font(.caption2.weight(.medium))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            selectedType == type.0 ? .orange.opacity(0.2) : theme.cardBackgroundLight,
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                        .foregroundStyle(selectedType == type.0 ? .orange : theme.secondaryTextColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(
                                                    selectedType == type.0 ? .orange.opacity(0.5) : theme.cardBackgroundLight,
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("How many coins?")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.7))

                            HStack(spacing: 10) {
                                Image(systemName: "star.circle.fill")
                                    .foregroundStyle(.yellow)

                                TextField("0", text: $coinAmount)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .keyboardType(.numberPad)

                                Spacer()

                                Button("Use all") {
                                    coinAmount = "\(availableCoins)"
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                            }
                            .padding(14)
                            .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                            )

                            if amount > availableCoins {
                                Text("You don't have enough coins")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Describe what you want")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.7))

                            TextField("e.g., LEGO Star Wars set", text: $description)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .padding(14)
                                .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                                )
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
            }
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .navigationTitle("Collect Rewards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        let redemption = RewardRedemption(
                            childName: childName,
                            coinAmount: amount,
                            redemptionType: selectedType,
                            itemDescription: description.trimmingCharacters(in: .whitespaces)
                        )
                        modelContext.insert(redemption)
                        let familyCode = authManager.familyCode
                        Task {
                            _ = await cloudKitManager.pushRedemption(redemption, familyCode: familyCode)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Coin Event Model

enum CoinEventKind {
    case earned
    case inReview
    case redeemed
    case rejected
}

struct CoinEvent: Identifiable {
    let id: String
    let date: Date
    let title: String
    let subtitle: String
    let coins: Int
    let kind: CoinEventKind
    let childName: String
    let icon: String
    var redemption: RewardRedemption?

    var kindLabel: String {
        switch kind {
        case .earned: return "Earned"
        case .inReview: return "In Review"
        case .redeemed: return "Redeemed"
        case .rejected: return "Returned"
        }
    }

    var kindColor: Color {
        switch kind {
        case .earned: return .green
        case .inReview: return .orange
        case .redeemed: return calmAccent
        case .rejected: return .red
        }
    }
}

// MARK: - Rewards History View

struct RewardsHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    let redemptions: [RewardRedemption]
    var tasks: [Item] = []
    var isParent: Bool = false
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    var childNameFilter: String = ""
    @State private var confirmFulfill: RewardRedemption?
    @State private var selectedFilter: CoinFilterOption = .all

    enum CoinFilterOption: String, CaseIterable {
        case all = "All"
        case earned = "Earned"
        case inReview = "In Review"
        case redeemed = "Redeemed"
    }

    private var coinEvents: [CoinEvent] {
        var events: [CoinEvent] = []

        let filteredTasks = childNameFilter.isEmpty
            ? tasks.filter { $0.reward > 0 }
            : tasks.filter { $0.reward > 0 && $0.assignedTo == childNameFilter }

        for task in filteredTasks {
            if task.isApproved {
                events.append(CoinEvent(
                    id: "earned-\(task.id.uuidString)",
                    date: task.targetDate,
                    title: task.name,
                    subtitle: task.assignedTo.isEmpty ? "Task completed" : task.assignedTo,
                    coins: Int(task.reward),
                    kind: .earned,
                    childName: task.assignedTo,
                    icon: "checkmark.circle.fill"
                ))
            } else if task.isInReview {
                events.append(CoinEvent(
                    id: "review-\(task.id.uuidString)",
                    date: task.targetDate,
                    title: task.name,
                    subtitle: task.assignedTo.isEmpty ? "Awaiting approval" : "\(task.assignedTo) — awaiting approval",
                    coins: Int(task.reward),
                    kind: .inReview,
                    childName: task.assignedTo,
                    icon: "hourglass.circle.fill"
                ))
            }
        }

        let filteredRedemptions = childNameFilter.isEmpty
            ? redemptions
            : redemptions.filter { $0.childName == childNameFilter }

        for r in filteredRedemptions {
            if r.isRejected {
                events.append(CoinEvent(
                    id: "redemption-\(r.id.uuidString)",
                    date: r.resolvedAt ?? r.createdAt,
                    title: r.itemDescription,
                    subtitle: "\(r.coinAmount) coins returned",
                    coins: r.coinAmount,
                    kind: .rejected,
                    childName: r.childName,
                    icon: "arrow.uturn.backward.circle.fill",
                    redemption: r
                ))
            } else {
                events.append(CoinEvent(
                    id: "redemption-\(r.id.uuidString)",
                    date: r.createdAt,
                    title: r.itemDescription,
                    subtitle: r.typeLabel,
                    coins: r.coinAmount,
                    kind: .redeemed,
                    childName: r.childName,
                    icon: r.typeIcon,
                    redemption: r
                ))
            }
        }

        return events.sorted { $0.date > $1.date }
    }

    private var filteredEvents: [CoinEvent] {
        switch selectedFilter {
        case .all: return coinEvents
        case .earned: return coinEvents.filter { $0.kind == .earned }
        case .inReview: return coinEvents.filter { $0.kind == .inReview }
        case .redeemed: return coinEvents.filter { $0.kind == .redeemed || $0.kind == .rejected }
        }
    }

    private var summaryEarned: Int {
        coinEvents.filter { $0.kind == .earned }.reduce(0) { $0 + $1.coins }
    }

    private var summaryInReview: Int {
        coinEvents.filter { $0.kind == .inReview }.reduce(0) { $0 + $1.coins }
    }

    private var summaryRedeemed: Int {
        coinEvents.filter { $0.kind == .redeemed }.reduce(0) { $0 + $1.coins }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                if coinEvents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle")
                            .font(.system(size: 56))
                            .foregroundStyle(.primary.opacity(0.5))
                        Text("No coin activity yet")
                            .font(.title3)
                            .foregroundStyle(.primary.opacity(0.85))
                        Text(isParent ? "Coin activity will appear here as tasks are completed." : "Complete tasks and redeem your coins!")
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            coinSummaryCard

                            filterPicker

                            if let awaitingAck = awaitingAcknowledgement, isParent && !awaitingAck.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundStyle(calmAccent)
                                        Text("Pending Acknowledgement (\(awaitingAck.count))")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(calmAccent)
                                    }
                                    .padding(.horizontal, 4)

                                    ForEach(awaitingAck) { event in
                                        coinEventRow(event)
                                    }
                                }
                                .padding(.bottom, 4)
                            }

                            ForEach(displayEvents) { event in
                                coinEventRow(event)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Coin History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Confirm Receipt?", isPresented: Binding(
                get: { confirmFulfill != nil },
                set: { if !$0 { confirmFulfill = nil } }
            )) {
                Button("Cancel", role: .cancel) { confirmFulfill = nil }
                Button("I Received It") {
                    if let r = confirmFulfill {
                        r.status = "fulfilled"
                        r.resolvedAt = Date()
                        let familyCode = authManager.familyCode
                        Task {
                            _ = await cloudKitManager.pushRedemption(r, familyCode: familyCode)
                        }
                    }
                    confirmFulfill = nil
                }
            } message: {
                if let r = confirmFulfill {
                    Text("Confirm you received \"\(r.itemDescription)\"? This will close the request permanently.")
                }
            }
        }
    }

    private var awaitingAcknowledgement: [CoinEvent]? {
        let ack = filteredEvents.filter { $0.redemption?.isApproved == true }
        return ack.isEmpty ? nil : ack
    }

    private var displayEvents: [CoinEvent] {
        if isParent {
            return filteredEvents.filter { $0.redemption?.isApproved != true }
        }
        return filteredEvents
    }

    private var coinSummaryCard: some View {
        HStack(spacing: 0) {
            summaryStat(value: summaryEarned, label: "Earned", color: .green)
            Divider().frame(height: 36).overlay(theme.tertiaryTextColor)
            summaryStat(value: summaryInReview, label: "In Review", color: .orange)
            Divider().frame(height: 36).overlay(theme.tertiaryTextColor)
            summaryStat(value: summaryRedeemed, label: "Redeemed", color: calmAccent)
        }
        .padding(.vertical, 14)
        .background(.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
        )
    }

    private func summaryStat(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                Text("\(value)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.primary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private var filterPicker: some View {
        HStack(spacing: 6) {
            ForEach(CoinFilterOption.allCases, id: \.rawValue) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = option
                    }
                } label: {
                    Text(option.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedFilter == option ? theme.textColor : theme.secondaryTextColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedFilter == option ? theme.cardBackground : .clear,
                            in: Capsule()
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func coinEventRow(_ event: CoinEvent) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: event.icon)
                    .font(.title3)
                    .foregroundStyle(event.kindColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        if isParent && !event.childName.isEmpty {
                            Label(event.childName, systemImage: "person.fill")
                                .font(.caption)
                                .foregroundStyle(calmAccent.opacity(0.8))

                            Text("•")
                                .foregroundStyle(.primary.opacity(0.5))
                        }

                        HStack(spacing: 3) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.yellow.opacity(0.85))
                            Text(event.kind == .earned ? "+\(event.coins)" : event.kind == .rejected ? "+\(event.coins)" : "-\(event.coins)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(event.kind == .earned || event.kind == .rejected ? .green : .yellow.opacity(0.85))
                        }

                        if let r = event.redemption {
                            Text("•")
                                .foregroundStyle(.primary.opacity(0.5))
                            Text(r.typeLabel)
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.7))
                        }
                    }

                    HStack(spacing: 6) {
                        Text(event.kindLabel)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(event.kindColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(event.kindColor.opacity(0.15), in: Capsule())

                        if let r = event.redemption {
                            if r.isFulfilled {
                                Text("Closed")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.green.opacity(0.15), in: Capsule())
                            } else if r.isPending {
                                Text("Pending")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.orange.opacity(0.15), in: Capsule())
                            }
                        }

                        Text(event.date, format: .relative(presentation: .named))
                            .font(.caption2)
                            .foregroundStyle(.primary.opacity(0.55))
                    }

                    if let r = event.redemption, r.isRejected, !r.rejectReason.isEmpty {
                        Text("Reason: \(r.rejectReason)")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }

                Spacer()
            }

            if let r = event.redemption {
                if !isParent && r.isApproved {
                    Button {
                        confirmFulfill = r
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                            Text("I Received This")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.green, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.top, 10)
                }

                if r.isFulfilled, let resolvedAt = r.resolvedAt {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("Closed on \(resolvedAt.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .font(.caption2)
                            .foregroundStyle(.green.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                }

                if isParent && r.isApproved {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.badge.exclamationmark.fill")
                            .font(.caption)
                            .foregroundStyle(calmAccent)
                        Text("Waiting for \(r.childName) to acknowledge receipt")
                            .font(.caption2)
                            .foregroundStyle(calmAccent.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                }
            }
        }
        .padding(14)
        .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(event.kindColor.opacity(0.2), lineWidth: 1)
        )
    }
}

struct EarningsCardCenterKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

struct FlyingCoin: Identifiable {
    let id = UUID()
    var startPosition: CGPoint
    var endPosition: CGPoint
    var delay: Double
    var arrived = false
}

struct FlyingCoinsOverlay: View {
    @Binding var coins: [FlyingCoin]

    var body: some View {
        ZStack {
            ForEach(coins) { coin in
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
                    .shadow(color: .yellow.opacity(0.6), radius: 4)
                    .position(coin.arrived ? coin.endPosition : coin.startPosition)
                    .scaleEffect(coin.arrived ? 0.5 : 1.2)
                    .opacity(coin.arrived ? 0.0 : 1.0)
            }
        }
        .allowsHitTesting(false)
    }
}

struct MyGiftsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allGifts: [SurpriseGift]
    let childName: String
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")

    private var myGifts: [SurpriseGift] {
        allGifts.filter { $0.childName == childName }.sorted { $0.earnedDate > $1.earnedDate }
    }

    private var unredeemed: [SurpriseGift] { myGifts.filter { !$0.isRedeemed } }
    private var redeemed: [SurpriseGift] { myGifts.filter { $0.isRedeemed } }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                if myGifts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "gift")
                            .font(.system(size: 56))
                            .foregroundStyle(.primary.opacity(0.3))
                        Text("No gifts yet")
                            .font(.title3)
                            .foregroundStyle(.primary.opacity(0.7))
                        Text("Complete tasks with surprise gifts to see them here!")
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if !unredeemed.isEmpty {
                                sectionHeader("Ready to Redeem", count: unredeemed.count)
                                ForEach(unredeemed) { gift in
                                    giftCard(gift, canRedeem: true)
                                }
                            }

                            if !redeemed.isEmpty {
                                sectionHeader("Redeemed", count: redeemed.count)
                                    .padding(.top, unredeemed.isEmpty ? 0 : 8)
                                ForEach(redeemed) { gift in
                                    giftCard(gift, canRedeem: false)
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .navigationTitle("My Gifts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text("\(count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.pink.opacity(0.3), in: Capsule())
            Spacer()
        }
    }

    private func giftCard(_ gift: SurpriseGift, canRedeem: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: gift.isRedeemed ? "checkmark.circle.fill" : "gift.fill")
                .font(.title2)
                .foregroundStyle(gift.isRedeemed ? .green : .pink)

            VStack(alignment: .leading, spacing: 4) {
                Text(gift.giftDescription)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("From: \(gift.taskName)")
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.5))
                Text(gift.earnedDate, format: .dateTime.month().day())
                    .font(.caption2)
                    .foregroundStyle(.primary.opacity(0.4))
            }

            Spacer()

            if canRedeem {
                Button {
                    withAnimation { gift.isRedeemed = true }
                } label: {
                    Text("Redeem")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.pink, in: Capsule())
                }
            } else {
                Text("Redeemed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green.opacity(0.7))
            }
        }
        .padding(14)
        .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(gift.isRedeemed ? .green.opacity(0.2) : .pink.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Theme Picker

struct ChildThemePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var theme: ChildTheme

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: theme.gradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        Spacer().frame(height: 8)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Background")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.primary.opacity(0.7))

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                                ForEach(themePresets) { preset in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.4)) {
                                            theme.themeId = preset.id
                                            theme.save()
                                        }
                                    } label: {
                                        VStack(spacing: 6) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(
                                                        LinearGradient(
                                                            colors: preset.gradientColors,
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                    )
                                                    .frame(height: 56)

                                                Text(preset.emoji)
                                                    .font(.title2)
                                            }
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .strokeBorder(
                                                        Color.primary.opacity(theme.themeId == preset.id ? 1 : 0.15),
                                                        lineWidth: theme.themeId == preset.id ? 2.5 : 1
                                                    )
                                            )

                                            Text(preset.name)
                                                .font(.caption2.weight(.medium))
                                                .foregroundStyle(Color.primary.opacity(theme.themeId == preset.id ? 1 : 0.6))
                                        }
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Font Style")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.primary.opacity(0.7))

                            ForEach(fontStylePresets) { preset in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        theme.fontId = preset.id
                                        theme.save()
                                    }
                                } label: {
                                    let isActive = theme.fontId == preset.id
                                    HStack(spacing: 14) {
                                        Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(isActive ? Color.green : Color.primary.opacity(0.3))
                                            .font(.title3)

                                        Text("The quick brown fox jumps")
                                            .font(preset.fontName != nil ? .custom(preset.fontName!, size: 16) : .body)
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        Text(preset.name)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.primary.opacity(0.5))
                                    }
                                    .padding(14)
                                    .background(
                                        Color.primary.opacity(isActive ? 0.15 : 0.08),
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(
                                                Color.primary.opacity(isActive ? 0.4 : 0.1),
                                                lineWidth: 1
                                            )
                                    )
                                }
                            }
                        }

                        Text("Preview")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 14) {
                            Circle()
                                .strokeBorder(.primary.opacity(0.4), lineWidth: 2)
                                .frame(width: 32, height: 32)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Clean my room")
                                    .font(theme.font(.body))
                                    .foregroundStyle(.primary)
                                Text("Today at 5:00 PM")
                                    .font(theme.font(.caption))
                                    .foregroundStyle(.primary.opacity(0.6))
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.primary.opacity(0.25), lineWidth: 1)
                        )

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
            }
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .navigationTitle("Customize Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    ChildDashboardView()
        .modelContainer(for: [Item.self, FamilyMember.self, RewardRedemption.self, SurpriseGift.self], inMemory: true)
        .environment(AuthManager())
        .environment(NotificationManager())
        .environment(SubscriptionManager())
        .environment(CloudKitManager())
}
