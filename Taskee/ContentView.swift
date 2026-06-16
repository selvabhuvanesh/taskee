//
//  ContentView.swift
//  Taskee
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import SwiftUI
import SwiftData
import StoreKit
import PhotosUI

// Shared gradient background used across all screens.
struct AppBackground: View {
    var body: some View {
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
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        policySection("Information We Collect",
                            "When you sign in with Apple, we collect your name, email address, and a unique Apple User ID. You may choose to hide your email using Apple's private relay.\n\nWe also store task details, family member profiles, chat messages, shopping list items, reward redemption requests, and coin totals to provide the app's functionality.\n\nLocally on your device, we store notification history (up to 100), subscription status, and app settings.")

                        policySection("How We Use Your Information",
                            "All data is used solely to provide the app's functionality. Account info identifies you within your family group. Task and family data enables assignment, tracking, and rewards. Notifications remind you about upcoming tasks.\n\nWe do not use your data for advertising, profiling, or analytics.")

                        policySection("Data Storage & Security",
                            "On-device data is stored in iOS-encrypted storage. Synced data is stored in Apple CloudKit (iCloud) within a private container accessible only to your family group. Purchases are processed through Apple's App Store.\n\nWe do not operate our own servers.")

                        policySection("Third-Party Services",
                            "We use only Apple's first-party services:\n\n• Sign in with Apple — Authentication\n• Apple CloudKit (iCloud) — Family data sync\n• Apple StoreKit 2 — In-app subscriptions\n• Apple Push Notifications — Task reminders\n\nWe do not integrate any third-party analytics, advertising, or tracking services.")

                        policySection("Data Sharing",
                            "FamiLogic LLC does not sell, trade, or share your personal information with third parties. Your family data is shared only with members of your family group through Apple CloudKit.")

                        policySection("Children's Privacy",
                            "Taskoot is designed for family use, including children. Children join a family group managed by a parent. FamiLogic LLC collects only the minimum information needed (name and avatar) and does not collect children's email addresses independently.")

                        policySection("Data Retention & Deletion",
                            "You can delete your account and all associated data by removing yourself from the family group and deleting the app. Local data is removed when the app is uninstalled. CloudKit data can be managed through your iCloud account settings.")

                        policySection("Your Rights",
                            "You have the right to access, correct, or delete your personal data, and to withdraw consent at any time by discontinuing use of the app.")

                        policySection("Contact Us",
                            "If you have questions about this privacy policy, please contact FamiLogic LLC at support@taskoot.com")

                        Text("© 2026 FamiLogic LLC. All rights reserved.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)

                        Text("Last updated: May 10, 2026")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func policySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - User Avatar Header

struct UserAvatarHeader: View {
    let name: String
    let avatar: String

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(avatarId: avatar, size: 44)

            Text("Hi, \(name)")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

// MARK: - Drag & Drop Helpers

func rescheduleTask(_ task: Item, toSameDayAs referenceDate: Date) {
    let calendar = Calendar.current
    let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: task.targetDate)
    var dayComponents = calendar.dateComponents([.year, .month, .day], from: referenceDate)
    dayComponents.hour = timeComponents.hour
    dayComponents.minute = timeComponents.minute
    dayComponents.second = timeComponents.second
    if let newDate = calendar.date(from: dayComponents) {
        task.targetDate = newDate
    }
}

// MARK: - Week Calendar Strip

struct WeekCalendarStrip: View {
    @Binding var selectedDate: Date
    let tasks: [Item]
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    @State private var weekOffset = 0

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(byAdding: .day, value: weekOffset * 7, to: today)!
        return (-1...5).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var weekRangeLabel: String {
        guard let first = weekDates.first, let last = weekDates.last else { return "" }
        let calendar = Calendar.current
        if calendar.component(.month, from: first) == calendar.component(.month, from: last) {
            return "\(first.formatted(.dateTime.month(.abbreviated))) \(first.formatted(.dateTime.day()))–\(last.formatted(.dateTime.day()))"
        }
        return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func taskCount(for date: Date) -> Int {
        let calendar = Calendar.current
        return tasks.filter { calendar.isDate($0.targetDate, inSameDayAs: date) }.count
    }

    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tom" }
        if calendar.isDateInYesterday(date) { return "Yest" }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    withAnimation(.snappy) { weekOffset -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.secondaryTextColor)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text(weekRangeLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryTextColor)
                    if weekOffset != 0 {
                        Button {
                            withAnimation(.snappy) {
                                weekOffset = 0
                                selectedDate = Date()
                            }
                        } label: {
                            Text("Today")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(calmAccent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                Button {
                    withAnimation(.snappy) { weekOffset += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.secondaryTextColor)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            HStack(spacing: 6) {
                ForEach(weekDates, id: \.self) { date in
                    let isSelected = Calendar.current.isDate(selectedDate, inSameDayAs: date)
                    let count = taskCount(for: date)

                    Button {
                        withAnimation(.snappy) { selectedDate = date }
                    } label: {
                        VStack(spacing: 4) {
                            Text(dayLabel(for: date))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(isSelected ? theme.textColor : theme.secondaryTextColor)

                            Text(date.formatted(.dateTime.day()))
                                .font(.system(size: 16, weight: isSelected ? .bold : .semibold))
                                .foregroundStyle(isSelected ? theme.textColor : theme.secondaryTextColor)

                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(isSelected ? theme.textColor : calmAccent)
                                    .frame(minWidth: 16, minHeight: 14)
                                    .background(
                                        isSelected ? calmAccent : theme.cardBackgroundLight,
                                        in: Capsule()
                                    )
                            } else {
                                Circle()
                                    .fill(theme.tertiaryTextColor)
                                    .frame(width: 6, height: 6)
                                    .padding(.vertical, 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? calmAccent.opacity(0.3) : theme.cardBackgroundLight,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    isSelected ? calmAccent.opacity(0.6) : .clear,
                                    lineWidth: 1.5
                                )
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        withAnimation(.snappy) { weekOffset += 1 }
                    } else if value.translation.width > 50 {
                        withAnimation(.snappy) { weekOffset -= 1 }
                    }
                }
        )
    }
}

// MARK: - Parent Main View

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Query(sort: \Item.targetDate) private var tasks: [Item]
    @Query private var allMembers: [FamilyMember]
    @Query(sort: \AnnualReminder.dueDate) private var annualReminders: [AnnualReminder]

    private var isIndividual: Bool { authManager.role == "individual" }

    private var children: [FamilyMember] {
        var seen = Set<String>()
        return allMembers
            .filter { $0.isChild }
            .sorted { !$0.appleUserID.isEmpty && $1.appleUserID.isEmpty }
            .filter { seen.insert($0.name).inserted }
    }
    private var pendingChildren: [FamilyMember] {
        allMembers.filter { $0.isChild && !$0.isAccepted }
    }
    private var otherParent: FamilyMember? {
        allMembers.first { $0.isParent && $0.name != authManager.userName }
    }
    @State private var showingAddTask = false
    @State private var showingChildren = false
    @State private var showPendingApprovals = false
    @State private var showOpenOnly = true
    @State private var isExpanded = true
    @State private var showCalendarView = false
    @State private var selectedCalendarDate = Date()
    @State private var showCelebration = false
    @State private var celebrationReward: Double = 0
    @State private var showNotificationCenter = false
    @State private var showSubscription = false
    @State private var showRedemptionApprovals = false
    @State private var showRewardsHistory = false
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var stickyNote: (message: String, color: Color)?
    @State private var showReminderSent = false
    @State private var reminderSentChildName = ""
    @State private var showShareSheet = false
    @State private var showPrivacyPolicy = false
    @State private var showThemePicker = false
    @State private var showSwitchRoleConfirm = false
    @State private var showFamilySetup = false
    @State private var isSwitchingToFamily = false
    @State private var showWeeklyPulse = false
    @State private var showInsights = false
    @State private var insightsTab: InsightsTab = .today
    private enum InsightsTab: String, CaseIterable { case today = "Today", weekly = "Weekly Pulse" }
    @State private var showAIAssistant = false
    @AppStorage("isAIMode") private var isAIMode = true
    @State private var parentTheme = ChildTheme.load(for: "parent")
    @State private var unreadNotifCount = 0
    @State private var showRecurringExtension = false
    @State private var showShoppingBag = false
    @State private var showFamilyChat = false
    @State private var showAnnualReminders = false
    @State private var showDayPreview = false
    @State private var showSharePreviewConfirm = false
    @State private var showFamilyProjects = false
    @State private var showWishList = false
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var showGoalsTab = false
    @State private var showStatsPopup = false
    @Query(sort: \ChatMessage.sentAt) private var chatMessages: [ChatMessage]
    @State private var recurringGroups: [RecurringTaskGroup] = []
    @State private var editRequest: TaskEditRequest?
    @State private var taskToDelete: Item?
    @State private var taskToApprove: Item?
    @State private var showTooEarlyAlert = false
    @State private var tooEarlyTask: Item?
    @State private var showEditChoice = false
    @State private var pendingEditTask: Item?
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Query private var allRedemptions: [RewardRedemption]
    @Query private var allGifts: [SurpriseGift]
    @State private var showParentRedeem = false
    @State private var showParentGifts = false
    @State private var showGoalPicker = false
    @Query(sort: \Goal.createdAt) private var allGoals: [Goal]
    @State private var selectedHomeGoal: Goal?
    @State private var giftTaskToReveal: Item?
    @State private var taskListVersion = 0

    private var pendingRedemptions: [RewardRedemption] {
        allRedemptions.filter { $0.isPending }
    }

    private var myRedemptions: [RewardRedemption] {
        allRedemptions.filter { $0.childName == authManager.userName }
    }

    private var parentInReviewCoins: Int {
        tasks
            .filter { $0.assignedTo == authManager.userName && $0.isInReview && $0.reward > 0 }
            .reduce(0) { $0 + Int($1.reward) }
    }

    private var parentPendingRedemptionCoins: Int {
        myRedemptions.filter { $0.isPending }.reduce(0) { $0 + $1.coinAmount }
    }

    private var parentAwaitingCoins: Int {
        parentPendingRedemptionCoins + parentInReviewCoins
    }

    private var parentRedeemedCoins: Int {
        var seen = Set<String>()
        var total = 0
        for r in myRedemptions where r.isApproved || r.isFulfilled || r.isPending {
            if seen.insert(r.id.uuidString).inserted { total += r.coinAmount }
        }
        return total
    }

    private var parentTotalEarned: Int {
        tasks
            .filter { $0.assignedTo == authManager.userName && $0.isApproved && $0.reward > 0 }
            .reduce(0) { $0 + Int($1.reward) }
    }

    private var parentCollectableCoins: Int {
        max(0, parentTotalEarned - parentRedeemedCoins)
    }

    private func deduplicatedRedeemed(for name: String) -> Int {
        var seen = Set<String>()
        var total = 0
        for r in allRedemptions where r.childName == name && (r.isApproved || r.isFulfilled || r.isPending) {
            if seen.insert(r.id.uuidString).inserted { total += r.coinAmount }
        }
        return total
    }

    private var parentUnredeemedGifts: Int {
        allGifts.filter { $0.childName == authManager.userName && !$0.isRedeemed }.count
    }

    private var activeTasks: [Item] {
        tasks.filter { !$0.isArchived }
    }

    private var upcomingReminders: [AnnualReminder] {
        annualReminders.filter { $0.isDueSoon || $0.isOverdue }
    }

    private var myTasks: [Item] {
        let myName = authManager.userName
        return activeTasks.filter { task in
            task.assignedTo == myName
        }
    }

    private var filteredTasks: [Item] {
        let base = showOpenOnly ? myTasks.filter { !$0.isApproved && !$0.isMissed && !$0.isCancelled } : myTasks
        if isSearching {
            let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
            if !query.isEmpty {
                return base.filter { task in
                    task.name.lowercased().contains(query)
                    || task.assignedTo.lowercased().contains(query)
                    || task.status.lowercased().contains(query)
                    || task.createdBy.lowercased().contains(query)
                    || task.transportLabel.lowercased().contains(query)
                    || task.dueDateLabel.lowercased().contains(query)
                    || task.targetDate.formatted(.dateTime.month(.wide).day().year()).lowercased().contains(query)
                }
            }
        }
        return base
    }

    private var calendarDayTasks: [Item] {
        let calendar = Calendar.current
        return filteredTasks
            .filter { calendar.isDate($0.targetDate, inSameDayAs: selectedCalendarDate) }
            .sorted { $0.targetDate < $1.targetDate }
    }

    private var pendingReviewCount: Int {
        activeTasks.filter { $0.isInReview }.count
    }

    private var pendingActionCount: Int {
        pendingReviewCount + pendingRedemptions.count + pendingChildren.count
    }

    private var groupedTasks: [(key: String, tasks: [Item])] {
        let grouped = Dictionary(grouping: filteredTasks) { $0.dueDateLabel }
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

    private var pastTaskCount: Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return filteredTasks.filter { $0.targetDate < startOfToday }.count
    }

    private var todayGroupIndex: Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return groupedTasks.firstIndex { ($0.tasks.first?.targetDate ?? .distantPast) >= startOfToday } ?? groupedTasks.count
    }

    @ViewBuilder
    var body: some View {
        if isAIMode {
            aiModeView
        } else {
            normalModeView
        }
    }

    private var aiModeView: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: parentTheme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                AIAssistantView(allTasks: tasks, allMembers: allMembers, allGoals: allGoals, isIndividual: isIndividual, theme: parentTheme, isInline: true)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation { isAIMode = false }
                    } label: {
                        Text("Done")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbarColorScheme(parentTheme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, parentTheme.colorScheme)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var normalModeView: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: parentTheme.gradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    if showGoalsTab {
                        GoalsTabContent(
                            userName: authManager.userName,
                            audience: isIndividual ? .individual : .parent,
                            theme: parentTheme,
                            showGoalPicker: $showGoalPicker,
                            onDone: { withAnimation(.easeInOut(duration: 0.2)) { showGoalsTab = false } }
                        )
                    } else {
                        parentTasksContent
                    }
                }

                CelebrationOverlay(
                    isActive: $showCelebration,
                    title: "Task Approved!",
                    subtitle: "Reward credited",
                    rewardAmount: celebrationReward
                )

            }
            .onAppear {
                // scheduleStickyNote(from: parentTips) // Disabled for now
                deduplicateRedemptions()
            }
            .toolbarColorScheme(parentTheme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, parentTheme.colorScheme)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        filterToggle

                        if pendingReviewCount > 0 {
                            Button {
                                showPendingApprovals = true
                            } label: {
                                Text("\(pendingReviewCount) pending")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.orange, in: Capsule())
                            }
                        }

                        if !isIndividual && !pendingRedemptions.isEmpty {
                            Button {
                                showRedemptionApprovals = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "gift.fill")
                                        .font(.caption2)
                                    Text("\(pendingRedemptions.count)")
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.purple, in: Capsule())
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if !isIndividual {
                            Button {
                                showWishList = true
                            } label: {
                                Image(systemName: "wand.and.stars")
                                    .font(.subheadline)
                            }
                        }

                        Button {
                            showNotificationCenter = true
                        } label: {
                            Image(systemName: "bell.fill")
                                .font(.subheadline)
                                .overlay(alignment: .topTrailing) {
                                    let badgeCount = unreadNotifCount + pendingActionCount
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

                        if !isIndividual {
                            Button {
                                showingChildren = true
                            } label: {
                                Image(systemName: "person.3.fill")
                                    .font(.subheadline)
                                    .overlay(alignment: .topTrailing) {
                                        if !pendingChildren.isEmpty {
                                            Circle()
                                                .fill(.orange)
                                                .frame(width: 8, height: 8)
                                                .offset(x: 3, y: -3)
                                        }
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
                            if !isIndividual {
                                Button {
                                    showSubscription = true
                                } label: {
                                    Label("Subscription", systemImage: "crown.fill")
                                }
                                Button {
                                    showRewardsHistory = true
                                } label: {
                                    Label("Rewards History", systemImage: "gift.fill")
                                }
                            }
                            Button {
                                showAnnualReminders = true
                            } label: {
                                Label("Annual Reminders", systemImage: "calendar.badge.clock")
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
                            Button {
                                if isIndividual {
                                    attemptSwitchToFamily()
                                } else {
                                    showSwitchRoleConfirm = true
                                }
                            } label: {
                                if isIndividual {
                                    Label(isSwitchingToFamily ? "Switching…" : "Switch to Family Mode", systemImage: "person.3.fill")
                                } else {
                                    Label("Switch to Individual Mode", systemImage: "person.fill")
                                }
                            }
                            .disabled(isSwitchingToFamily)
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
            .sheet(isPresented: $showingAddTask, onDismiss: { taskListVersion += 1 }) {
                AddTaskView(children: children, otherParent: otherParent, theme: parentTheme)
            }
            .sheet(isPresented: $showingChildren) {
                ChildrenManagementView(theme: parentTheme)
            }
            .sheet(isPresented: $showNotificationCenter) {
                NotificationCenterView(theme: parentTheme)
            }
            .sheet(isPresented: $showShoppingBag) {
                ShoppingBagView(theme: parentTheme)
            }
            .sheet(isPresented: $showFamilyChat) {
                FamilyChatView(theme: parentTheme)
            }
            .onAppear {
                if ScreenshotHelper.isScreenshotMode && ScreenshotHelper.shouldOpenChat {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showFamilyChat = true
                    }
                }
            }
            .sheet(isPresented: $showAnnualReminders) {
                AnnualRemindersView(theme: parentTheme)
            }
            .sheet(isPresented: $showFamilyProjects) {
                FamilyProjectsListView(theme: parentTheme)
            }
            .sheet(isPresented: $showWishList) {
                WishListView(theme: parentTheme)
            }
            .sheet(isPresented: $showGoalPicker) {
                GoalPickerView(
                    audience: isIndividual ? .individual : .parent,
                    assignee: authManager.userName,
                    theme: parentTheme
                )
            }
            .sheet(item: $selectedHomeGoal) { goal in
                GoalDetailView(goal: goal, theme: parentTheme)
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
            .sheet(isPresented: $showInsights) {
                insightsSheet
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(theme: parentTheme)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(theme: parentTheme)
            }
            .sheet(isPresented: $showThemePicker) {
                ChildThemePickerView(theme: $parentTheme)
            }
            .sheet(isPresented: $showSubscription) {
                SubscriptionView(theme: parentTheme)
            }
            .sheet(isPresented: $showRedemptionApprovals) {
                RedemptionApprovalsView(theme: parentTheme)
            }
            .sheet(isPresented: $showRewardsHistory) {
                RewardsHistoryView(
                    redemptions: allRedemptions.sorted { $0.createdAt > $1.createdAt },
                    tasks: tasks,
                    isParent: true,
                    theme: parentTheme
                )
            }
            .sheet(isPresented: $showParentRedeem) {
                RedeemRewardsView(
                    availableCoins: parentCollectableCoins,
                    childName: authManager.userName,
                    theme: parentTheme
                )
            }
            .sheet(isPresented: $showParentGifts) {
                MyGiftsView(childName: authManager.userName, theme: parentTheme)
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [ShareTextWithLink(text: parentShareMessage, url: appStoreURL)])
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showStatsPopup) {
                NavigationStack {
                    ZStack {
                        LinearGradient(
                            colors: parentTheme.gradientColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                        VStack(spacing: 16) {
                            parentEarningsCard
                            QuestProgressBar(
                                quest: MonthlyQuest.compute(tasks: tasks, userName: authManager.userName),
                                theme: parentTheme
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
            .sheet(isPresented: $showPendingApprovals) {
                PendingApprovalsView(theme: parentTheme) { reward in
                    celebrationReward = reward
                    showCelebration = true
                }
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
                }
            }
            .onChange(of: notificationManager.showPendingApprovals) { _, newValue in
                if newValue {
                    showPendingApprovals = true
                    notificationManager.showPendingApprovals = false
                }
            }
            .alert("Reminder Sent!", isPresented: $showReminderSent) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(reminderSentChildName) has been reminded about today's tasks.")
            }
            .alert("Switch to Individual Mode?", isPresented: $showSwitchRoleConfirm) {
                Button("Switch", role: .destructive) {
                    withAnimation {
                        authManager.role = "individual"
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Individual mode hides family features like coins, gifts, and family chat for a simpler experience. You can switch back anytime.")
            }
            .sheet(isPresented: $showFamilySetup) {
                FamilySetupSheet(theme: parentTheme)
            }
            .modifier(ParentExpandedTaskAlerts(
                taskToDelete: $taskToDelete,
                taskToApprove: $taskToApprove,
                editRequest: $editRequest,
                showTooEarlyAlert: $showTooEarlyAlert,
                tooEarlyTask: $tooEarlyTask,
                tasks: tasks,
                children: children,
                otherParent: otherParent,
                allMembers: allMembers,
                theme: parentTheme,
                onTaskChanged: { taskListVersion += 1 }
            ))
            .confirmationDialog("This is a recurring task", isPresented: $showEditChoice, titleVisibility: .visible) {
                Button("Edit This Task Only") {
                    if let task = pendingEditTask {
                        editRequest = TaskEditRequest(task: task, editAll: false)
                    }
                    pendingEditTask = nil
                }
                Button("Edit All Recurring") {
                    if let task = pendingEditTask {
                        editRequest = TaskEditRequest(task: task, editAll: true)
                    }
                    pendingEditTask = nil
                }
                Button("Cancel", role: .cancel) { pendingEditTask = nil }
            } message: {
                Text("Would you like to edit just this task or all open instances?")
            }
            .task {
                archiveOldTasks()
                checkRecurringExtension()
            }
            .sheet(isPresented: $showRecurringExtension) {
                RecurringExtensionSheet(
                    groups: recurringGroups,
                    theme: parentTheme,
                    taskLimit: subscriptionManager.maxTasksPerMonth.map { max(0, $0 - subscriptionManager.tasksCreatedThisMonth(allTasks: tasks)) },
                    onConfirm: { extendRecurringTasks() },
                    onDismiss: { RecurringTaskExtender.markDismissed() }
                )
            }
        }
        .overlay(alignment: .bottom) {
            bottomPillBar
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
    }

    private var bottomPillBar: some View {
        VStack(spacing: 0) {
            if let note = stickyNote {
                StickyNoteView(message: note.message, color: note.color) {
                    withAnimation { stickyNote = nil }
                }
                .transition(.scale.combined(with: .opacity))
            }

            HStack(spacing: 14) {
                pillTasksButton
                pillGoalsButton

                if !isIndividual {
                    familyChatButton
                    shoppingBagButton
                    familyProjectsButton
                }
                addTaskButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(parentTheme.pillBarBackground.opacity(0.85))
                    .overlay(
                        Capsule()
                            .fill(.white.opacity(parentTheme.pillBarIsLight ? 0.3 : 0.08))
                    )
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
    }

    private var pillTasksButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showGoalsTab = false }
        } label: {
            Image(systemName: "checklist")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(showGoalsTab ? .white.opacity(0.15) : .green.opacity(0.5), in: Circle())
        }
    }

    private var pillGoalsButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showGoalsTab = true }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "target")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(!showGoalsTab ? .white.opacity(0.15) : .green.opacity(0.5), in: Circle())

                let activeCount = allGoals.filter { $0.assignedTo == authManager.userName && $0.isActive }.count
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

    private func checkRecurringExtension() {
        guard RecurringTaskExtender.needsExtension() else { return }
        let groups = RecurringTaskExtender.findRecurringGroups(from: tasks)
        guard !groups.isEmpty else { return }
        recurringGroups = groups
        showRecurringExtension = true
    }

    private func extendRecurringTasks() {
        let remaining = subscriptionManager.maxTasksPerMonth.map {
            max(0, $0 - subscriptionManager.tasksCreatedThisMonth(allTasks: tasks))
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
                    createdByChild: group.createdByChild,
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

    private func attemptSwitchToFamily() {
        isSwitchingToFamily = true
        Task {
            let code = authManager.familyCode
            let result = await cloudKitManager.validateFamilyCode(code)
            if result == .valid {
                withAnimation { authManager.role = "parent" }
            } else {
                showFamilySetup = true
            }
            isSwitchingToFamily = false
        }
    }

    private func archiveOldTasks() {
        guard !authManager.familyCode.isEmpty else { return }
        Task {
            await cloudKitManager.archiveOldTasks(context: modelContext, familyCode: authManager.familyCode)
        }
    }

    private var insightsSheet: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    Picker("", selection: $insightsTab) {
                        ForEach(InsightsTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    if insightsTab == .today {
                        todayPreviewContent
                    } else {
                        weeklyPulseInlineContent
                    }
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showInsights = false }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var weeklyPulseInlineContent: some View {
        WeeklyPulseView(
            allTasks: tasks,
            allMembers: allMembers.filter { !$0.isChild || $0.isAccepted },
            currentUserName: authManager.userName,
            isIndividual: isIndividual,
            theme: parentTheme,
            embedded: true
        )
    }

    private var todayPreviewContent: some View {
        let calendar = Calendar.current
        let todayTasks = activeTasks.filter { calendar.isDateInToday($0.targetDate) }
        let allNames: [String] = {
            var names = [authManager.userName]
            if let parent = otherParent { names.append(parent.name) }
            names.append(contentsOf: children.map { $0.name })
            return names
        }()
        let grouped: [(name: String, tasks: [Item])] = allNames.map { name in
            (name: name, tasks: todayTasks.filter { $0.assignedTo == name }.sorted { $0.targetDate < $1.targetDate })
        }
        let totalCount = todayTasks.count

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(parentTheme.accentColor)
                Text("Today's Preview")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(parentTheme.textColor)
                Spacer()
                Text("\(totalCount) task\(totalCount == 1 ? "" : "s")")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(parentTheme.secondaryTextColor)
                Button {
                    showSharePreviewConfirm = true
                } label: {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(parentTheme.accentColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider().overlay(parentTheme.secondaryTextColor.opacity(0.2))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(grouped, id: \.name) { group in
                        dayPreviewMemberSection(name: group.name, tasks: group.tasks)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
        .alert("Share to Family Chat", isPresented: $showSharePreviewConfirm) {
            Button("Share") {
                shareDayPreviewToChat(grouped: grouped, totalCount: totalCount)
                showInsights = false
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will post today's task preview as an image in the family chat.")
        }
    }

    private var dayPreviewOverlay: some View {
        let calendar = Calendar.current
        let todayTasks = activeTasks.filter { calendar.isDateInToday($0.targetDate) }
        let allNames: [String] = {
            var names = [authManager.userName]
            if let parent = otherParent { names.append(parent.name) }
            names.append(contentsOf: children.map { $0.name })
            return names
        }()
        let grouped: [(name: String, tasks: [Item])] = allNames.map { name in
            (name: name, tasks: todayTasks.filter { $0.assignedTo == name }.sorted { $0.targetDate < $1.targetDate })
        }
        let totalCount = todayTasks.count

        return ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(duration: 0.3)) { showDayPreview = false }
                }

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(parentTheme.accentColor)
                    Text("Today's Preview")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(totalCount) task\(totalCount == 1 ? "" : "s")")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Button {
                        showSharePreviewConfirm = true
                    } label: {
                        Image(systemName: "bubble.left.and.text.bubble.right.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(parentTheme.accentColor)
                    }
                    Button {
                        withAnimation(.spring(duration: 0.3)) { showDayPreview = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

                Divider().overlay(.white.opacity(0.15))

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(grouped, id: \.name) { group in
                            dayPreviewMemberSection(name: group.name, tasks: group.tasks)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
                .frame(maxHeight: 380)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
            .alert("Share to Family Chat", isPresented: $showSharePreviewConfirm) {
                Button("Share") {
                    shareDayPreviewToChat(grouped: grouped, totalCount: totalCount)
                    withAnimation(.spring(duration: 0.3)) { showDayPreview = false }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will post today's task preview as an image in the family chat.")
            }
        }
    }

    private func dayPreviewMemberSection(name: String, tasks: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)

            if tasks.isEmpty {
                Text("No tasks today")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.leading, 4)
            } else {
                ForEach(tasks, id: \.id) { task in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(task.isApproved ? .green : task.isInReview ? .orange : task.isMissed ? .red : task.isCancelled ? .gray : .white.opacity(0.3))
                            .frame(width: 6, height: 6)

                        Text(task.name)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(task.isApproved ? 0.5 : 0.85))
                            .strikethrough(task.isApproved)
                            .lineLimit(1)

                        Spacer()

                        if task.belongsToProject {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 16, height: 16)
                                .background(parentTheme.accentColor, in: Circle())
                        }

                        if task.belongsToGoal {
                            Image(systemName: "target")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 16, height: 16)
                                .background(parentTheme.accentColor, in: Circle())
                        }

                        if task.needsTransport {
                            Image(systemName: task.transportIcon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.yellow)
                        }

                        Text(task.targetDate, format: .dateTime.hour().minute())
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .padding(.leading, 4)
                }
            }
        }
    }

    private func shareDayPreviewToChat(grouped: [(name: String, tasks: [Item])], totalCount: Int) {
        let dateStr = Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
        let cardView = VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(parentTheme.accentColor)
                Text("Today's Preview")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(totalCount) task\(totalCount == 1 ? "" : "s")")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 6)

            Text(dateStr)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            Rectangle().fill(.white.opacity(0.15)).frame(height: 1)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(grouped, id: \.name) { group in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(group.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)

                        if group.tasks.isEmpty {
                            Text("No tasks today")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.35))
                                .padding(.leading, 4)
                        } else {
                            ForEach(group.tasks, id: \.id) { task in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(task.isApproved ? .green : task.isInReview ? .orange : task.isMissed ? .red : task.isCancelled ? .gray : .white.opacity(0.3))
                                        .frame(width: 6, height: 6)
                                    Text(task.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(task.isApproved ? 0.5 : 0.85))
                                        .strikethrough(task.isApproved)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(task.targetDate, format: .dateTime.hour().minute())
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.45))
                                }
                                .padding(.leading, 4)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.15, blue: 0.25), Color(red: 0.08, green: 0.1, blue: 0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = UIScreen.main.scale
        guard let uiImage = renderer.uiImage,
              let photoData = uiImage.jpegData(compressionQuality: 0.85) else { return }

        let message = ChatMessage(
            senderName: authManager.userName,
            senderAvatar: authManager.avatar,
            senderAppleUserID: authManager.appleUserID,
            text: "",
            attachmentData: photoData
        )
        modelContext.insert(message)

        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushChatMessage(message, familyCode: familyCode) }
    }

    private var parentHomeGoalStrip: some View {
        HStack(spacing: 6) {
            MemberGoalStrip(
                memberName: authManager.userName,
                goals: allGoals,
                tasks: Array(tasks),
                theme: parentTheme,
                onAddGoal: { showGoalPicker = true },
                onTapGoal: { goal in selectedHomeGoal = goal }
            )
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var familyStrip: some View {
        HStack {
            HStack(spacing: 10) {
                insightsCalendarButton
                searchButton
            }
            .padding(.leading, 16)

            Spacer()
            HStack(alignment: .top, spacing: 14) {
                if let parent = otherParent {
                    VStack(spacing: 4) {
                        NavigationLink(destination: DateTasksView(
                            dateLabel: "\(parent.name)'s Tasks",
                            tasks: activeTasks.filter { $0.assignedTo == parent.name },
                            children: children,
                            otherParent: parent,
                            memberName: parent.name,
                            theme: parentTheme
                        )) {
                            VStack(spacing: 4) {
                                AvatarView(avatarId: parent.avatar, size: 44)
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "shield.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.cyan)
                                            .offset(x: 2, y: 2)
                                    }
                                    .overlay(alignment: .topLeading) {
                                        let rank = MonthlyQuest.compute(tasks: tasks, userName: parent.name).rank
                                        Image(systemName: rank.icon)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(rank.color)
                                            .frame(width: 18, height: 18)
                                            .background(.ultraThinMaterial, in: Circle())
                                            .offset(x: -4, y: -4)
                                    }

                                Text(parent.name.count > 6 ? "\(parent.name.prefix(6)).." : parent.name)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(parentTheme.secondaryTextColor)
                                    .lineLimit(1)
                            }
                        }

                        let pEarned = tasks
                            .filter { $0.assignedTo == parent.name && $0.isApproved && $0.reward > 0 }
                            .reduce(0) { $0 + Int($1.reward) }
                        let pRedeemed = deduplicatedRedeemed(for: parent.name)
                        let pAvail = max(0, pEarned - pRedeemed)

                        HStack(spacing: 2) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.yellow)
                            Text("\(pAvail)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.yellow.opacity(0.85))
                        }

                        let parentTodayCount = activeTasks.filter {
                            $0.assignedTo == parent.name && $0.isOpen
                            && Calendar.current.isDateInToday($0.targetDate)
                        }.count

                        if parentTodayCount > 0 {
                            Button {
                                sendReminder(to: parent)
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 8))
                                    Text("Remind")
                                        .font(.system(size: 9, weight: .semibold))
                                        .fixedSize()
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.orange, in: Capsule())
                            }
                        }
                    }
                    .frame(minWidth: 60)
                }

                ForEach(children) { child in
                    VStack(spacing: 4) {
                        NavigationLink(destination: ChildTasksView(
                            child: child,
                            tasks: activeTasks.filter { $0.assignedTo == child.name },
                            allChildren: children,
                            otherParent: otherParent,
                            theme: parentTheme
                        )) {
                            VStack(spacing: 4) {
                                AvatarView(avatarId: child.avatar, size: 44)
                                    .overlay(alignment: .topLeading) {
                                        let rank = MonthlyQuest.compute(tasks: tasks, userName: child.name).rank
                                        Image(systemName: rank.icon)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(rank.color)
                                            .frame(width: 18, height: 18)
                                            .background(.ultraThinMaterial, in: Circle())
                                            .offset(x: -4, y: -4)
                                    }

                                Text(child.name.count > 6 ? "\(child.name.prefix(6)).." : child.name)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(parentTheme.secondaryTextColor)
                                    .lineLimit(1)
                            }
                        }

                        let childEarned = tasks
                            .filter { $0.assignedTo == child.name && $0.isApproved && $0.reward > 0 }
                            .reduce(0) { $0 + Int($1.reward) }
                        let childRedeemed = deduplicatedRedeemed(for: child.name)
                        let childAvail = max(0, childEarned - childRedeemed)

                        HStack(spacing: 2) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.yellow)
                            Text("\(childAvail)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.yellow.opacity(0.85))
                        }

                        let todayTaskCount = activeTasks.filter {
                            $0.assignedTo == child.name && $0.isOpen
                            && Calendar.current.isDateInToday($0.targetDate)
                        }.count

                        if todayTaskCount > 0 {
                            Button {
                                sendReminder(to: child)
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 8))
                                    Text("Remind")
                                        .font(.system(size: 9, weight: .semibold))
                                        .fixedSize()
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.orange, in: Capsule())
                            }
                        }
                    }
                    .frame(minWidth: 60)
                }
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 6)
    }

    private func refreshUnreadCount() {
        let lastRead = UserDefaults.standard.double(forKey: "lastNotifReadTime")
        let lastReadDate = lastRead > 0 ? Date(timeIntervalSince1970: lastRead) : Date.distantPast
        let myName = authManager.userName
        let all = notificationManager.savedNotifications()
        unreadNotifCount = all.filter { $0.createdAt > lastReadDate && ($0.senderName != myName || $0.senderName.isEmpty) }.count
    }

    private func sendReminder(to child: FamilyMember) {
        let openToday = activeTasks.filter {
            $0.assignedTo == child.name && $0.isOpen
            && Calendar.current.isDateInToday($0.targetDate)
        }
        guard !openToday.isEmpty else { return }

        let now = Date()
        let familyCode = authManager.familyCode
        for task in openToday {
            task.lastRemindedAt = now
        }
        Task {
            for task in openToday {
                await cloudKitManager.pushTask(task, familyCode: familyCode)
            }
        }

        reminderSentChildName = child.name
        showReminderSent = true
    }

    private var parentTasksGoalsToggle: some View {
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
                .foregroundStyle(showGoalsTab ? parentTheme.secondaryTextColor : parentTheme.textColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(showGoalsTab ? Color.clear : parentTheme.cardBackground, in: Capsule())
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showGoalsTab = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gauge.open.with.lines.needle.33percent.and.arrowtriangle")
                        .font(.system(size: 12, weight: .semibold))
                        .symbolEffect(.pulse, isActive: !showGoalsTab)
                    Text("Goals")
                        .font(.subheadline.weight(.bold))
                    let activeCount = allGoals.filter { $0.assignedTo == authManager.userName && $0.isActive }.count
                    if activeCount > 0 {
                        Text("\(activeCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(
                                LinearGradient(colors: [Color(red: 0.18, green: 0.55, blue: 0.34), Color(red: 0.10, green: 0.40, blue: 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: Circle()
                            )
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.55, blue: 0.34),
                            Color(red: 0.13, green: 0.45, blue: 0.27),
                            Color(red: 0.22, green: 0.60, blue: 0.35),
                            Color(red: 0.10, green: 0.40, blue: 0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.15), .clear, .white.opacity(0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .shadow(color: Color(red: 0.1, green: 0.4, blue: 0.2).opacity(0.5), radius: 6, y: 2)
            }

            Spacer()

            if !showGoalsTab && !isIndividual && (parentTotalEarned > 0 || parentAwaitingCoins > 0) {
                parentStatsIconPill
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var parentTasksContent: some View {
        if !isIndividual && (!children.isEmpty || otherParent != nil) {
            familyStrip
                .padding(.top, 6)
        }

        parentHomeGoalStrip

        if !upcomingReminders.isEmpty {
            Button { showAnnualReminders = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.orange)
                    let overdueCount = annualReminders.filter { $0.isOverdue }.count
                    if overdueCount > 0 {
                        Text("\(overdueCount) overdue, \(upcomingReminders.count - overdueCount) upcoming reminder\(upcomingReminders.count - overdueCount == 1 ? "" : "s")")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary.opacity(0.7))
                    } else {
                        Text("\(upcomingReminders.count) reminder\(upcomingReminders.count == 1 ? "" : "s") due within 30 days")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.4))
                }
                .padding(10)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.orange.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }

        if isSearching {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    TextField("Search tasks...", text: $searchText)
                        .font(.subheadline)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(parentTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))

                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        searchText = ""
                        isSearching = false
                    }
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }

        viewModeToggle

        ScrollViewReader { proxy in
            ScrollView {
                if showCalendarView {
                    VStack(spacing: 0) {
                        WeekCalendarStrip(
                            selectedDate: $selectedCalendarDate,
                            tasks: filteredTasks,
                            theme: parentTheme
                        )
                        if calendarDayTasks.isEmpty {
                            calendarEmptyState
                        } else {
                            calendarTaskList
                        }
                    }
                } else if filteredTasks.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        if isExpanded || isSearching {
                            expandedListContent
                        } else {
                            groupListContent
                        }
                    }
                }
            }
            .id(taskListVersion)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation { proxy.scrollTo("Today", anchor: .top) }
                }
            }
            .onChange(of: showOpenOnly) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo("Today", anchor: .top)
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
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 60)
        }
    }

    private var filterToggle: some View {
        Button {
            withAnimation(.snappy) {
                showOpenOnly.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: showOpenOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                Text(showOpenOnly ? "Open Tasks" : "All Tasks")
                    .font(.subheadline)
            }
        }
    }

    private func deduplicateRedemptions() {
        var seen = Set<String>()
        for r in allRedemptions {
            let key = r.id.uuidString
            if seen.contains(key) {
                modelContext.delete(r)
            } else {
                seen.insert(key)
            }
        }
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: showOpenOnly ? "checkmark.circle" : "checklist")
                .font(.system(size: 56))
                .foregroundStyle(.primary.opacity(0.3))
            Text(showOpenOnly ? "All caught up!" : "No tasks yet")
                .font(.title3)
                .foregroundStyle(.primary.opacity(0.7))
            Text(showOpenOnly ? "No open tasks remaining." : "Tap the button below to get started.")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var viewModeToggle: some View {
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
                    .foregroundStyle(parentTheme.secondaryTextColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(parentTheme.cardBackgroundLight, in: Capsule())
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
                .foregroundStyle(parentTheme.secondaryTextColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(parentTheme.cardBackgroundLight, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var calendarEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 40))
                .foregroundStyle(.primary.opacity(0.3))
            Text("No tasks on this day")
                .font(.headline)
                .foregroundStyle(.primary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var calendarTaskList: some View {
        LazyVStack(spacing: 10) {
            ForEach(calendarDayTasks) { task in
                HStack(spacing: 0) {
                    TaskRow(
                        task: task,
                        showAssignee: false,
                        currentUserName: authManager.userName,
                        theme: parentTheme,
                        onApprove: {
                            if !task.canComplete {
                                tooEarlyTask = task
                                showTooEarlyAlert = true
                            } else {
                                taskToApprove = task
                            }
                        },
                        onEdit: {
                            if task.isRecurring {
                                pendingEditTask = task
                                showEditChoice = true
                            } else {
                                editRequest = TaskEditRequest(task: task, editAll: false)
                            }
                        },
                        onDelete: { taskToDelete = task },
                        onMarkMissed: {
                            task.status = "missed"
                            let familyCode = authManager.familyCode
                            Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
                        },
                        onCancel: {
                            task.status = "cancelled"
                            let familyCode = authManager.familyCode
                            Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
                        }
                    )
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
                .background(.primary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            task.isMissed ? Color.red.opacity(0.3) : task.isCancelled ? Color.gray.opacity(0.3) : task.isInReview ? Color.orange.opacity(0.3) : Color.primary.opacity(0.25),
                            lineWidth: 1
                        )
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var expandedListContent: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(groupedTasks.enumerated()), id: \.element.key) { index, group in
                if index == todayGroupIndex && pastTaskCount > 0 {
                    PastTasksDivider(count: pastTaskCount)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(group.key)
                        .font(parentTheme.font(.subheadline).weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.6))
                        .padding(.leading, 4)

                    ForEach(group.tasks) { task in
                        HStack(spacing: 0) {
                            TaskRow(
                                task: task,
                                showAssignee: false,
                                currentUserName: authManager.userName,
                                theme: parentTheme,
                                onApprove: {
                                    if !task.canComplete {
                                        tooEarlyTask = task
                                        showTooEarlyAlert = true
                                    } else {
                                        taskToApprove = task
                                    }
                                },
                                onEdit: {
                                    if task.isRecurring {
                                        pendingEditTask = task
                                        showEditChoice = true
                                    } else {
                                        editRequest = TaskEditRequest(task: task, editAll: false)
                                    }
                                },
                                onDelete: { taskToDelete = task },
                                onMarkMissed: {
                                    withAnimation(.snappy) { task.status = "missed" }
                                    let familyCode = authManager.familyCode
                                    Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
                                    taskListVersion += 1
                                },
                                onCancel: {
                                    withAnimation(.snappy) { task.status = "cancelled" }
                                    let familyCode = authManager.familyCode
                                    Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
                                    taskListVersion += 1
                                }
                            )
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 2)
                        .background(.primary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    task.isMissed ? Color.red.opacity(0.3) : task.isCancelled ? Color.gray.opacity(0.3) : task.isInReview ? Color.orange.opacity(0.3) : Color.primary.opacity(0.25),
                                    lineWidth: 1
                                )
                        )
                        .draggable(TaskTransfer(id: task.id))

                        if task.hasGift && task.isApproved && !task.giftRevealed && task.assignedTo == authManager.userName {
                            Button {
                                giftTaskToReveal = task
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "gift.fill")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("Open Gift")
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
                    }
                }
                .id(index == todayGroupIndex ? "Today" : group.key)
                .dropDestination(for: TaskTransfer.self) { items, _ in
                    guard let transfer = items.first,
                          let refDate = group.tasks.first?.targetDate else { return false }
                    return handleTaskDrop(taskId: transfer.id, toDate: refDate)
                } isTargeted: { isTargeted in
                    // visual feedback handled by system
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var groupListContent: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(groupedTasks.enumerated()), id: \.element.key) { index, group in
                if index == todayGroupIndex && pastTaskCount > 0 {
                    PastTasksDivider(count: pastTaskCount)
                }

                NavigationLink(destination: DateTasksView(
                    dateLabel: group.key,
                    tasks: group.tasks,
                    children: children,
                    otherParent: otherParent,
                    theme: parentTheme
                )) {
                    GroupCard(dateLabel: group.key, count: group.tasks.count, theme: parentTheme)
                }
                .buttonStyle(.plain)
                .id(index == todayGroupIndex ? "Today" : group.key)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var tierBanner: some View {
        Button {
            showSubscription = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: subscriptionManager.tier == .family ? "person.3.fill" : "sparkles")
                    .font(.caption)
                    .foregroundStyle(subscriptionManager.tier == .family ? calmAccent : .orange)

                Text(subscriptionManager.tier == .pro ? "Pro Plan" : subscriptionManager.tier == .family ? "Basic Plan" : "Free Plan")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.85))

                Spacer()

                Text("Upgrade")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.orange.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.orange.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private var addTaskButton: some View {
        Button {
            showingAddTask = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.teal, in: Circle())
        }
    }

    private var dayPreviewButton: some View {
        let dayNumber = Calendar.current.component(.day, from: Date())
        return Button {
            withAnimation(.spring(duration: 0.3)) { showDayPreview = true }
        } label: {
            ZStack {
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.red)
                        .frame(width: 28, height: 9)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white)
                        .frame(width: 28, height: 19)
                }
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                .frame(width: 52, height: 52)
                .background(parentTheme.accentColor, in: Circle())

                Text("\(dayNumber)")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.black.opacity(0.8))
                    .offset(y: 4)
            }
        }
        .shadow(color: parentTheme.accentColor.opacity(0.3), radius: 8, y: 4)
    }

    private var insightsCalendarButton: some View {
        let dayNumber = Calendar.current.component(.day, from: Date())
        return Button {
            showInsights = true
        } label: {
            ZStack {
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.red)
                        .frame(width: 28, height: 9)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white)
                        .frame(width: 28, height: 19)
                }
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                .frame(width: 52, height: 52)
                .background(parentTheme.accentColor, in: Circle())

                Text("\(dayNumber)")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.black.opacity(0.8))
                    .offset(y: 4)
            }
        }
        .shadow(color: parentTheme.accentColor.opacity(0.3), radius: 8, y: 4)
    }

    private var searchButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isSearching.toggle()
                if !isSearching { searchText = "" }
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(isSearching ? .orange : parentTheme.accentColor, in: Circle())
        }
        .shadow(color: parentTheme.accentColor.opacity(0.3), radius: 8, y: 4)
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

    @Query private var shoppingItems: [ShoppingItem]

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

    @Query private var allProjects: [FamilyProject]

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

    private var goalsButton: some View {
        NavigationLink {
            GoalsListView(
                userName: authManager.userName,
                audience: isIndividual ? .individual : .parent,
                theme: parentTheme
            )
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "target")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.teal, in: Circle())

                let activeCount = allGoals.filter { $0.assignedTo == authManager.userName && $0.isActive }.count
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
        .shadow(color: .teal.opacity(0.3), radius: 8, y: 4)
    }

    private var parentStatsIconPill: some View {
        Button { showStatsPopup = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
                Text("\(parentCollectableCoins)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                Text("\(parentAwaitingCoins)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(parentTheme.cardBackground, in: Capsule())
        }
    }

    private var parentEarningsCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                        Text("\(parentCollectableCoins)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                            .contentTransition(.numericText())
                    }
                    Text("Ready to Redeem")
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(.primary.opacity(0.15))
                    .frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                        Text("\(parentAwaitingCoins)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                            .contentTransition(.numericText())
                    }
                    Text("Awaiting Approval")
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 10) {
                Button {
                    showParentRedeem = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "gift.fill")
                            .font(.caption)
                        Text("Redeem")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(parentCollectableCoins > 0 ? .orange : parentTheme.cardBackgroundLight, in: RoundedRectangle(cornerRadius: 10))
                }
                .disabled(parentCollectableCoins <= 0)

                Button {
                    showParentGifts = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "gift.fill")
                            .font(.caption)
                            .foregroundStyle(.pink)
                        Text("Gifts")
                            .font(.caption.weight(.semibold))
                        if parentUnredeemedGifts > 0 {
                            Text("\(parentUnredeemedGifts)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.primary)
                                .frame(minWidth: 14, minHeight: 14)
                                .background(.pink, in: Circle())
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    showRewardsHistory = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                        Text("History")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.green.opacity(0.2), lineWidth: 1)
        )
    }

    private func handleTaskDrop(taskId: UUID, toDate referenceDate: Date) -> Bool {
        guard let task = tasks.first(where: { $0.id == taskId }) else { return false }
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
}

// MARK: - Group Card

struct GroupCard: View {
    let dateLabel: String
    let count: Int
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateLabel)
                    .font(.headline)
                    .foregroundStyle(theme.textColor)
                    .lineLimit(1)

                Text("\(count) task\(count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryTextColor)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.tertiaryTextColor)
        }
        .padding(16)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(theme.cardBackgroundLight, lineWidth: 1)
        )
    }
}

// MARK: - Past Tasks Divider

struct PastTasksDivider: View {
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(.primary.opacity(0.15))
                .frame(height: 1)
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                Text("\(count) past task\(count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.primary.opacity(0.4))
            .fixedSize()
            Rectangle()
                .fill(.primary.opacity(0.15))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Date Tasks View

struct DateTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    @Query(sort: \Item.targetDate) private var allTasks: [Item]
    @Query private var allRedemptions: [RewardRedemption]
    @Query(sort: \Goal.createdAt) private var allGoals: [Goal]
    let dateLabel: String
    let tasks: [Item]
    let children: [FamilyMember]
    var otherParent: FamilyMember? = nil
    var memberName: String = ""
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    @State private var taskToDelete: Item?
    @State private var editRequest: TaskEditRequest?
    @State private var taskToApprove: Item?
    @State private var showingAddTask = false
    @State private var showTooEarlyAlert = false
    @State private var tooEarlyTask: Item?
    @State private var showCelebration = false
    @State private var celebrationReward: Double = 0
    @State private var showEditChoice = false
    @State private var pendingEditTask: Item?
    @State private var showOpenOnly = true
    @State private var isExpanded = true
    @State private var showCalendarView = false
    @State private var selectedCalendarDate = Date()
    @State private var showGoalPickerForMember = false
    @State private var selectedMemberGoal: Goal?

    private var memberTotalEarned: Int {
        allTasks
            .filter { $0.assignedTo == memberName && $0.isApproved && $0.reward > 0 }
            .reduce(0) { $0 + Int($1.reward) }
    }

    private var memberRedeemedCoins: Int {
        var seen = Set<String>()
        var total = 0
        for r in allRedemptions where r.childName == memberName && (r.isApproved || r.isFulfilled || r.isPending) {
            if seen.insert(r.id.uuidString).inserted { total += r.coinAmount }
        }
        return total
    }

    private var memberAvailableCoins: Int {
        max(0, memberTotalEarned - memberRedeemedCoins)
    }

    private var liveTasks: [Item] {
        if !memberName.isEmpty {
            return allTasks.filter { $0.assignedTo == memberName }
        }
        let taskIds = Set(tasks.map { $0.id })
        return allTasks.filter { taskIds.contains($0.id) }
    }

    private var filteredTasks: [Item] {
        if showOpenOnly {
            return liveTasks.filter { !$0.isArchived && !$0.isApproved && !$0.isMissed && !$0.isCancelled }
        } else {
            return liveTasks
        }
    }

    private var dateGroupedTasks: [(key: String, tasks: [Item])] {
        let grouped = Dictionary(grouping: filteredTasks) { $0.dueDateLabel }
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

    private var datePastTaskCount: Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return filteredTasks.filter { $0.targetDate < startOfToday }.count
    }

    private var dateTodayGroupIndex: Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return dateGroupedTasks.firstIndex { ($0.tasks.first?.targetDate ?? .distantPast) >= startOfToday } ?? dateGroupedTasks.count
    }

    private var dateCalendarDayTasks: [Item] {
        let calendar = Calendar.current
        return filteredTasks
            .filter { calendar.isDate($0.targetDate, inSameDayAs: selectedCalendarDate) }
            .sorted { $0.targetDate < $1.targetDate }
    }

    private func dateTaskRowView(_ task: Item) -> some View {
        HStack(spacing: 0) {
            TaskRow(
                task: task,
                currentUserName: authManager.userName,
                theme: theme,
                onApprove: {
                    if !task.canComplete {
                        tooEarlyTask = task
                        showTooEarlyAlert = true
                    } else {
                        taskToApprove = task
                    }
                },
                onEdit: {
                    if task.isRecurring {
                        pendingEditTask = task
                        showEditChoice = true
                    } else {
                        editRequest = TaskEditRequest(task: task, editAll: false)
                    }
                },
                onDelete: { taskToDelete = task },
                onMarkMissed: {
                    task.status = "missed"
                    let familyCode = authManager.familyCode
                    Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
                },
                onCancel: {
                    task.status = "cancelled"
                    let familyCode = authManager.familyCode
                    Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
                }
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .background(.primary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    task.isMissed ? Color.red.opacity(0.3) : task.isCancelled ? Color.gray.opacity(0.3) : task.isInReview ? Color.orange.opacity(0.3) : Color.primary.opacity(0.25),
                    lineWidth: 1
                )
        )
    }

    private var dateViewModeToggle: some View {
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
                    .foregroundStyle(theme.secondaryTextColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.cardBackgroundLight, in: Capsule())
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
                .foregroundStyle(theme.secondaryTextColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(theme.cardBackgroundLight, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var taskListContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(dateGroupedTasks.enumerated()), id: \.element.key) { index, group in
                            if index == dateTodayGroupIndex && datePastTaskCount > 0 {
                                PastTasksDivider(count: datePastTaskCount)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                if isExpanded {
                                    Text(group.key)
                                        .font(theme.font(.subheadline).weight(.semibold))
                                        .foregroundStyle(.primary.opacity(0.6))
                                        .padding(.leading, 4)

                                    ForEach(group.tasks) { task in
                                        dateTaskRowView(task)
                                            .draggable(TaskTransfer(id: task.id))
                                    }
                                } else {
                                    GroupCard(dateLabel: group.key, count: group.tasks.count, theme: theme)
                                }
                            }
                            .id(group.key)
                            .dropDestination(for: TaskTransfer.self) { items, _ in
                                guard let transfer = items.first,
                                      let refDate = group.tasks.first?.targetDate else { return false }
                                return dateHandleTaskDrop(taskId: transfer.id, toDate: refDate)
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
            .onChange(of: showOpenOnly) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation { proxy.scrollTo("Today", anchor: .top) }
                }
            }
        }
    }

    private var memberGoalStripSection: some View {
        HStack(spacing: 6) {
            MemberGoalStrip(
                memberName: memberName,
                goals: allGoals,
                tasks: Array(allTasks),
                theme: theme,
                onAddGoal: { showGoalPickerForMember = true },
                onTapGoal: { goal in selectedMemberGoal = goal }
            )
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var memberHeader: some View {
        HStack(spacing: 14) {
            AvatarView(avatarId: otherParent?.avatar ?? "", size: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(memberName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text("\(memberAvailableCoins) coins")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.yellow.opacity(0.85))
                    if memberRedeemedCoins > 0 {
                        Text("(\(memberRedeemedCoins) redeemed)")
                            .font(.caption2)
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                }

                Text("\(liveTasks.filter { $0.isApproved }.count)/\(liveTasks.count) completed")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.5))
            }

            Spacer()

            if !todayOpenTasks.isEmpty {
                Button {
                    sendMemberReminder()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10))
                        Text("Remind (\(todayOpenTasks.count) today)")
                            .font(.system(size: 11, weight: .semibold))
                            .fixedSize()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.orange, in: Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var todayOpenTasks: [Item] {
        liveTasks.filter { $0.isOpen && Calendar.current.isDateInToday($0.targetDate) }
    }

    @State private var showMemberReminderSent = false

    private func sendMemberReminder() {
        let now = Date()
        let familyCode = authManager.familyCode
        for task in todayOpenTasks {
            task.lastRemindedAt = now
        }
        Task {
            for task in todayOpenTasks {
                await cloudKitManager.pushTask(task, familyCode: familyCode)
            }
        }
        showMemberReminderSent = true
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if !memberName.isEmpty {
                    memberHeader

                    QuestProgressBar(
                        quest: MonthlyQuest.compute(tasks: allTasks, userName: memberName),
                        theme: theme
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                    memberGoalStripSection
                }

                dateViewModeToggle

                if showCalendarView {
                    WeekCalendarStrip(
                        selectedDate: $selectedCalendarDate,
                        tasks: filteredTasks,
                        theme: theme
                    )
                    if dateCalendarDayTasks.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.system(size: 40))
                                .foregroundStyle(.primary.opacity(0.3))
                            Text("No tasks on this day")
                                .font(.headline)
                                .foregroundStyle(.primary.opacity(0.5))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(dateCalendarDayTasks) { task in
                                    dateTaskRowView(task)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                        }
                    }
                } else if filteredTasks.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: showOpenOnly ? "checkmark.circle" : "tray")
                            .font(.system(size: 40))
                            .foregroundStyle(.primary.opacity(0.3))
                        Text(showOpenOnly ? "All caught up!" : "No tasks yet")
                            .font(.headline)
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                    Spacer()
                } else {
                    taskListContent
                }

                Color.clear.frame(height: 70)
            }
        }
        .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
        .navigationTitle(dateLabel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.snappy) { showOpenOnly.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showOpenOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        Text(showOpenOnly ? "Open Tasks" : "All Tasks")
                            .font(.caption)
                    }
                    .foregroundStyle(.primary.opacity(0.7))
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(children: children, otherParent: otherParent, preselectedChild: otherParent?.name ?? "", theme: theme)
        }
        .alert(deleteAlertTitle, isPresented: deleteAlertBinding) {
            deleteAlertButtons
        } message: {
            deleteAlertMessageView
        }
        .sheet(item: $editRequest) { request in
            EditTaskView(
                task: request.task, children: children, otherParent: otherParent, theme: theme, editAll: request.editAll,
                onDelete: { taskToDelete = request.task; editRequest = nil },
                onMarkMissed: {
                    request.task.status = "missed"
                    let familyCode = authManager.familyCode
                    Task { await cloudKitManager.pushTask(request.task, familyCode: familyCode) }
                    editRequest = nil
                }
            )
        }
        .confirmationDialog("This is a recurring task", isPresented: $showEditChoice, titleVisibility: .visible) {
            Button("Edit This Task Only") {
                if let task = pendingEditTask {
                    editRequest = TaskEditRequest(task: task, editAll: false)
                }
                pendingEditTask = nil
            }
            Button("Edit All Recurring") {
                if let task = pendingEditTask {
                    editRequest = TaskEditRequest(task: task, editAll: true)
                }
                pendingEditTask = nil
            }
            Button("Cancel", role: .cancel) { pendingEditTask = nil }
        } message: {
            Text("Would you like to edit just this task or all open instances?")
        }
        .alert(approveAlertTitle, isPresented: approveAlertBinding) {
            approveAlertButtons
        } message: {
            approveAlertMessageView
        }
        .alert("Not Yet! ⏰", isPresented: $showTooEarlyAlert) {
            Button("Got It", role: .cancel) { tooEarlyTask = nil }
        } message: {
            if let task = tooEarlyTask {
                Text("This task is scheduled for \(task.dueDateLabel). It can be completed when the day arrives!")
            }
        }
        .alert("Reminder Sent!", isPresented: $showMemberReminderSent) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(memberName) has been reminded about today's tasks.")
        }
        .sheet(isPresented: $showGoalPickerForMember) {
            GoalPickerView(
                audience: children.contains(where: { $0.name == memberName }) ? .child : .parent,
                assignee: memberName,
                theme: theme
            )
        }
        .sheet(item: $selectedMemberGoal) { goal in
            GoalDetailView(goal: goal, theme: theme)
        }
        .overlay {
            CelebrationOverlay(
                isActive: $showCelebration,
                title: "Task Approved!",
                subtitle: "Reward credited",
                rewardAmount: celebrationReward
            )
        }
    }

    private var deleteAlertTitle: String {
        if let task = taskToDelete, task.isApproved || task.isInReview {
            return "Cannot Delete"
        }
        return "Delete Task"
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { taskToDelete != nil },
            set: { if !$0 { taskToDelete = nil } }
        )
    }

    @ViewBuilder
    private var deleteAlertButtons: some View {
        if let task = taskToDelete {
            if task.isApproved || task.isInReview {
                Button("OK", role: .cancel) { taskToDelete = nil }
            } else if task.isRecurring {
                Button("Delete This Task Only", role: .destructive) {
                    deleteSingleTask(task)
                    taskToDelete = nil
                }
                Button("Delete All Recurring", role: .destructive) {
                    deleteAllRecurring(like: task)
                    taskToDelete = nil
                }
                Button("Cancel", role: .cancel) { taskToDelete = nil }
            } else {
                Button("Delete", role: .destructive) {
                    deleteSingleTask(task)
                    taskToDelete = nil
                }
                Button("Cancel", role: .cancel) { taskToDelete = nil }
            }
        }
    }

    @ViewBuilder
    private var deleteAlertMessageView: some View {
        if let task = taskToDelete {
            deleteAlertMessage(for: task)
        }
    }

    private var approveAlertTitle: String {
        taskToApprove?.isInReview == true ? "Approve Task?" : "Mark as Complete?"
    }

    private var approveAlertBinding: Binding<Bool> {
        Binding(
            get: { taskToApprove != nil },
            set: { if !$0 { taskToApprove = nil } }
        )
    }

    @ViewBuilder
    private var approveAlertButtons: some View {
        Button("Cancel", role: .cancel) {
            taskToApprove = nil
        }
        if taskToApprove?.isInReview == true {
            Button("Reject", role: .destructive) {
                if let task = taskToApprove {
                    handleRejection(task: task)
                }
                taskToApprove = nil
            }
        }
        Button(taskToApprove?.isInReview == true ? "Approve" : "Complete") {
            if let task = taskToApprove {
                handleApproval(task: task)
            }
            taskToApprove = nil
        }
    }

    @ViewBuilder
    private var approveAlertMessageView: some View {
        if let task = taskToApprove {
            if task.isInReview {
                Text("\"\(task.name)\" is waiting for your approval.")
            } else {
                Text("Mark \"\(task.name)\" as complete? This cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private func deleteAlertMessage(for task: Item) -> some View {
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

    private func deleteSingleTask(_ task: Item) {
        guard !task.isApproved && !task.isInReview else { return }
        notificationManager.cancelTaskReminder(taskId: task.id)
        let taskID = task.id
        withAnimation { modelContext.delete(task) }
        try? modelContext.save()
        Task { await cloudKitManager.deleteRemoteTask(taskID) }
    }

    private func deleteAllRecurring(like task: Item) {
        let taskName = task.name
        let taskAssignee = task.assignedTo
        let matching = allTasks.filter {
            $0.name == taskName && $0.assignedTo == taskAssignee
            && $0.isRecurring && !$0.isArchived
        }
        let toDelete = matching.filter { !$0.isApproved && !$0.isInReview }
        guard !toDelete.isEmpty else { return }
        var taskIDs: [UUID] = []
        for t in toDelete {
            notificationManager.cancelTaskReminder(taskId: t.id)
            taskIDs.append(t.id)
        }
        withAnimation {
            for t in toDelete { modelContext.delete(t) }
        }
        try? modelContext.save()
        Task { await cloudKitManager.deleteRemoteTasks(taskIDs) }
    }

    private func handleApproval(task: Item) {
        withAnimation(.snappy) {
            task.status = "approved"
        }
        let snapshot = CloudKitManager.TaskSnapshot(task)
        if task.reward > 0 && !task.assignedTo.isEmpty {
            let allFamilyMembers = children + [otherParent].compactMap { $0 }
            if let member = allFamilyMembers.first(where: { $0.name == task.assignedTo }) {
                member.addReward(task.reward)
                let familyCode = authManager.familyCode
                Task { await cloudKitManager.pushMember(member, familyCode: familyCode) }
            }
        }
        try? modelContext.save()
        if !task.assignedTo.isEmpty {
            notificationManager.sendTaskApprovedNotification(
                taskName: task.name,
                childName: task.assignedTo,
                reward: task.reward
            )
        }
        let familyCode = authManager.familyCode
        Task {
            await cloudKitManager.pushTaskSnapshot(snapshot, familyCode: familyCode)
        }
        SoundManager.shared.playApplause()
        celebrationReward = task.reward
        showCelebration = true

    }

    private func handleRejection(task: Item) {
        task.status = "open"
        let snapshot = CloudKitManager.TaskSnapshot(task)
        notificationManager.sendTaskRejectedNotification(
            taskName: task.name,
            childName: task.assignedTo
        )
        let familyCode = authManager.familyCode
        Task {
            await cloudKitManager.pushTaskSnapshot(snapshot, familyCode: familyCode)
        }
    }

    private func dateHandleTaskDrop(taskId: UUID, toDate referenceDate: Date) -> Bool {
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
}

// MARK: - Child Tasks View

struct ChildTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    @Query(sort: \Item.targetDate) private var allTasks: [Item]
    @Query private var allRedemptions: [RewardRedemption]
    @Query(sort: \Goal.createdAt) private var allGoals: [Goal]
    let child: FamilyMember
    let tasks: [Item]
    let allChildren: [FamilyMember]
    var otherParent: FamilyMember? = nil
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    @State private var showOpenOnly = true
    @State private var isExpanded = true
    @State private var showCalendarView = false
    @State private var selectedCalendarDate = Date()
    @State private var editRequest: TaskEditRequest?
    @State private var taskToDelete: Item?
    @State private var taskToApprove: Item?
    @State private var showCelebration = false
    @State private var celebrationReward: Double = 0
    @State private var showingAddTask = false
    @State private var showTooEarlyAlert = false
    @State private var tooEarlyTask: Item?
    @State private var showReminderSent = false
    @State private var showEditChoice = false
    @State private var pendingEditTask: Item?
    @State private var showGoalPickerForChild = false
    @State private var selectedChildGoal: Goal?

    private var childCalendarDayTasks: [Item] {
        let calendar = Calendar.current
        return filteredTasks
            .filter { calendar.isDate($0.targetDate, inSameDayAs: selectedCalendarDate) }
            .sorted { $0.targetDate < $1.targetDate }
    }

    private var childTotalEarned: Int {
        allTasks
            .filter { $0.assignedTo == child.name && $0.isApproved && $0.reward > 0 }
            .reduce(0) { $0 + Int($1.reward) }
    }

    private var childRedeemedCoins: Int {
        var seen = Set<String>()
        var total = 0
        for r in allRedemptions where r.childName == child.name && (r.isApproved || r.isFulfilled || r.isPending) {
            if seen.insert(r.id.uuidString).inserted { total += r.coinAmount }
        }
        return total
    }

    private var childAvailableCoins: Int {
        max(0, childTotalEarned - childRedeemedCoins)
    }

    private var childLiveTasks: [Item] {
        allTasks.filter { $0.assignedTo == child.name }
    }

    private var filteredTasks: [Item] {
        showOpenOnly ? childLiveTasks.filter { !$0.isApproved && !$0.isMissed && !$0.isCancelled } : childLiveTasks
    }

    private var groupedTasks: [(key: String, tasks: [Item])] {
        let grouped = Dictionary(grouping: filteredTasks) { $0.dueDateLabel }
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

    private var childPastTaskCount: Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return filteredTasks.filter { $0.targetDate < startOfToday }.count
    }

    private var childTodayGroupIndex: Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return groupedTasks.firstIndex { ($0.tasks.first?.targetDate ?? .distantPast) >= startOfToday } ?? groupedTasks.count
    }

    private var childViewModeToggle: some View {
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
                    .foregroundStyle(theme.secondaryTextColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.cardBackgroundLight, in: Capsule())
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
                .foregroundStyle(theme.secondaryTextColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(theme.cardBackgroundLight, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func childTaskRowView(_ task: Item) -> some View {
        HStack(spacing: 0) {
            TaskRow(
                task: task,
                currentUserName: authManager.userName,
                canActOnBehalf: true,
                theme: theme,
                onApprove: {
                    if !task.canComplete {
                        tooEarlyTask = task
                        showTooEarlyAlert = true
                    } else {
                        taskToApprove = task
                    }
                },
                onEdit: {
                    if task.isRecurring {
                        pendingEditTask = task
                        showEditChoice = true
                    } else {
                        editRequest = TaskEditRequest(task: task, editAll: false)
                    }
                },
                onDelete: { taskToDelete = task },
                onMarkMissed: {
                    task.status = "missed"
                    let familyCode = authManager.familyCode
                    Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
                },
                onCancel: {
                    task.status = "cancelled"
                    let familyCode = authManager.familyCode
                    Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
                }
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .background(.primary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    task.isMissed ? Color.red.opacity(0.3) : task.isCancelled ? Color.gray.opacity(0.3) : task.isInReview ? Color.orange.opacity(0.3) : Color.primary.opacity(0.25),
                    lineWidth: 1
                )
        )
    }

    private var childTaskListContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    LazyVStack(spacing: isExpanded ? 10 : 12) {
                        ForEach(Array(groupedTasks.enumerated()), id: \.element.key) { index, group in
                            if index == childTodayGroupIndex && childPastTaskCount > 0 {
                                PastTasksDivider(count: childPastTaskCount)
                            }

                        VStack(alignment: .leading, spacing: 8) {
                            if isExpanded {
                                Text(group.key)
                                    .font(theme.font(.subheadline).weight(.semibold))
                                    .foregroundStyle(.primary.opacity(0.6))
                                    .padding(.leading, 4)

                                ForEach(group.tasks) { task in
                                    childTaskRowView(task)
                                        .draggable(TaskTransfer(id: task.id))
                                }
                            } else {
                                GroupCard(dateLabel: group.key, count: group.tasks.count, theme: theme)
                            }
                        }
                        .id(group.key)
                        .dropDestination(for: TaskTransfer.self) { items, _ in
                            guard let transfer = items.first,
                                  let refDate = group.tasks.first?.targetDate else { return false }
                            return childHandleTaskDrop(taskId: transfer.id, toDate: refDate)
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
        .onChange(of: showOpenOnly) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation { proxy.scrollTo("Today", anchor: .top) }
            }
        }
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                childHeader

                QuestProgressBar(
                    quest: MonthlyQuest.compute(tasks: allTasks, userName: child.name),
                    theme: theme
                )
                .padding(.horizontal, 16)
                .padding(.top, 6)

                childGoalStripSection

                childViewModeToggle

                if showCalendarView {
                    WeekCalendarStrip(
                        selectedDate: $selectedCalendarDate,
                        tasks: filteredTasks,
                        theme: theme
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(childCalendarDayTasks) { task in
                                    childTaskRowView(task)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                        }
                    }
                } else if filteredTasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: showOpenOnly ? "checkmark.circle" : "tray")
                            .font(.system(size: 56))
                            .foregroundStyle(.primary.opacity(0.3))
                        Text(showOpenOnly ? "All caught up!" : "No tasks yet")
                            .font(.title3)
                            .foregroundStyle(.primary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    childTaskListContent
                }

                Color.clear.frame(height: 70)
            }

        }
        .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
        .navigationTitle("\(child.name)'s Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { childFilterToolbar }
        .alert(childDeleteAlertTitle, isPresented: childDeleteAlertBinding) {
            childDeleteAlertButtons
        } message: {
            childDeleteAlertMessageView
        }
        .alert(childApproveAlertTitle, isPresented: childApproveAlertBinding) {
            childApproveAlertButtons
        } message: {
            childApproveAlertMessageView
        }
        .sheet(item: $editRequest) { request in
            EditTaskView(
                task: request.task, children: allChildren, otherParent: otherParent, theme: theme, editAll: request.editAll,
                onDelete: { taskToDelete = request.task; editRequest = nil },
                onMarkMissed: {
                    request.task.status = "missed"
                    let familyCode = authManager.familyCode
                    Task { await cloudKitManager.pushTask(request.task, familyCode: familyCode) }
                    editRequest = nil
                }
            )
        }
        .confirmationDialog("This is a recurring task", isPresented: $showEditChoice, titleVisibility: .visible) {
            Button("Edit This Task Only") {
                if let task = pendingEditTask {
                    editRequest = TaskEditRequest(task: task, editAll: false)
                }
                pendingEditTask = nil
            }
            Button("Edit All Recurring") {
                if let task = pendingEditTask {
                    editRequest = TaskEditRequest(task: task, editAll: true)
                }
                pendingEditTask = nil
            }
            Button("Cancel", role: .cancel) { pendingEditTask = nil }
        } message: {
            Text("Would you like to edit just this task or all open instances?")
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(children: allChildren, otherParent: otherParent, preselectedChild: child.name, theme: theme)
        }
        .alert("Not Yet! ⏰", isPresented: $showTooEarlyAlert) {
            Button("Got It", role: .cancel) { tooEarlyTask = nil }
        } message: {
            if let task = tooEarlyTask {
                Text("This task is scheduled for \(task.dueDateLabel). It can be completed when the day arrives!")
            }
        }
        .sheet(isPresented: $showGoalPickerForChild) {
            GoalPickerView(
                audience: .child,
                assignee: child.name,
                theme: theme
            )
        }
        .sheet(item: $selectedChildGoal) { goal in
            GoalDetailView(goal: goal, theme: theme)
        }
        .overlay {
            CelebrationOverlay(
                isActive: $showCelebration,
                title: "Task Approved!",
                subtitle: "Reward credited",
                rewardAmount: celebrationReward
            )
        }
    }

    private var childFilterToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                withAnimation(.snappy) { showOpenOnly.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showOpenOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    Text(showOpenOnly ? "Open Tasks" : "All Tasks")
                        .font(.subheadline)
                }
            }
        }
    }

    private var childDeleteAlertTitle: String {
        if let task = taskToDelete, task.isApproved || task.isInReview {
            return "Cannot Delete"
        }
        return "Delete Task"
    }

    private var childDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { taskToDelete != nil },
            set: { if !$0 { taskToDelete = nil } }
        )
    }

    @ViewBuilder
    private var childDeleteAlertButtons: some View {
        if let task = taskToDelete {
            if task.isApproved || task.isInReview {
                Button("OK", role: .cancel) { taskToDelete = nil }
            } else if task.isRecurring {
                Button("Delete This Task Only", role: .destructive) {
                    deleteSingleTask(task)
                    taskToDelete = nil
                }
                Button("Delete All Recurring", role: .destructive) {
                    deleteAllRecurring(like: task)
                    taskToDelete = nil
                }
                Button("Cancel", role: .cancel) { taskToDelete = nil }
            } else {
                Button("Delete", role: .destructive) {
                    deleteSingleTask(task)
                    taskToDelete = nil
                }
                Button("Cancel", role: .cancel) { taskToDelete = nil }
            }
        }
    }

    @ViewBuilder
    private var childDeleteAlertMessageView: some View {
        if let task = taskToDelete {
            deleteAlertMessage(for: task)
        }
    }

    private var childApproveAlertTitle: String {
        taskToApprove?.isInReview == true ? "Approve Task?" : "Mark as Complete?"
    }

    private var childApproveAlertBinding: Binding<Bool> {
        Binding(
            get: { taskToApprove != nil },
            set: { if !$0 { taskToApprove = nil } }
        )
    }

    @ViewBuilder
    private var childApproveAlertButtons: some View {
        Button("Cancel", role: .cancel) { taskToApprove = nil }
        if taskToApprove?.isInReview == true {
            Button("Reject", role: .destructive) {
                if let task = taskToApprove {
                    handleChildRejection(task: task)
                }
                taskToApprove = nil
            }
        }
        Button(taskToApprove?.isInReview == true ? "Approve" : "Complete") {
            if let task = taskToApprove {
                handleChildApproval(task: task)
            }
            taskToApprove = nil
        }
    }

    @ViewBuilder
    private var childApproveAlertMessageView: some View {
        if let task = taskToApprove {
            if task.isInReview {
                Text("\"\(task.name)\" is waiting for your approval.")
            } else {
                Text("Mark \"\(task.name)\" as complete? This cannot be undone.")
            }
        }
    }

    private var todayOpenTasks: [Item] {
        tasks.filter { $0.isOpen && Calendar.current.isDateInToday($0.targetDate) }
    }

    private var childGoalStripSection: some View {
        HStack(spacing: 6) {
            MemberGoalStrip(
                memberName: child.name,
                goals: allGoals,
                tasks: Array(allTasks),
                theme: theme,
                onAddGoal: { showGoalPickerForChild = true },
                onTapGoal: { goal in selectedChildGoal = goal }
            )
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var childHeader: some View {
        HStack(spacing: 14) {
            AvatarView(avatarId: child.avatar, size: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(child.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text("\(childAvailableCoins) coins")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.yellow.opacity(0.85))
                    if childRedeemedCoins > 0 {
                        Text("(\(childRedeemedCoins) redeemed)")
                            .font(.caption2)
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                }

                if !todayOpenTasks.isEmpty {
                    Button {
                        sendReminder()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 10))
                            Text("Remind (\(todayOpenTasks.count) today)")
                                .font(.system(size: 11, weight: .semibold))
                                .fixedSize()
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.orange, in: Capsule())
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(tasks.filter { $0.isApproved }.count)/\(tasks.count)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text("completed")
                    .font(.caption2)
                    .foregroundStyle(.primary.opacity(0.4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .alert("Reminder Sent!", isPresented: $showReminderSent) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("A reminder has been sent to \(child.name).")
        }
    }

    private func sendReminder() {
        guard !todayOpenTasks.isEmpty else { return }

        let now = Date()
        let familyCode = authManager.familyCode
        for task in todayOpenTasks {
            task.lastRemindedAt = now
        }
        Task {
            for task in todayOpenTasks {
                await cloudKitManager.pushTask(task, familyCode: familyCode)
            }
        }

        showReminderSent = true
    }

    @ViewBuilder
    private func deleteAlertMessage(for task: Item) -> some View {
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

    private func handleChildApproval(task: Item) {
        withAnimation(.snappy) {
            task.status = "approved"
        }
        let snapshot = CloudKitManager.TaskSnapshot(task)
        if task.reward > 0 {
            child.addReward(task.reward)
        }
        try? modelContext.save()
        notificationManager.sendTaskApprovedNotification(
            taskName: task.name,
            childName: child.name,
            reward: task.reward
        )
        let familyCode = authManager.familyCode
        Task {
            await cloudKitManager.pushTaskSnapshot(snapshot, familyCode: familyCode)
            await cloudKitManager.pushMember(child, familyCode: familyCode)
        }
        SoundManager.shared.playApplause()
        celebrationReward = task.reward
        showCelebration = true

    }

    private func handleChildRejection(task: Item) {
        task.status = "open"
        let snapshot = CloudKitManager.TaskSnapshot(task)
        notificationManager.sendTaskRejectedNotification(
            taskName: task.name,
            childName: child.name
        )
        let familyCode = authManager.familyCode
        Task {
            await cloudKitManager.pushTaskSnapshot(snapshot, familyCode: familyCode)
        }
    }

    private func deleteSingleTask(_ task: Item) {
        guard !task.isApproved && !task.isInReview else { return }
        notificationManager.cancelTaskReminder(taskId: task.id)
        let taskID = task.id
        withAnimation { modelContext.delete(task) }
        try? modelContext.save()
        Task { await cloudKitManager.deleteRemoteTask(taskID) }
    }

    private func deleteAllRecurring(like task: Item) {
        let taskName = task.name
        let taskAssignee = task.assignedTo
        let matching = allTasks.filter {
            $0.name == taskName && $0.assignedTo == taskAssignee
            && $0.isRecurring && !$0.isArchived
        }
        let toDelete = matching.filter { !$0.isApproved && !$0.isInReview }
        guard !toDelete.isEmpty else { return }
        var taskIDs: [UUID] = []
        for t in toDelete {
            notificationManager.cancelTaskReminder(taskId: t.id)
            taskIDs.append(t.id)
        }
        withAnimation {
            for t in toDelete { modelContext.delete(t) }
        }
        try? modelContext.save()
        Task { await cloudKitManager.deleteRemoteTasks(taskIDs) }
    }

    private func childHandleTaskDrop(taskId: UUID, toDate referenceDate: Date) -> Bool {
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
}

// MARK: - Parent Expanded Task Alerts

struct ParentExpandedTaskAlerts: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    @Query(sort: \Item.targetDate) private var allTasksQuery: [Item]

    @Binding var taskToDelete: Item?
    @Binding var taskToApprove: Item?
    @Binding var editRequest: TaskEditRequest?
    @Binding var showTooEarlyAlert: Bool
    @Binding var tooEarlyTask: Item?
    let tasks: [Item]
    let children: [FamilyMember]
    var otherParent: FamilyMember?
    let allMembers: [FamilyMember]
    var theme: ChildTheme
    var onTaskChanged: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .alert("Not Yet! ⏰", isPresented: $showTooEarlyAlert) {
                Button("Got It", role: .cancel) { tooEarlyTask = nil }
            } message: {
                if let task = tooEarlyTask {
                    Text("This task is scheduled for \(task.dueDateLabel). It can be completed when the day arrives!")
                }
            }
            .alert(
                "Delete Task?",
                isPresented: Binding(get: { taskToDelete != nil }, set: { if !$0 { taskToDelete = nil } })
            ) {
                if let task = taskToDelete, task.isRecurring {
                    Button("Delete This Task Only", role: .destructive) {
                        deleteTask(task)
                    }
                    Button("Delete All Recurring", role: .destructive) {
                        deleteAllRecurringExpanded(like: task)
                    }
                    Button("Cancel", role: .cancel) { taskToDelete = nil }
                } else {
                    Button("Delete", role: .destructive) {
                        if let task = taskToDelete {
                            deleteTask(task)
                        }
                    }
                    Button("Cancel", role: .cancel) { taskToDelete = nil }
                }
            } message: {
                if let task = taskToDelete {
                    Text(task.isRecurring
                         ? "Do you want to delete only this instance of \"\(task.name)\" or all recurring instances?"
                         : "Are you sure you want to delete \"\(task.name)\"?")
                }
            }
            .alert(
                taskToApprove?.isInReview == true ? "Approve Task?" : "Mark as Complete?",
                isPresented: Binding(get: { taskToApprove != nil }, set: { if !$0 { taskToApprove = nil } })
            ) {
                approveButtons
            } message: {
                approveMessage
            }
            .sheet(item: $editRequest) { request in
                EditTaskView(
                    task: request.task, children: children, otherParent: otherParent, theme: theme, editAll: request.editAll,
                    onDelete: { taskToDelete = request.task; editRequest = nil },
                    onMarkMissed: {
                        request.task.status = "missed"
                        let familyCode = authManager.familyCode
                        Task { await cloudKitManager.pushTask(request.task, familyCode: familyCode) }
                        editRequest = nil
                    }
                )
            }
    }

    private func deleteTask(_ task: Item) {
        guard !task.isApproved && !task.isInReview else {
            taskToDelete = nil
            return
        }
        let taskID = task.id
        notificationManager.cancelTaskReminder(taskId: taskID)
        withAnimation { modelContext.delete(task) }
        try? modelContext.save()
        taskToDelete = nil
        Task { await cloudKitManager.deleteRemoteTask(taskID) }
    }

    private func deleteAllRecurringExpanded(like task: Item) {
        let taskName = task.name
        let taskAssignee = task.assignedTo
        let matching = tasks.filter {
            $0.name == taskName && $0.assignedTo == taskAssignee
            && $0.isRecurring && !$0.isArchived
        }
        let toDelete = matching.filter { !$0.isApproved && !$0.isInReview }
        var taskIDs: [UUID] = []
        for t in toDelete {
            notificationManager.cancelTaskReminder(taskId: t.id)
            taskIDs.append(t.id)
        }
        withAnimation {
            for t in toDelete { modelContext.delete(t) }
        }
        try? modelContext.save()
        taskToDelete = nil
        Task { await cloudKitManager.deleteRemoteTasks(taskIDs) }
    }

    @ViewBuilder
    private var approveButtons: some View {
        Button(taskToApprove?.isInReview == true ? "Approve" : "Complete") {
            if let task = taskToApprove {
                withAnimation(.snappy) {
                    task.status = "approved"
                }
                let familyCode = authManager.familyCode
                Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
                if task.reward > 0, !task.assignedTo.isEmpty {
                    if let member = allMembers.first(where: { $0.name == task.assignedTo }) {
                        member.addReward(task.reward)
                        Task { await cloudKitManager.pushMember(member, familyCode: familyCode) }
                    }
                }
                try? modelContext.save()
                onTaskChanged?()
                taskToApprove = nil
            }
        }
        Button("Cancel", role: .cancel) { taskToApprove = nil }
    }

    @ViewBuilder
    private var approveMessage: some View {
        if let task = taskToApprove {
            if task.isInReview {
                Text("\"\(task.name)\" is waiting for your approval.")
            } else {
                Text("Mark \"\(task.name)\" as complete? This cannot be undone.")
            }
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    @Bindable var task: Item
    var showAssignee: Bool = false
    var currentUserName: String = ""
    var canActOnBehalf: Bool = false
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    var onApprove: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onMarkMissed: (() -> Void)?
    var onCancel: (() -> Void)?
    @State private var showMissedOptions = false

    private var statusColor: Color {
        if task.isApproved { return .green }
        if task.isInReview { return .orange }
        if task.isMissed { return .red }
        if task.isCancelled { return .gray }
        return Color.primary.opacity(0.4)
    }

    private var statusLabel: String {
        if task.isApproved { return "Done" }
        if task.isInReview { return "Review" }
        if task.isMissed { return "Missed" }
        if task.isCancelled { return "Cancelled" }
        return "To Do"
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary.opacity(0.25))
                .frame(width: 20)

            Button {
                if task.isMissed {
                    showMissedOptions = true
                    return
                }
                guard task.isOpen || task.isInReview else { return }
                let isMyTask = currentUserName.isEmpty || task.assignedTo == currentUserName
                guard isMyTask || task.isInReview || canActOnBehalf else { return }
                onApprove?()
            } label: {
                VStack(spacing: 3) {
                    ZStack {
                        Circle()
                            .strokeBorder(statusColor, lineWidth: 2)
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
                    Text(statusLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .disabled(task.isApproved || task.isCancelled)

            Button {
                onEdit?()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(task.emoji) \(task.name)")
                            .font(theme.font(.body))
                            .lineLimit(1)
                            .strikethrough(task.isApproved || task.isCancelled)
                            .foregroundStyle(Color.primary.opacity(task.isApproved || task.isCancelled ? 0.35 : 1))

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

                            if task.hasGift {
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color(red: 1.0, green: 0.2, blue: 0.5))
                                    .overlay(
                                        Image(systemName: "gift")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.primary.opacity(0.6))
                                    )
                            }

                            if task.belongsToProject {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(theme.accentColor, in: Circle())
                            }

                            if task.belongsToGoal {
                                Image(systemName: "target")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(theme.accentColor, in: Circle())
                            }

                            if task.needsTransport {
                                Image(systemName: task.transportIcon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.yellow)
                            }

                            if showAssignee && !task.assignedTo.isEmpty {
                                Text("•")
                                    .foregroundStyle(.primary.opacity(0.3))
                                Label(task.assignedTo, systemImage: "person.fill")
                                    .font(.caption)
                                    .foregroundStyle(calmAccent.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                        .lineLimit(1)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let onDelete {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .background(.red.opacity(0.5), in: Circle())
                        .overlay(Circle().strokeBorder(.red.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .opacity(task.isApproved || task.isCancelled ? 0.7 : 1)
        .contextMenu {
            if task.isOpen || task.isInReview {
                Button {
                    onMarkMissed?()
                } label: {
                    Label("Mark as Missed", systemImage: "exclamationmark.triangle")
                }
                Button(role: .destructive) {
                    onCancel?()
                } label: {
                    Label("Cancel Task", systemImage: "xmark.circle")
                }
            }
            if task.isMissed || task.isCancelled {
                Button {
                    task.status = "open"
                    onEdit?()
                } label: {
                    Label("Reopen Task", systemImage: "arrow.uturn.backward")
                }
            }
        }
        .confirmationDialog("This task was missed", isPresented: $showMissedOptions, titleVisibility: .visible) {
            Button("Reopen & Replan") {
                task.status = "open"
                onEdit?()
            }
            Button("Mark as Closed") {
                task.status = "approved"
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Would you like to reopen this task to replan it, or close it?")
        }
    }
}

// MARK: - Task Detail View

struct TaskDetailView: View {
    let task: Item
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    var canEdit: Bool = false
    var canDelete: Bool = false
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    private var statusText: String {
        if task.isApproved { return "Approved" }
        if task.isInReview { return "In Review" }
        if task.isMissed { return "Missed" }
        if task.isCancelled { return "Cancelled" }
        return "Open"
    }

    private var statusColor: Color {
        if task.isApproved { return .green }
        if task.isInReview { return .orange }
        if task.isMissed { return .red }
        if task.isCancelled { return .gray }
        return calmAccent
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Spacer().frame(height: 8)

                        // Status badge
                        HStack {
                            Image(systemName: task.isApproved ? "checkmark.circle.fill" : task.isInReview ? "clock.fill" : task.isMissed ? "xmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(statusColor)
                            Text(statusText)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(statusColor)
                            Spacer()
                            if task.isRecurring {
                                Label("Recurring", systemImage: "repeat")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary.opacity(0.6))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.primary.opacity(0.1), in: Capsule())
                            }
                        }

                        // Task name
                        detailRow(icon: "text.alignleft", label: "Task Name") {
                            Text(task.name)
                                .font(theme.font(.body).weight(.medium))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Due date
                        detailRow(icon: "calendar", label: "Due Date") {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.dueDateLabel)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(task.targetDate, format: .dateTime.month(.wide).day().year().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.primary.opacity(0.6))
                            }
                        }

                        // Assigned to
                        if !task.assignedTo.isEmpty {
                            detailRow(icon: "person.fill", label: "Assigned To") {
                                Text(task.assignedTo)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                            }
                        }

                        // Reward
                        if task.reward > 0 {
                            detailRow(icon: "star.circle.fill", label: "Reward") {
                                CoinDisplay(count: Int(task.reward), earned: task.isApproved)
                            }
                        }

                        // Gift
                        if task.hasGift {
                            detailRow(icon: "gift.fill", label: "Surprise Gift") {
                                Text(task.giftRevealed ? task.giftText : "Hidden until approved")
                                    .font(.body)
                                    .foregroundStyle(Color.primary.opacity(task.giftRevealed ? 1 : 0.5))
                                    .italic(!task.giftRevealed)
                            }
                        }

                        // Created by
                        if !task.createdBy.isEmpty {
                            detailRow(icon: "person.badge.plus", label: "Created By") {
                                Text(task.createdBy)
                                    .font(.body)
                                    .foregroundStyle(.primary.opacity(0.8))
                            }
                        }

                        // Actions
                        if canEdit || canDelete {
                            HStack(spacing: 16) {
                                if canEdit {
                                    Button {
                                        onEdit?()
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(calmAccent.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                                            .foregroundStyle(.primary)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .strokeBorder(calmAccent.opacity(0.4), lineWidth: 1)
                                            )
                                    }
                                }

                                if canDelete {
                                    Button {
                                        onDelete?()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(.red.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                                            .foregroundStyle(.red)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .strokeBorder(.red.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func detailRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.5))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.5))
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Wish List View

struct WishListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    @Query(sort: \WishListItem.createdAt) private var allWishListItems: [WishListItem]
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")

    @State private var newItemName = ""
    @State private var editingItem: WishListItem?
    @State private var editText = ""
    @State private var itemToDelete: WishListItem?

    private var myItems: [WishListItem] {
        allWishListItems.filter { $0.ownerAppleUserID == authManager.appleUserID }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        TextField("Add a wish...", text: $newItemName)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.sentences)
                            .onSubmit { addItem() }
                        if !newItemName.isEmpty {
                            Button {
                                addItem()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                    .padding(14)
                    .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.yellow.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                    if myItems.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "star.circle")
                                .font(.system(size: 50))
                                .foregroundStyle(.primary.opacity(0.3))
                            Text("Your wish list is empty")
                                .font(.headline)
                                .foregroundStyle(.primary.opacity(0.5))
                            Text("Add things you'd love to receive!")
                                .font(.subheadline)
                                .foregroundStyle(.primary.opacity(0.3))
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(myItems) { item in
                                HStack(spacing: 12) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(.yellow)

                                    if editingItem?.id == item.id {
                                        TextField("Wish name", text: $editText)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                            .onSubmit { saveEdit(item) }
                                        Button {
                                            saveEdit(item)
                                        } label: {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        }
                                    } else {
                                        Text(item.name)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Button {
                                            editingItem = item
                                            editText = item.name
                                        } label: {
                                            Image(systemName: "pencil")
                                                .font(.caption)
                                                .foregroundStyle(.primary.opacity(0.4))
                                        }
                                    }
                                }
                                .listRowBackground(theme.cardBackground)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteItem(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("My Wish List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    private func addItem() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let item = WishListItem(
            name: trimmed,
            ownerAppleUserID: authManager.appleUserID,
            ownerName: authManager.userName
        )
        modelContext.insert(item)
        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushWishListItem(item, familyCode: familyCode) }
        newItemName = ""
    }

    private func saveEdit(_ item: WishListItem) {
        let trimmed = editText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        item.name = trimmed
        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushWishListItem(item, familyCode: familyCode) }
        editingItem = nil
        editText = ""
    }

    private func deleteItem(_ item: WishListItem) {
        let id = item.id
        let familyCode = authManager.familyCode
        modelContext.delete(item)
        Task { await cloudKitManager.deleteWishListItem(id: id, familyCode: familyCode) }
    }
}

// MARK: - Add Task View (Parent)

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    @Query(sort: \Item.targetDate) private var allTasks: [Item]
    @Query(sort: \WishListItem.createdAt) private var allWishListItems: [WishListItem]
    let children: [FamilyMember]
    var otherParent: FamilyMember? = nil
    var preselectedChild: String = ""
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")

    @State private var taskName = ""
    @State private var targetDate = roundedToNext5Minutes()
    @State private var selectedChildren: Set<String> = []
    @State private var rewardText = ""
    @State private var recurrenceType: RecurrenceType = .none
    @State private var occurrences = 10
    @State private var selectedWeekdays: Set<Int> = []
    @State private var selectedTemplate: TaskTemplate?
    @State private var useSmartScheduler = false
    @State private var smartInput = ""
    @State private var parsedTask: ParsedTask?
    @State private var showQuotaAlert = false
    @State private var giftText = ""
    @State private var includeGift = false
    @State private var transportType = "none"
    @State private var showDictionary = false

    private var isValid: Bool {
        !taskName.trimmingCharacters(in: .whitespaces).isEmpty && !selectedChildren.isEmpty
    }

    private var rewardValue: Double {
        Double(rewardText) ?? 0
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
        rewardText = "\(template.suggestedReward)"
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
        rewardText = "\(entry.suggestedReward)"
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
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
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
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: remaining == 0 ? "xmark.circle.fill" : remaining <= 10 ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                        .foregroundStyle(remaining == 0 ? .red : remaining <= 10 ? .orange : .cyan)
                                    Text(remaining == 0 ? "Task limit reached" : "\(remaining) tasks remaining this month")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.primary.opacity(0.7))
                                    Spacer()
                                    Text(subscriptionManager.tier.displayName)
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.primary.opacity(0.5))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.primary.opacity(0.1), in: Capsule())
                                }

                                if remaining <= 10 {
                                    NavigationLink {
                                        SubscriptionView(theme: theme)
                                    } label: {
                                        HStack {
                                            Image(systemName: "crown.fill")
                                                .font(.caption)
                                            Text(remaining == 0 ? "Upgrade to add more tasks" : "Upgrade for more tasks")
                                                .font(.caption.weight(.semibold))
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption2)
                                        }
                                        .foregroundStyle(.orange)
                                        .padding(10)
                                        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                            .padding(12)
                            .background(
                                (remaining == 0 ? Color.red.opacity(0.1) : remaining <= 10 ? Color.orange.opacity(0.1) : Color.cyan.opacity(0.08)),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder({
                                        if remaining == 0 { return Color.red.opacity(0.2) }
                                        return remaining <= 10 ? Color.orange.opacity(0.2) : Color.cyan.opacity(0.15)
                                    }(),
                                        lineWidth: 1
                                    )
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Task Name")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary.opacity(0.7))
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

                            TextField("What needs to be done?", text: $taskName)
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.primary)
                                .padding(16)
                                .background(.primary.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(taskName.isEmpty ? Color.primary.opacity(0.35) : Color.green.opacity(0.6), lineWidth: 1.5)
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

                        recurrenceSection

                        if authManager.role != "individual" {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reward (coins)")
                                    .font(.caption)
                                    .foregroundStyle(.primary.opacity(0.5))

                                HStack(spacing: 10) {
                                    Image(systemName: "star.circle.fill")
                                        .foregroundStyle(.yellow)

                                    TextField("0", text: $rewardText)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .keyboardType(.decimalPad)
                                }
                                .padding(14)
                                .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                                )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(isOn: $includeGift) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "gift.fill")
                                            .foregroundStyle(.pink)
                                        Text("Add Surprise Gift")
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .tint(.pink)
                                .padding(14)
                                .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                                )

                                if includeGift {
                                    let assigneeWishes = allWishListItems.filter { wish in
                                        selectedChildren.contains(wish.ownerName)
                                    }

                                    if !assigneeWishes.isEmpty {
                                        Text("Pick from wish list")
                                            .font(.caption)
                                            .foregroundStyle(.primary.opacity(0.5))

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(assigneeWishes) { wish in
                                                    Button {
                                                        giftText = wish.name
                                                    } label: {
                                                        HStack(spacing: 6) {
                                                            Image(systemName: "star.fill")
                                                                .font(.system(size: 10))
                                                                .foregroundStyle(.yellow)
                                                            Text(wish.name)
                                                                .font(.caption.weight(.medium))
                                                                .foregroundStyle(giftText == wish.name ? .white : .primary)
                                                        }
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(giftText == wish.name ? .pink : .primary.opacity(0.15), in: Capsule())
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                    }

                                    Text("Or type a custom gift")
                                        .font(.caption)
                                        .foregroundStyle(.primary.opacity(0.5))

                                    TextField("e.g. New shoes, Movie of choice", text: $giftText)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .padding(14)
                                        .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(.pink.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }

                            transportPicker
                        }

                        if authManager.role != "individual" {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Assign To")
                                        .font(.caption)
                                        .foregroundStyle(.primary.opacity(0.5))
                                    Spacer()
                                    if allMemberNames.count > 1 {
                                        Button {
                                            if selectedChildren.count == allMemberNames.count {
                                                selectedChildren = []
                                            } else {
                                                selectedChildren = Set(allMemberNames)
                                            }
                                        } label: {
                                            Text(selectedChildren.count == allMemberNames.count ? "Deselect All" : "Select All")
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(calmAccent)
                                        }
                                    }
                                }

                                VStack(spacing: 8) {
                                    childChip(name: authManager.userName, isSelected: selectedChildren.contains(authManager.userName)) {
                                        toggleMember(authManager.userName)
                                    }

                                    if let parent = otherParent {
                                        childChip(name: parent.name, isSelected: selectedChildren.contains(parent.name)) {
                                            toggleMember(parent.name)
                                        }
                                    }

                                    ForEach(children) { child in
                                        childChip(name: child.name, isSelected: selectedChildren.contains(child.name)) {
                                            toggleMember(child.name)
                                        }
                                    }
                                }
                            }
                        }

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
            .onAppear {
                if selectedChildren.isEmpty {
                    let initial = preselectedChild.isEmpty ? authManager.userName : preselectedChild
                    selectedChildren = [initial]
                }
            }
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
                        var createdTasks: [Item] = []
                        let recurring = recurrenceType != .none
                        let trimmedGift = includeGift ? giftText.trimmingCharacters(in: .whitespaces) : ""
                        for member in selectedChildren {
                            for date in dates {
                                let task = Item(
                                    name: trimmedName,
                                    targetDate: date,
                                    assignedTo: member,
                                    reward: rewardValue,
                                    isRecurring: recurring,
                                    giftText: trimmedGift,
                                    createdBy: authManager.userName,
                                    createdByID: authManager.appleUserID,
                                    transportType: transportType
                                )
                                modelContext.insert(task)
                                createdTasks.append(task)
                                subscriptionManager.recordTaskCreation()
                                notificationManager.scheduleTaskReminder(
                                    taskId: task.id,
                                    taskName: trimmedName,
                                    assignedTo: member,
                                    dueDate: date
                                )
                            }
                        }
                        if transportType != "none" {
                            for member in selectedChildren {
                                notificationManager.sendTransportNotification(
                                    taskName: trimmedName,
                                    assignedTo: member,
                                    transportType: transportType,
                                    dueDate: dates.first ?? targetDate
                                )
                            }
                        }
                        let familyCode = authManager.familyCode
                        Task {
                            for task in createdTasks {
                                await cloudKitManager.pushTask(task, familyCode: familyCode)
                            }
                        }
                        try? modelContext.save()
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
            NavigationLink("Upgrade Plan") {
                SubscriptionView(theme: theme)
            }
            Button("OK", role: .cancel) { }
        } message: {
            if !subscriptionManager.canCreateMoreTasks(allTasks: allTasks) {
                if let limit = subscriptionManager.maxTasksPerMonth {
                    Text("You've used all \(limit) tasks for this month on the \(subscriptionManager.tier.displayName) plan. Upgrade your plan for more tasks, or wait until next month.")
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
                                    .foregroundStyle(selectedTemplate?.name == template.name ? Color.primary : template.color)
                                Text(template.name)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(Color.primary.opacity(selectedTemplate?.name == template.name ? 1 : 0.7))
                                    .lineLimit(1)
                            }
                            .frame(width: 90, height: 70)
                            .background(
                                selectedTemplate?.name == template.name ? template.color.opacity(0.6) : .primary.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        selectedTemplate?.name == template.name ? template.color : .primary.opacity(0.1),
                                        lineWidth: 1
                                    )
                            )
                        }
                    }
                }
            }
        }
    }

    // templatePicker kept for potential future use but no longer shown in the form

    private var recurrenceSection: some View {
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
                                        selectedWeekdays.contains(day) ? calmAccent : .primary.opacity(0.15),
                                        in: Circle()
                                    )
                                    .foregroundStyle(Color.primary.opacity(selectedWeekdays.contains(day) ? 1 : 0.5))
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

    private var transportPicker: some View {
        let iconName: String = {
            switch transportType {
            case "pickup": return "car.fill"
            case "dropoff": return "car.side.fill"
            case "both": return "car.2.fill"
            default: return "car"
            }
        }()
        let label: String = {
            switch transportType {
            case "pickup": return "Pickup Needed"
            case "dropoff": return "Drop-off Needed"
            case "both": return "Pickup & Drop-off"
            default: return "No Transport"
            }
        }()
        let isActive = transportType != "none"

        return Button {
            transportType = Item.nextTransportType(after: transportType)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isActive ? .yellow : .primary.opacity(0.4))
                    .frame(width: 40, height: 40)
                    .background(isActive ? .yellow.opacity(0.2) : .primary.opacity(0.1), in: Circle())
                    .overlay(
                        Circle().strokeBorder(isActive ? .yellow.opacity(0.4) : .primary.opacity(0.15), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("Tap to change")
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.4))
                }

                Spacer()

                if isActive {
                    Button {
                        transportType = "none"
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.primary.opacity(0.3))
                    }
                }
            }
            .padding(14)
            .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isActive ? .yellow.opacity(0.3) : .primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

                TextField("e.g. Study time for Arya tomorrow 5pm 3 coins daily", text: $smartInput, axis: .vertical)
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
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(smartInput.trimmingCharacters(in: .whitespaces).isEmpty ? .primary.opacity(0.1) : calmAccent, in: RoundedRectangle(cornerRadius: 12))
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
                        if authManager.role != "individual" {
                            smartRow(icon: "person.fill", label: "Assign To", value: parsed.assignedTo.isEmpty ? (preselectedChild.isEmpty ? authManager.userName : preselectedChild) : parsed.assignedTo)
                            smartRow(icon: "star.circle.fill", label: "Reward", value: parsed.reward > 0 ? "\(parsed.reward) coins" : "None")
                        }
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
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(parsed.name.isEmpty ? .primary.opacity(0.1) : calmAccent, in: RoundedRectangle(cornerRadius: 12))
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
        let memberNames = children.map { $0.name }
        let parser = SmartTaskParser(familyMembers: memberNames)
        withAnimation { parsedTask = parser.parse(smartInput) }
    }

    private func applyParsedTask(_ parsed: ParsedTask) {
        taskName = parsed.name
        targetDate = parsed.targetDate
        let assignee = parsed.assignedTo.isEmpty ? (preselectedChild.isEmpty ? authManager.userName : preselectedChild) : parsed.assignedTo
        selectedChildren = [assignee]
        rewardText = parsed.reward > 0 ? "\(parsed.reward)" : ""
        recurrenceType = parsed.recurrence

        if !subscriptionManager.canCreateMoreTasks(allTasks: allTasks) || !subscriptionManager.canCreateTask {
            showQuotaAlert = true
            return
        }

        let dates = generateTaskDates()
        let trimmedName = taskName.trimmingCharacters(in: .whitespaces)
        let recurring = recurrenceType != .none

        let trimmedGiftSmart = includeGift ? giftText.trimmingCharacters(in: .whitespaces) : ""
        for date in dates {
            let task = Item(
                name: trimmedName,
                targetDate: date,
                assignedTo: assignee,
                reward: Double(rewardText) ?? 0,
                isRecurring: recurring,
                giftText: trimmedGiftSmart,
                createdBy: authManager.userName,
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

    private var allMemberNames: [String] {
        var names = [authManager.userName]
        if let parent = otherParent {
            names.append(parent.name)
        }
        names.append(contentsOf: children.map(\.name))
        return names
    }

    private func toggleMember(_ name: String) {
        if selectedChildren.contains(name) {
            selectedChildren.remove(name)
        } else {
            selectedChildren.insert(name)
        }
    }

    private func childChip(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? calmAccent : Color.primary.opacity(0.3))
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(12)
            .background(
                isSelected ? calmAccent.opacity(0.15) : Color.primary.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? calmAccent.opacity(0.4) : Color.primary.opacity(0.15),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - Task Dictionary View

struct TaskDictionaryView: View {
    @Environment(\.dismiss) private var dismiss
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    var onSelect: (TaskDictionaryEntry) -> Void
    @State private var searchText = ""
    @State private var expandedCategory: UUID?

    private var filteredCategories: [TaskDictionaryCategory] {
        if searchText.isEmpty { return taskDictionary }
        let query = searchText.lowercased()
        return taskDictionary.compactMap { category in
            let filtered = category.tasks.filter { $0.name.lowercased().contains(query) }
            if filtered.isEmpty { return nil }
            return TaskDictionaryCategory(name: category.name, icon: category.icon, color: category.color, tasks: filtered)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.primary.opacity(0.4))
                            TextField("Search tasks...", text: $searchText)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                        .padding(12)
                        .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        ForEach(filteredCategories) { category in
                            VStack(spacing: 0) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        expandedCategory = expandedCategory == category.id ? nil : category.id
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: category.icon)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(category.color)
                                            .frame(width: 32, height: 32)
                                            .background(category.color.opacity(0.15), in: Circle())
                                        Text(category.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text("\(category.tasks.count)")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.primary.opacity(0.4))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(.primary.opacity(0.08), in: Capsule())
                                        Image(systemName: expandedCategory == category.id ? "chevron.up" : "chevron.down")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.primary.opacity(0.4))
                                    }
                                    .padding(14)
                                }
                                .buttonStyle(.plain)

                                if expandedCategory == category.id || !searchText.isEmpty {
                                    VStack(spacing: 2) {
                                        ForEach(category.tasks) { entry in
                                            Button {
                                                onSelect(entry)
                                                dismiss()
                                            } label: {
                                                HStack(spacing: 12) {
                                                    Text(entry.emoji)
                                                        .font(.title3)
                                                        .frame(width: 36)
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(entry.name)
                                                            .font(.subheadline.weight(.medium))
                                                            .foregroundStyle(.primary)
                                                        HStack(spacing: 6) {
                                                            Text(entry.frequencyLabel)
                                                                .font(.caption2.weight(.semibold))
                                                                .foregroundStyle(frequencyColor(entry.frequencyLabel))
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 2)
                                                                .background(frequencyColor(entry.frequencyLabel).opacity(0.15), in: Capsule())
                                                            HStack(spacing: 2) {
                                                                Image(systemName: "star.fill")
                                                                    .font(.system(size: 9))
                                                                    .foregroundStyle(.yellow)
                                                                Text("\(entry.suggestedReward)")
                                                                    .font(.caption2.weight(.bold))
                                                                    .foregroundStyle(.primary.opacity(0.5))
                                                            }
                                                        }
                                                    }
                                                    Spacer()
                                                    Image(systemName: "plus.circle.fill")
                                                        .font(.system(size: 20))
                                                        .foregroundStyle(calmAccent)
                                                }
                                                .padding(.vertical, 10)
                                                .padding(.horizontal, 14)
                                            }
                                            .buttonStyle(.plain)

                                            if entry.id != category.tasks.last?.id {
                                                Divider().opacity(0.15).padding(.leading, 62)
                                            }
                                        }
                                    }
                                    .padding(.bottom, 8)
                                }
                            }
                            .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                            )
                            .padding(.horizontal, 16)
                        }

                        Spacer().frame(height: 20)
                    }
                }
            }
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .navigationTitle("Task Dictionary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            if !searchText.isEmpty || filteredCategories.count == 1 {
                expandedCategory = filteredCategories.first?.id
            }
        }
    }

    private func frequencyColor(_ label: String) -> Color {
        switch label {
        case "Daily": return .green
        case "Weekly": return .blue
        case "Monthly": return .purple
        case "Quarterly": return .orange
        case "Half-Yearly": return .pink
        case "Annual": return .red
        default: return .gray
        }
    }
}

// MARK: - Edit Task View (Parent)

struct TaskEditRequest: Identifiable {
    let task: Item
    let editAll: Bool
    var id: UUID { task.id }
}

struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    @Query(sort: \Item.targetDate) private var allTasks: [Item]
    @Query(sort: \WishListItem.createdAt) private var allWishListItems: [WishListItem]
    @Bindable var task: Item
    let children: [FamilyMember]
    var otherParent: FamilyMember? = nil
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    var onDelete: (() -> Void)?
    var onMarkMissed: (() -> Void)?
    var canEdit: Bool = true

    @State private var taskName: String
    @State private var targetDate: Date
    @State private var selectedChild: String
    @State private var rewardText: String
    @State private var includeGift: Bool
    @State private var giftText: String
    @State private var transportType: String
    @State private var showDeleteConfirm = false
    @State private var showFrequencyChangeConfirm = false

    @State private var newFrequency: RecurrenceType = .none
    @State private var originalFrequency: RecurrenceType = .none
    @State private var newOccurrences: Int = 4
    @State private var newWeekdays: Set<Int> = []
    @State private var frequencyDetected = false

    private let originalName: String
    private let originalAssignee: String
    @State private var editAll: Bool

    init(task: Item, children: [FamilyMember], otherParent: FamilyMember? = nil, theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default"), editAll: Bool = false, onDelete: (() -> Void)? = nil, onMarkMissed: (() -> Void)? = nil, canEdit: Bool = true) {
        self.task = task
        self.children = children
        self.otherParent = otherParent
        self.theme = theme
        _editAll = State(initialValue: editAll)
        self.onDelete = onDelete
        self.onMarkMissed = onMarkMissed
        self.canEdit = canEdit
        self.originalName = task.name
        self.originalAssignee = task.assignedTo
        _taskName = State(initialValue: task.name)
        _targetDate = State(initialValue: task.targetDate)
        _selectedChild = State(initialValue: task.assignedTo)
        _rewardText = State(initialValue: task.reward > 0 ? String(format: "%.2f", task.reward) : "")
        _includeGift = State(initialValue: !task.giftText.isEmpty)
        _giftText = State(initialValue: task.giftText)
        _transportType = State(initialValue: task.transportType)
    }

    private var isValid: Bool {
        !taskName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var rewardValue: Double {
        Double(rewardText) ?? 0
    }

    private var editStepperMax: Int {
        switch newFrequency {
        case .daily: return 90
        case .weekly: return 52
        case .monthly: return 12
        case .none: return 52
        }
    }

    private var editRecurrenceUnitLabel: String {
        switch newFrequency {
        case .none: return ""
        case .daily: return newOccurrences == 1 ? "day" : "days"
        case .weekly: return newOccurrences == 1 ? "week" : "weeks"
        case .monthly: return newOccurrences == 1 ? "month" : "months"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 20)

                        if task.isRecurring && canEdit {
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "repeat")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(calmAccent)
                                    Text("Recurring Task")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    let count = allTasks.filter {
                                        $0.name == originalName && $0.assignedTo == originalAssignee
                                        && $0.isRecurring && !$0.isArchived
                                    }.count
                                    Text("\(count) instance\(count == 1 ? "" : "s")")
                                        .font(.caption2)
                                        .foregroundStyle(.primary.opacity(0.5))
                                }

                                Picker("Edit scope", selection: $editAll) {
                                    Text("This Task Only").tag(false)
                                    Text("All in Series").tag(true)
                                }
                                .pickerStyle(.segmented)

                                if editAll && frequencyDetected {
                                    Divider().opacity(0.3)

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Change Frequency")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.primary.opacity(0.7))

                                        Picker("Frequency", selection: $newFrequency) {
                                            Text("Daily").tag(RecurrenceType.daily)
                                            Text("Weekly").tag(RecurrenceType.weekly)
                                            Text("Monthly").tag(RecurrenceType.monthly)
                                        }
                                        .pickerStyle(.segmented)
                                        .onChange(of: newFrequency) { _, newValue in
                                            switch newValue {
                                            case .daily: newOccurrences = 10
                                            case .weekly:
                                                newOccurrences = 4
                                                if newWeekdays.isEmpty {
                                                    let weekday = Calendar.current.component(.weekday, from: targetDate)
                                                    newWeekdays.insert(weekday)
                                                }
                                            case .monthly: newOccurrences = 4
                                            case .none: break
                                            }
                                        }

                                        if newFrequency != originalFrequency {
                                            if newFrequency == .weekly {
                                                HStack(spacing: 8) {
                                                    ForEach(1...7, id: \.self) { day in
                                                        Button {
                                                            if newWeekdays.contains(day) {
                                                                if newWeekdays.count > 1 {
                                                                    newWeekdays.remove(day)
                                                                }
                                                            } else {
                                                                newWeekdays.insert(day)
                                                            }
                                                        } label: {
                                                            Text(weekdayLabels[day - 1])
                                                                .font(.caption.weight(.bold))
                                                                .frame(width: 32, height: 32)
                                                                .background(
                                                                    newWeekdays.contains(day) ? calmAccent : .primary.opacity(0.15),
                                                                    in: Circle()
                                                                )
                                                                .foregroundStyle(Color.primary.opacity(newWeekdays.contains(day) ? 1 : 0.5))
                                                        }
                                                    }
                                                }
                                                .frame(maxWidth: .infinity)
                                            }

                                            Stepper(value: $newOccurrences, in: 2...editStepperMax) {
                                                HStack {
                                                    Text("Repeat for")
                                                        .foregroundStyle(.primary)
                                                    Spacer()
                                                    Text("\(newOccurrences) \(editRecurrenceUnitLabel)")
                                                        .foregroundStyle(.primary.opacity(0.7))
                                                }
                                                .font(.caption)
                                            }
                                            .tint(.primary)

                                            HStack(spacing: 6) {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.orange)
                                                Text("This will delete the current series and create a new one.")
                                                    .font(.caption2)
                                                    .foregroundStyle(.orange)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(calmAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(calmAccent.opacity(0.3), lineWidth: 1)
                            )
                            .onAppear {
                                guard !frequencyDetected else { return }
                                let siblings = allTasks.filter {
                                    $0.name == originalName && $0.assignedTo == originalAssignee
                                    && $0.isRecurring && !$0.isArchived
                                }
                                let sortedDates = siblings.map(\.targetDate).sorted()
                                let detected: RecurrenceType
                                if sortedDates.count >= 2 {
                                    let calendar = Calendar.current
                                    let intervals = zip(sortedDates, sortedDates.dropFirst()).map {
                                        calendar.dateComponents([.day], from: $0.0, to: $0.1).day ?? 0
                                    }
                                    let avgInterval = intervals.reduce(0, +) / max(intervals.count, 1)
                                    if avgInterval <= 1 { detected = .daily }
                                    else if avgInterval <= 10 { detected = .weekly }
                                    else { detected = .monthly }
                                } else {
                                    detected = .daily
                                }
                                originalFrequency = detected
                                newFrequency = detected
                                let weekdays = Set(siblings.map { Calendar.current.component(.weekday, from: $0.targetDate) })
                                newWeekdays = weekdays
                                frequencyDetected = true
                            }
                        } else if task.isRecurring {
                            HStack(spacing: 8) {
                                Image(systemName: "repeat")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(calmAccent)
                                Text("Recurring Task")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(12)
                            .background(calmAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(calmAccent.opacity(0.3), lineWidth: 1)
                            )
                        }

                        if !canEdit {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.primary.opacity(0.5))
                                Text("This task was created by a parent. You can view details but not edit.")
                                    .font(.caption)
                                    .foregroundStyle(.primary.opacity(0.5))
                            }
                            .padding(12)
                            .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Task Name")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary.opacity(0.7))

                            TextField("What needs to be done?", text: $taskName)
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.primary)
                                .padding(16)
                                .background(.primary.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(taskName.isEmpty ? Color.primary.opacity(0.35) : Color.green.opacity(0.6), lineWidth: 1.5)
                                )
                                .disabled(!canEdit)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Due Date")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.5))

                            FiveMinuteDatePicker(selection: $targetDate)
                            .frame(height: 44)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.primary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.primary.opacity(0.2), lineWidth: 1)
                            )
                            .disabled(!canEdit)
                        }

                        if authManager.role != "individual" {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reward (coins)")
                                    .font(.caption)
                                    .foregroundStyle(.primary.opacity(0.5))

                                HStack(spacing: 10) {
                                    Image(systemName: "star.circle.fill")
                                        .foregroundStyle(.yellow)

                                    TextField("0", text: $rewardText)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .keyboardType(.decimalPad)
                                        .disabled(!canEdit)
                                }
                                .padding(14)
                                .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                                )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(isOn: $includeGift) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "gift.fill")
                                            .foregroundStyle(.pink)
                                        Text("Surprise Gift")
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .tint(.pink)
                                .padding(14)
                                .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                                )
                                .disabled(!canEdit)

                                if includeGift {
                                    let assigneeWishes = allWishListItems.filter { $0.ownerName == selectedChild }

                                    if !assigneeWishes.isEmpty {
                                        Text("Pick from wish list")
                                            .font(.caption)
                                            .foregroundStyle(.primary.opacity(0.5))

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(assigneeWishes) { wish in
                                                    Button {
                                                        giftText = wish.name
                                                    } label: {
                                                        HStack(spacing: 6) {
                                                            Image(systemName: "star.fill")
                                                                .font(.system(size: 10))
                                                                .foregroundStyle(.yellow)
                                                            Text(wish.name)
                                                                .font(.caption.weight(.medium))
                                                                .foregroundStyle(giftText == wish.name ? .white : .primary)
                                                        }
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(giftText == wish.name ? .pink : .primary.opacity(0.15), in: Capsule())
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                    }

                                    Text("Or type a custom gift")
                                        .font(.caption)
                                        .foregroundStyle(.primary.opacity(0.5))

                                    TextField("e.g. New shoes, Movie of choice", text: $giftText)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .padding(14)
                                        .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(.pink.opacity(0.3), lineWidth: 1)
                                        )
                                        .disabled(!canEdit)
                                }
                            }

                            editTransportPicker

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Assign To")
                                    .font(.caption)
                                    .foregroundStyle(.primary.opacity(0.5))

                                VStack(spacing: 8) {
                                    editChildChip(name: authManager.userName, isSelected: selectedChild == authManager.userName || selectedChild.isEmpty) {
                                        selectedChild = authManager.userName
                                    }

                                    if let parent = otherParent {
                                        editChildChip(name: parent.name, isSelected: selectedChild == parent.name) {
                                            selectedChild = parent.name
                                        }
                                    }

                                    ForEach(children) { child in
                                        editChildChip(name: child.name, isSelected: selectedChild == child.name) {
                                            selectedChild = child.name
                                        }
                                    }
                                }
                            }
                            .disabled(!canEdit)
                        }

                        if task.isOpen && task.isPastDue, let onMarkMissed {
                            Button {
                                onMarkMissed()
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 16))
                                    Text("Mark as Missed")
                                        .font(.body.weight(.semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.red, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }

                        if let onDelete {
                            Button {
                                showDeleteConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 14))
                                    Text("Delete Task")
                                        .font(.body.weight(.semibold))
                                }
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(.red.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .alert("Delete Task?", isPresented: $showDeleteConfirm) {
                                Button("Delete", role: .destructive) {
                                    onDelete()
                                    dismiss()
                                }
                                Button("Cancel", role: .cancel) { }
                            } message: {
                                Text("This action cannot be undone.")
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
            }
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .navigationTitle(canEdit ? "Edit Task" : "Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(canEdit ? "Cancel" : "Done") { dismiss() }
                }
                if canEdit {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if editAll && newFrequency != originalFrequency {
                                showFrequencyChangeConfirm = true
                            } else if editAll {
                                saveAllRecurring()
                            } else {
                                saveSingleTask()
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                    }
                }
            }
            .alert("Change Frequency?", isPresented: $showFrequencyChangeConfirm) {
                Button("Change", role: .destructive) {
                    saveWithNewFrequency()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will delete all tasks in the current series and create a new \(newFrequency.rawValue.lowercased()) series with \(newOccurrences) occurrences starting from the selected date.")
            }
        }
        .presentationDetents([.large])
    }

    private func saveSingleTask() {
        let trimmedName = taskName.trimmingCharacters(in: .whitespaces)
        let trimmedGift = includeGift ? giftText.trimmingCharacters(in: .whitespaces) : ""
        task.name = trimmedName
        task.targetDate = targetDate
        task.assignedTo = selectedChild
        task.reward = rewardValue
        task.giftText = trimmedGift
        task.transportType = transportType
        notificationManager.cancelTaskReminder(taskId: task.id)
        notificationManager.scheduleTaskReminder(
            taskId: task.id,
            taskName: trimmedName,
            assignedTo: selectedChild,
            dueDate: targetDate
        )
        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
        try? modelContext.save()
        dismiss()
    }

    private func saveAllRecurring() {
        let trimmedName = taskName.trimmingCharacters(in: .whitespaces)
        let trimmedGift = includeGift ? giftText.trimmingCharacters(in: .whitespaces) : ""
        let familyCode = authManager.familyCode
        let calendar = Calendar.current
        let newTimeComponents = calendar.dateComponents([.hour, .minute], from: targetDate)
        let siblings = allTasks.filter {
            $0.name == originalName && $0.assignedTo == originalAssignee
            && $0.isRecurring && !$0.isArchived
        }
        for sibling in siblings {
            sibling.name = trimmedName
            sibling.assignedTo = selectedChild
            sibling.reward = rewardValue
            sibling.giftText = trimmedGift
            sibling.transportType = transportType
            var siblingDateComponents = calendar.dateComponents([.year, .month, .day], from: sibling.targetDate)
            siblingDateComponents.hour = newTimeComponents.hour
            siblingDateComponents.minute = newTimeComponents.minute
            if let updatedDate = calendar.date(from: siblingDateComponents) {
                sibling.targetDate = updatedDate
            }
            notificationManager.cancelTaskReminder(taskId: sibling.id)
            if sibling.isOpen {
                notificationManager.scheduleTaskReminder(
                    taskId: sibling.id,
                    taskName: trimmedName,
                    assignedTo: selectedChild,
                    dueDate: sibling.targetDate
                )
            }
        }
        try? modelContext.save()
        let snapshots = siblings.map { CloudKitManager.TaskSnapshot($0) }
        Task {
            for snap in snapshots {
                await cloudKitManager.pushTaskSnapshot(snap, familyCode: familyCode)
            }
        }
        dismiss()
    }

    private func saveWithNewFrequency() {
        let trimmedName = taskName.trimmingCharacters(in: .whitespaces)
        let trimmedGift = includeGift ? giftText.trimmingCharacters(in: .whitespaces) : ""
        let familyCode = authManager.familyCode
        let calendar = Calendar.current

        let siblings = allTasks.filter {
            $0.name == originalName && $0.assignedTo == originalAssignee
            && $0.isRecurring && !$0.isArchived
        }
        for sibling in siblings {
            notificationManager.cancelTaskReminder(taskId: sibling.id)
            modelContext.delete(sibling)
        }
        try? modelContext.save()

        let dates = generateEditTaskDates(calendar: calendar)
        var createdTasks: [Item] = []
        for date in dates {
            let newTask = Item(
                name: trimmedName,
                targetDate: date,
                assignedTo: selectedChild,
                reward: rewardValue,
                isRecurring: true,
                giftText: trimmedGift,
                createdBy: authManager.userName,
                createdByID: authManager.appleUserID,
                transportType: transportType
            )
            modelContext.insert(newTask)
            createdTasks.append(newTask)
            notificationManager.scheduleTaskReminder(
                taskId: newTask.id,
                taskName: trimmedName,
                assignedTo: selectedChild,
                dueDate: date
            )
        }
        try? modelContext.save()

        Task {
            for created in createdTasks {
                await cloudKitManager.pushTask(created, familyCode: familyCode)
            }
        }
        dismiss()
    }

    private func generateEditTaskDates(calendar: Calendar) -> [Date] {
        switch newFrequency {
        case .none:
            return [targetDate]
        case .daily:
            return (0..<newOccurrences).compactMap { i in
                calendar.date(byAdding: .day, value: i, to: targetDate)
            }
        case .weekly:
            guard !newWeekdays.isEmpty else { return [targetDate] }
            var dates: [Date] = []
            let timeComponents = calendar.dateComponents([.hour, .minute], from: targetDate)
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: targetDate)?.start ?? targetDate
            for week in 0..<newOccurrences {
                guard let weekBase = calendar.date(byAdding: .weekOfYear, value: week, to: weekStart) else { continue }
                let baseWeekday = calendar.component(.weekday, from: weekBase)
                for day in newWeekdays.sorted() {
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
            return (0..<newOccurrences).compactMap { i in
                calendar.date(byAdding: .month, value: i, to: targetDate)
            }
        }
    }

    private func editChildChip(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? calmAccent : Color.primary.opacity(0.3))
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(12)
            .background(
                isSelected ? calmAccent.opacity(0.15) : Color.primary.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? calmAccent.opacity(0.4) : Color.primary.opacity(0.15),
                        lineWidth: 1
                    )
            )
        }
    }

    private var editTransportPicker: some View {
        let iconName: String = {
            switch transportType {
            case "pickup": return "car.fill"
            case "dropoff": return "car.side.fill"
            case "both": return "car.2.fill"
            default: return "car"
            }
        }()
        let label: String = {
            switch transportType {
            case "pickup": return "Pickup Needed"
            case "dropoff": return "Drop-off Needed"
            case "both": return "Pickup & Drop-off"
            default: return "No Transport"
            }
        }()
        let isActive = transportType != "none"

        return Button {
            transportType = Item.nextTransportType(after: transportType)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isActive ? .yellow : .primary.opacity(0.4))
                    .frame(width: 40, height: 40)
                    .background(isActive ? .yellow.opacity(0.2) : .primary.opacity(0.1), in: Circle())
                    .overlay(
                        Circle().strokeBorder(isActive ? .yellow.opacity(0.4) : .primary.opacity(0.15), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("Tap to change")
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.4))
                }

                Spacer()

                if isActive {
                    Button {
                        transportType = "none"
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.primary.opacity(0.3))
                    }
                }
            }
            .padding(14)
            .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isActive ? .yellow.opacity(0.3) : .primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canEdit)
    }
}

// MARK: - Children Management View

struct ChildrenManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Query private var allMembers: [FamilyMember]
    @Query(sort: \Item.targetDate) private var allTasks: [Item]
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    @State private var memberToRemove: FamilyMember?

    private var parents: [FamilyMember] {
        var seen = Set<String>()
        return allMembers
            .filter { $0.isParent }
            .sorted { !$0.appleUserID.isEmpty && $1.appleUserID.isEmpty }
            .filter { seen.insert($0.name).inserted }
    }
    private var children: [FamilyMember] {
        var seen = Set<String>()
        return allMembers
            .filter { $0.isChild && $0.isAccepted }
            .sorted { !$0.appleUserID.isEmpty && $1.appleUserID.isEmpty }
            .filter { seen.insert($0.name).inserted }
    }
    private var pendingMembers: [FamilyMember] {
        allMembers.filter { $0.isChild && !$0.isAccepted }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        inviteCodeSection

                        if !pendingMembers.isEmpty {
                            pendingRequestsSection
                        }

                        if !parents.isEmpty {
                            memberSection(title: "Parents (\(parents.count)/2)", members: parents, canRemove: false)
                        }

                        memberSection(title: "Children (\(children.count)/\(subscriptionManager.maxMembers))", members: children, canRemove: true)

                        if !subscriptionManager.canAddMember(currentCount: allMembers.count) {
                            memberLimitUpgrade
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
            }
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .navigationTitle("My Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Remove Member", isPresented: Binding(
                get: { memberToRemove != nil },
                set: { if !$0 { memberToRemove = nil } }
            )) {
                Button("Cancel", role: .cancel) { memberToRemove = nil }
                Button("Remove", role: .destructive) {
                    if let member = memberToRemove {
                        let memberID = member.id
                        modelContext.delete(member)
                        Task { await cloudKitManager.deleteRemoteMember(memberID) }
                        memberToRemove = nil
                    }
                }
            } message: {
                if let member = memberToRemove {
                    Text("Remove \(member.name) from your family?")
                }
            }
        }
    }

    private var inviteCodeSection: some View {
        VStack(spacing: 12) {
            Text("Family Invite Code")
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.5))

            Text(authManager.familyCode)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .tracking(6)

            Text("New members can use this code to join your family")
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.35))

            ShareLink(
                item: "Join my family on Taskoot! Use invite code: \(authManager.familyCode)"
            ) {
                Label("Share Invite", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(calmAccent, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private var pendingRequestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "person.badge.clock.fill")
                    .foregroundStyle(.orange)
                Text("Pending Requests")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            ForEach(pendingMembers) { member in
                HStack {
                    AvatarView(avatarId: member.avatar, size: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.name)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("Wants to join your family")
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.5))
                    }

                    Spacer()

                    Button {
                        let memberID = member.id
                        modelContext.delete(member)
                        Task { await cloudKitManager.deleteRemoteMember(memberID) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red.opacity(0.7))
                    }

                    Button {
                        member.isAccepted = true
                        let familyCode = authManager.familyCode
                        Task {
                            await cloudKitManager.pushMember(member, familyCode: familyCode)
                        }
                    } label: {
                        Text("Accept")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(theme.accentColor, in: Capsule())
                    }
                }
                .padding(14)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    private func memberSection(title: String, members: [FamilyMember], canRemove: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.5))

            if members.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.primary.opacity(0.25))
                        Text("No members yet")
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.35))
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                ForEach(members) { member in
                    HStack {
                        AvatarView(avatarId: member.avatar, size: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(.body)
                                .foregroundStyle(.primary)

                            if member.isChild {
                                let earned = allTasks.filter { $0.assignedTo == member.name && $0.isApproved && $0.reward > 0 }.reduce(0) { $0 + Int($1.reward) }
                                Text("Earned: \(earned) coins")
                                    .font(.caption)
                                    .foregroundStyle(.yellow.opacity(0.8))
                            } else {
                                Text("Parent")
                                    .font(.caption)
                                    .foregroundStyle(.primary.opacity(0.4))
                            }
                        }

                        Spacer()

                        if canRemove {
                            Button {
                                memberToRemove = member
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.primary.opacity(0.3))
                            }
                        }
                    }
                    .padding(14)
                    .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
                    )
                }
            }
        }
    }

    private var memberLimitUpgrade: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.exclamationmark.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Member limit reached")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Your \(subscriptionManager.tier.displayName) plan allows up to \(subscriptionManager.maxMembers) members.")
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.7))
                }

                Spacer()
            }

            NavigationLink {
                SubscriptionView(theme: theme)
            } label: {
                HStack {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                    Text("Upgrade to add more members")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundStyle(.primary)
                .padding(12)
                .background(.orange, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.orange.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Pending Approvals View

struct PendingApprovalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    @Query(filter: #Predicate<Item> { $0.status == "inReview" }, sort: \Item.targetDate)
    private var pendingTasks: [Item]
    @Query(sort: \Item.targetDate) private var allTasks: [Item]
    @Query private var children: [FamilyMember]
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    var onApproved: ((Double) -> Void)?
    @State private var taskToApprove: Item?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                if pendingTasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 56))
                            .foregroundStyle(.primary.opacity(0.3))
                        Text("All caught up!")
                            .font(.title3)
                            .foregroundStyle(.primary.opacity(0.7))
                        Text("No tasks pending approval.")
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(pendingTasks) { task in
                                approvalRow(task: task)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("Pending Approvals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Approve Task?", isPresented: Binding(
                get: { taskToApprove != nil },
                set: { if !$0 { taskToApprove = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    taskToApprove = nil
                }
                Button("Approve") {
                    if let task = taskToApprove {
                        withAnimation(.snappy) {
                            task.status = "approved"
                        }
                        let snapshot = CloudKitManager.TaskSnapshot(task)
                        if task.reward > 0 && !task.assignedTo.isEmpty {
                            if let child = children.first(where: { $0.name == task.assignedTo }) {
                                child.addReward(task.reward)
                                let familyCode = authManager.familyCode
                                Task { await cloudKitManager.pushMember(child, familyCode: familyCode) }
                            }
                        }
                        try? modelContext.save()
                        withAnimation(.snappy) {
                            onApproved?(task.reward)
                        }
                        let familyCode = authManager.familyCode
                        Task {
                            await cloudKitManager.pushTaskSnapshot(snapshot, familyCode: familyCode)
                        }
                        if !task.assignedTo.isEmpty {
                            notificationManager.sendTaskApprovedNotification(
                                taskName: task.name,
                                childName: task.assignedTo,
                                reward: task.reward
                            )
                        }
                        SoundManager.shared.playApplause()
                    }
                    taskToApprove = nil
                }
            } message: {
                if let task = taskToApprove {
                    Text("Approve \"\(task.name)\"? This cannot be undone.")
                }
            }
        }
    }

    private func approvalRow(task: Item) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let member = children.first(where: { $0.name == task.assignedTo }) {
                    AvatarView(avatarId: member.avatar, size: 40)
                } else {
                    Image(systemName: "clock.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: 40, height: 40)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(.white)

                    HStack(spacing: 6) {
                        if !task.assignedTo.isEmpty {
                            Text(task.assignedTo)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.85))
                        }

                        Text(task.dueDateLabel)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))

                        if task.reward > 0 {
                            Text("•")
                                .foregroundStyle(.white.opacity(0.3))
                            Label("\(Int(task.reward)) coins", systemImage: "star.circle.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.yellow.opacity(0.85))
                        }
                    }
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    task.status = "open"
                    let snapshot = CloudKitManager.TaskSnapshot(task)
                    let familyCode = authManager.familyCode
                    Task {
                        await cloudKitManager.pushTaskSnapshot(snapshot, familyCode: familyCode)
                    }
                    if !task.assignedTo.isEmpty {
                        notificationManager.sendTaskRejectedNotification(
                            taskName: task.name,
                            childName: task.assignedTo
                        )
                    }
                } label: {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Reject")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.red.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.red)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.red.opacity(0.3), lineWidth: 1)
                    )
                }

                Button {
                    taskToApprove = task
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Approve")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.green)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.green.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.orange.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Parent Onboarding View

struct ParentOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Query private var allMembers: [FamilyMember]
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    var onComplete: () -> Void

    private var children: [FamilyMember] {
        var seen = Set<String>()
        return allMembers
            .filter { $0.isChild }
            .sorted { !$0.appleUserID.isEmpty && $1.appleUserID.isEmpty }
            .filter { seen.insert($0.name).inserted }
    }

    @State private var newChildName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 20)

                        VStack(spacing: 12) {
                            Image(systemName: "party.popper.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(.yellow)

                            Text("You're all set, \(authManager.userName)!")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)

                            Text("Share the invite code below with your family members so they can join. You can also add children here to get started right away!")
                                .font(.subheadline)
                                .foregroundStyle(.primary.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }

                        inviteCodeCard

                        if !children.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Children (\(children.count)/\(subscriptionManager.maxMembers))")
                                    .font(.caption)
                                    .foregroundStyle(.primary.opacity(0.5))

                                ForEach(children) { child in
                                    HStack {
                                        AvatarView(avatarId: child.avatar, size: 36)

                                        Text(child.name)
                                            .font(.body)
                                            .foregroundStyle(.primary)

                                        Spacer()
                                    }
                                    .padding(14)
                                    .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
                                    )
                                }
                            }
                        }

                        if subscriptionManager.canAddMember(currentCount: allMembers.count) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Add Child")
                                    .font(.caption)
                                    .foregroundStyle(.primary.opacity(0.5))

                                HStack(spacing: 10) {
                                    TextField("Child's name", text: $newChildName)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .padding(12)
                                        .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                                        )

                                    Button {
                                        let child = FamilyMember(name: newChildName.trimmingCharacters(in: .whitespaces))
                                        modelContext.insert(child)
                                        let familyCode = authManager.familyCode
                                        Task { await cloudKitManager.pushMember(child, familyCode: familyCode) }
                                        newChildName = ""
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(calmAccent)
                                    }
                                    .disabled(newChildName.trimmingCharacters(in: .whitespaces).isEmpty || !subscriptionManager.canAddMember(currentCount: allMembers.count))
                                }
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.orange)
                                Text("Upgrade your plan to add more members")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary.opacity(0.8))
                            }
                            .padding(12)
                            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(.orange.opacity(0.2), lineWidth: 1)
                            )
                        }

                        Spacer().frame(height: 10)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .navigationTitle("Welcome!")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onComplete()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var inviteCodeCard: some View {
        VStack(spacing: 12) {
            Text("Your Family Invite Code")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.5))

            Text(authManager.familyCode)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .tracking(6)

            Text("Send this code to your children and other family members so they can join from their own device")
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.35))
                .multilineTextAlignment(.center)

            ShareLink(
                item: "Join my family on Taskoot! Use invite code: \(authManager.familyCode)"
            ) {
                Label("Share Invite", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(calmAccent, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Weekly Pulse View

struct WeeklyPulseView: View {
    @Environment(\.dismiss) private var dismiss
    let allTasks: [Item]
    let allMembers: [FamilyMember]
    let currentUserName: String
    let isIndividual: Bool
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    var embedded: Bool = false

    private let calendar = Calendar.current
    private let today = Calendar.current.startOfDay(for: Date())

    private var startOfPastWeek: Date {
        calendar.date(byAdding: .day, value: -7, to: today)!
    }

    private var endOfUpcomingWeek: Date {
        calendar.date(byAdding: .day, value: 7, to: today)!
    }

    private var pastWeekTasks: [Item] {
        allTasks.filter {
            let d = calendar.startOfDay(for: $0.targetDate)
            return d >= startOfPastWeek && d < today
        }
    }

    private var upcomingWeekTasks: [Item] {
        allTasks.filter {
            let d = calendar.startOfDay(for: $0.targetDate)
            return d >= today && d < endOfUpcomingWeek
        }
    }

    private var pastCompleted: Int { pastWeekTasks.filter { $0.isApproved }.count }
    private var pastMissed: Int { pastWeekTasks.filter { $0.isMissed }.count }
    private var pastCancelled: Int { pastWeekTasks.filter { $0.isCancelled }.count }
    private var pastTotal: Int { pastWeekTasks.count }
    private var completionRate: Double {
        guard pastTotal > 0 else { return 0 }
        return Double(pastCompleted) / Double(pastTotal)
    }
    private var pastCoinsEarned: Int {
        pastWeekTasks.filter { $0.isApproved && $0.reward > 0 }.reduce(0) { $0 + Int($1.reward) }
    }

    private var bestDay: (name: String, count: Int)? {
        let days = (-7 ..< 0).map { calendar.date(byAdding: .day, value: $0, to: today)! }
        let best = days.map { day -> (String, Int) in
            let dayStart = calendar.startOfDay(for: day)
            let count = pastWeekTasks.filter {
                calendar.startOfDay(for: $0.targetDate) == dayStart && $0.isApproved
            }.count
            let name = day.formatted(.dateTime.weekday(.abbreviated))
            return (name, count)
        }.max { $0.1 < $1.1 }
        guard let best, best.1 > 0 else { return nil }
        return best
    }

    private var mvp: (name: String, count: Int)? {
        guard !isIndividual else { return nil }
        let members = Set(pastWeekTasks.map { $0.assignedTo }).filter { !$0.isEmpty }
        let scores = members.map { name -> (String, Int) in
            let count = pastWeekTasks.filter { $0.assignedTo == name && $0.isApproved }.count
            return (name, count)
        }
        guard let top = scores.max(by: { $0.1 < $1.1 }), top.1 > 0 else { return nil }
        return top
    }

    private func upcomingDays() -> [(date: Date, label: String, shortLabel: String, tasks: [Item])] {
        (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            let dayStart = calendar.startOfDay(for: date)
            let dayTasks = upcomingWeekTasks.filter { calendar.startOfDay(for: $0.targetDate) == dayStart }
            let label = offset == 0 ? "Today" : date.formatted(.dateTime.weekday(.wide))
            let shortLabel = offset == 0 ? "Today" : date.formatted(.dateTime.weekday(.abbreviated))
            return (date, label, shortLabel, dayTasks)
        }
    }

    private func loadLevel(_ count: Int) -> (label: String, color: Color) {
        switch count {
        case 0: return ("Free", .gray)
        case 1...3: return ("Light", .green)
        case 4...6: return ("Moderate", .yellow)
        default: return ("Heavy", .red)
        }
    }

    private func generateInsights() -> [(icon: String, text: String, color: Color)] {
        var insights: [(String, String, Color)] = []
        let days = upcomingDays()

        for day in days {
            if day.tasks.count >= 6 {
                insights.append(("flame.fill", "\(day.label) looks packed — \(day.tasks.count) tasks scheduled.", .red))
            }
        }

        for day in days {
            let sorted = day.tasks.sorted { $0.targetDate < $1.targetDate }
            for i in 0..<sorted.count {
                for j in (i+1)..<sorted.count {
                    let gap = sorted[j].targetDate.timeIntervalSince(sorted[i].targetDate)
                    if gap >= 0 && gap < 30 * 60 {
                        insights.append(("clock.badge.exclamationmark.fill",
                            "\(day.label): \"\(sorted[i].name)\" and \"\(sorted[j].name)\" are within 30 min of each other.",
                            .orange))
                        break
                    }
                }
                if insights.count > 6 { break }
            }
        }

        if !isIndividual {
            let members = Set(upcomingWeekTasks.compactMap { $0.assignedTo.isEmpty ? nil : $0.assignedTo })
            if members.count >= 2 {
                let counts = members.map { name in (name, upcomingWeekTasks.filter { $0.assignedTo == name }.count) }
                if let most = counts.max(by: { $0.1 < $1.1 }),
                   let least = counts.min(by: { $0.1 < $1.1 }),
                   most.1 > 0 && least.1 >= 0 && most.1 >= least.1 * 2 && most.1 - least.1 >= 4 {
                    insights.append(("scale.3d", "\(most.0) has \(most.1) tasks vs \(least.0)'s \(least.1) — consider rebalancing.", .blue))
                }
            }
        }

        if !isIndividual {
            let members = Set(pastWeekTasks.compactMap { $0.assignedTo.isEmpty ? nil : $0.assignedTo })
            for name in members {
                let pastMissedCount = pastWeekTasks.filter { $0.assignedTo == name && $0.isMissed }.count
                let upcomingCount = upcomingWeekTasks.filter { $0.assignedTo == name }.count
                if pastMissedCount >= 3 && upcomingCount >= 5 {
                    insights.append(("exclamationmark.triangle.fill",
                        "\(name) missed \(pastMissedCount) last week and has \(upcomingCount) due ahead — may need support.",
                        .red))
                }
            }
            for name in members {
                let pastDone = pastWeekTasks.filter { $0.assignedTo == name && $0.isApproved }.count
                let pastPersonTotal = pastWeekTasks.filter { $0.assignedTo == name }.count
                let upcomingCount = upcomingWeekTasks.filter { $0.assignedTo == name }.count
                if pastPersonTotal >= 3 && pastDone == pastPersonTotal && upcomingCount > 0 {
                    insights.append(("flame.fill", "\(name) had a perfect week! \(upcomingCount) tasks lined up to keep the streak.", .green))
                }
            }
        } else {
            if pastTotal >= 3 && pastCompleted == pastTotal {
                let upcomingCount = upcomingWeekTasks.count
                if upcomingCount > 0 {
                    insights.append(("flame.fill", "Perfect week! \(upcomingCount) tasks lined up to keep the streak.", .green))
                }
            } else if pastMissed >= 3 {
                let upcomingCount = upcomingWeekTasks.count
                if upcomingCount >= 5 {
                    insights.append(("exclamationmark.triangle.fill",
                        "You missed \(pastMissed) tasks last week and have \(upcomingCount) ahead — plan carefully.",
                        .orange))
                }
            }
        }

        let emptyDays = days.filter { $0.tasks.isEmpty && $0.date != today }
        if !emptyDays.isEmpty && emptyDays.count <= 3 {
            let names = emptyDays.map { $0.shortLabel }.joined(separator: ", ")
            insights.append(("sun.max.fill", "\(names) \(emptyDays.count == 1 ? "is" : "are") free — enjoy the break or plan something.", .cyan))
        }

        let expiringRecurring = upcomingWeekTasks.filter { $0.isRecurring }.map { $0.name }
        let uniqueExpiring = Set(expiringRecurring)
        if uniqueExpiring.count > 0 {
            let lastDates = uniqueExpiring.compactMap { name -> (String, Date)? in
                let latest = allTasks.filter { $0.name == name && $0.isRecurring }.max(by: { $0.targetDate < $1.targetDate })
                guard let latest, latest.targetDate < endOfUpcomingWeek else { return nil }
                return (name, latest.targetDate)
            }
            if !lastDates.isEmpty {
                insights.append(("repeat", "\(lastDates.count) recurring task\(lastDates.count == 1 ? "" : "s") ending this week — extend or let them expire.", .purple))
            }
        }

        if insights.isEmpty && upcomingWeekTasks.isEmpty {
            insights.append(("tray.fill", "No tasks scheduled this week — time to plan ahead!", .gray))
        } else if insights.isEmpty {
            insights.append(("checkmark.seal.fill", "Week looks well balanced — you're all set!", .green))
        }

        return insights
    }

    var body: some View {
        if embedded {
            pulseScrollContent
        } else {
            NavigationStack {
                ZStack {
                    AppBackground()
                    pulseScrollContent
                }
                .navigationTitle("Weekly Pulse")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private var pulseScrollContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                pastWeekSection
                upcomingHeatmap
                insightsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var pastWeekSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(.white.opacity(0.6))
                Text("Past 7 Days")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
            }

            HStack(spacing: 0) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    Circle()
                        .trim(from: 0, to: completionRate)
                        .stroke(completionRate >= 0.8 ? .green : completionRate >= 0.5 ? .yellow : .red, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(completionRate * 100))%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.trailing, 20)

                VStack(alignment: .leading, spacing: 8) {
                    statRow(icon: "checkmark.circle.fill", label: "Completed", value: "\(pastCompleted)", color: .green)
                    statRow(icon: "xmark.circle.fill", label: "Missed", value: "\(pastMissed)", color: .red)
                    statRow(icon: "minus.circle.fill", label: "Cancelled", value: "\(pastCancelled)", color: .gray)
                    if !isIndividual && pastCoinsEarned > 0 {
                        statRow(icon: "star.circle.fill", label: "Coins earned", value: "\(pastCoinsEarned)", color: .yellow)
                    }
                }
                Spacer()
            }

            HStack(spacing: 16) {
                if let best = bestDay {
                    infoChip(icon: "trophy.fill", text: "Best: \(best.name) (\(best.count))", color: .yellow)
                }
                if let mvp = mvp {
                    infoChip(icon: "star.fill", text: "MVP: \(mvp.name) (\(mvp.count))", color: .orange)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.1), lineWidth: 1))
    }

    private var upcomingHeatmap: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "arrow.forward")
                    .foregroundStyle(.white.opacity(0.6))
                Text("Week Ahead")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
            }

            HStack(spacing: 6) {
                ForEach(upcomingDays(), id: \.date) { day in
                    let level = loadLevel(day.tasks.count)
                    VStack(spacing: 6) {
                        Text(day.shortLabel)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))

                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(level.color.opacity(day.tasks.isEmpty ? 0.15 : 0.35))
                                .frame(height: 48)
                            Text("\(day.tasks.count)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(day.tasks.isEmpty ? .white.opacity(0.3) : .white)
                        }

                        Text(level.label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(level.color.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.1), lineWidth: 1))
    }

    private var insightsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Insights")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
            }

            ForEach(Array(generateInsights().enumerated()), id: \.offset) { _, insight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: insight.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(insight.color)
                        .frame(width: 24)

                    Text(insight.text)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(insight.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(insight.color.opacity(0.2), lineWidth: 1))
            }
        }
        .padding(16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.1), lineWidth: 1))
    }

    private func statRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
    }

    private func infoChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15), in: Capsule())
    }
}

// MARK: - Family Setup Sheet (Individual → Family)

struct FamilySetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Query(sort: \Item.targetDate) private var allTasks: [Item]
    @Query private var allMembers: [FamilyMember]
    var theme: ChildTheme

    @State private var joinExisting = false
    @State private var inviteCode = ""
    @State private var isValidating = false
    @State private var showInvalidCode = false
    @State private var showCloudUnavailable = false
    @State private var showFamilyFull = false

    private var isFormValid: Bool {
        if joinExisting {
            return inviteCode.trimmingCharacters(in: .whitespaces).count >= 6
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 24) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(calmAccent)

                        Text("Switch to Family Mode")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)

                        Text("Start your own family using your existing code, or join another family with an invite code.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)

                        VStack(spacing: 12) {
                            Button {
                                withAnimation(.snappy) { joinExisting = false }
                            } label: {
                                HStack {
                                    Image(systemName: joinExisting ? "circle" : "checkmark.circle.fill")
                                        .foregroundStyle(joinExisting ? .white.opacity(0.3) : calmAccent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Start My Family")
                                            .foregroundStyle(.white)
                                        Text("Use your code \(authManager.familyCode) and invite members")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    Spacer()
                                }
                                .font(.subheadline)
                                .padding(12)
                                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                            }

                            Button {
                                withAnimation(.snappy) { joinExisting = true }
                            } label: {
                                HStack {
                                    Image(systemName: joinExisting ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(joinExisting ? calmAccent : .white.opacity(0.3))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Join Existing Family")
                                            .foregroundStyle(.white)
                                        Text("Enter an invite code from another family")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    Spacer()
                                }
                                .font(.subheadline)
                                .padding(12)
                                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        if joinExisting {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Family Invite Code")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))

                                TextField("e.g. ABC123", text: $inviteCode)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .textInputAutocapitalization(.characters)
                                    .padding(14)
                                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                        }

                        Button {
                            switchToFamily()
                        } label: {
                            HStack(spacing: 8) {
                                if isValidating {
                                    ProgressView().tint(.white)
                                }
                                Text(joinExisting ? "Join Family" : "Start Family")
                            }
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                isFormValid && !isValidating
                                    ? AnyShapeStyle(calmAccent)
                                    : AnyShapeStyle(.white.opacity(0.1)),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .foregroundStyle(.white)
                        }
                        .disabled(!isFormValid || isValidating)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 32)
                }
            }
            .navigationTitle("Family Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .alert("Invalid Family Code", isPresented: $showInvalidCode) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("No family exists with that invite code. Please check the code and try again.")
            }
            .alert("Connection Error", isPresented: $showCloudUnavailable) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(cloudKitManager.lastSyncError ?? "Unable to connect. Please check your internet connection and try again.")
            }
            .alert("Family Full", isPresented: $showFamilyFull) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This family has reached the maximum number of members (\(subscriptionManager.maxMembers)) for the current plan.")
            }
        }
    }

    private func switchToFamily() {
        if joinExisting {
            isValidating = true
            Task {
                let result = await cloudKitManager.validateFamilyCode(inviteCode.uppercased())
                switch result {
                case .valid:
                    let count = await cloudKitManager.memberCount(familyCode: inviteCode.uppercased())
                    guard count < subscriptionManager.maxMembers else {
                        isValidating = false
                        showFamilyFull = true
                        return
                    }
                    completeSwitch(code: inviteCode.uppercased(), isNew: false)
                case .invalid:
                    isValidating = false
                    showInvalidCode = true
                case .cloudUnavailable:
                    isValidating = false
                    showCloudUnavailable = true
                }
            }
        } else {
            isValidating = true
            Task {
                let code = authManager.familyCode
                let result = await cloudKitManager.validateFamilyCode(code)
                if result == .valid {
                    authManager.role = "parent"
                    isValidating = false
                    dismiss()
                    return
                }
                let saved = await cloudKitManager.registerFamily(code: code, createdBy: authManager.userName, appleUserID: authManager.appleUserID)
                if saved {
                    completeSwitch(code: code, isNew: true)
                } else {
                    isValidating = false
                    showCloudUnavailable = true
                }
            }
        }
    }

    private func completeSwitch(code: String, isNew: Bool) {
        let member = FamilyMember(
            name: authManager.userName,
            memberRole: "parent",
            avatar: authManager.avatar,
            appleUserID: authManager.appleUserID
        )
        modelContext.insert(member)

        Task {
            let pushed = await cloudKitManager.pushMember(member, familyCode: code)
            guard pushed else {
                modelContext.delete(member)
                isValidating = false
                showCloudUnavailable = true
                return
            }

            if isNew {
                await cloudKitManager.createFamilyZone(familyCode: code)
            } else {
                await cloudKitManager.ensureFamilyZoneAccess(familyCode: code, appleUserID: authManager.appleUserID)
                await cloudKitManager.syncAll(context: modelContext, familyCode: code)
            }

            for task in allTasks where task.assignedTo == authManager.userName {
                await cloudKitManager.pushTask(task, familyCode: code)
            }

            if let familyTier = await cloudKitManager.fetchFamilyTier(familyCode: code) {
                subscriptionManager.setFamilyTier(familyTier)
            }

            await cloudKitManager.setupSubscriptions(familyCode: code, appleUserID: authManager.appleUserID, role: "parent")

            authManager.role = "parent"
            authManager.familyCode = code
            isValidating = false
            dismiss()
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationManager.self) private var notificationManager
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")

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
                        Spacer().frame(height: 12)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reminders")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.7))

                            HStack {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.primary.opacity(0.6))
                                    .frame(width: 24)
                                Text("Voice Reminders")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { notificationManager.isVoiceEnabled },
                                    set: { notificationManager.isVoiceEnabled = $0 }
                                ))
                                .labelsHidden()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                            )

                            if !notificationManager.isVoiceEnabled {
                                Text("Reminders will play a beep sound instead of speaking the task name.")
                                    .font(.caption)
                                    .foregroundStyle(.primary.opacity(0.5))
                            }

                            HStack {
                                Image(systemName: SoundManager.shared.isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.primary.opacity(0.6))
                                    .frame(width: 24)
                                Text("In-App Sounds")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { SoundManager.shared.isSoundEnabled },
                                    set: { SoundManager.shared.isSoundEnabled = $0 }
                                ))
                                .labelsHidden()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                            )

                            if !SoundManager.shared.isSoundEnabled {
                                Text("Celebration sounds and beeps are muted.")
                                    .font(.caption)
                                    .foregroundStyle(.primary.opacity(0.5))
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reminder Timing")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.7))

                            VStack(spacing: 0) {
                                ForEach(Array(NotificationManager.allReminderIntervals.enumerated()), id: \.element.minutes) { index, interval in
                                    HStack {
                                        Image(systemName: interval.minutes == 0 ? "bell.fill" : "bell")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.primary.opacity(0.6))
                                            .frame(width: 24)
                                        Text(interval.label)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Toggle("", isOn: Binding(
                                            get: { notificationManager.isIntervalEnabled(interval.minutes) },
                                            set: { _ in notificationManager.toggleInterval(interval.minutes) }
                                        ))
                                        .labelsHidden()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)

                                    if index < NotificationManager.allReminderIntervals.count - 1 {
                                        Divider()
                                            .padding(.leading, 52)
                                    }
                                }
                            }
                            .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Siri Announce (Hands-Free)")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.7))

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Let Siri read your task reminders aloud through AirPods, CarPlay, or HomePod — even when the app is closed.")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary.opacity(0.7))

                                VStack(alignment: .leading, spacing: 6) {
                                    Label("Turn on Announce Notifications", systemImage: "1.circle.fill")
                                    Label("Select Taskoot from the app list", systemImage: "2.circle.fill")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.primary.opacity(0.8))

                                Button {
                                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "speaker.wave.2.fill")
                                        Text("Open Notification Settings")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(theme.accentColor, in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
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
            .navigationTitle("Settings")
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

// MARK: - Edit Profile View

struct EditProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Query private var allMembers: [FamilyMember]
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")

    @State private var name = ""
    @State private var selectedAvatar = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var customPhotoImage: UIImage?

    private var myMember: FamilyMember? {
        allMembers.first { $0.appleUserID == authManager.appleUserID }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
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
                        Spacer().frame(height: 12)

                        AvatarView(avatarId: selectedAvatar, size: 90)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Choose Avatar")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.7))

                            HStack(spacing: 16) {
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    VStack(spacing: 6) {
                                        if let img = customPhotoImage, selectedAvatar.hasPrefix("photo_") {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 50, height: 50)
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle().strokeBorder(.blue, lineWidth: 2)
                                                        .frame(width: 54, height: 54)
                                                )
                                        } else {
                                            ZStack {
                                                Circle()
                                                    .fill(.primary.opacity(0.15))
                                                    .frame(width: 50, height: 50)
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(.primary.opacity(0.7))
                                            }
                                        }
                                        Text("Photo")
                                            .font(.caption2)
                                            .foregroundStyle(.primary.opacity(0.5))
                                    }
                                }
                                .onChange(of: selectedPhotoItem) { _, item in
                                    guard let item else { return }
                                    Task {
                                        if let data = try? await item.loadTransferable(type: Data.self),
                                           let uiImage = UIImage(data: data) {
                                            let photoID = UUID().uuidString
                                            let resized = resizeAvatarImage(uiImage, maxSize: 400)
                                            if saveAvatarPhoto(resized, photoID: photoID) {
                                                customPhotoImage = resized
                                                selectedAvatar = "photo_\(photoID)"
                                            }
                                        }
                                    }
                                }

                                Spacer()
                            }

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                                ForEach(avatarPresets, id: \.id) { preset in
                                    AvatarView(avatarId: preset.id, size: 50)
                                        .overlay(
                                            Circle().strokeBorder(selectedAvatar == preset.id ? avatarColor(for: preset.id) : .clear, lineWidth: 2)
                                        )
                                        .onTapGesture {
                                            selectedAvatar = preset.id
                                            customPhotoImage = nil
                                        }
                                }
                            }

                            Text("Animals")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.5))
                                .padding(.top, 4)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                                ForEach(animalAvatarPresets, id: \.id) { preset in
                                    AvatarView(avatarId: preset.id, size: 50)
                                        .overlay(
                                            Circle().strokeBorder(selectedAvatar == preset.id ? avatarColor(for: preset.id) : .clear, lineWidth: 2)
                                        )
                                        .onTapGesture {
                                            selectedAvatar = preset.id
                                            customPhotoImage = nil
                                        }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Name")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.7))

                            TextField("Enter your name", text: $name)
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
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedName = name.trimmingCharacters(in: .whitespaces)
                        authManager.userName = trimmedName
                        authManager.avatar = selectedAvatar
                        if let member = myMember {
                            member.name = trimmedName
                            member.avatar = selectedAvatar
                            let familyCode = authManager.familyCode
                            Task { await cloudKitManager.pushMember(member, familyCode: familyCode) }
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                name = authManager.userName
                selectedAvatar = authManager.avatar
                if selectedAvatar.hasPrefix("photo_") {
                    let photoID = String(selectedAvatar.dropFirst(6))
                    customPhotoImage = loadAvatarPhoto(photoID: photoID)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func resizeAvatarImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let scale = min(maxSize / image.size.width, maxSize / image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Redemption Approvals View (Parent)

struct RedemptionApprovalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    @Environment(NotificationManager.self) private var notificationManager
    @Query(filter: #Predicate<RewardRedemption> { $0.status == "pending" }, sort: \RewardRedemption.createdAt)
    private var pendingRedemptions: [RewardRedemption]
    @Query private var allMembers: [FamilyMember]
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    @State private var rejectTarget: RewardRedemption?
    @State private var rejectReason = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                if pendingRedemptions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "gift")
                            .font(.system(size: 56))
                            .foregroundStyle(.primary.opacity(0.5))
                        Text("No pending requests")
                            .font(.title3)
                            .foregroundStyle(.primary.opacity(0.85))
                        Text("All reward requests have been handled.")
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.6))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(pendingRedemptions) { redemption in
                                redemptionApprovalRow(redemption)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("Reward Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Reject Request", isPresented: Binding(
                get: { rejectTarget != nil },
                set: { if !$0 { rejectTarget = nil; rejectReason = "" } }
            )) {
                TextField("Reason (optional)", text: $rejectReason)
                Button("Cancel", role: .cancel) {
                    rejectTarget = nil
                    rejectReason = ""
                }
                Button("Reject", role: .destructive) {
                    if let redemption = rejectTarget {
                        redemption.status = "rejected"
                        redemption.rejectReason = rejectReason
                        redemption.resolvedAt = Date()
                        let familyCode = authManager.familyCode
                        Task {
                            _ = await cloudKitManager.pushRedemption(redemption, familyCode: familyCode)
                        }
                    }
                    rejectTarget = nil
                    rejectReason = ""
                }
            } message: {
                if let r = rejectTarget {
                    Text("Reject \(r.childName)'s request for \"\(r.itemDescription)\"?")
                }
            }
        }
    }

    private func redemptionApprovalRow(_ r: RewardRedemption) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: r.typeIcon)
                    .font(.title2)
                    .foregroundStyle(.purple)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(r.itemDescription)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Label(r.childName, systemImage: "person.fill")
                            .font(.caption)
                            .foregroundStyle(calmAccent.opacity(0.8))

                        Text("•")
                            .foregroundStyle(.primary.opacity(0.5))

                        Label("\(r.coinAmount) coins", systemImage: "star.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.yellow.opacity(0.85))

                        Text("•")
                            .foregroundStyle(.primary.opacity(0.5))

                        Text(r.typeLabel)
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.7))
                    }

                    Text(r.createdAt, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.55))
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    rejectTarget = r
                } label: {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Reject")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.red.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.red)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.red.opacity(0.3), lineWidth: 1)
                    )
                }

                Button {
                    approveRedemption(r)
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Approve")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.green)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.green.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.purple.opacity(0.2), lineWidth: 1)
        )
    }

    private func approveRedemption(_ r: RewardRedemption) {
        r.status = "approved"
        r.resolvedAt = Date()
        let familyCode = authManager.familyCode
        Task {
            _ = await cloudKitManager.pushRedemption(r, familyCode: familyCode)
        }
    }
}

// MARK: - Subscription View

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    @State private var isPurchasing = false

    private struct PlanFeature {
        let text: String
        let included: Bool
    }

    private struct PlanInfo {
        let tier: SubscriptionManager.Tier
        let name: String
        let icon: String
        let color: Color
        let price: String
        let period: String
        let features: [PlanFeature]
        let monthlyID: String?
        let annualID: String?
    }

    private var plans: [PlanInfo] {
        [
            PlanInfo(
                tier: .free,
                name: "Free Trial",
                icon: "person.2.fill",
                color: .gray,
                price: "$0",
                period: "7 days",
                features: [
                    PlanFeature(text: "Up to 4 family members", included: true),
                    PlanFeature(text: "50 tasks per month", included: true),
                    PlanFeature(text: "Basic notifications", included: true),
                    PlanFeature(text: "Priority support", included: false),
                ],
                monthlyID: nil,
                annualID: nil
            ),
            PlanInfo(
                tier: .family,
                name: "Basic",
                icon: "person.3.fill",
                color: calmAccent,
                price: "$4.99",
                period: "/month",
                features: [
                    PlanFeature(text: "Up to 6 family members", included: true),
                    PlanFeature(text: "500 tasks per month", included: true),
                    PlanFeature(text: "All notifications", included: true),
                    PlanFeature(text: "Cancel anytime, pro-rated refund", included: true),
                    PlanFeature(text: "Priority support", included: false),
                ],
                monthlyID: SubscriptionManager.familyMonthly,
                annualID: SubscriptionManager.familyAnnual
            ),
            PlanInfo(
                tier: .pro,
                name: "Pro",
                icon: "crown.fill",
                color: .orange,
                price: "$9.99",
                period: "/month",
                features: [
                    PlanFeature(text: "Up to 10 family members", included: true),
                    PlanFeature(text: "2000 tasks per month", included: true),
                    PlanFeature(text: "All notifications", included: true),
                    PlanFeature(text: "Cancel anytime, pro-rated refund", included: true),
                    PlanFeature(text: "Priority support", included: true),
                ],
                monthlyID: SubscriptionManager.proMonthly,
                annualID: SubscriptionManager.proAnnual
            ),
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        currentPlanBadge

                        ForEach(plans, id: \.name) { plan in
                            planCard(plan)
                        }

                        if subscriptionManager.tier != .free {
                            cancelSubscriptionButton
                        }

                        restoreButton

                        if let error = subscriptionManager.purchaseError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 16)
                        }

                        subscriptionLegalText

                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await subscriptionManager.loadProducts()
            }
        }
    }

    private var currentPlanBadge: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: subscriptionManager.tier == .pro ? "crown.fill" : subscriptionManager.tier == .family ? "person.3.fill" : "person.2.fill")
                    .font(.title3)
                    .foregroundStyle(subscriptionManager.tier == .pro ? .orange : subscriptionManager.tier == .family ? calmAccent : .gray)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Plan")
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.7))
                    Text(subscriptionManager.tier == .free ? "Free Trial" : subscriptionManager.tier.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer()

                if subscriptionManager.tier == .free {
                    if subscriptionManager.isTrialActive {
                        Text("\(subscriptionManager.trialDaysRemaining)d left")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.3), in: Capsule())
                    } else {
                        Text("Expired")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.3), in: Capsule())
                    }
                } else {
                    Text("Active")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.3), in: Capsule())
                }
            }

            if subscriptionManager.tier == .free && subscriptionManager.isTrialExpired {
                Text("Your free trial has expired. Upgrade to continue using Taskoot.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(16)
        .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    subscriptionManager.isTrialExpired ? Color.red.opacity(0.4) : .primary.opacity(0.15),
                    lineWidth: subscriptionManager.isTrialExpired ? 2 : 1
                )
        )
    }

    private func planCard(_ plan: PlanInfo) -> some View {
        let isCurrent = subscriptionManager.tier == plan.tier
        let isUpgrade = plan.tier > subscriptionManager.tier

        return VStack(spacing: 16) {
            HStack {
                Image(systemName: plan.icon)
                    .font(.title2)
                    .foregroundStyle(plan.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(planPrice(plan))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if plan.tier != .free {
                            Text(plan.period)
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.7))
                        }
                    }
                }

                Spacer()

                if isCurrent {
                    Text("Current")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(plan.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(plan.color.opacity(0.15), in: Capsule())
                }
            }

            VStack(spacing: 8) {
                ForEach(plan.features, id: \.text) { feature in
                    HStack(spacing: 10) {
                        Image(systemName: feature.included ? "checkmark.circle.fill" : "xmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(feature.included ? Color.green : Color.primary.opacity(0.25))

                        Text(feature.text)
                            .font(.subheadline)
                            .foregroundStyle(Color.primary.opacity(feature.included ? 0.8 : 0.3))

                        Spacer()
                    }
                }
            }

            if isUpgrade {
                HStack(spacing: 8) {
                    subscribeButton(plan: plan, isAnnual: false)
                    subscribeButton(plan: plan, isAnnual: true)
                }
            }
        }
        .padding(18)
        .background(
            isCurrent ? plan.color.opacity(0.08) : .primary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isCurrent ? plan.color.opacity(0.4) : .primary.opacity(0.1),
                    lineWidth: isCurrent ? 2 : 1
                )
        )
    }

    private func subscribeButton(plan: PlanInfo, isAnnual: Bool) -> some View {
        let productID = isAnnual ? plan.annualID : plan.monthlyID
        let product = subscriptionManager.products.first { $0.id == productID }
        let label = isAnnual ? "Annual" : "Monthly"

        return Button {
            guard let product else { return }
            isPurchasing = true
            Task {
                let success = await subscriptionManager.purchase(product)
                if success {
                    await cloudKitManager.pushFamilyTier(subscriptionManager.tier.rawValue, familyCode: authManager.familyCode)
                }
                isPurchasing = false
            }
        } label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(.caption.weight(.semibold))
                if let product {
                    Text(product.displayPrice)
                        .font(.subheadline.weight(.bold))
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isAnnual ? plan.color : plan.color.opacity(0.4),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .foregroundStyle(.primary)
        }
        .disabled(product == nil || isPurchasing)
    }

    private func planPrice(_ plan: PlanInfo) -> String {
        if plan.tier == .free { return "$0" }
        if let product = subscriptionManager.products.first(where: { $0.id == plan.monthlyID }) {
            return product.displayPrice
        }
        return plan.price
    }

    private var cancelSubscriptionButton: some View {
        VStack(spacing: 8) {
            Button {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle")
                        .font(.subheadline)
                    Text("Cancel Subscription")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.red.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.red.opacity(0.2), lineWidth: 1)
                )
            }

            Text("You can cancel anytime. Unused time will be pro-rated on a monthly basis and refunded to your Apple ID.")
                .font(.caption2)
                .foregroundStyle(.primary.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }

    private var restoreButton: some View {
        Button {
            Task {
                await subscriptionManager.restorePurchases()
                if subscriptionManager.tier != .free {
                    await cloudKitManager.pushFamilyTier(subscriptionManager.tier.rawValue, familyCode: authManager.familyCode)
                }
            }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.7))
                .padding(.vertical, 8)
        }
    }

    private var subscriptionLegalText: some View {
        VStack(spacing: 12) {
            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can cancel anytime and unused time will be pro-rated on a monthly basis and refunded. Manage subscriptions in your App Store account settings.")
                .font(.caption2)
                .foregroundStyle(.primary.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            HStack(spacing: 16) {
                Link("Privacy Policy", destination: privacyPolicyURL)
                Link("Terms of Use", destination: termsOfUseURL)
                Link("Manage Subscriptions", destination: manageSubscriptionsURL)
            }
            .font(.caption2.weight(.medium))
            .tint(Color.primary.opacity(0.6))
        }
        .padding(.top, 8)
    }
}

// MARK: - Notification Center View

struct NotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(AuthManager.self) private var authManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Query private var allMembers: [FamilyMember]
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    @State private var notifications: [NotificationManager.LocalNotification] = []
    @State private var showClearAllConfirm = false
    @State private var acknowledgedPickups: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: theme.gradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if notifications.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 56))
                            .foregroundStyle(.primary.opacity(0.5))
                        Text("No notifications")
                            .font(.title3)
                            .foregroundStyle(.primary.opacity(0.85))
                        Text("You're all caught up!")
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.6))
                    }
                } else {
                    List {
                        ForEach(notifications) { notif in
                            notificationRow(notif)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        }
                        .onDelete { indexSet in
                            deleteNotifications(at: indexSet)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !notifications.isEmpty {
                        Button(role: .destructive) {
                            showClearAllConfirm = true
                        } label: {
                            Text("Clear All")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Clear All Notifications?", isPresented: $showClearAllConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clearAllNotifications()
                }
            } message: {
                Text("This will delete all \(notifications.count) notifications from your device.")
            }
            .onAppear {
                notifications = notificationManager.savedNotifications()
            }
        }
    }

    private func deleteNotifications(at offsets: IndexSet) {
        let toDelete = offsets.map { notifications[$0] }
        withAnimation {
            notifications.remove(atOffsets: offsets)
        }
        for notif in toDelete {
            notificationManager.deleteLocalNotification(id: notif.id)
        }
    }

    private func clearAllNotifications() {
        notificationManager.clearAllLocalNotifications()
        withAnimation {
            notifications.removeAll()
        }
    }

    private func acknowledgePickupFromNotification(_ notif: NotificationManager.LocalNotification) {
        let childName = notif.senderName
        guard let child = allMembers.first(where: { $0.name == childName && $0.isChild }) else { return }

        child.lastPickupAckAt = Date()
        child.lastPickupAckBy = authManager.userName

        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushMember(child, familyCode: familyCode) }

        _ = withAnimation { acknowledgedPickups.insert(notif.id) }
    }

    private func notificationRow(_ notif: NotificationManager.LocalNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(avatarId: notif.senderAvatar, size: 36)

                Image(systemName: iconForCategory(notif.category))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 16, height: 16)
                    .background(colorForCategory(notif.category), in: Circle())
                    .offset(x: 2, y: 2)
            }
            .frame(width: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(notif.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(notif.body)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineLimit(3)

                if notif.category == "PICKUP_REQUEST" && notif.createdAt.timeIntervalSinceNow > -600 && authManager.role == "parent" {
                    if acknowledgedPickups.contains(notif.id) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                            Text("On My Way!")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.top, 2)
                    } else {
                        Button {
                            acknowledgePickupFromNotification(notif)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "car.fill")
                                    .font(.caption2)
                                Text("On My Way!")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(calmAccent, in: Capsule())
                        }
                        .padding(.top, 2)
                    }
                }

                Text(notif.createdAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.primary.opacity(0.55))
            }

            Spacer()
        }
        .padding(14)
        .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(colorForCategory(notif.category).opacity(0.2), lineWidth: 1)
        )
    }

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "PICKUP_REQUEST": return "car.fill"
        case "TASK_REVIEW": return "clock.fill"
        case "TASK_APPROVED": return "checkmark.circle.fill"
        case "TASK_REJECTED": return "xmark.circle.fill"
        case "TASK_ASSIGNED": return "plus.circle.fill"
        case "TASK_CREATED": return "pencil.circle.fill"
        case "REWARD_REQUEST": return "gift.fill"
        case "REWARD_APPROVED": return "gift.circle.fill"
        case "REWARD_REJECTED": return "gift.circle"
        case "REWARD_FULFILLED": return "checkmark.seal.fill"
        default: return "bell.fill"
        }
    }

    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "PICKUP_REQUEST": return calmAccent
        case "TASK_REVIEW": return .orange
        case "TASK_APPROVED": return .green
        case "TASK_REJECTED": return .red
        case "TASK_ASSIGNED": return .cyan
        case "TASK_CREATED": return .purple
        case "REWARD_REQUEST": return .purple
        case "REWARD_APPROVED": return .green
        case "REWARD_REJECTED": return .red
        case "REWARD_FULFILLED": return .green
        default: return .cyan
        }
    }
}

// MARK: - Shopping Bag View

struct ShoppingBagView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Query(sort: \ShoppingItem.createdAt) private var allItems: [ShoppingItem]
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")

    @State private var newItemName = ""
    @State private var editingItem: ShoppingItem?
    @State private var editingName = ""
    @FocusState private var isInputFocused: Bool

    private var unboughtItems: [ShoppingItem] {
        allItems.filter { !$0.isBought }
    }

    private var boughtItems: [ShoppingItem] {
        allItems.filter { $0.isBought }
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

                VStack(spacing: 0) {
                    addItemBar
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    if allItems.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "cart")
                                .font(.system(size: 48))
                                .foregroundStyle(.primary.opacity(0.3))
                            Text("Shopping bag is empty")
                                .font(.subheadline)
                                .foregroundStyle(.primary.opacity(0.4))
                            Text("Add items your family needs to buy")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.3))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(unboughtItems) { item in
                                    shoppingRow(item: item)
                                }

                                if !boughtItems.isEmpty {
                                    HStack {
                                        Text("Bought")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.primary.opacity(0.4))
                                        Spacer()
                                        Button("Clear All") {
                                            clearBoughtItems()
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.orange)
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.top, 12)

                                    ForEach(boughtItems) { item in
                                        shoppingRow(item: item)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        }
                        .refreshable {
                            guard !authManager.familyCode.isEmpty else { return }
                            await cloudKitManager.syncShoppingOnly(context: modelContext, familyCode: authManager.familyCode)
                        }
                    }
                }
            }
            .task {
                guard !authManager.familyCode.isEmpty else { return }
                await cloudKitManager.syncShoppingOnly(context: modelContext, familyCode: authManager.familyCode)
            }
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .navigationTitle("Family Shopping Bag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .alert("Edit Item", isPresented: Binding(
            get: { editingItem != nil },
            set: { if !$0 { editingItem = nil } }
        )) {
            TextField("Item name", text: $editingName)
            Button("Save") {
                if let item = editingItem {
                    let trimmed = editingName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    item.name = trimmed
                    let snap = CloudKitManager.ShoppingSnapshot(item)
                    let familyCode = authManager.familyCode
                    Task { await cloudKitManager.pushShoppingSnapshot(snap, familyCode: familyCode) }
                }
                editingItem = nil
            }
            Button("Cancel", role: .cancel) { editingItem = nil }
        }
    }

    private var addItemBar: some View {
        HStack(spacing: 10) {
            TextField("Add an item...", text: $newItemName)
                .font(.body)
                .foregroundStyle(.primary)
                .focused($isInputFocused)
                .padding(12)
                .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                )
                .submitLabel(.done)
                .onSubmit { addItem() }

            Button {
                addItem()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.primary)
                    .symbolRenderingMode(.hierarchical)
            }
            .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func shoppingRow(item: ShoppingItem) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleBought(item)
            } label: {
                Image(systemName: item.isBought ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isBought ? Color.green : Color.primary.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .foregroundStyle(Color.primary.opacity(item.isBought ? 0.35 : 1))
                    .strikethrough(item.isBought, color: .primary.opacity(0.3))

                Text("Added by \(item.addedBy)")
                    .font(.caption2)
                    .foregroundStyle(.primary.opacity(0.3))
            }
            .onTapGesture {
                editingName = item.name
                editingItem = item
            }

            Spacer()

            Button {
                deleteItem(item)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.3))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.primary.opacity(item.isBought ? 0.04 : 0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private func addItem() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let item = ShoppingItem(name: trimmed, addedBy: authManager.userName)
        modelContext.insert(item)
        let snap = CloudKitManager.ShoppingSnapshot(item)
        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushShoppingSnapshot(snap, familyCode: familyCode) }
        newItemName = ""
    }

    private func toggleBought(_ item: ShoppingItem) {
        item.isBought.toggle()
        let snap = CloudKitManager.ShoppingSnapshot(item)
        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushShoppingSnapshot(snap, familyCode: familyCode) }
    }

    private func deleteItem(_ item: ShoppingItem) {
        let id = item.id
        let familyCode = authManager.familyCode
        modelContext.delete(item)
        Task { await cloudKitManager.deleteShoppingItem(id: id, familyCode: familyCode) }
    }

    private func clearBoughtItems() {
        let bought = boughtItems
        let familyCode = authManager.familyCode
        for item in bought {
            let id = item.id
            modelContext.delete(item)
            Task { await cloudKitManager.deleteShoppingItem(id: id, familyCode: familyCode) }
        }
    }
}

// MARK: - Annual Reminders View

struct AnnualRemindersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    @Query(sort: \AnnualReminder.dueDate) private var reminders: [AnnualReminder]
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    @State private var showAddReminder = false
    @State private var selectedCategory: ReminderCategory?
    @State private var reminderToEdit: AnnualReminder?
    @State private var reminderToDelete: AnnualReminder?

    private var filteredReminders: [AnnualReminder] {
        if let cat = selectedCategory {
            return reminders.filter { $0.category == cat.rawValue }
        }
        return Array(reminders)
    }

    private var groupedReminders: [(ReminderCategory, [AnnualReminder])] {
        let grouped = Dictionary(grouping: filteredReminders) { $0.categoryEnum }
        return ReminderCategory.allCases.compactMap { cat in
            let items = grouped[cat] ?? []
            return items.isEmpty ? nil : (cat, items)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryChip(nil, label: "All", icon: "tray.full.fill")
                            ForEach(ReminderCategory.allCases, id: \.self) { cat in
                                categoryChip(cat, label: cat.rawValue, icon: cat.icon)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }

                    if filteredReminders.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 48))
                                .foregroundStyle(.primary.opacity(0.3))
                            Text("No reminders yet")
                                .font(.headline)
                                .foregroundStyle(.primary.opacity(0.5))
                            Text("Add annual reminders for insurance, vehicle, medical and more")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.35))
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .padding(32)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(groupedReminders, id: \.0) { category, items in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 6) {
                                            Image(systemName: category.icon)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(category.color)
                                            Text(category.rawValue)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.primary)
                                        }
                                        .padding(.horizontal, 4)

                                        ForEach(items) { reminder in
                                            reminderRow(reminder)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 80)
                        }
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { showAddReminder = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(calmAccent, in: Circle())
                        .shadow(color: calmAccent.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .navigationTitle("Annual Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddReminder) {
                AddAnnualReminderView(theme: theme)
            }
            .sheet(item: $reminderToEdit) { reminder in
                AddAnnualReminderView(theme: theme, editingReminder: reminder)
            }
            .alert("Delete Reminder?", isPresented: Binding(
                get: { reminderToDelete != nil },
                set: { if !$0 { reminderToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { reminderToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let reminder = reminderToDelete {
                        let id = reminder.id
                        notificationManager.cancelAnnualReminder(reminderId: id)
                        modelContext.delete(reminder)
                        Task { await cloudKitManager.deleteAnnualReminder(id: id) }
                        reminderToDelete = nil
                    }
                }
            } message: {
                if let r = reminderToDelete {
                    Text("Delete \"\(r.name)\"?")
                }
            }
        }
    }

    private func categoryChip(_ cat: ReminderCategory?, label: String, icon: String) -> some View {
        let isSelected = selectedCategory == cat
        return Button { selectedCategory = cat } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? (cat?.color ?? calmAccent) : .primary.opacity(0.15), in: Capsule())
            .foregroundStyle(isSelected ? .white : .primary.opacity(0.7))
        }
        .buttonStyle(.plain)
    }

    private func reminderRow(_ reminder: AnnualReminder) -> some View {
        HStack(spacing: 12) {
            Button {
                markDone(reminder)
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(reminder.isOverdue ? .red : reminder.isDueSoon ? .orange : .primary.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    if reminder.isDone {
                        Circle().fill(.green).frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Button { reminderToEdit = reminder } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(reminder.dueDate, format: .dateTime.month().day().year())
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.5))
                        if reminder.isOverdue {
                            Text("Overdue")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.red)
                        } else if reminder.isDueSoon {
                            Text("\(reminder.daysUntilDue)d left")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.orange)
                        }
                        if reminder.repeats {
                            HStack(spacing: 2) {
                                Image(systemName: "repeat")
                                    .font(.system(size: 9))
                                Text(reminder.frequencyEnum.label)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(.primary.opacity(0.35))
                        }
                    }
                }
                Spacer()
            }
            .buttonStyle(.plain)

            Button { reminderToDelete = reminder } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(.red.opacity(0.6))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    reminder.isOverdue ? .red.opacity(0.3) : reminder.isDueSoon ? .orange.opacity(0.2) : .clear,
                    lineWidth: 1
                )
        )
    }

    private func markDone(_ reminder: AnnualReminder) {
        if reminder.repeats {
            reminder.advanceToNextDue()
            reminder.isDone = false
            notificationManager.scheduleAnnualReminder(
                reminderId: reminder.id, name: reminder.name,
                dueDate: reminder.dueDate, remindDaysBefore: reminder.remindDays
            )
        } else {
            reminder.isDone = true
            notificationManager.cancelAnnualReminder(reminderId: reminder.id)
        }
        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushAnnualReminder(reminder, familyCode: familyCode) }
    }
}

// MARK: - Add Annual Reminder View

struct AddAnnualReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    var editingReminder: AnnualReminder?

    @State private var name = ""
    @State private var selectedCategory: ReminderCategory = .home
    @State private var dueDate = Date()
    @State private var repeatFrequency: ReminderRepeat = .yearly
    @State private var remindDays: Set<Int> = [30, 14, 7]
    @State private var notes = ""

    private var isEditing: Bool { editingReminder != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 20)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary.opacity(0.7))

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                                ForEach(ReminderCategory.allCases, id: \.self) { cat in
                                    Button { selectedCategory = cat } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: cat.icon)
                                                .font(.system(size: 12, weight: .semibold))
                                            Text(cat.rawValue)
                                                .font(.caption.weight(.medium))
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(selectedCategory == cat ? cat.color : .primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                                        .foregroundStyle(selectedCategory == cat ? .white : .primary.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if let templates = reminderTemplates[selectedCategory], !templates.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Quick Pick")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary.opacity(0.7))
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(templates) { template in
                                            Button { name = template.name } label: {
                                                Text(template.name)
                                                    .font(.caption.weight(.medium))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(name == template.name ? selectedCategory.color.opacity(0.3) : .primary.opacity(0.1), in: Capsule())
                                                    .foregroundStyle(.primary.opacity(0.8))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reminder Name")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary.opacity(0.7))
                            TextField("e.g. Car Insurance Renewal", text: $name)
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.primary)
                                .padding(16)
                                .background(.primary.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(name.isEmpty ? Color.primary.opacity(0.35) : Color.green.opacity(0.6), lineWidth: 1.5)
                                )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Due Date")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.5))
                            DatePicker("", selection: $dueDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(.primary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Remind Me Before")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary.opacity(0.7))
                            HStack(spacing: 8) {
                                ForEach([30, 14, 7, 1], id: \.self) { days in
                                    Button {
                                        if remindDays.contains(days) {
                                            remindDays.remove(days)
                                        } else {
                                            remindDays.insert(days)
                                        }
                                    } label: {
                                        Text(days == 1 ? "1 day" : "\(days) days")
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(remindDays.contains(days) ? selectedCategory.color : .primary.opacity(0.12), in: Capsule())
                                            .foregroundStyle(remindDays.contains(days) ? .white : .primary.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Repeat")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary.opacity(0.7))
                            Picker("Repeat", selection: $repeatFrequency) {
                                ForEach(ReminderRepeat.allCases, id: \.self) { freq in
                                    Text(freq.label).tag(freq)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(14)
                            .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes (optional)")
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.5))
                            TextField("Policy number, amount, etc.", text: $notes, axis: .vertical)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineLimit(3...5)
                                .padding(14)
                                .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .navigationTitle(isEditing ? "Edit Reminder" : "Add Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .onAppear {
                if let r = editingReminder {
                    name = r.name
                    selectedCategory = r.categoryEnum
                    dueDate = r.dueDate
                    repeatFrequency = r.frequencyEnum
                    remindDays = Set(r.remindDays)
                    notes = r.notes
                }
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let sortedDays = remindDays.sorted(by: >)
        let familyCode = authManager.familyCode

        if let reminder = editingReminder {
            reminder.name = trimmedName
            reminder.category = selectedCategory.rawValue
            reminder.dueDate = dueDate
            reminder.repeatFrequency = repeatFrequency.rawValue
            reminder.repeatYearly = repeatFrequency != .none
            reminder.setRemindDays(sortedDays)
            reminder.notes = notes
            notificationManager.cancelAnnualReminder(reminderId: reminder.id)
            notificationManager.scheduleAnnualReminder(
                reminderId: reminder.id, name: trimmedName,
                dueDate: dueDate, remindDaysBefore: sortedDays
            )
            Task { await cloudKitManager.pushAnnualReminder(reminder, familyCode: familyCode) }
        } else {
            let reminder = AnnualReminder(
                name: trimmedName,
                category: selectedCategory.rawValue,
                dueDate: dueDate,
                repeatYearly: repeatFrequency != .none,
                repeatFrequency: repeatFrequency.rawValue,
                remindDaysBefore: {
                    if let data = try? JSONEncoder().encode(sortedDays),
                       let str = String(data: data, encoding: .utf8) { return str }
                    return "[30,14,7]"
                }(),
                notes: notes
            )
            modelContext.insert(reminder)
            notificationManager.scheduleAnnualReminder(
                reminderId: reminder.id, name: trimmedName,
                dueDate: dueDate, remindDaysBefore: sortedDays
            )
            Task { await cloudKitManager.pushAnnualReminder(reminder, familyCode: familyCode) }
        }
        dismiss()
    }
}

// MARK: - Family Chat View

private struct PhotoWrapper: Identifiable {
    let id = UUID()
    let data: Data
}


struct FamilyChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Query(sort: \ChatMessage.sentAt) private var allMessages: [ChatMessage]
    @Query private var allMembers: [FamilyMember]
    @Query(sort: \Item.targetDate) private var allTasks: [Item]
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")

    @State private var messageText = ""
    @State private var displayLimit = 50
    @State private var showReactionPicker: ChatMessage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingPhotoData: Data?
    @State private var tappedPhoto: Data?
    @State private var showClearAttachmentsAlert = false
    @FocusState private var isInputFocused: Bool

    private static let coinReactionKey = "⭐coin"
    private static let reactions = ["👍", "❤️", "😂", "🎉", "👏", "🔥"]

    private static let coinGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.95, blue: 0.4), Color(red: 1.0, green: 0.7, blue: 0.0)],
        startPoint: .top,
        endPoint: .bottom
    )

    private var visibleMessages: [ChatMessage] {
        let sorted = allMessages.sorted { $0.sentAt < $1.sentAt }
        if sorted.count <= displayLimit { return sorted }
        return Array(sorted.suffix(displayLimit))
    }

    private var canLoadMore: Bool {
        allMessages.count > displayLimit
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                if canLoadMore {
                                    Button {
                                        withAnimation { displayLimit += 50 }
                                    } label: {
                                        Text("Load earlier messages")
                                            .font(.caption)
                                            .foregroundStyle(.primary.opacity(0.5))
                                            .padding(.vertical, 8)
                                    }
                                }

                                ForEach(visibleMessages) { message in
                                    let isMe = message.senderAppleUserID == authManager.appleUserID
                                    chatBubble(message: message, isMe: isMe)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onAppear {
                            scrollToBottom(proxy: proxy)
                        }
                        .onChange(of: allMessages.count) {
                            scrollToBottom(proxy: proxy)
                        }
                    }

                    inputBar
                }
            }
            .navigationTitle("Family Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button(role: .destructive) {
                            showClearAttachmentsAlert = true
                        } label: {
                            Label("Clear All Photos", systemImage: "trash.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Clear All Photos?", isPresented: $showClearAttachmentsAlert) {
                Button("Clear", role: .destructive) {
                    let familyCode = authManager.familyCode
                    Task {
                        let count = await cloudKitManager.clearChatAttachments(familyCode: familyCode, context: modelContext)
                        print("[Chat] Cleared \(count) attachments from CloudKit")
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will delete all photos from chat to free up iCloud storage. Text messages will be kept.")
            }
            .onAppear {
                markChatAsRead()
            }
            .onDisappear {
                markChatAsRead()
            }
        }
        .presentationDetents([.large])
        .fullScreenCover(item: Binding(
            get: { tappedPhoto.map { PhotoWrapper(data: $0) } },
            set: { if $0 == nil { tappedPhoto = nil } }
        )) { wrapper in
            ZStack {
                Color.black.ignoresSafeArea()
                if let uiImage = UIImage(data: wrapper.data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                }
            }
            .onTapGesture { tappedPhoto = nil }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = visibleMessages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func markChatAsRead() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastChatReadTime")
    }

    private func chatBubble(message: ChatMessage, isMe: Bool) -> some View {
        VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
            if !isMe {
                HStack(spacing: 6) {
                    AvatarView(avatarId: message.senderAvatar, size: 20)
                    Text(message.senderName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                .padding(.leading, 4)
            }

            HStack {
                if isMe { Spacer(minLength: 60) }

                VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let photoData = message.attachmentData,
                           message.isImageAttachment,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: 220, maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .onTapGesture {
                                    tappedPhoto = photoData
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deletePhoto(from: message)
                                    } label: {
                                        Label("Delete Photo", systemImage: "trash")
                                    }
                                }
                        }

                        if !message.text.isEmpty {
                            Text(message.text)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal, message.hasAttachment ? 6 : 14)
                    .padding(.vertical, message.hasAttachment ? 6 : 10)
                    .background(
                        isMe ? calmAccent.opacity(0.7) : Color.primary.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 18)
                    )

                    if !message.reactionDict.isEmpty {
                        reactionBadges(for: message)
                    }
                }
                .onTapGesture {
                    showReactionPicker = showReactionPicker?.id == message.id ? nil : message
                }

                if !isMe { Spacer(minLength: 60) }
            }

            if showReactionPicker?.id == message.id {
                reactionPicker(for: message)
            }

            Text(message.sentAt, style: .time)
                .font(.system(size: 10))
                .foregroundStyle(.primary.opacity(0.3))
                .padding(.horizontal, 8)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: isMe ? .trailing : .leading)
    }

    private func reactionBadges(for message: ChatMessage) -> some View {
        HStack(spacing: 4) {
            ForEach(message.reactionDict.sorted(by: { $0.key < $1.key }), id: \.key) { emoji, users in
                let isCoin = emoji == Self.coinReactionKey
                let myCoin = isCoin && users.contains(authManager.userName) && authManager.role == "parent"
                Button {
                    if myCoin {
                        undoCoinAward(from: message)
                    } else if !isCoin {
                        message.toggleReaction(emoji, by: authManager.userName)
                        pushReactionUpdate(message)
                    }
                } label: {
                    HStack(spacing: 2) {
                        if isCoin {
                            Image(systemName: "star.circle.fill")
                                .symbolRenderingMode(.monochrome)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Self.coinGradient)
                        } else {
                            Text(emoji)
                                .font(.caption2)
                        }
                        Text("\(users.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.primary.opacity(0.8))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        isCoin ? Color.yellow.opacity(0.25) :
                        users.contains(authManager.userName) ? calmAccent.opacity(0.4) : Color.primary.opacity(0.12),
                        in: Capsule()
                    )
                }
                .disabled(isCoin && !myCoin)
            }
        }
    }

    private func reactionPicker(for message: ChatMessage) -> some View {
        let alreadyAwarded = message.reactionDict[Self.coinReactionKey]?.contains(authManager.userName) == true
        return HStack(spacing: 8) {
            if canShowCoinReaction(for: message) {
                Button {
                    if alreadyAwarded {
                        undoCoinAward(from: message)
                    } else {
                        awardCoin(to: message)
                    }
                    showReactionPicker = nil
                } label: {
                    Image(systemName: "star.circle.fill")
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(
                            alreadyAwarded
                                ? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
                                : Self.coinGradient
                        )
                        .shadow(color: Color(red: 1.0, green: 0.7, blue: 0.0).opacity(alreadyAwarded ? 0 : 0.4), radius: 2, y: 1)
                        .overlay(alignment: .bottomTrailing) {
                            if alreadyAwarded {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red)
                                    .offset(x: 2, y: 2)
                            }
                        }
                }
            }

            ForEach(Self.reactions, id: \.self) { emoji in
                Button {
                    message.toggleReaction(emoji, by: authManager.userName)
                    pushReactionUpdate(message)
                    showReactionPicker = nil
                } label: {
                    Text(emoji)
                        .font(.title3)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func pushReactionUpdate(_ message: ChatMessage) {
        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushChatMessage(message, familyCode: familyCode) }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            if let pendingPhotoData, let uiImage = UIImage(data: pendingPhotoData) {
                HStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                self.pendingPhotoData = nil
                                selectedPhoto = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white, .black.opacity(0.6))
                            }
                            .offset(x: 6, y: -6)
                        }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(calmAccent.opacity(0.8))
                }

                TextField("Message", text: $messageText, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding(12)
                    .background(.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 20))
                    .focused($isInputFocused)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(canSend ? calmAccent : .primary.opacity(0.3))
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.black.opacity(0.2))
        .onChange(of: selectedPhoto) {
            Task { await loadSelectedPhoto() }
        }
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespaces).isEmpty || pendingPhotoData != nil
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhoto else {
            pendingPhotoData = nil
            return
        }
        guard let data = try? await selectedPhoto.loadTransferable(type: Data.self) else { return }
        guard let uiImage = UIImage(data: data) else { return }
        pendingPhotoData = compressPhoto(uiImage)
    }

    private func compressPhoto(_ image: UIImage) -> Data? {
        let maxDimension: CGFloat = 800
        let size = image.size
        let scale: CGFloat
        if size.width > maxDimension || size.height > maxDimension {
            scale = maxDimension / max(size.width, size.height)
        } else {
            scale = 1.0
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.6)
    }

    private func canShowCoinReaction(for message: ChatMessage) -> Bool {
        guard authManager.role == "parent" else { return false }
        guard message.senderAppleUserID != authManager.appleUserID else { return false }
        let senderMember = allMembers.first { $0.appleUserID == message.senderAppleUserID }
        return senderMember?.isChild == true
    }

    private func awardCoin(to message: ChatMessage) {
        guard let child = allMembers.first(where: { $0.appleUserID == message.senderAppleUserID }),
              child.isChild else { return }

        message.toggleReaction(Self.coinReactionKey, by: authManager.userName)
        pushReactionUpdate(message)

        let task = Item(
            name: "Chat Bonus from \(authManager.userName)",
            targetDate: Date(),
            assignedTo: child.name,
            reward: 1,
            status: "approved",
            createdBy: authManager.userName,
            createdByID: authManager.appleUserID
        )
        task.giftText = message.id.uuidString
        modelContext.insert(task)

        child.addReward(task.reward)

        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
    }

    private func undoCoinAward(from message: ChatMessage) {
        guard let child = allMembers.first(where: { $0.appleUserID == message.senderAppleUserID }),
              child.isChild else { return }

        message.toggleReaction(Self.coinReactionKey, by: authManager.userName)
        pushReactionUpdate(message)

        let msgID = message.id.uuidString
        if let bonusTask = allTasks.first(where: { $0.giftText == msgID && $0.assignedTo == child.name && $0.name.hasPrefix("Chat Bonus") }) {
            let taskID = bonusTask.id
            modelContext.delete(bonusTask)
            Task { await cloudKitManager.deleteRemoteTasks([taskID]) }
        }
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty || pendingPhotoData != nil else { return }

        let message = ChatMessage(
            senderName: authManager.userName,
            senderAvatar: authManager.avatar,
            senderAppleUserID: authManager.appleUserID,
            text: trimmed,
            attachmentData: pendingPhotoData
        )
        modelContext.insert(message)
        messageText = ""
        pendingPhotoData = nil
        selectedPhoto = nil

        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushChatMessage(message, familyCode: familyCode) }

        markChatAsRead()
    }

    private func deletePhoto(from message: ChatMessage) {
        message.attachmentData = nil
        message.attachmentName = ""
        message.attachmentType = "image"

        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushChatMessage(message, familyCode: familyCode) }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, FamilyMember.self, RewardRedemption.self, ShoppingItem.self, ChatMessage.self], inMemory: true)
        .environment(AuthManager())
        .environment(NotificationManager())
        .environment(SubscriptionManager())
        .environment(CloudKitManager())
}
